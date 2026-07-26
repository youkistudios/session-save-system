# Architecture

Session Save v2 separates portable behavior, client adaptation, deterministic persistence, and user-owned records.

```text
Claude Code adapter          Codex adapter
~/.claude/skills/            ~/.agents/skills/
          │                         │
          └──── same four Agent Skills ────┐
                                           ▼
                              thin local launchers
                                           │
                                           ▼
                           one Python persistence kernel
                      ~/.local/share/session-save/session_save.py
                         identity · events · atomic views
                                           │
                                           ▼
                                  one shared local home
                       projects / claude + codex / audits
```

## Portable behavior

Four open-format Agent Skills define Tag, Save, Summarize, and Audit. Each installed skill receives a small `CLIENT.md` identifying `claude` or `codex` and a tiny `scripts/session_save.py` compatibility launcher. Every launcher executes the one manifest-owned kernel under `~/.local/share/session-save/`. The guide owns product behavior; adapters own invocation and optional host capabilities.

Claude Code receives slash-command entry points and aliases. Codex discovers the skills from `~/.agents/skills/` and invokes them through skill mention or selection.

## Record plane

```text
sessions/<project>/<client>/<date>_<slug>/
├── record.json
├── tag.md
├── checkpoints/<timestamp>_<event-id>.md
├── human.md
└── agent.md
```

`record.json` contains the stable machine envelope: schema and record IDs, client, optional model and host-session ID, project, slug, status, timestamps, gist, continuation reference, and witnessed capability flags.

Markdown contains the human and agent narrative. Skills never edit the envelope directly.

## Identity

1. A real `client_id + provider_session_id` is preferred.
2. `client_id + session_slug` is the fallback.
3. Ambiguity requires the user.
4. Two clients never share one record directory.
5. Similar names never trigger cross-client merging.
6. `model_id` is optional metadata and never a path key.

## State

```text
no record ── tag ──► open ── summary ──► closed
     └────── save ─► provisional ── tag ─► open
open ─────── save ─► open
```

Summary locates an existing record and cannot create one. A first checkpoint creates one provisional record without inventing a verdict.

## Concurrency

Multiple clients cannot safely mutate one Markdown index directly. The kernel therefore:

- serializes mutations with a local file lock;
- writes metadata and views through flush + atomic rename;
- allocates globally unique event and checkpoint names;
- isolates every source record by client and verifies client ownership on mutation;
- emits immutable JSON operation receipts;
- rebuilds `_INDEX.md` from validated envelopes.

A stale or interrupted derived view can be rebuilt. Source records remain the authority.

## Global audit

`audit-sources` returns record envelopes and available tag/human/agent paths across all clients. The skill groups them by project and attributes every factual bullet to its client and source path. Contradictions remain visible. `write-audit` atomically publishes the combined weekly report.

## Home resolution

1. explicit `--home`;
2. `SESSION_SAVE_HOME` or legacy `SAVE_SYSTEM_HOME`;
3. `~/.config/session-save/config.json`;
4. legacy Claude pointer during migration;
5. `~/Desktop/session-logs/`.

The shared config is never an uninstall target.

## Installation boundary

Claude and Codex have separate SHA-256 ownership manifests and backup trees. The shared kernel has its own exact manifest. Unrelated client collisions are skipped; an unowned conflicting shared kernel fails installation. Managed replacements are backed up. Uninstall considers only allowlisted regular files whose current hash matches the relevant manifest, and retains the shared kernel while any managed launcher remains.

The shared home, config, legacy sources, migration receipts, and backups are user data and remain untouched.

## Migration

V1 records are inventoried before mutation. Records containing symlinks are refused. Apply copies each safe legacy directory into private staging, writes its envelope there, atomically places it under `sessions/<project>/claude/`, rebuilds the view, and emits a receipt. Every source directory remains in place.

## Degraded modes

- Missing stable session ID → client + slug fallback.
- Missing rename/archive tools → print manual guidance.
- Missing historical chat access → disable sweep outside visible chats.
- Missing context or filesystem permission → abort rather than fabricate a save.
- Legacy records awaiting migration → doctor reports not ready and skills stop.
