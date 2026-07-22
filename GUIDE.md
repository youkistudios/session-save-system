# Save System — the Rulebook

> **Single source of truth.** The four skills — `/session-tag` (`/st`), `/session-save` (`/ss`), `/session-summary` (`/ssum`), `/session-audit` (`/sa`) — are thin triggers that defer to this file. Full names are canonical; abbreviations are aliases with identical behavior. If a skill's behavior would drift from this guide, the guide wins.

## Home folder
Resolve in this order: **(1)** the path in `~/.claude/save-system-home` (written by the installer — env vars don't reach Claude sessions), **(2)** `SAVE_SYSTEM_HOME` if set, **(3)** `~/Desktop/session-logs/`. **If the folder doesn't exist yet, create it** (with `sessions/`, `audits/`, a blank `_INDEX.md` and `sessions/_PROJECTS.md`) rather than failing or writing elsewhere. Never write session logs anywhere else. All paths below are relative to home.

```
_INDEX.md                       ← one line per session, newest first (read FIRST to catch up)
GUIDE.md                        ← this file
sessions/_PROJECTS.md           ← the project registry (auto-built, user-approved)
sessions/<Project>/<YYYY-MM-DD>_<slug>/
  tag.md          ← /st     name · gist (per arc) · assets · verdict (compute-once handoff)
  checkpoints.md  ← /ss     running timestamped notes
  human.md        ← /ssum   readable capture (inherits tag.md's gist)
  agent.md        ← /ssum   technical resume-state
audits/<YYYY>-W<week>_audit.md  ← /session-audit (/sa) weekly bird's-eye
```

## Projects — discovered, never hardcoded
There is no fixed category list. A **project** is whatever the user actually works on, discovered at tag time:
1. Check `sessions/_PROJECTS.md` — does this session belong to an existing project? Use it.
2. If not, derive a candidate from (in order): the repo/folder name being worked in · the deliverable's own name · the dominant topic. Propose it: *"New project '<Name>'? Or file under: <existing 1> / <existing 2> / name it yourself."* Never silently invent a project.
3. On approval, add one line to `_PROJECTS.md`: `- **<Name>** — <one-line description> (first: <date>)`.
Keep project names short (1–2 words, Title Case). **Project FOLDER name = the project name with spaces → hyphens** (`Job Search` → `sessions/Job-Search/`) — no spaces in paths. If the user can't be asked mid-run, use the best candidate and mark it `(unconfirmed)` in the registry; confirm on the next run. A session spanning two projects files under the dominant one, with the cross-link noted in `tag.md`.

## Naming — the name IS the key
`<Project> Topic`, topic 1–3 words. One name, three surfaces: the chat title, the folder slug (kebab-case of the name), the `_INDEX` row.
- **Purpose beats work-done.** Name the session for what it exists to produce; if it pivoted, keep the purpose and note the pivot in the gist. Never overwrite a user-set title without checking — a title counts as user-given only if the user typed or confirmed it; auto-generated titles are freely overwritable.
- **Repeats must disambiguate.** `Website Hero-Section`, never `Website Build 2`.
- Low confidence → offer **3 choices + "name it yourself."**

## Idempotency — one session, ONE record
A session's identity = its session id (stash in `tag.md` when available) with the slug as fallback. Re-running any command **updates the existing record**:
- Folder: find it (id → slug) and reuse. Name changed? **Rename the existing folder** — never create a second. Ambiguous → ask.
- `tag.md`/`human.md`/`agent.md`: refresh in place; bump `updated:` and append the run time to `revisions:` (entries are `MM-DD HH:MM` so multi-day sessions stay unambiguous). `human.md`/`agent.md` carry the same minimal frontmatter: `session_slug / project / date / updated / revisions / status`.
- `checkpoints.md`: append a new `### <HH:MM>` block to the one file.
- `_INDEX.md`: **one row per session.** `/st` normally creates it as 🟢 open. When `/ss` is the first command used, it may create one 🟡 provisional row after resolving the same session identity and folder; use gist `Checkpoint saved; run /st to tag this session.` and do not invent a verdict. A later `/st` updates that row in place to 🟢 open. `/ssum` never creates a row; it updates the existing row to ✅ closed. Never add a second row.
- `status:` in `tag.md` mirrors the index: `/st` writes `open`; **`/ssum` flips it to `closed`** (one truth, two surfaces).

## `/st` — the triage gate (run at session end, before anything else)
Computes `{name, project, gist, verdict, assets}` ONCE into `tag.md`; everything downstream reads it.

### tag.md
```
---
session_slug: <slug>
session_id: <if available>
project: <Project>
name: "<Project> Topic"
verdict: finished|live|stale
date: <YYYY-MM-DD>
updated: <YYYY-MM-DD HH:MM>
revisions: [<HH:MM>, ...]
status: open|closed
---
# <Name> — session tag

## Arc 1 — <Title> (<date>) [<kind>] → finished|live|stale
Gist (3–5): • … • … • …
Assets: • <name> — <file> — <one-line value>
[Still to do (≤3): • …   ← only if live]

## Session verdict: <FINISHED|LIVE|STALE> — <one sentence>
## Route: /ssum | /ss | archive-stub
```

### Arcs (default = ONE)
A second arc sparks ONLY when the **work-target changes** AND (**new assets appear** OR a **day boundary** is crossed). Phases of the same deliverable (design→build, plan→execute) are ONE arc. Test: "different thing, or the next phase of the same thing?" Next phase → one arc.

### Assets ledger
Each arc lists what it left behind: `<name> — <file> — <one-line value>`. Chat-only deliverables (no file) are listed as `<name> — (in chat) — <value>` — and flagged, since anything not in a file is one closed tab from gone. This makes logs searchable by *what got built*, not just discussed.

### Verdict per arc — decouple "has follow-ups" from LIVE
Test: **is the core intent achieved?** — NOT "is anything left?"
- **finished** — core work done; follow-ups allowed (they go to Next).
- **live** — the core work itself is mid-flight; you'd resume it next session. Tie-break: **if the user explicitly says they'll continue this work, it's live.**
- **stale** — dead or superseded; you won't return.

### Roll-up + routing (precedence, not "least-done")
Any arc `live` → **LIVE → `/ss`**. Else all `stale` → **STALE → archive-stub** (one `_INDEX` line, no full close-out). Else → **FINISHED → `/ssum`**. If a stale arc rides with finished ones, name it in the tag so it isn't buried.

### Applying the name
Set the chat title via the session tools if available (always confirm with the user). If unavailable, print the name and ask the user to set it.

## `/st all` — the sweep
List sessions → group by project → rank by staleness. **Write `_SWEEP-REVIEW.md` FIRST** (read-only proposal: current title · suggested name · last active · disposition ✅ keep / 📦 archive / ⚠️ your-call / ✂️ rename + an approvals checklist). A real FINISHED/LIVE/STALE verdict needs a log to read — un-logged chats get *staleness + obvious-duplicate* flags only, stated as such. On approval: rename/archive **one by one**. Never delete. Target ≤5 active per project. **Never archive a chat whose knowledge isn't captured — close it out first.**

## `/ss` — checkpoint
Append `### <HH:MM> — **Now** … / **Working on** … / **Next** … / **Watch** …` (~100–300 words — it's a quick checkpoint, not an essay) to the session's `checkpoints.md`. Ensure the session's one `_INDEX` row exists. If `/ss` runs before `/st`, create the single 🟡 provisional row defined under Idempotency; `/st` must update it rather than prepend another row.

## `/ssum` — close-out
Write `human.md` (~500w: `## GIST` promoted verbatim from tag.md if `/st` ran — verbatim = same content, reformatting into bullets is fine, rewording is not — + bottom line · `## Assets` · Problems · Solutions · Achieved · Actioned · Insights · Next) + `agent.md` (~500w technical: state, decisions+why, proven vs unproven, open threads). If `checkpoints.md` contradicts the tag (work moved on since a checkpoint), the tag wins — note the reconciliation in `agent.md`. Update the `_INDEX` row → ✅ closed AND flip `tag.md`'s `status:` → closed. Honest state, not a highlight reel.

## `/session-audit` (`/sa`) — weekly bird's-eye
Read the window's `tag.md`/`human.md` files (summaries, never raw transcripts) → group by project → per project: **Achieved · Open plans not actioned · High-value assets · Live threads** → cross-project dependencies → prioritized next actions. **Surface close-out debt:** a FINISHED session with no `human.md` gets named explicitly (its knowledge isn't banked yet). Write `audits/<YYYY>-W<week>_audit.md` (ISO week, zero-padded: `W05`, `W29`). Read-only over the logs. An audit that says "all good" every week is theatre.

## Chat output format (every skill prints this way)
Skimmable blocks — bold labels, dot points, a route line. The detail lives in files, not chat.

**/session-tag:**
```
🏷 <Name> · <Project> · <FINISHED|LIVE|STALE>
What happened
• …  • …  • …
Assets
• <name> — <file> — <value>
Verdict: <one line>
→ Route: /ssum (or /ss · archive)
```
**/session-save:**
```
💾 Checkpoint — <Name> · <HH:MM>
• Now: …   • Next: …   • Watch: …
📍 <folder path>
```
**/session-summary:**
```
✅ Closed — <Name> (<Project>)
Achieved
• …  • …
Open / next
• …
📁 human.md · agent.md   ·   🔖 updated <timestamp>
```
**/session-audit:** the audit's `## GIST` (5 facts + bottom line) + `📁 <audit path>`.

## Safety invariants (non-negotiable)
1. **Archive, never delete.** 2. **Capture-before-archive.** 3. **Find-by-id/slug, update-in-place — never fork a duplicate.** 4. **Sweeps propose first; the review file is read-only until approved.**
