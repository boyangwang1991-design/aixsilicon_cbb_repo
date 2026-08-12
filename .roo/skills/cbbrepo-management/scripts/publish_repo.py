#!/usr/bin/env python3
"""Publish the unified repository to GitHub (unified repo phase 3).

Ownership: cbbrepo-management / publish_repo.

Steps:
  1. Load config (org + unified repo name)
  2. git add/commit (ips/ changes + registry.yaml)
  3. Add remote + push main
  4. Create git tags for every IP version present in registry.yaml
     (tag format: <ip>-v<version> by default; see config: publish.tag_with_ip)

Requirements:
  - git on PATH
  - GITHUB_TOKEN or SSH key configured

Usage:
  python -m scripts.publish_repo <unified-repo> [--config path] [--dry-run] [--no-tag] [--no-push]
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, Optional

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.exit("PyYAML required: pip install pyyaml")

from scripts.config import (
    load_config,
    unified_repo_name,
    unified_repo_ssh_url,
    tag_for,
)


def run(cmd: list[str], cwd: Optional[Path] = None, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(cwd) if cwd else None, capture_output=True, text=True, check=check)


def git_available() -> bool:
    try:
        run(["git", "--version"], check=False)
        return True
    except FileNotFoundError:
        return False


def remote_url_for(config: dict) -> str:
    """Build the git remote URL for the unified repo based on auth type."""
    org = config.get("github", {}).get("org", "rtl-team")
    repo = unified_repo_name(config)
    auth = config.get("github", {}).get("auth", "ssh-key")
    if auth == "token":
        token = None
        env_name = config.get("github", {}).get("token_env", "GITHUB_TOKEN")
        if config.get("github", {}).get("auth") == "token":
            import os
            token = os.environ.get(env_name)
        if token:
            return f"https://{token}@github.com/{org}/{repo}.git"
        return f"https://github.com/{org}/{repo}.git"
    return f"git@github.com:{org}/{repo}.git"


def load_registry(unified: Path) -> dict[str, Any]:
    reg_path = unified / "registry.yaml"
    if not reg_path.is_file():
        raise FileNotFoundError(f"No registry.yaml in {unified}; run ipkg index first")
    data = yaml.safe_load(reg_path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("registry.yaml must be a mapping")
    return data


def collect_tags(registry: dict[str, Any], config: dict) -> list[str]:
    """Collect tags for all IP versions in the registry (sorted, de-duplicated)."""
    tags: list[str] = []
    for ip in registry.get("ips", []):
        name = ip.get("name", "")
        for v in ip.get("versions", []):
            ver = v.get("version", "")
            if name and ver:
                tags.append(tag_for(config, name, ver))
    return sorted(set(tags))


def publish_repo(
    unified: Path,
    config: Optional[dict] = None,
    dry_run: bool = False,
    auto_tag: bool = True,
    auto_push: bool = True,
) -> int:
    """Publish the unified repo. Returns process exit code."""
    if config is None:
        config = load_config()

    if not git_available():
        print("ERROR: git is not installed")
        return 1

    registry = load_registry(unified)
    org = config.get("github", {}).get("org", "rtl-team")
    repo = unified_repo_name(config)
    remote = remote_url_for(config)

    print(f"Publishing unified repo: {org}/{repo}")
    print(f"  remote: {remote}")

    # 1. git init if needed
    if not (unified / ".git").exists():
        run(["git", "init", "-b", "main"], cwd=unified)
        run(["git", "config", "user.name", "ipkg"], cwd=unified)
        run(["git", "config", "user.email", "ipkg@localhost"], cwd=unified)

    # 2. Stage + commit
    # R1: add 白名单，绝不 `git add -A`（避免误跟踪开发工作区/EDA scratch）
    # R3: dry-run 只读，不执行任何写操作（含 add/commit）
    WHITELIST = ("ips/", "registry.yaml", ".github/", "docs/",
                 "README.md", "LICENSE", "CHANGELOG.md")
    status = run(["git", "status", "--porcelain"], cwd=unified, check=False)
    lines = status.stdout.strip().splitlines() if status.stdout.strip() else []
    paths = [ln[3:] for ln in lines]  # strip "XY " status prefix
    outside = [p for p in paths if not p.startswith(WHITELIST)]
    if outside:
        print("WARNING: non-whitelist changes detected (R1):")
        for p in outside[:20]:
            print(f"    {p}")
        print("  STOP: refusing to auto-add non-whitelist paths; "
              "resolve first (gitignore/clean) then re-run")
        return 1
    ip_names = sorted({p.split("/")[2] for p in paths
                       if p.startswith("ips/") and len(p.split("/")) > 2})
    commit_msg = (f"Update unified IP repository "
                  f"({', '.join(ip_names) if ip_names else 'ips + registry'})")
    if not paths:
        print("  nothing to commit")
    elif dry_run:
        print(f"  (dry-run) would add: {', '.join(WHITELIST)}")
        print(f"  (dry-run) would commit: {commit_msg}")
    else:
        run(["git", "add", "ips/", "registry.yaml", ".github/", "docs/",
             "README.md", "LICENSE", "CHANGELOG.md"], cwd=unified)
        run(["git", "commit", "-m", commit_msg], cwd=unified)
        print(f"  committed: {commit_msg}")

    # 3. Add remote + push
    existing_remotes = run(["git", "remote"], cwd=unified, check=False).stdout.split()
    if "origin" not in existing_remotes:
        run(["git", "remote", "add", "origin", remote], cwd=unified)

    if auto_push and not dry_run:
        run(["git", "push", "-u", "origin", "main"], cwd=unified, check=False)
        print("  pushed to origin/main")
    else:
        print("  (push skipped)")

    # 4. Tags for every IP version
    tags = collect_tags(registry, config)
    if auto_tag and not dry_run:
        for tag in tags:
            run(["git", "tag", "-a", tag, "-m", f"Release {tag}"], cwd=unified, check=False)
            run(["git", "push", "origin", tag], cwd=unified, check=False)
        print(f"  tagged: {', '.join(tags)}")
    else:
        print(f"  (tags skipped: {', '.join(tags)})")

    print(f"PUBLISH COMPLETE: {org}/{repo}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Publish unified repo (phase 3)")
    parser.add_argument("unified_repo", type=Path, help="unified repo path")
    parser.add_argument("--config", type=Path, help="config file path")
    parser.add_argument("--dry-run", action="store_true", help="do not actually push/tag")
    parser.add_argument("--no-tag", action="store_true", help="do not create git tags")
    parser.add_argument("--no-push", action="store_true", help="do not push to remote")
    args = parser.parse_args(argv)

    config = load_config(args.config)
    auto_tag = config.get("publish", {}).get("auto_tag", True) and not args.no_tag
    auto_push = config.get("publish", {}).get("auto_push", True) and not args.no_push

    try:
        return publish_repo(
            args.unified_repo,
            config=config,
            dry_run=args.dry_run,
            auto_tag=auto_tag,
            auto_push=auto_push,
        )
    except (FileNotFoundError, ValueError) as exc:
        print(f"ERROR: {exc}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
