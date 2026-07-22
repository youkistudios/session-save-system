#!/usr/bin/env python3
"""Dependency-free structural and safety validation."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "README.md", "GUIDE.md", "LICENSE", "SECURITY.md", "PROVENANCE.md",
    "CONTRIBUTING.md", "CODE_OF_CONDUCT.md", "SUPPORT.md", "CITATION.cff",
    "NOTICE", "install.sh", "uninstall.sh", "tests/run.sh", "docs/index.html",
    "docs/styles.css", "docs/PRODUCT-THESIS.md", "docs/ARCHITECTURE.md",
    "docs/SAFETY-MODEL.md", "docs/ROADMAP.md", "provenance/COMPONENTS.json",
    "automation/workflows/ci.yml", "automation/workflows/pages.yml",
]


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    raise SystemExit(1)


missing = [path for path in REQUIRED if not (ROOT / path).is_file()]
if missing:
    fail("missing required files: " + ", ".join(missing))

install = (ROOT / "install.sh").read_text()
uninstall = (ROOT / "uninstall.sh").read_text()
if "grep -q \"Session Save System\"" in install + uninstall or "grep -q \"session-\"" in install + uninstall:
    fail("text-search ownership detection remains")
for phrase in ("session-save-system.manifest", "hash_file", "backup_file"):
    if phrase not in install:
        fail(f"installer safety mechanism missing: {phrase}")
for phrase in ("is_allowed_path", "preserved modified file", "hash_file"):
    if phrase not in uninstall:
        fail(f"uninstaller safety mechanism missing: {phrase}")
if "rm -rf" in uninstall:
    fail("uninstaller must not recursively delete managed paths")

guide = (ROOT / "GUIDE.md").read_text()
save = (ROOT / "skills/session-save/SKILL.md").read_text()
for text in (guide, save):
    if "🟡 provisional row" not in text:
        fail("first-checkpoint index behavior is not aligned")

html = (ROOT / "docs/index.html").read_text()
for token in ('name="viewport"', 'href="styles.css"', 'id="main"'):
    if token not in html:
        fail(f"site missing {token}")

for command in ([str(ROOT / "tests/run.sh")], [sys.executable, str(ROOT / "scripts/generate_manifest.py"), "--check"]):
    result = subprocess.run(command, cwd=ROOT)
    if result.returncode:
        raise SystemExit(result.returncode)
print("repository validation ok")
