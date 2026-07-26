---
name: session-checkpoint
description: Checkpoint current AI work into the shared local Session Save home. Public lifecycle alias for session-save; use when pausing unfinished work.
license: MIT
compatibility: Requires Python 3 and local filesystem write access. Installed adapters support Claude Code and Codex.
---

# Session checkpoint

This is the clearer public alias for `session-save`. Existing names remain supported.

Resolve this skill directory as `SKILL_DIR`. Read `CLIENT.md` beside this file, then read and follow `../session-save/SKILL.md` completely as the canonical checkpoint procedure. Use this alias's `scripts/session_save.py` launcher when that procedure refers to the kernel.

Do not close the session, infer a project, or create behavior beyond the canonical `session-save` contract.
