#!/usr/bin/env python3
"""Stage an IP into the unified repository directly from build results.

Ownership: cbbrepo-management / stage_ip (unified repo phase 1).

Input : ip_<name>/ workspace with release/<ip>_<version>/manifest.yaml +
        real deliverable files (rtl/, docs/, fusesoc/, ...) produced by
        ip-development-suite 18-release-packager.
Output: <unified>/ips/<vendor>/<ip>/<version>/ populated from the workspace
        (NOT from the .zip archive).

Steps:
  1. Load config (vendor/library/unified repo)
  2. Locate the single release/<ip>_<version>/manifest.yaml
  3. Copy every manifest file from the workspace into the version dir,
     verifying SHA-256 against the manifest
  4. Copy release_note.md + manifest.yaml as evidence
  5. Reuse fusesoc/*.core from the build results (no regeneration)
  6. Generate README.md / LICENSE / CHANGELOG.md / ip-package.yaml

Usage:
  python -m scripts.stage_ip <ip-workspace> [--unified dir] [--config path]
                             [--version V] [--then-index] [--then-publish]
"""

from __future__ import annotations

import argparse
import hashlib
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.exit("PyYAML required: pip install pyyaml")

from scripts.config import load_config, ip_rel_dir

LICENSES = {
    "MIT": """MIT License

Copyright (c) 2026 rtl-team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
""",
    "Apache-2.0": """Apache License 2.0

Copyright (c) 2026 rtl-team

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
""",
}


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def find_manifest(workspace: Path, version: Optional[str] = None) -> tuple[Path, dict[str, Any]]:
    """Locate the single release/<ip>_<version>/manifest.yaml.

    Returns (manifest_path, manifest). Raises FileNotFoundError / ValueError.
    """
    release_dir = workspace / "release"
    if not release_dir.is_dir():
        raise FileNotFoundError(f"No release/ directory in {workspace}")

    if version:
        candidates = [release_dir / f"{version}" / "manifest.yaml"]
    else:
        candidates = sorted(release_dir.glob("*/manifest.yaml"))
        if len(candidates) > 1:
            names = ", ".join(c.parent.name for c in candidates)
            raise ValueError(
                f"Multiple release manifests found ({names}); pass --version"
            )
    if not candidates or not candidates[0].is_file():
        raise FileNotFoundError(
            f"No manifest.yaml found under {release_dir}"
        )
    manifest_path = candidates[0]
    manifest = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    if not isinstance(manifest, dict) or "ip_name" not in manifest:
        raise ValueError(f"Invalid manifest: {manifest_path}")
    return manifest_path, manifest


def copy_manifest_files(
    workspace: Path,
    manifest: dict[str, Any],
    version_dir: Path,
) -> list[str]:
    """Copy every file listed in manifest from the workspace into version_dir.

    Verifies SHA-256 of each copied file against the manifest. Returns list of
    copied paths (POSIX relative to version_dir). Raises ValueError on mismatch.
    """
    copied: list[str] = []
    errors: list[str] = []
    for entry in manifest.get("files", []):
        if not isinstance(entry, dict) or "path" not in entry:
            continue
        rel = entry["path"]
        src = workspace / rel
        if not src.is_file():
            errors.append(f"missing in workspace: {rel}")
            continue
        dst = version_dir / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
        actual = sha256_file(dst)
        expected = entry.get("sha256")
        if expected and actual != expected:
            errors.append(f"SHA-256 mismatch: {rel} ({actual[:12]}... != {expected[:12]}...)")
            continue
        copied.append(rel)
    if errors:
        raise ValueError("Staging failed:\n  " + "\n  ".join(errors))
    return copied


def copy_evidence(workspace: Path, manifest_path: Path, version_dir: Path) -> None:
    """Copy manifest.yaml + release_note.md into the version dir as evidence."""
    shutil.copyfile(manifest_path, version_dir / "manifest.yaml")
    note = manifest_path.parent / "release_note.md"
    if note.is_file():
        shutil.copyfile(note, version_dir / "release_note.md")


# Reports copied by stage (independent of manifest role classification):
REPORT_DIRS = (
    "reports/quality", "reports/lint", "reports/elab", "reports/synth",
    "reports/formal", "reports/smoke", "reports/regression",
)


