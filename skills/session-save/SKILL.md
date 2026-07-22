---
name: session-save
description: Session Save System mid-session checkpoint. `/session-save` (alias `/ss`) — drop a quick timestamped "here's where I'm at" into the session's log so nothing's lost if the chat ends. Use when the user says "/session-save", "/ss", "save a checkpoint". NOT the end-of-session close-out (that's /session-summary). Rulebook: GUIDE.md in the save-system home folder.
---

# /ss — checkpoint

**Rulebook: `GUIDE.md` in the home folder** (home = `~/.claude/save-system-home` path if present, else `$SAVE_SYSTEM_HOME`, else `~/Desktop/session-logs/`). This skill is just the trigger.

- Session folder: `sessions/<Project>/<DATE>_<slug>/` — reuse the session's existing folder (guide → "Idempotency"); if none exists yet, derive project + slug per the guide (ask on real ambiguity, never invent folders elsewhere).
- Append `### <HH:MM> — **Now** … / **Working on** … / **Next** … / **Watch** …` (~200–400 words) to `<folder>/checkpoints.md` (create with simple frontmatter on first write). Re-runs append another timestamped block to the SAME file — never a new file.
- Ensure exactly one index row for this session. If `/st` already ran, update
  its 🟢 open row. If `/ss` is the first command, create one 🟡 provisional row
  using gist `Checkpoint saved; run /st to tag this session.`; `/st` later
  upgrades that same row in place. Never invent a verdict or duplicate the row.
- Do NOT write the close-out reports here — that's `/ssum`.
- **Print the tidy `/ss` block** (guide → "Chat output format"): 💾 Checkpoint · Name · time / Now · Next · Watch / 📍 path.
