---
name: session-close
description: Close finished AI work with a human summary and technical resume state. Public lifecycle alias for session-summary.
license: MIT
compatibility: Requires Python 3 and local filesystem write access. Installed adapters support Claude Code and Codex.
---

# Session close

This is the clearer public alias for `session-summary`. Existing names remain supported.

Resolve this skill directory as `SKILL_DIR`. Read `CLIENT.md` beside this file, then read and follow `../session-summary/SKILL.md` completely as the canonical close-out procedure. Use this alias's `scripts/session_save.py` launcher when that procedure refers to the kernel.

Do not use this for an in-progress checkpoint or change the canonical close-out contract.
