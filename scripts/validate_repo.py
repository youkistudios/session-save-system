#!/usr/bin/env python3
"""Dependency-free structural, portability, and safety validation."""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "README.md", "GUIDE.md", "LICENSE", "SECURITY.md", "PROVENANCE.md",
    "CONTRIBUTING.md", "CODE_OF_CONDUCT.md", "SUPPORT.md", "CITATION.cff",
    "NOTICE", "install.sh", "uninstall.sh", "tests/run.sh",
    "scripts/session_save.py", "scripts/session_save_adapter.py",
    "docs/index.html", "docs/styles.css", "docs/site.js",
    "docs/assets/fonts/IBMPlexSansCondensed-SemiBold.woff2",
    "docs/assets/fonts/IBMPlexSansCondensed-Bold.woff2", "docs/assets/fonts/license.txt",
    "docs/CONTINUITY-IMPLEMENTATION-PLAN.md",
    "docs/PRODUCT-THESIS.md", "docs/ARCHITECTURE.md", "docs/SAFETY-MODEL.md",
    "docs/ROADMAP.md", "docs/decisions/0003-client-neutral-shared-home.md",
    "docs/decisions/0004-one-installed-kernel.md",
    "docs/decisions/0005-deterministic-approved-projects.md",
    "docs/evidence/2026-07-26-deterministic-project-safety.md",
    "adapters/claude/CLIENT.md", "adapters/codex/CLIENT.md",
    "provenance/COMPONENTS.json", "automation/workflows/ci.yml",
    "automation/workflows/pages.yml",
]
SKILLS = ("session-tag", "session-save", "session-summary", "session-audit")
ALIASES = {
    "session-checkpoint": "session-save",
    "session-close": "session-summary",
    "session-review": "session-audit",
}


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    raise SystemExit(1)


missing = [path for path in REQUIRED if not (ROOT / path).is_file()]
if missing:
    fail("missing required files: " + ", ".join(missing))

install = (ROOT / "install.sh").read_text()
uninstall = (ROOT / "uninstall.sh").read_text()
kernel = (ROOT / "scripts/session_save.py").read_text()
launcher = (ROOT / "scripts/session_save_adapter.py").read_text()

if "grep -q \"Session Save System\"" in install + uninstall:
    fail("text-search ownership detection remains")
for phrase in (
    "session-save-system.manifest", "install.manifest", "hash_file", "AGENTS_CONFIG_DIR",
    "adapters/$client/CLIENT.md", "scripts/session_save_adapter.py", "LIB_DIR/session_save.py",
):
    if phrase not in install:
        fail(f"dual-client installer mechanism missing: {phrase}")
for phrase in ("is_allowed_path", "preserved modified file", "hash_file", "AGENTS_CONFIG_DIR"):
    if phrase not in uninstall:
        fail(f"dual-client uninstaller mechanism missing: {phrase}")
if "rm -rf" in uninstall:
    fail("uninstaller must not recursively delete managed paths")
for phrase in ("SESSION_SAVE_KERNEL", "SESSION_SAVE_LIB_DIR", "os.execv", "is_symlink"):
    if phrase not in launcher:
        fail(f"thin kernel launcher mechanism missing: {phrase}")

for phrase in (
    "fcntl.flock", "mutation_lock", "atomic_text", "safe_under", "record_id", "client_id",
    "checkpoint-path", "rebuild_index", "migrate-v1", "source_records_preserved",
    "write-audit", "project-list", "project-check", "project-register",
    "require_registered_project",
):
    if phrase not in kernel:
        fail(f"persistence mechanism missing: {phrase}")

for skill_name in SKILLS:
    path = ROOT / "skills" / skill_name / "SKILL.md"
    if not path.is_file():
        fail(f"missing skill: {path.relative_to(ROOT)}")
    text = path.read_text()
    if not text.startswith("---\n") or f"name: {skill_name}\n" not in text:
        fail(f"invalid Agent Skills frontmatter: {skill_name}")
    if "CLIENT.md" not in text or "scripts/session_save.py" not in text:
        fail(f"skill is not adapter/kernel portable: {skill_name}")
    if "~/.claude/save-system-home" in text:
        fail(f"skill hardcodes Claude home: {skill_name}")
    description = re.search(r"^description: (.+)$", text, re.MULTILINE)
    if not description or len(description.group(1)) > 1024:
        fail(f"invalid skill description: {skill_name}")

for alias, canonical in ALIASES.items():
    path = ROOT / "skills" / alias / "SKILL.md"
    if not path.is_file():
        fail(f"missing lifecycle alias: {path.relative_to(ROOT)}")
    text = path.read_text()
    for phrase in (f"name: {alias}\n", "CLIENT.md", "scripts/session_save.py", f"../{canonical}/SKILL.md"):
        if phrase not in text:
            fail(f"invalid lifecycle alias {alias}: missing {phrase}")
    command = ROOT / "commands" / f"{alias}.md"
    if not command.is_file() or f"`{alias}` skill" not in command.read_text():
        fail(f"missing Claude command alias: {alias}")

claude = (ROOT / "adapters/claude/CLIENT.md").read_text()
codex = (ROOT / "adapters/codex/CLIENT.md").read_text()
if "`client_id`: `claude`" not in claude or "`client_id`: `codex`" not in codex:
    fail("adapter identity is not explicit")

for text in ((ROOT / "GUIDE.md").read_text(), (ROOT / "skills/session-save/SKILL.md").read_text()):
    if "provisional" not in text.lower():
        fail("first-checkpoint behavior is not aligned")

guide = (ROOT / "GUIDE.md").read_text()
for phrase in ("One record per client session", "never edit directly", "Claude Code + Codex"):
    if phrase not in guide:
        fail(f"shared rulebook contract missing: {phrase}")

html = (ROOT / "docs/index.html").read_text()
for token in ('name="viewport"', 'href="styles.css"', 'id="main"', "CLAUDE CODE + CODEX"):
    if token not in html:
        fail(f"site missing {token}")

commands = (
    [str(ROOT / "tests/run.sh")],
    [sys.executable, str(ROOT / "scripts/generate_manifest.py"), "--check"],
)
for command in commands:
    result = subprocess.run(command, cwd=ROOT)
    if result.returncode:
        raise SystemExit(result.returncode)
print("repository validation ok")
