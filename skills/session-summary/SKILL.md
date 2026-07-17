---
name: session-summary
description: Session Save System end-of-session close-out. `/session-summary` (alias `/ssum`) — write the readable summary (human.md) + technical resume-state (agent.md) and mark the session closed, so any future chat can catch up cold. Use when the user says "/session-summary", "/ssum", "close out the session". NOT a mid-session checkpoint (that's /session-save). Rulebook: GUIDE.md in the save-system home folder.
---

# /ssum — close-out

**Rulebook: `GUIDE.md` in the home folder** (home = `~/.claude/save-system-home` path if present, else `$SAVE_SYSTEM_HOME`, else `~/Desktop/session-logs/`). This skill is just the trigger.

1. Folder: `sessions/<Project>/<DATE>_<slug>/` — reuse the session's existing folder (guide → "Idempotency").
2. Write `human.md` (~500w readable: `## GIST` — **promoted verbatim from `tag.md` if `/st` ran, never recomputed** — + bottom line · `## Assets` · Problems · Solutions · Achieved · Actioned · Insights · Next) + `agent.md` (~500w technical only: state, decisions + why, proven vs unproven, open threads). No gist overlap between the two.
3. **Idempotent:** if they already exist, refresh in place; bump `updated:` + append to `revisions:` — never a second file or folder.
4. **Index — one row per session:** update the session's existing `_INDEX.md` row in place (status → ✅ closed, refresh gist); only prepend a new row if none exists. Never duplicate.
5. **Print the tidy `/ssum` block** (guide → "Chat output format"): ✅ Closed · Achieved · Open/next · 📁 paths · 🔖 updated.

Rules: honest state, not a highlight reel. Real paths only. Concise beats complete. Guide wins on any conflict.
