#!/usr/bin/env python3
"""Validate an ip-development-suite build result for staging into the unified repo.

Ownership: cbbrepo-management / validate_release.

The input is the IP workspace (build result), NOT a zip archive. Checks:
  1. release/<ip>_<version>/manifest.yaml exists and is valid YAML
  2. manifest fields: schema_version, ip_name, version (SemVer)
  3. G5 quality gates all pass (model/quality.yaml)
  4. Every manifest file exists in the workspace and SHA-256 matches (--strict)

Usage:
  python -m scripts.validate_release <ip-workspace> [--config path] [--strict]
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path
from typing import Any, Dict, Tuple

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.exit("PyYAML required: pip install pyyaml")

SEMVER_RE = re.compile(
    r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
    r"(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)"
    r"(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?"
    r"(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$"
)

PASSING_PROFILES = {"commercial-systemverilog", "commercial-verilog", "opensource"}


def sha256_file(path: Path) -> str:
    """Compute SHA-256 of a file."""
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def is_semver(version: str) -> bool:
    """Return True if the version string is valid SemVer 2.0.0."""
    return bool(SEMVER_RE.match(version or ""))


def find_release_dir(workspace: Path, version: str = "") -> Tuple[Path, Path]:
    """Locate release/ directory and the (optionally versioned) manifest.yaml.

    Returns (release_dir, manifest_path). Raises FileNotFoundError otherwise.
    """
    release_dir = workspace / "release"
    if not release_dir.is_dir():
        raise FileNotFoundError(f"No release/ directory in {workspace}")
    if version:
        manifests = [release_dir / version / "manifest.yaml"]
    else:
        manifests = sorted(release_dir.glob("*/manifest.yaml"))
    manifests = [m for m in manifests if m.is_file()]
    if not manifests:
        raise FileNotFoundError(f"No manifest.yaml found under {release_dir}")
    if len(manifests) > 1:
        raise ValueError(
            "Multiple manifests found; pass explicit version to disambiguate: "
            + ", ".join(str(m.parent.name) for m in manifests)
        )
    return release_dir, manifests[0]


def validate_manifest(manifest_path: Path) -> Tuple[bool, Dict[str, Any]]:
    """Validate manifest.yaml structure and required fields."""
    try:
        manifest = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        return False, {"error": f"invalid YAML: {exc}"}
    if not isinstance(manifest, dict):
        return False, {"error": "manifest root must be a mapping"}

    for field in ("schema_version", "ip_name", "version"):
        if field not in manifest:
            return False, {"error": f"missing required field: {field}"}

    if not is_semver(str(manifest["version"])):
        return False, {"error": f"invalid SemVer version: {manifest['version']}"}

    if "files" in manifest:
        if not isinstance(manifest["files"], list):
            return False, {"error": "'files' must be a list"}
        for entry in manifest["files"]:
            if not isinstance(entry, dict) or "path" not in entry:
                return False, {"error": "each files entry needs a 'path' key"}

    return True, manifest


def validate_gates(workspace: Path, manifest: Dict[str, Any]) -> Tuple[bool, Dict[str, Any]]:
    """Validate that quality gates G0-G5 all pass (formal release)."""
    quality_path = workspace / "model" / "quality.yaml"
    gates: Dict[str, str] = {}
    if quality_path.exists():
        try:
            quality = yaml.safe_load(quality_path.read_text(encoding="utf-8"))
            for g in quality.get("gates", []) or []:
                if isinstance(g, dict):
                    gates[str(g.get("id"))] = str(g.get("status"))
        except yaml.YAMLError:
            pass

    # Fallback: gates embedded in manifest
    if not gates and isinstance(manifest.get("quality"), dict):
        mq = manifest["quality"]
        if isinstance(mq.get("gates"), dict):
            gates = {str(k): str(v) for k, v in mq["gates"].items()}
        elif "g5_status" in mq:
            for i in range(6):
                gates[f"G{i}"] = "pass" if i < 5 or mq["g5_status"] == "pass" else mq["g5_status"]

    missing = [f"G{i}" for i in range(6) if gates.get(f"G{i}") != "pass"]
    if missing:
        return False, {"error": "not all G0-G5 pass", "gates": gates, "missing": missing}
    return True, {"gates": gates}


def validate_workspace_files(
    workspace: Path,
    manifest: Dict[str, Any],
    strict: bool,
) -> Tuple[bool, Dict[str, Any]]:
    """Validate that every manifest file exists in the workspace.

    With strict=True, also verify SHA-256 matches the manifest.
    """
    problems: list[str] = []
    checked = 0
    for entry in manifest.get("files", []):
        if not isinstance(entry, dict) or "path" not in entry:
            continue
        rel = entry["path"]
        src = workspace / rel
        if not src.is_file():
            problems.append(f"missing in workspace: {rel}")
            continue
        checked += 1
        if strict and entry.get("sha256"):
            actual = sha256_file(src)
            if actual != entry["sha256"]:
                problems.append(
                    f"SHA-256 mismatch: {rel} "
                    f"({actual[:12]}... != {entry['sha256'][:12]}...)"
                )

    if problems:
        return False, {"problems": problems, "checked": checked}
    return True, {"checked": checked}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate IP build result")
    parser.add_argument("workspace", type=Path, help="IP workspace path (build result)")
    parser.add_argument("--config", type=Path, help="config file path (unused here)")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="require every manifest file SHA-256 to match the workspace",
    )
    parser.add_argument("--version", help="specific release version (multiple manifests)")
    args = parser.parse_args(argv)

    try:
        release_dir, manifest_path = find_release_dir(args.workspace, args.version or "")
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}")
        return 1

    print(f"Manifest: {manifest_path}")

    ok, manifest = validate_manifest(manifest_path)
    if not ok:
        print(f"ERROR: manifest invalid: {manifest['error']}")
        return 1
    print(f"  IP: {manifest['ip_name']}  version: {manifest['version']}")

    ok, gates = validate_gates(args.workspace, manifest)
    if not ok:
        print(f"ERROR: {gates['error']} ({gates.get('gates')})")
        return 1
    print("  Gates: G0-G5 all pass")

    ok, files = validate_workspace_files(args.workspace, manifest, args.strict)
    if not ok:
        for d in files.get("problems", []):
            print(f"ERROR: {d}")
        return 1
    print(f"  Workspace files: {files['checked']} present"
          + (" (SHA-256 verified)" if args.strict else " (not hashed; use --strict)"))

    print("VALIDATION PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
