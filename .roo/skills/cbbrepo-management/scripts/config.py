#!/usr/bin/env python3
"""Configuration loading for ipkg (unified repo architecture).

Ownership: cbbrepo-management / config.

Load order (first match wins):
  1. --config path (explicit)
  2. $IPKG_CONFIG
  3. ./ipkg.yaml
  4. ~/.config/ipkg/config.yaml
  5. /etc/ipkg/config.yaml
  6. built-in defaults
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any, Dict, Optional

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None


DEFAULTS: Dict[str, Any] = {
    "schema_version": "2.0",
    "github": {
        "org": "rtl-team",
        "auth": "ssh-key",
        "token_env": "GITHUB_TOKEN",
        "unified_repo": "ip-unified",
    },
    "fusesoc": {"vendor": "rtl-team", "library": "rtl", "cores_dir": "fusesoc"},
    "publish": {
        "default_class": "formal",
        "auto_tag": True,
        "auto_push": True,
        "tag_with_ip": True,
        "checks": ["g5_pass", "valid_manifest", "files_hash_ok"],
    },
    "template": {"license": "MIT", "changelog": True, "readme_template": "default"},
}


def _candidate_paths(explicit: Optional[Path]) -> list[Path]:
    candidates: list[Path] = []
    if explicit is not None:
        candidates.append(explicit)
    env = os.environ.get("IPKG_CONFIG")
    if env:
        candidates.append(Path(env))
    candidates.append(Path.cwd() / "ipkg.yaml")
    candidates.append(Path.home() / ".config" / "ipkg" / "config.yaml")
    candidates.append(Path("/etc/ipkg/config.yaml"))
    return candidates


def deep_merge(base: Dict[str, Any], override: Dict[str, Any]) -> Dict[str, Any]:
    """Recursively merge override dict into base (override wins on scalars)."""
    result = dict(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result


def load_config(explicit: Optional[Path] = None) -> Dict[str, Any]:
    """Load configuration from the first available source."""
    if yaml is None:
        return dict(DEFAULTS)
    config = deep_merge({}, DEFAULTS)
    for candidate in _candidate_paths(explicit):
        if candidate.is_file():
            try:
                data = yaml.safe_load(candidate.read_text(encoding="utf-8"))
            except yaml.YAMLError:
                continue
            if isinstance(data, dict):
                config = deep_merge(config, data)
                break
    return config


def unified_repo_name(config: Dict[str, Any]) -> str:
    """Return the unified repository name (default ip-unified).

    May be overridden by the IPKG_UNIFIED_REPO environment variable.
    """
    env = os.environ.get("IPKG_UNIFIED_REPO")
    if env:
        return env
    return config.get("github", {}).get("unified_repo", "ip-unified")


def unified_repo_url(config: Dict[str, Any]) -> str:
    """Compute the HTTPS clone URL for the unified repository."""
    org = config.get("github", {}).get("org", "rtl-team")
    repo = unified_repo_name(config)
    return f"https://github.com/{org}/{repo}.git"


def unified_repo_ssh_url(config: Dict[str, Any]) -> str:
    """Compute the SSH clone URL for the unified repository."""
    org = config.get("github", {}).get("org", "rtl-team")
    repo = unified_repo_name(config)
    return f"git@github.com:{org}/{repo}.git"


def ip_rel_dir(config: Dict[str, Any], ip_name: str, version: str = "") -> Path:
    """Relative directory of an IP inside the unified repo.

    ips/<vendor>/<ip>/[<version>]
    """
    vendor = config.get("fusesoc", {}).get("vendor", "rtl-team")
    rel = Path("ips") / vendor / ip_name
    if version:
        rel = rel / version
    return rel


def tag_for(config: Dict[str, Any], ip_name: str, version: str) -> str:
    """Tag name for an IP version inside the unified repo.

    tag_with_ip=True (default) -> <ip>-v<version>  (avoids collisions across IPs)
    tag_with_ip=False          -> v<version>
    """
    if config.get("publish", {}).get("tag_with_ip", True):
        return f"{ip_name}-v{version}"
    return f"v{version}"
