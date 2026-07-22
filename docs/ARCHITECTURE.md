# Architecture

Session Save System is a file-first instruction suite with two separate data
zones: managed Claude configuration and user-owned session records.

```text
Claude session
   │
   ├─ /st ───► tag.md ─────────────┐
   ├─ /ss ───► checkpoints.md      ├──► _INDEX.md
   ├─ /ssum ─► human.md + agent.md ┘
   └─ /sa ─── reads summaries ─────────► audits/<week>.md

installer ─► skills + commands + pointer + ownership manifest
log home  ─► GUIDE + index + session records (user data)
```

## Control plane

`GUIDE.md` is the single behavioral rulebook. The four skills are thin triggers
and the eight command files are entry points. Full command names are canonical;
aliases have identical behavior.

## Identity and state

Session identity resolves by host session id when available and slug otherwise.
The same identity binds folder, chat title, and index row. State moves through:

```text
no row ── /st ──► open ── /ssum ──► closed
   └───── /ss ──► provisional ── /st ──► open
```

`/ssum` never invents a record. This keeps closing behavior dependent on an
existing, inspectable identity.

## Installation boundary

Managed files live below the Claude configuration directory. The installer
records `SHA-256<TAB>relative-path` for every installed file. An unrelated
collision with no manifest identity is skipped. A previously managed file is
backed up before replacement. The uninstaller accepts only an internal allowlist
of paths and deletes only a regular file whose current hash matches the
manifest.

The chosen log home is not part of that manifest and is never an uninstall
target.

## Degraded modes

- Without session-management tools, naming and logging work but title changes
  and archive operations become manual.
- Without a host session id, slug is the fallback identity and ambiguity must be
  resolved with the user.
- If a managed install file is edited locally, uninstall preserves it.
- Weekly audits depend on completed tags and summaries; missing close-outs are
  surfaced as debt rather than reconstructed from transcripts.
