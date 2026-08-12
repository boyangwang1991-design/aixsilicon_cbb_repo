#!/usr/bin/env python3
"""Update the unified repository's embedded registry.yaml index.

Ownership: cbbrepo-management / update_registry (unified repo phase 2).

Unlike the old per-IP architecture (separate ip-registry repo + auto PR), the
index now lives inside the unified repo and is updated IN PLACE on the working
copy, so it is committed and pushed together with the ips/ changes.

Two operating modes:
  1. update_registry(...) - scan the unified repo and rebuild registry.yaml
     from every ips/**/ip-package.yaml (or update only --ip).
  2. `__main__` - standalone CLI.

Usage:
  python -m scripts.update_registry --unified <repo> [--ip <name>] [--config path] [--dry-run]
"""

from __future__ import annotations

import argparse
import datetime
import sys
from pathlib import Path
from typing import Any, Dict, Optional

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.exit("PyYAML required: pip install pyyaml")

from scripts.config import load_config, unified_repo_url, tag_for, ip_rel_dir


def _now_iso() -> str:
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _load_registry(path: Path) -> dict[str, Any]:
    if path.is_file():
        try:
            data = yaml.safe_load(path.read_text(encoding="utf-8"))
        except yaml.YAMLError:
            data = None
        if isinstance(data, dict) and "ips" in data:
            return data
    return {"schema_version": "2.0", "updated": _now_iso(), "ips": []}


def find_ip_packages(unified: Path) -> list[Path]:
    """Find all ips/**/ip-package.yaml in the unified repo.

    Layout: ips/<vendor>/<ip>/<version>/ip-package.yaml
    """
    ips_root = unified / "ips"
    if not ips_root.is_dir():
        return []
    return sorted(ips_root.glob("*/*/*/ip-package.yaml"))


def build_entry(ip_name: str, version: str, repo_url: str, config: dict,
                gates: Optional[Dict[str, str]] = None,
                description: str = "", path: str = "",
                manifest_sha256: str = "") -> dict[str, Any]:
    """Build a registry version entry (unified repo layout)."""
    vendor = config.get("fusesoc", {}).get("vendor", "rtl-team")
    library = config.get("fusesoc", {}).get("library", "rtl")
    entry = {
        "version": version,
        "tag": tag_for(config, ip_name, version),
        "released": _now_iso(),
        "path": path,
        "gates": gates or {f"G{i}": "pass" for i in range(6)},
        "description": description,
        "fusesoc": {"core": f"{vendor}:{library}:{ip_name}:{version}"},
    }
    if manifest_sha256:
        entry["manifest_sha256"] = manifest_sha256
    return entry


def upsert_registry(registry: dict[str, Any], entry: dict[str, Any], ip_name: str) -> dict[str, Any]:
    """Insert or update the entry for (ip_name, version). Returns new registry dict."""
    ips = registry.setdefault("ips", [])
    target = next((ip for ip in ips if ip.get("name") == ip_name), None)
    if target is None:
        target = {
            "name": ip_name,
            "vendor": entry.get("fusesoc", {}).get("core", "").split(":")[0],
            "library": entry.get("fusesoc", {}).get("core", "").split(":")[1],
            "description": entry.get("description", ""),
            "license": entry.get("license", "MIT"),
            "path": str(Path(entry["path"]).parent) if entry.get("path") else "",
            "versions": [],
        }
        ips.append(target)

    versions = target.setdefault("versions", [])
    existing = next((v for v in versions if v.get("version") == entry["version"]), None)
    if existing is not None:
        versions[versions.index(existing)] = entry
    else:
        versions.append(entry)

    def _key(v: str) -> list[int]:
        parts = []
        for part in v.split(".")[:3]:
            try:
                parts.append(int(part))
            except ValueError:
                parts.append(0)
        return parts

    versions.sort(key=lambda v: _key(v["version"]))

    registry["updated"] = _now_iso()
    return registry


def update_registry(
    unified: Path,
    config: dict,
    ip: Optional[str] = None,
    dry_run: bool = False,
) -> int:
    """Rebuild the embedded registry.yaml from ips/ content. Returns exit code."""
    registry_path = unified / "registry.yaml"
    registry = _load_registry(registry_path)
    registry["unified_repo"] = unified_repo_url(config)

    packages = find_ip_packages(unified)
    if ip:
        packages = [p for p in packages if p.parent.parent.name == ip]

    changed: list[str] = []
    for pkg_path in packages:
        pkg = yaml.safe_load(pkg_path.read_text(encoding="utf-8"))
        if not isinstance(pkg, dict):
            continue
        ip_name = pkg.get("name", "")
        version = str(pkg.get("version", ""))
        if not ip_name or not version:
            continue
        rel = pkg_path.parent.relative_to(unified)
        entry = build_entry(
            ip_name,
            version,
            unified_repo_url(config),
            config,
            gates=pkg.get("quality") or None,
            description=pkg.get("description", ""),
            path=str(rel),
            manifest_sha256=pkg.get("manifest_sha256", ""),
        )
        before = yaml.safe_dump(registry, sort_keys=False, allow_unicode=True)
        registry = upsert_registry(registry, entry, ip_name)
        after = yaml.safe_dump(registry, sort_keys=False, allow_unicode=True)
        if before != after:
            changed.append(f"{ip_name} {version}")

    if dry_run:
        print(f"[dry-run] would update {registry_path}")
        if changed:
            print("  changes: " + ", ".join(changed))
        return 0

    registry_path.parent.mkdir(parents=True, exist_ok=True)
    registry_path.write_text(
        yaml.safe_dump(registry, sort_keys=False, allow_unicode=True),
        encoding="utf-8",
    )
    if changed:
        print(f"INDEX UPDATED: {', '.join(changed)}")
    else:
        print("INDEX UNCHANGED")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Update unified repo embedded registry")
    parser.add_argument("--unified", type=Path, required=True, help="unified repo root")
    parser.add_argument("--ip", help="only update this IP (default: all)")
    parser.add_argument("--config", type=Path, help="config file path")
    parser.add_argument("--dry-run", action="store_true", help="print changes without applying")
    args = parser.parse_args(argv)

    config = load_config(args.config)
    return update_registry(args.unified, config, ip=args.ip, dry_run=args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