def copy_reports(workspace: Path, version_dir: Path) -> list[str]:
    """Copy quality/verification report evidence into the version dir.

    ip-development-suite keeps gate reports, lint/elab/synth/formal results and
    run_log under <workspace>/reports/. These are essential release evidence and
    should be shipped with the IP version even when the frozen manifest does not
    list them (some manifests exclude scratch-y reports). Copies only textual
    report artifacts, skipping EDA scratch (simv*, *.daidir, work/, logs with
    huge binary content). Returns list of copied relative paths.
    """
    if not workspace.is_dir():
        return []
    copied: list[str] = []
    for sub in REPORT_DIRS:
        src_dir = workspace / sub
        if not src_dir.is_dir():
            continue
        dst_dir = version_dir / sub
        dst_dir.mkdir(parents=True, exist_ok=True)
        for src in sorted(src_dir.rglob("*")):
            if not src.is_file():
                continue
            rel = src.relative_to(workspace).as_posix()
            name = src.name
            if name in ("simv", "simv.vdb") or name.endswith((".daidir", ".log.gz")):
                continue
            dst = version_dir / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, dst)
            copied.append(rel)
    return copied


def copy_fusesoc_cores(workspace: Path, version_dir: Path) -> list[str]:
    """Reuse fusesoc/*.core produced by ip-development-suite 08-fusesoc-packager.

    Returns list of copied core file names. No regeneration.
    """
    src_dir = workspace / "fusesoc"
    dst_dir = version_dir / "fusesoc"
    copied: list[str] = []
    if src_dir.is_dir():
        dst_dir.mkdir(parents=True, exist_ok=True)
        for core in sorted(src_dir.glob("*.core")):
            shutil.copyfile(core, dst_dir / core.name)
            copied.append(core.name)
    return copied


def generate_readme(
    manifest: dict[str, Any],
    release_note: str,
    config: dict[str, Any],
    rel_dir: Path,
) -> str:
    ip_name = manifest["ip_name"]
    version = manifest["version"]
    vendor = config.get("fusesoc", {}).get("vendor", "rtl-team")
    library = config.get("fusesoc", {}).get("library", "rtl")
    gates = {}
    if isinstance(manifest.get("quality"), dict):
        qg = manifest["quality"].get("gates")
        if isinstance(qg, dict):
            gates = qg
        elif "g5_status" in manifest["quality"]:
            for i in range(6):
                gates[f"G{i}"] = (
                    "pass"
                    if i < 5 or manifest["quality"]["g5_status"] == "pass"
                    else manifest["quality"]["g5_status"]
                )
    rows = "\n".join(
        f"| G{i} | {gates.get(f'G{i}', 'unknown')} |" for i in range(6)
    )
    return f"""# {ip_name}

{manifest.get('description', 'IP description')}

## Version

- **Version**: {version}
- **Released**: {_now()}
- **Unified repo path**: `{rel_dir}`

## Quality Gates

| Gate | Status |
|------|--------|
{rows}

## License

{config.get('template', {}).get('license', 'MIT')}

## Usage (FuseSoC)

The unified repository is added once:

```bash
fusesoc library add ip-unified https://github.com/{{org}}/ip-unified.git
fusesoc run --target sim {vendor}:{library}:{ip_name}:{version}
```

## Release Notes

{release_note}
"""


def generate_changelog(ip_name: str, version: str, release_note: str) -> str:
    return f"""# Changelog

All notable changes to {ip_name} are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [{version}] - {_now()}

{release_note}
"""


def generate_ip_package(
    manifest: dict[str, Any],
    release_note: str,
    config: dict[str, Any],
    rel_dir: Path,
    license_type: str,
) -> dict[str, Any]:
    ip_name = manifest["ip_name"]
    version = manifest["version"]
    vendor = config.get("fusesoc", {}).get("vendor", "rtl-team")
    library = config.get("fusesoc", {}).get("library", "rtl")
    gates = {}
    if isinstance(manifest.get("quality"), dict):
        qg = manifest["quality"].get("gates")
        if isinstance(qg, dict):
            gates = qg
    description = manifest.get("description", "")
    if not description and release_note.strip():
        for line in release_note.splitlines():
            line = line.strip()
            if line and not line.startswith("#") and not line.startswith("-") and not line.startswith("*"):
                description = line
                break
    return {
        "schema_version": "2.0",
        "name": ip_name,
        "version": version,
        "vendor": vendor,
        "library": library,
        "description": description,
        "license": license_type,
        "path": str(rel_dir),
        "quality": gates,
        "dependencies": manifest.get("dependencies", []),
        "fusesoc": {
            "core": f"{vendor}:{library}:{ip_name}:{version}",
            "cores": f"{rel_dir}/fusesoc",
        },
    }


