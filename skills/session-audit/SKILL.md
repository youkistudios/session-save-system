---
name: session-audit
description: Session Save System weekly audit. `/session-audit` (alias `/sa`) — read the week's session logs (grouped by project) and produce one bird's-eye report: what was achieved, plans created but never actioned, high-value assets, cross-project dependencies, and prioritized next steps. Use when the user says "/session-audit", "/sa", "week audit", "sum up the week", "where are we across everything". Rulebook: GUIDE.md in the save-system home folder.
---

# /session-audit (/sa) — weekly bird's-eye

**Rulebook: `GUIDE.md` in the home folder** (home = `~/.claude/save-system-home` path if present, else `$SAVE_SYSTEM_HOME`, else `~/Desktop/session-logs/`). Reads the logs the other skills produce; changes nothing but the audit file.

1. **Window:** last 7 days by default (or the range the user names). `mkdir -p` `audits/`.
2. **Gather cheap:** each in-window `sessions/<Project>/<date>_<slug>/` — read `tag.md` (gist · assets · verdict) + `human.md` GIST/Next if present. Use `_INDEX.md` for statuses. **Summaries, never raw transcripts.** For large weeks, spawn reader sub-agents per project and synthesize their digests.
3. **Group by project** (from `_PROJECTS.md`): per project collect **Achieved** (finished arcs) · **Open plans not actioned** · **High-value assets** (from the assets ledgers) · **Live threads / pending decisions**.
4. **Cross-wires:** surface dependencies between projects (tag.md cross-links feed this).
5. **Prioritize:** rank next actions — time-sensitive and decision-gating items first; each names the session + the specific move.
6. **Write** `audits/<YYYY>-W<ISO week>_audit.md`: `## GIST` (5 facts + bottom line) · `## By project` · `## Cross-wires` · `## Do next (prioritized)`. One audit per window — a re-run updates it (idempotency).
7. **Tell the user:** the path + the GIST, in tidy dot points.

Rules: read-only over the logs. A project with no activity gets one line. An audit that says "all good" every week is theatre — honest state always.
