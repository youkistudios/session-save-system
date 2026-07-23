# Session Save — Shared Rulebook

> **Single source of behavioral truth.** Claude Code and Codex use the same four moments: session-tag, session-save, session-summary, and session-audit. Installed skills are thin client adapters. This guide owns identity, naming, state, content, provenance, and safety.

## Product boundary

Session Save is client-neutral local memory, not transcript synchronization. Each supported client captures only context it can currently access. All records live in one user-approved home, remain ordinary Markdown/JSON, and retain the client that authored them.

The implemented support contract is Claude Code + Codex local clients. Other clients are not claimed.

## Shared home

The kernel resolves home in this order:

1. explicit `--home` (tests and administration);
2. `SESSION_SAVE_HOME`, then legacy `SAVE_SYSTEM_HOME`;
3. `~/.config/session-save/config.json`;
4. the legacy `~/.claude/save-system-home` pointer during transition;
5. `~/Desktop/session-logs/`.

GUI applications may not inherit shell variables, so the shared config is canonical after installation. If the home does not exist, the kernel creates only the required structure. Never write records elsewhere after a successful resolution.

```text
session-logs/
├── GUIDE.md
├── config.json                       optional portable copy
├── _INDEX.md                         generated; never edit directly
├── sessions/
│   ├── _PROJECTS.md
│   └── <project>/
│       ├── claude/<date>_<slug>/
│       │   ├── record.json
│       │   ├── tag.md
│       │   ├── checkpoints/<timestamp>_<event>.md
│       │   ├── human.md
│       │   └── agent.md
│       └── codex/<date>_<slug>/...
├── events/<date>/<timestamp>_<event>.json
├── audits/global/<YYYY>-W<week>_audit.md
└── .session-save/                    schema, views, migration receipts
```

A client directory appears only after that client writes its first record for a project.

## Client and model identity

- `client_id` identifies the application surface: currently `claude` or `codex`.
- `model_id` is optional metadata only when the host exposes it reliably.
- Storage is namespaced by client, never by a guessed model.
- A Cursor session running Claude would not be a Claude Code record; client and model are different concepts.
- Never claim client identity from prose. The installed `CLIENT.md` adapter supplies it.

## Projects — discovered, never hardcoded

A project is whatever the user actually works on.

1. Check `sessions/_PROJECTS.md` for a match.
2. Otherwise derive a candidate from repository/folder, deliverable, then dominant topic.
3. Propose the candidate and nearby existing projects. Never silently invent one when the user can answer.
4. Register an approved project with a one-line description and first date.

Project display names remain short. The kernel creates a safe lowercase folder slug. Cross-client work uses the same project display name so audits can aggregate it.

## Naming

Name each client session `<Project> Topic`, with a one-to-three-word topic.

- Purpose beats work-done.
- If the session pivots, preserve its core purpose and name the pivot in the gist.
- Repeated sessions must disambiguate by purpose, not “2”.
- Low confidence means three choices plus “name it yourself.”
- Rename a chat only when that client exposes the capability and the user confirms.

## Identity — one record per client session

A record has a globally unique `record_id`. Reuse resolves by:

1. `client_id + provider_session_id` when a stable real ID is available;
2. `client_id + session_slug` otherwise;
3. explicit user resolution on ambiguity.

Never invent a provider session ID. Never merge records merely because Claude and Codex used similar names. Cross-client continuation may be referenced, but each source record remains intact.

`record.json` is the machine identity envelope. Narrative truth remains in Markdown. Skills never overwrite or hand-edit `record.json`; they use the kernel.

## State model

```text
no record ── tag ───────► open ── summary ──► closed
     └────── save ──────► provisional ── tag ──► open
                                      └── save ─► provisional
open ─────── save ──────► open
```

Session-summary requires an existing tagged record and never creates one. Stale records remain preserved and may be marked `stale`; archive never means delete.

## Concurrency and derived views

Claude and Codex may write at the same time.

- Each writes only inside its own record namespace.
- Checkpoints are immutable uniquely named files, not appends to one shared file.
- Every operation emits a uniquely named event receipt.
- `_INDEX.md` is rebuilt from `record.json` envelopes through an atomic replace.
- A failed index rebuild cannot invalidate a source record.
- `session_save.py rebuild` restores the index at any time.

The index contains state, updated time, project, client, name, gist, and record path. Project is primary for human scanning; client provenance is always visible.

## session-tag — triage gate

Compute `{name, project, gist, verdict, assets}` once into `tag.md`. Downstream summaries read it.

### Arcs

Default to one arc. A second arc exists only when the work target changes and either new assets appear or a day boundary is crossed. Design → build → review of the same deliverable is one arc.

