#!/usr/bin/env python3
"""Exercise installer failures and profile replacement without network or Nix writes."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


INSTALLER = Path(__file__).with_name("install-runtime-tools.sh")
MOCK = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
tool = Path(sys.argv[0]).name
with open(os.environ["TEST_LOG"], "a") as log:
    log.write(json.dumps([tool, *args]) + "\n")
if tool == "curl":
    url = next(a for a in args if a.startswith("https://"))
    if url.endswith("/latest"):
        print(os.environ["TEST_RELEASE"])
    else:
        assert url.endswith("/" + os.environ["TEST_RELEASE"] + "/manifest.json")
        version = "0.0.0" if os.environ.get("TEST_BAD_MANIFEST") else os.environ["TEST_RELEASE"]
        manifest = {"version": version, "platforms": {"linux-x64": {"checksum": "a" * 64}}}
        Path(args[args.index("--output") + 1]).write_text(json.dumps(manifest))
elif args[0] == "build":
    if os.environ.get("TEST_BUILD_FAIL"):
        sys.exit(17)
    manifest = json.loads(Path(os.environ["FRAMEWORK_CLAUDE_MANIFEST"]).read_text())
    assert manifest["version"] == os.environ["TEST_RELEASE"]
    print(os.environ["TEST_PACKAGE"])
elif args[:3] == ["profile", "list", "--json"]:
    state = os.environ.get("TEST_STATE", "old")
    elements = {"_1password-cli": {"storePaths": ["/existing/op"]}}
    if state != "missing":
        previous = os.environ["TEST_PACKAGE"] if state == "current" else os.environ["TEST_PREVIOUS"]
        elements["claude-code"] = {"storePaths": [previous]}
    print(json.dumps({"elements": elements}))
elif args[:2] == ["profile", "add"]:
    if os.environ.get("TEST_ADD_FAIL") and args[2] == os.environ["TEST_PACKAGE"]:
        sys.exit(18)
elif args[:2] not in (["profile", "remove"], ["profile", "install"]):
    raise SystemExit("Unexpected nix command: " + repr(args))
'''


class RuntimeInstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        commands = self.root / "commands"
        commands.mkdir()
        for name in ("curl", "nix"):
            path = commands / name
            path.write_text(MOCK)
            path.chmod(0o755)
        self.package = self.root / "new-package"
        (self.package / "bin").mkdir(parents=True)
        claude = self.package / "bin/claude"
        claude.write_text('#!/bin/sh\nprintf "%s (Claude Code)\\n" "$TEST_RELEASE"\n')
        claude.chmod(0o755)
        self.previous = str(self.root / "old-package")
        self.log = self.root / "calls.jsonl"
        self.env = {
            **os.environ,
            "PATH": str(commands) + os.pathsep + os.environ["PATH"],
            "TEST_LOG": str(self.log),
            "TEST_RELEASE": "2.1.999",
            "TEST_PACKAGE": str(self.package),
            "TEST_PREVIOUS": self.previous,
        }

    def run_installer(self, *args, **changes):
        return subprocess.run(
            ["bash", str(INSTALLER), *args],
            env={**self.env, **changes}, capture_output=True, text=True,
        )

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def mutations(self):
        return [call for call in self.calls() if call[:2] == ["nix", "profile"] and call[2] != "list"]

    def test_new_release_replaces_only_claude(self):
        result = self.run_installer("claude")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.mutations(), [
            ["nix", "profile", "remove", "claude-code"],
            ["nix", "profile", "add", str(self.package)],
        ])

    def test_current_release_does_not_mutate_profile(self):
        result = self.run_installer("claude", TEST_STATE="current")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already installed", result.stdout)
        self.assertEqual(self.mutations(), [])

    def test_first_install_does_not_remove_anything(self):
        result = self.run_installer("claude", TEST_STATE="missing")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.mutations(), [["nix", "profile", "add", str(self.package)]])

    def test_failed_build_preserves_profile(self):
        self.assertNotEqual(self.run_installer("claude", TEST_BUILD_FAIL="1").returncode, 0)
        self.assertEqual(self.mutations(), [])

    def test_failed_replacement_restores_previous_package(self):
        self.assertNotEqual(self.run_installer("claude", TEST_ADD_FAIL="1").returncode, 0)
        self.assertEqual(self.mutations(), [
            ["nix", "profile", "remove", "claude-code"],
            ["nix", "profile", "add", str(self.package)],
            ["nix", "profile", "add", self.previous],
        ])

    def test_invalid_release_is_rejected_before_nix(self):
        self.assertNotEqual(self.run_installer("claude", TEST_RELEASE="../invalid").returncode, 0)
        self.assertFalse(any(call[0] == "nix" for call in self.calls()))

    def test_mismatched_manifest_preserves_profile(self):
        self.assertNotEqual(self.run_installer("claude", TEST_BAD_MANIFEST="1").returncode, 0)
        self.assertEqual(self.mutations(), [])

    def test_invalid_later_argument_does_not_start_install(self):
        self.assertEqual(self.run_installer("claude", "unknown").returncode, 2)
        self.assertEqual(self.calls(), [])

    def test_op_retains_its_existing_pin(self):
        result = self.run_installer("op")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [[
            "nix", "profile", "install", "--impure",
            "github:NixOS/nixpkgs/08d3a97586f6b6343b3b5e799980773629432610#_1password-cli",
        ]])


if __name__ == "__main__":
    unittest.main()