def stage_ip(
    workspace: Path,
    unified: Optional[Path] = None,
    config: Optional[dict[str, Any]] = None,
    version: Optional[str] = None,
) -> Path:
    """Stage an IP from build results into the unified repo. Returns version dir."""
    if config is None:
        config = load_config()

    manifest_path, manifest = find_manifest(workspace, version)
    ip_name = manifest["ip_name"]
    ver = str(manifest["version"])

    rel_dir = ip_rel_dir(config, ip_name, ver)
    if unified is None:
        unified = workspace.parent / "ip-unified"
    version_dir = unified / rel_dir
    version_dir.mkdir(parents=True, exist_ok=True)

    print(f"Staging {ip_name} {ver} -> {version_dir}")

    # 1. Copy manifest-listed files from workspace (verify SHA-256)
    copied = copy_manifest_files(workspace, manifest, version_dir)
    print(f"  copied {len(copied)} files from workspace")

    # 2. Evidence: manifest.yaml + release_note.md
    copy_evidence(workspace, manifest_path, version_dir)

    # 2b. Quality/verification reports (gate reports, lint/elab/synth/formal)
    reports = copy_reports(workspace, version_dir)
    if reports:
        print(f"  copied {len(reports)} report evidence files")

    # 3. Reuse fusesoc cores (08-fusesoc-packager output)
    cores = copy_fusesoc_cores(workspace, version_dir)
    if not cores:
        print("  WARNING: no fusesoc/*.core found; run 08-fusesoc-packager first")

    # 4. README / LICENSE / CHANGELOG
    note_path = manifest_path.parent / "release_note.md"
    release_note = note_path.read_text(encoding="utf-8") if note_path.is_file() else ""
    (version_dir / "README.md").write_text(
        generate_readme(manifest, release_note, config, rel_dir), encoding="utf-8"
    )
    license_type = config.get("template", {}).get("license", "MIT")
    (version_dir / "LICENSE").write_text(
        LICENSES.get(license_type, LICENSES["MIT"]), encoding="utf-8"
    )
    if config.get("template", {}).get("changelog", True):
        (version_dir / "CHANGELOG.md").write_text(
            generate_changelog(ip_name, ver, release_note), encoding="utf-8"
        )

    # 5. ip-package.yaml
    pkg = generate_ip_package(manifest, release_note, config, rel_dir, license_type)
    pkg_path = version_dir / "ip-package.yaml"
    # Compute manifest_sha256 from the copied manifest.yaml
    pkg["manifest_sha256"] = sha256_file(version_dir / "manifest.yaml")
    pkg_path.write_text(
        yaml.safe_dump(pkg, sort_keys=False, allow_unicode=True), encoding="utf-8"
    )

    print(f"STAGE COMPLETE: {rel_dir}")
    return version_dir


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Stage IP into unified repo")
    parser.add_argument("workspace", type=Path, help="IP workspace path")
    parser.add_argument("--unified", type=Path, help="unified repo root (default ../ip-unified)")
    parser.add_argument("--config", type=Path, help="config file path")
    parser.add_argument("--version", help="specify version (multiple releases)")
    parser.add_argument("--then-index", action="store_true", help="update registry after stage")
    parser.add_argument("--then-publish", action="store_true", help="index + publish after stage")
    args = parser.parse_args(argv)

    config = load_config(args.config)
    try:
        version_dir = stage_ip(args.workspace, args.unified, config, args.version)
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}")
        return 1

    unified = args.unified or args.workspace.parent / "ip-unified"
    if args.then_index or args.then_publish:
        from scripts.update_registry import update_registry

        update_registry(unified, config, dry_run=False)
    if args.then_publish:
        from scripts.publish_repo import publish_repo

        return publish_repo(unified, config=config, dry_run=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