### Verdict

Ask whether the core intent is achieved—not whether any follow-up exists.

- **finished:** core work done; follow-ups may remain.
- **live:** core work remains in flight and would be resumed.
- **stale:** dead or superseded.

Routing precedence: any live arc → LIVE; else all stale → STALE; else FINISHED.

### `tag.md`

```markdown
---
session_slug: <slug>
provider_session_id: <only when real>
client_id: claude|codex
model_id: <optional>
project: <Project>
name: "<Project> Topic"
verdict: finished|live|stale
date: <YYYY-MM-DD>
updated: <ISO timestamp>
revisions: [<timestamp>, ...]
status: open|closed|stale
record_id: <from record.json>
---
# <Name> — session tag

## Arc 1 — <Title> (<date>) [<kind>] → finished|live|stale
Gist: • … • … • …
Assets: • <name> — <real file or “in chat”> — <value>

## Session verdict: <FINISHED|LIVE|STALE> — <one sentence>
## Route: session-summary | session-save | archive guidance
```

Assets in chat are explicitly marked because they are not durable files.

### Sweep

A sweep is client-local because no adapter may pretend it can see another client’s chat list. Write `_SWEEP-REVIEW.md` before any action. Unlogged chats receive only staleness/duplicate flags, not fabricated verdicts. Wait for approval; archive one by one; never delete; capture before archive.

## session-save — checkpoint

Write approximately 100–300 words to the unique checkpoint path allocated by the kernel:

```markdown
### <HH:MM> — <client_id>

- **Now:** …
- **Working on:** …
- **Next:** …
- **Watch:** …
```

If Save runs first, create one provisional record with gist:

`Checkpoint saved; run session-tag to tag this session.`

A later tag upgrades that same client record. An open record stays open after more checkpoints. Never write a close-out here.

## session-summary — close-out

Require the existing `tag.md`. Write two files in place:

- `human.md`: promoted GIST from tag, bottom line, assets, problems, solutions, achieved, actioned, insights, and next.
- `agent.md`: technical state, decisions and reasons, proven versus unproven, client source, reconciliation against later checkpoints, and open threads.

Refresh these files on rerun and append revision timestamps. Then use the kernel to mark the record closed and rebuild views. Honest state beats a highlight reel.

## session-audit — cross-client bird’s-eye

Default window is seven days. Gather sources through the kernel, then read `record.json`, `tag.md`, and `human.md` only—never raw transcripts.

Group by project first. Within each project include:

- Achieved
- Open plans not actioned
- High-value assets
- Live threads and pending decisions

Prefix factual bullets with `[Claude]`, `[Codex]`, or the returned client ID and link the record path. Surface contradictions between client records instead of silently reconciling them. Name close-out debt. Add cross-project dependencies and prioritized next moves.

Publish the weekly report atomically through the kernel to `audits/global/<YYYY>-W<week>_audit.md`. A client-specific audit may be added later, but the default is the combined project view.

## Chat receipts

### Tag

```text
🏷 <Name> · <Project> · <VERDICT> · <Client>
• What happened …
• Assets …
→ Route: summary | save | archive guidance
📍 <record path>
```

### Save

```text
💾 Checkpoint · <Name> · <time> · <Client>
• Now …  • Next …  • Watch …
📍 <checkpoint path>
```

### Summary

```text
✅ Closed · <Name> · <Project> · <Client>
• Achieved …  • Open / next …
📁 human.md · agent.md
```

### Audit

Print the five-fact GIST, bottom line, and global audit path.

## Migration from v1

Legacy records use `sessions/<Project>/<date>_<slug>/`. Schema v2 uses `sessions/<project>/<client>/<date>_<slug>/`.

Migration is explicit:

1. run `migrate-v1 --client claude --dry-run`;
2. inspect every source and destination;
3. run `--apply` only with approval;
4. copy records into the Claude namespace;
5. generate envelopes and a migration receipt;
6. preserve every legacy source directory.

Historical model identity remains null unless proven. Migration identifies the legacy client family, not a specific Claude model.

## Safety invariants

1. Archive, never delete.
2. Capture before archive.
3. One record per client session; never merge on title similarity.
4. Client source is mandatory; model source is optional.
5. `_INDEX.md` is derived and never a writing target for skills.
6. User logs are outside installer ownership and uninstall scope.
7. Unknown client identity fails closed.
8. Paths remain inside the resolved home; symlink replacement is refused.
9. Summaries use available context only and never imply transcript recovery.
10. Unsupported rename/archive/history capabilities degrade to printed guidance.
