"""Unit tests for the cbbrepo-management scripts (unified repo).

Run with: uv run pytest scripts/tests -v
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from scripts.config import (  # noqa: E402
    deep_merge,
    load_config,
    unified_repo_name,
    unified_repo_url,
    ip_rel_dir,
    tag_for,
)
from scripts.stage_ip import (  # noqa: E402
    copy_manifest_files,
    copy_evidence,
    copy_fusesoc_cores,
    copy_reports,
    find_manifest,
    generate_readme,
    generate_changelog,
    generate_ip_package,
    sha256_file,
)
from scripts.update_registry import (  # noqa: E402
    build_entry,
    find_ip_packages,
    upsert_registry,
)
from scripts.validate_release import is_semver  # noqa: E402


# ---------- config (unified repo) ----------

def test_unified_repo_name_default():
    config = load_config()
    assert unified_repo_name(config) == "ip-unified"


def test_unified_repo_name_env(monkeypatch):
    monkeypatch.setenv("IPKG_UNIFIED_REPO", "ip-central")
    config = load_config()
    assert unified_repo_name(config) == "ip-central"


def test_unified_repo_url():
    config = {"github": {"org": "rtl-team", "unified_repo": "ip-unified"}}
    assert unified_repo_url(config) == "https://github.com/rtl-team/ip-unified.git"


def test_ip_rel_dir():
    config = {"fusesoc": {"vendor": "rtl-team", "library": "rtl"}}
    assert str(ip_rel_dir(config, "apb_gpio_lite", "1.0.0")) == "ips/rtl-team/apb_gpio_lite/1.0.0"


def test_tag_with_ip_true():
    config = {"publish": {"tag_with_ip": True}}
    assert tag_for(config, "apb_gpio_lite", "1.0.0") == "apb_gpio_lite-v1.0.0"


def test_tag_with_ip_false():
    config = {"publish": {"tag_with_ip": False}}
    assert tag_for(config, "apb_gpio_lite", "1.0.0") == "v1.0.0"


def test_deep_merge():
    base = {"a": 1, "b": {"x": 1, "y": 2}}
    override = {"b": {"y": 3, "z": 4}}
    result = deep_merge(base, override)
    assert result == {"a": 1, "b": {"x": 1, "y": 3, "z": 4}}


def test_load_config_defaults(tmp_path):
    config = load_config()
    assert config["github"]["org"] == "rtl-team"
    assert config["github"]["unified_repo"] == "ip-unified"


# ---------- validate_release ----------

def test_is_semver():
    assert is_semver("1.0.0")
    assert is_semver("0.1.0")
    assert is_semver("1.0.0-rc.1")
    assert not is_semver("v1.0.0")
    assert not is_semver("1.0")
    assert not is_semver("")


# ---------- stage_ip ----------

def test_find_manifest(tmp_path):
    release = tmp_path / "release" / "demo_1.0.0"
    release.mkdir(parents=True)
    (release / "manifest.yaml").write_text(
        yaml.safe_dump({"ip_name": "demo", "version": "1.0.0"})
    )
    manifest_path, manifest = find_manifest(tmp_path)
    assert manifest["ip_name"] == "demo"
    assert manifest_path.parent.name == "demo_1.0.0"


def test_find_manifest_multiple_requires_version(tmp_path):
    for v in ["demo_1.0.0", "demo_1.1.0"]:
        d = tmp_path / "release" / v
        d.mkdir(parents=True)
        (d / "manifest.yaml").write_text(yaml.safe_dump({"ip_name": "demo", "version": "1.0.0"}))
    try:
        find_manifest(tmp_path)
        assert False, "expected ValueError for multiple manifests"
    except ValueError:
        pass
    # With --version it resolves
    manifest_path, _ = find_manifest(tmp_path, version="demo_1.1.0")
    assert manifest_path.parent.name == "demo_1.1.0"


def test_copy_manifest_files_copies_and_verifies_hash(tmp_path):
    # Build a workspace with one file
    src = tmp_path / "src"
    src.mkdir()
    rtl = src / "rtl"
    rtl.mkdir()
    demo = rtl / "demo.sv"
    demo.write_text("module demo; endmodule")
    sha = sha256_file(demo)
    manifest = {
        "ip_name": "demo",
        "version": "1.0.0",
        "files": [{"path": "rtl/demo.sv", "sha256": sha, "role": "rtl"}],
    }
    dst = tmp_path / "unified" / "ips" / "rtl-team" / "demo" / "1.0.0"
    copied = copy_manifest_files(src, manifest, dst)
    assert copied == ["rtl/demo.sv"]
    assert (dst / "rtl" / "demo.sv").read_text() == "module demo; endmodule"
    assert sha256_file(dst / "rtl" / "demo.sv") == sha


def test_copy_manifest_files_hash_mismatch_raises(tmp_path):
    src = tmp_path / "src"
    rtl = src / "rtl"
    rtl.mkdir(parents=True)
    (rtl / "demo.sv").write_text("module demo; endmodule")
    manifest = {
        "files": [{"path": "rtl/demo.sv", "sha256": "0" * 64, "role": "rtl"}],
    }
    dst = tmp_path / "dst"
    try:
        copy_manifest_files(src, manifest, dst)
        assert False, "expected ValueError on hash mismatch"
    except ValueError as exc:
        assert "SHA-256 mismatch" in str(exc)


def test_copy_evidence(tmp_path):
    src = tmp_path / "src"
    rel = src / "release" / "demo_1.0.0"
    rel.mkdir(parents=True)
    (rel / "manifest.yaml").write_text("m: 1")
    (rel / "release_note.md").write_text("# note")
    dst = tmp_path / "ver"
    dst.mkdir()
    copy_evidence(src, rel / "manifest.yaml", dst)
    assert (dst / "manifest.yaml").exists()
    assert (dst / "release_note.md").read_text() == "# note"


def test_copy_fusesoc_cores(tmp_path):
    src = tmp_path / "src"
    fsrc = src / "fusesoc"
    fsrc.mkdir(parents=True)
    (fsrc / "rtl_team_rtl_demo.core").write_text("CAPI=2:\n")
    dst = tmp_path / "ver"
    dst.mkdir()
    copied = copy_fusesoc_cores(src, dst)
    assert copied == ["rtl_team_rtl_demo.core"]
    assert (dst / "fusesoc" / "rtl_team_rtl_demo.core").exists()


def test_copy_reports_copies_quality_and_skips_scratch(tmp_path):
    src = tmp_path / "src"
    (src / "reports/quality").mkdir(parents=True)
    (src / "reports/lint").mkdir(parents=True)
    (src / "reports/synth").mkdir(parents=True)
    (src / "reports/quality/gate_report.md").write_text("# gate")
    (src / "reports/quality/run_log.md").write_text("log")
    (src / "reports/lint/vcs_lint.log").write_text("ok")
    # scratch that must be skipped
    (src / "reports/synth/simv").write_text("binary")
    (src / "reports/synth/simv.vdb").write_text("db")
    dst = tmp_path / "ver"
    dst.mkdir()
    copied = copy_reports(src, dst)
    assert "reports/quality/gate_report.md" in copied
    assert "reports/quality/run_log.md" in copied
    assert "reports/lint/vcs_lint.log" in copied
    assert "reports/synth/simv" not in copied
    assert (dst / "reports/quality/gate_report.md").exists()
    assert not (dst / "reports/synth/simv").exists()


def test_generate_readme_uses_unified_path():
    manifest = {"ip_name": "demo", "version": "1.0.0", "description": "Demo"}
    config = {
        "fusesoc": {"vendor": "rtl-team", "library": "rtl"},
        "template": {"license": "MIT"},
    }
    readme = generate_readme(manifest, "", config, Path("ips/rtl-team/demo/1.0.0"))
    assert "ips/rtl-team/demo/1.0.0" in readme
    assert "fusesoc library add ip-unified" in readme


def test_generate_changelog():
    changelog = generate_changelog("demo", "1.0.0", "first release")
    assert "## [1.0.0]" in changelog
    assert "first release" in changelog


def test_generate_ip_package():
    manifest = {"ip_name": "demo", "version": "1.0.0", "description": "Demo",
                "dependencies": []}
    config = {"fusesoc": {"vendor": "rtl-team", "library": "rtl"}}
    pkg = generate_ip_package(manifest, "", config, Path("ips/rtl-team/demo/1.0.0"), "MIT")
    assert pkg["schema_version"] == "2.0"
    assert pkg["path"] == "ips/rtl-team/demo/1.0.0"
    assert pkg["fusesoc"]["core"] == "rtl-team:rtl:demo:1.0.0"


# ---------- update_registry ----------

def test_find_ip_packages(tmp_path):
    unified = tmp_path / "unified"
    pkg = unified / "ips" / "rtl-team" / "demo" / "1.0.0" / "ip-package.yaml"
    pkg.parent.mkdir(parents=True)
    pkg.write_text(yaml.safe_dump({"name": "demo", "version": "1.0.0"}))
    found = find_ip_packages(unified)
    assert len(found) == 1
    assert "demo" in str(found[0])


def test_build_entry():
    config = {"fusesoc": {"vendor": "rtl-team", "library": "rtl"}, "publish": {"tag_with_ip": True}}
    entry = build_entry("demo", "1.0.0", "https://github.com/rtl-team/ip-unified.git", config,
                        path="ips/rtl-team/demo/1.0.0")
    assert entry["version"] == "1.0.0"
    assert entry["tag"] == "demo-v1.0.0"
    assert entry["fusesoc"]["core"] == "rtl-team:rtl:demo:1.0.0"
    assert entry["gates"]["G5"] == "pass"


def test_upsert_registry_add_and_update():
    config = {"fusesoc": {"vendor": "rtl-team", "library": "rtl"}, "publish": {"tag_with_ip": True}}
    registry = {"schema_version": "2.0", "ips": []}

    e1 = build_entry("demo", "1.0.0", "u", config, path="p1")
    r = upsert_registry(registry, e1, "demo")
    assert len(r["ips"]) == 1
    assert len(r["ips"][0]["versions"]) == 1

    e2 = build_entry("demo", "1.1.0", "u", config, path="p2")
    r = upsert_registry(r, e2, "demo")
    assert len(r["ips"]) == 1
    assert len(r["ips"][0]["versions"]) == 2

    e3 = build_entry("demo", "1.0.0", "u", config, path="p1")
    r = upsert_registry(r, e3, "demo")
    assert len(r["ips"][0]["versions"]) == 2

    e4 = build_entry("other", "1.0.0", "u", config, path="p3")
    r = upsert_registry(r, e4, "other")
    assert len(r["ips"]) == 2


def test_upsert_registry_sorts_versions():
    config = {"fusesoc": {"vendor": "rtl-team", "library": "rtl"}, "publish": {"tag_with_ip": True}}
    registry = {"schema_version": "2.0", "ips": []}
    for v in ["1.0.0", "1.1.0", "0.9.0"]:
        e = build_entry("demo", v, "u", config, path="p")
        registry = upsert_registry(registry, e, "demo")
    versions = [v["version"] for v in registry["ips"][0]["versions"]]
    assert versions == ["0.9.0", "1.0.0", "1.1.0"]


# ---------- publish_repo ----------

def test_remote_url_auth_ssh():
    from scripts.publish_repo import remote_url_for

    url = remote_url_for({"github": {"org": "rtl-team", "auth": "ssh-key", "unified_repo": "ip-unified"}})
    assert url == "git@github.com:rtl-team/ip-unified.git"


def test_remote_url_auth_token(monkeypatch):
    from scripts.publish_repo import remote_url_for

    monkeypatch.setenv("GITHUB_TOKEN", "ghp_secret")
    config = {"github": {"org": "rtl-team", "auth": "token", "token_env": "GITHUB_TOKEN", "unified_repo": "ip-unified"}}
    url = remote_url_for(config)
    assert "https://ghp_secret@github.com/rtl-team/ip-unified.git" == url


def test_collect_tags():
    from scripts.publish_repo import collect_tags

    registry = {
        "ips": [
            {"name": "demo", "versions": [{"version": "1.0.0"}, {"version": "1.1.0"}]},
            {"name": "other", "versions": [{"version": "2.0.0"}]},
        ]
    }
    config = {"publish": {"tag_with_ip": True}}
    tags = collect_tags(registry, config)
    assert tags == ["demo-v1.0.0", "demo-v1.1.0", "other-v2.0.0"]


# ---------- ipkg_cli ----------

def test_init_does_not_mutate_defaults(tmp_path):
    from scripts import ipkg_cli
    from scripts.config import DEFAULTS

    before_org = DEFAULTS["github"]["org"]
    args = type("Args", (), {"org": "other-org", "unified_repo": None, "output": tmp_path / "c.yaml"})()
    ipkg_cli.cmd_init(args)
    assert DEFAULTS["github"]["org"] == before_org
