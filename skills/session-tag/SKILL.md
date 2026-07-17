---
name: session-tag
description: Session Save System triage gate. `/session-tag` (alias `/st`) — at session end, distill the session into a gist (one per arc), name it `<Project> Topic`, judge FINISHED/LIVE/STALE, and route to `/session-summary` or `/session-save`. Writes `tag.md` as the compute-once handoff the close-out reads. `/session-tag all` (or `/st all`) sweeps the whole chat list (review file first) to keep recents ≤5. Use when the user says "/session-tag", "/st", "session tag", "tag this session". NOT the close-out (that's /session-summary) and NOT a checkpoint (that's /session-save) — it DECIDES which to run. Rulebook: GUIDE.md in the save-system home folder.
---

# /st — session tag (triage gate)

**Rulebook: `GUIDE.md` in the home folder — the single source of truth.** Home = the path in `~/.claude/save-system-home` if present, else `$SAVE_SYSTEM_HOME`, else `~/Desktop/session-logs/`. This skill is just the trigger; the guide owns the tag structure, arcs, verdicts, naming, projects, idempotency, sweep, and safety rules.

## Default — tag THIS session
1. **Project** (guide → "Projects"): match against `sessions/_PROJECTS.md`; if new, propose a name derived from repo/folder/deliverable/topic — never silently invent. On approval, register it.
2. **Name = slug** (guide → "Naming"): `<Project> Topic`, purpose-beats-work-done; folder `sessions/<Project>/<DATE>_<slug>/` — find by id/slug and update in place, never fork. Unsure → 3 choices + "name it yourself".
3. **Arcs** (guide → "Arcs"): default ONE; split only on work-target change AND (new assets OR new day).
4. **Write `tag.md`** per the guide template — idempotent (`updated:` + `revisions:` on re-run). **`/st` owns the `_INDEX.md` row:** create it 🟢 open at first tag (one row per session, update in place on re-runs).
5. **Verdict + roll-up** (guide → "Verdict"): finished allows follow-ups; roll-up by routing precedence (live > all-stale > finished).
6. **Route + apply the name** (on the user's OK): FINISHED → offer `/ssum` · LIVE → offer `/ss` · STALE → offer archive-stub. Set the chat title via session tools if available (confirm); else print it for manual setting.
7. **Print the tidy `/st` block** (guide → "Chat output format"). Dot points, not prose.

## Sweep — `/st all`
Per guide → "the sweep": list sessions → group by project → staleness rank → **write `_SWEEP-REVIEW.md` first (read-only proposal + approvals checklist)** → on approval, rename/archive one-by-one. Full verdicts only for logged sessions; un-logged get staleness/duplicate flags, stated honestly. Never delete. Capture-before-archive.
