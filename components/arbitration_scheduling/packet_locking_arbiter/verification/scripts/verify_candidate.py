#!/usr/bin/env python3
"""Verify candidate hashes and build/run its extracted FuseSoC dependency closure."""

from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import tarfile
import tempfile
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    out = ROOT / "build/releases"
    archive = out / "packet-locking-arbiter-0.1.0-candidate.tar.gz"
    with tempfile.TemporaryDirectory(prefix="replay-", dir=out) as tmp:
        base = Path(tmp)
        with tarfile.open(archive) as tar:
            for member in tar.getmembers():
                dest = (base / member.name).resolve()
                if not dest.is_relative_to(base.resolve()) or not member.isfile():
                    raise ValueError("Unsafe/non-file archive entry")
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(tar.extractfile(member).read())
        cbb = base / ROOT.name
        dep = base / "fixed_priority_arbiter"
        manifest = yaml.safe_load((cbb / "release/manifest.yaml").read_text())
        for artifact in manifest["artifacts"]:
            path = cbb / artifact["path"]
            if not path.resolve().is_relative_to(cbb.resolve()) or sha(path) != artifact["sha256"]:
                raise ValueError("Manifest hash mismatch: " + artifact["path"])
        sbom = manifest["sbom"]["dependencies"][0]
        if sha(dep / "rtl/fixed_priority_arbiter.sv") != sbom["rtl_sha256"]:
            raise ValueError("Dependency RTL hash mismatch")
        if sha(dep / "fusesoc/aixsilicon_cbb_fixed_priority_arbiter.core") != sbom["core_sha256"]:
            raise ValueError("Dependency core hash mismatch")
        cmd = [
            shutil.which("fusesoc"),
            "--cores-root",
            str(cbb),
            "--cores-root",
            str(dep),
            "run",
            "--target=sim",
            "--setup",
            "--build",
            "--run",
            "--build-root",
            str(base / "build"),
            "aixsilicon:cbb:packet_locking_arbiter:0.1.0",
        ]
        log = out / "archive-replay.txt"
        with log.open("w") as stream:
            result = subprocess.run(
                cmd, cwd=base, stdout=stream, stderr=subprocess.STDOUT, timeout=240
            )
        if result.returncode or "PLA_PASS" not in log.read_text():
            raise RuntimeError("Extracted candidate build/run failed; see " + str(log))
        summary = dict(
            status="pass",
            archive_sha256=sha(archive),
            artifacts_checked=len(manifest["artifacts"]),
            method="Extracted source+dependency FuseSoC setup/build/run",
            log_sha256=sha(log),
        )
        (out / "replay-summary.json").write_text(json.dumps(summary, indent=2) + "\n")
        print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
