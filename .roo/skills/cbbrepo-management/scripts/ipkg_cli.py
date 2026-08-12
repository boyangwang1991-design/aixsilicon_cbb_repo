#!/usr/bin/env python3
"""ipkg - IP Repository Management CLI (unified repo architecture).

Ownership: cbbrepo-management.

Commands:
  init        - create a default ipkg config file
  init-repo   - initialize a unified repository (monorepo) from template
  config      - show effective configuration
  validate    - validate an ip-development-suite build result (manifest + files)
  stage       - stage an IP into the unified repo from build results (phase 1)
  index       - update the embedded registry.yaml (phase 2)
  publish     - commit/push the unified repo + tags (phase 3)
  search      - search the registry for IPs
  list        - list all IPs in the registry
  info        - show details of a specific IP version

Usage:
  python -m scripts.ipkg_cli <command> [options]
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import urllib.request
from copy import deepcopy
from pathlib import Path
from typing import Any, Dict

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.exit("PyYAML required: pip install pyyaml")

from scripts.config import load_config, unified_repo_url, unified_repo_name


def cmd_init(args: argparse.Namespace) -> int:
    """Create a default config file."""
    from scripts.config import DEFAULTS

    target = args.output or (Path.home() / ".config" / "ipkg" / "config.yaml")
    config = deepcopy(DEFAULTS)
    if args.org:
        config["github"]["org"] = args.org
    if args.unified_repo:
        config["github"]["unified_repo"] = args.unified_repo

    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        yaml.safe_dump(config, sort_keys=False, allow_unicode=True),
        encoding="utf-8",
    )
    print(f"Config written to: {target}")
    print("  Edit it to set github.org and github.unified_repo before publishing.")
    return 0


def cmd_init_repo(args: argparse.Namespace) -> int:
    """Initialize a unified repository from the bundled template."""
    suite = Path(__file__).resolve().parents[1]  # .roo/skills/cbbrepo-management
    template = suite / "unified-repo-template"
    if not template.is_dir():
        print(f"ERROR: template not found: {template}")
        return 1

    output = args.output or (Path.cwd() / (args.name or "ip-unified"))
    if output.exists() and any(output.iterdir()):
        print(f"ERROR: output dir not empty: {output}")
        return 1
    shutil.copytree(template, output)

    # Inject org / unified repo name into the registry skeleton
    reg_path = output / "registry.yaml"
    if reg_path.is_file():
        org = args.org or "rtl-team"
        name = args.name or unified_repo_name(load_config())
        data = yaml.safe_load(reg_path.read_text(encoding="utf-8")) or {}
        data["unified_repo"] = f"https://github.com/{org}/{name}.git"
        reg_path.write_text(
            yaml.safe_dump(data, sort_keys=False, allow_unicode=True),
            encoding="utf-8",
        )

    print(f"Unified repo initialized at: {output}")
    print("  Next: git init + add remote + push, then ipkg stage ...")
    return 0


def cmd_config(args: argparse.Namespace) -> int:
    config = load_config(args.config)
    print(yaml.safe_dump(config, sort_keys=False, allow_unicode=True))
    return 0


def cmd_validate(args: argparse.Namespace) -> int:
    """Validate an ip-development-suite build result (manifest + workspace files)."""
    from scripts.validate_release import main as validate_main

    argv = [str(args.workspace)]
    if args.config:
        argv += ["--config", str(args.config)]
    if args.strict:
        argv.append("--strict")
    return validate_main(argv)


def cmd_stage(args: argparse.Namespace) -> int:
    """Stage an IP into the unified repo from build results (phase 1)."""
    from scripts.stage_ip import main as stage_main

    argv = [str(args.workspace)]
    if args.unified:
        argv += ["--unified", str(args.unified)]
    if args.config:
        argv += ["--config", str(args.config)]
    if args.version:
        argv += ["--version", args.version]
    if getattr(args, "then_index", False):
        argv.append("--then-index")
    if getattr(args, "then_publish", False):
        argv.append("--then-publish")
    return stage_main(argv)


def cmd_index(args: argparse.Namespace) -> int:
    """Update the embedded registry.yaml (phase 2)."""
    from scripts.update_registry import main as index_main

    argv = ["--unified", str(args.unified)]
    if args.ip:
        argv += ["--ip", args.ip]
    if args.config:
        argv += ["--config", str(args.config)]
    if args.dry_run:
        argv.append("--dry-run")
    return index_main(argv)


def cmd_publish(args: argparse.Namespace) -> int:
    """Commit/push the unified repo + tags (phase 3)."""
    from scripts.publish_repo import main as publish_main

    argv = [str(args.unified_repo)]
    if args.config:
        argv += ["--config", str(args.config)]
    if args.dry_run:
        argv.append("--dry-run")
    if args.no_tag:
        argv.append("--no-tag")
    if args.no_push:
        argv.append("--no-push")
    return publish_main(argv)


def _fetch_registry(config: dict) -> Dict[str, Any]:
    """Fetch registry.yaml from the unified repo (raw GitHub or local)."""
    url = unified_repo_url(config)
    repo = unified_repo_name(config)
    branch = "main"
    if "github.com" in url:
        path = url.split("github.com/")[-1].replace(".git", "")
        owner = path.split("/")[0]
        raw_url = f"https://raw.githubusercontent.com/{owner}/{repo}/{branch}/registry.yaml"
        try:
            with urllib.request.urlopen(raw_url, timeout=15) as resp:
                data = yaml.safe_load(resp.read().decode("utf-8"))
            return data if isinstance(data, dict) else {"ips": []}
        except Exception as exc:
            raise RuntimeError(f"failed to fetch registry: {exc}")
    raise RuntimeError(f"unified repo URL is not a GitHub URL: {url}")


def _print_table(rows: list[list[str]]) -> None:
    widths = [max(len(cell) for cell in col) for col in zip(*rows)] if rows else []
    for row in rows:
        print("  " + "  ".join(cell.ljust(w) for cell, w in zip(row, widths)))


def cmd_search(args: argparse.Namespace) -> int:
    config = load_config(args.config)
    try:
        registry = _fetch_registry(config)
    except RuntimeError as exc:
        print(f"ERROR: {exc}")
        return 1

    pattern = (args.pattern or "*").lower()
    import fnmatch

    ips = registry.get("ips", [])
    matched = [ip for ip in ips if fnmatch.fnmatch(ip.get("name", "").lower(), pattern)]

    if args.format == "json":
        print(json.dumps(matched, indent=2, ensure_ascii=False))
        return 0

    rows = [["IP", "Latest", "Versions", "Path"]]
    for ip in matched:
        versions = ip.get("versions", [])
        latest = versions[-1]["version"] if versions else "-"
        vers = ", ".join(v["version"] for v in versions)
        rows.append([ip.get("name", "-"), latest, vers, ip.get("path", "-")])
    if len(rows) == 1:
        print("No matching IPs.")
    else:
        _print_table(rows)
    return 0


def cmd_list(args: argparse.Namespace) -> int:
    return cmd_search(argparse.Namespace(pattern="*", config=args.config, format=args.format))


def cmd_info(args: argparse.Namespace) -> int:
    config = load_config(args.config)
    try:
        registry = _fetch_registry(config)
    except RuntimeError as exc:
        print(f"ERROR: {exc}")
        return 1

    ip = next((x for x in registry.get("ips", []) if x.get("name") == args.ip), None)
    if ip is None:
        print(f"ERROR: IP not found: {args.ip}")
        return 1

    versions = ip.get("versions", [])
    if args.version:
        version = next((v for v in versions if v.get("version") == args.version), None)
    else:
        version = versions[-1] if versions else None

    if version is None:
        print(f"ERROR: version not found: {args.version or 'latest'}")
        return 1

    print(f"IP:            {ip.get('name')}")
    print(f"Description:   {ip.get('description', '-')}")
    print(f"Path:          {ip.get('path', '-')}")
    print(f"Version:       {version.get('version')}")
    print(f"Tag:           {version.get('tag', '-')}")
    print(f"Released:      {version.get('released', '-')}")
    print(f"FuseSoC core:  {version.get('fusesoc', {}).get('core', '-')}")
    gates = version.get("gates", {})
    if gates:
        print("Gates:         " + ", ".join(f"{k}={v}" for k, v in gates.items()))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="ipkg",
        description="IP Repository Management CLI (unified repo)",
    )
    parser.add_argument("--config", type=Path, help="path to ipkg config file")
    sub = parser.add_subparsers(dest="command", required=True)

    p_init = sub.add_parser("init", help="create default config")
    p_init.add_argument("--org", help="GitHub org/user")
    p_init.add_argument("--unified-repo", help="unified repo name (default ip-unified)")
    p_init.add_argument("--output", type=Path, help="output path for config")
    p_init.set_defaults(func=cmd_init)

    p_init_repo = sub.add_parser("init-repo", help="initialize unified repo from template")
    p_init_repo.add_argument("--org", help="GitHub org/user")
    p_init_repo.add_argument("--name", help="unified repo name (default ip-unified)")
    p_init_repo.add_argument("--output", type=Path, help="output directory")
    p_init_repo.set_defaults(func=cmd_init_repo)

    p_config = sub.add_parser("config", help="show effective config")
    p_config.set_defaults(func=cmd_config)

    p_validate = sub.add_parser("validate", help="validate build result")
    p_validate.add_argument("workspace", type=Path, help="IP workspace path")
    p_validate.add_argument("--strict", action="store_true", help="require exact SHA-256")
    p_validate.set_defaults(func=cmd_validate)

    p_stage = sub.add_parser("stage", help="stage IP into unified repo (phase 1)")
    p_stage.add_argument("workspace", type=Path, help="IP workspace path")
    p_stage.add_argument("--unified", type=Path, help="unified repo root")
    p_stage.add_argument("--version", help="specify version (multiple releases)")
    p_stage.add_argument("--then-index", action="store_true", help="update registry after stage")
    p_stage.add_argument("--then-publish", action="store_true", help="index + publish after stage")
    p_stage.set_defaults(func=cmd_stage)

    p_index = sub.add_parser("index", help="update embedded registry (phase 2)")
    p_index.add_argument("--unified", type=Path, required=True, help="unified repo root")
    p_index.add_argument("--ip", help="only update this IP")
    p_index.add_argument("--dry-run", action="store_true")
    p_index.set_defaults(func=cmd_index)

    p_publish = sub.add_parser("publish", help="publish unified repo (phase 3)")
    p_publish.add_argument("unified_repo", type=Path, help="unified repo path")
    p_publish.add_argument("--dry-run", action="store_true")
    p_publish.add_argument("--no-tag", action="store_true")
    p_publish.add_argument("--no-push", action="store_true")
    p_publish.set_defaults(func=cmd_publish)

    p_search = sub.add_parser("search", help="search registry")
    p_search.add_argument("pattern", nargs="?", default="*", help="name pattern (glob)")
    p_search.add_argument("--format", choices=["table", "json"], default="table")
    p_search.set_defaults(func=cmd_search)

    p_list = sub.add_parser("list", help="list all IPs in registry")
    p_list.add_argument("--format", choices=["table", "json"], default="table")
    p_list.set_defaults(func=cmd_list)

    p_info = sub.add_parser("info", help="show IP info")
    p_info.add_argument("ip", help="IP name")
    p_info.add_argument("version", nargs="?", help="version (default latest)")
    p_info.set_defaults(func=cmd_info)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
