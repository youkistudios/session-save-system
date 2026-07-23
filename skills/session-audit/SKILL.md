---
name: session-audit
description: Audit source-attributed Session Save records across Claude Code and Codex, grouped by project, into one local weekly report. Use when the user asks what happened this week, what remains open, or what to do next.
license: MIT
compatibility: Requires Python 3 and local filesystem write access. Installed adapters support Claude Code and Codex.
---

# Session audit — cross-client bird’s-eye

Resolve this skill directory as `SKILL_DIR`. Read `CLIENT.md` beside this file for the active client identity. Read the shared home’s `GUIDE.md`.

1. Run `python3 "$SKILL_DIR/scripts/session_save.py" doctor --client <client_id>`. Stop unless `ok` is true and `migration_required` is zero.
2. Run `audit-sources --days 7` or the requested window. This returns source-attributed records from every installed client.
3. Read only each returned `record.json`, `tag.md`, and `human.md` when present. Never read raw transcripts. For every claim retain the source client and record path.
4. Group by project first. Within each project report **Achieved**, **Open plans not actioned**, **High-value assets**, and **Live threads / pending decisions**. Surface cross-project dependencies and contradictions between client records rather than silently reconciling them.
5. Name close-out debt: finished/open records missing `human.md` are not banked knowledge.
6. Write a complete audit draft to a temporary regular file. Include a five-fact GIST, bottom line, by-project sections, cross-wires, and prioritized next actions. Prefix factual bullets with `[Claude]`, `[Codex]`, or the returned client ID and link the source record.
7. Run `write-audit --week <YYYY-Www> --input <draft>` to publish atomically into `audits/global/`. Remove the temporary draft.
8. Print the audit GIST and real output path.

An audit is read-only over source records. It may replace the same weekly global report atomically, but it never edits session records or erases provenance.
