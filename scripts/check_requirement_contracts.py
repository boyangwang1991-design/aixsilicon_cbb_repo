#!/usr/bin/env python3
"""Check registry coverage and freshness of human-readable requirement contracts."""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

import yaml


def check(root: Path) -> tuple[list[str], dict[str, int]]:
    root = root.resolve()
    errors: list[str] = []
    counts = {"draft": 0, "derived": 0}
    registry = yaml.safe_load((root / "registry.yaml").read_text())
    for entry in registry["cbbs"]:
        name = entry["name"]
        try:
            package = (root / entry["path"]).resolve()
            package.relative_to(root)
            contract = package / f"{name}_contract.md"
            contract.resolve().relative_to(package)
            content = contract.read_text()
            parts = content.split("---\n", 2)
            if len(parts) != 3 or parts[0]:
                raise ValueError("missing YAML frontmatter")
            meta = yaml.safe_load(parts[1])
            expected = {"document_type": "cbb-requirements", "registry_id": entry["id"],
                        "name": name, "version": str(entry["version"])}
            for field, value in expected.items():
                if meta.get(field) != value:
                    raise ValueError(f"{field}: expected {value!r}")
            status = meta.get("status")
            if status not in counts:
                raise ValueError("status must be draft or derived")
            basis = "existing_yaml" if status == "derived" else "planning_intent"
            if meta.get("basis") != basis:
                raise ValueError("basis/status mismatch")
            if len(parts[2].strip()) < 300:
                raise ValueError("contract body is empty or incomplete")
            if status == "derived":
                hashes = meta.get("source_hashes", {})
                if "cbb.yaml" not in hashes:
                    raise ValueError("derived contract requires cbb.yaml source hash")
                for source, digest in hashes.items():
                    file = (package / source).resolve()
                    file.relative_to(package)
                    if hashlib.sha256(file.read_bytes()).hexdigest() != digest:
                        raise ValueError(f"stale source: {source}; regenerate derived view")
            else:
                if (package / "cbb.yaml").exists():
                    raise ValueError("YAML now exists; reconcile planning intent and derive view")
                for token in [*(f"| REQ-{i:03d} |" for i in range(1, 10)),
                              *(f"| AC-{i:02d} " for i in range(1, 7))]:
                    if sum(line.startswith(token) for line in parts[2].splitlines()) != 1:
                        raise ValueError(f"missing or duplicate requirement/acceptance row: {token}")
            readme = (package / "README.md").read_text()
            if f"({name}_contract.md)" not in readme:
                raise ValueError("README missing contract link")
            counts[status] += 1
        except (OSError, ValueError, TypeError, AttributeError, yaml.YAMLError) as exc:
            errors.append(f"{name}: {exc}")
    return errors, counts


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    errors, counts = check(args.root)
    for error in errors:
        print(f"ERROR: {error}")
    print(f"Contracts: {counts['draft']} draft, {counts['derived']} derived; {len(errors)} errors")
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
