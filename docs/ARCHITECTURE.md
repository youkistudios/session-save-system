# Architecture

Session Save v2 separates portable behavior, client adaptation, deterministic persistence, and user-owned records.

```text
Claude Code adapter          Codex adapter
~/.claude/skills/            ~/.agents/skills/
          │                         │
          └── four capture skills + Pickup ──┐
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

## Memory architecture

Session Save is a local session-memory architecture, not a transcript warehouse. Its memory has four layers:

1. **Captured context:** Tag, immutable Checkpoints, and Close summaries preserve decisions, progress, open questions, and resumption state.
2. **Artifact references:** records name relevant documents, code, and outputs with their real paths and value. Session Save does not silently copy every referenced artifact into its home.
3. **Identity envelopes:** JSON binds each memory record to an approved project and the client session that produced it.
4. **Rebuildable projections:** the global index and Review organize source records without becoming a second authority.

Capture remains deliberate and user-invoked. Memory is useful without Session Save because its canonical material remains ordinary Markdown and JSON.

## Portable behavior

Four open-format canonical Agent Skills implement Tag, Save, Summary, and Audit. Additive Checkpoint, Close, and Review wrappers expose clearer lifecycle language without changing those implementations. Pickup is a separate read-only access skill, not another capture state. Each installed skill receives a small `CLIENT.md` identifying `claude` or `codex` and a tiny `scripts/session_save.py` launcher. Every launcher executes the one manifest-owned kernel under `~/.local/share/session-save/`. The guide owns product behavior; adapters own invocation and optional host capabilities.

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
7. Project identity is a user-approved registry name after Unicode/case normalization, never punctuation normalization or a semantic match.
8. Project registration creates no content folder; the first approved record does.

## Project registry

`sessions/_PROJECTS.md` remains the user-readable approved registry. The kernel exposes exact list/check/register operations and a strict begin flag used by normal skills. Historical unregistered labels remain readable and are reported separately by Audit. Slug collisions fail closed. There are no automatic aliases, keyword clustering, lifecycle-stage inference, or master-plan writes.

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

## Pickup read plane

`pickup-sources` is the only supported reader for restart briefs. It has three phases:

1. approved-project and candidate metadata;
2. exact record selection with narrative paths, sizes, fingerprints, and a selection token;
3. bounded content returned only with that unchanged token after consent.

The read plane opens the configured home and every descendant through retained, no-follow directory descriptors. It validates schema, types, project/client/path agreement, timestamps, status, and record IDs before ranking. Reads are capped at 64 KiB per narrative and 256 KiB per request. Directory, registry, envelope, checkpoint, and malformed-record counts are bounded.

Pre-consent output contains no saved descriptions, session names, gists, narrative text, or attacker-controlled corruption details. A changed envelope or narrative invalidates the selection token. The model never opens returned paths; external artifact references remain references.

Pickup performs no mutation and emits no event, receipt, record, project, report, telemetry, or continuation relationship. The skill adds provider disclosure, content consent, exact file citations, evidence questions, and a separate scoped action confirmation around this kernel boundary.

## Global audit

`audit-sources` returns record envelopes, canonical approved project names, registration state, and available tag/human/agent paths across all clients. The skill groups only the returned approved identity and attributes every factual bullet to its client and source path. Case-only migrated labels may map to one canonical project; punctuation and semantic variants do not. Unregistered labels remain separate; contradictions remain visible. Audit cannot mutate the project registry or a master plan. `write-audit` atomically publishes the combined weekly report.

## Home resolution

1. explicit `--home`;
2. `SESSION_SAVE_HOME` or legacy `SAVE_SYSTEM_HOME`;
3. `~/.config/session-save/config.json`;
4. legacy Claude pointer during migration;
5. `~/Desktop/session-logs/`.

The shared config is never an uninstall target.

## Installation boundary

Claude and Codex have separate SHA-256 ownership manifests. The shared kernel has its own exact manifest. Unrelated client collisions are skipped; an unowned conflicting shared kernel fails installation. Managed replacements are backed up below the Session Save state directory.

Install, uninstall, and recovery share one retained global lock and one cross-surface journal. The journal binds exact allowlisted operations to root directory identities, prior/intended hashes, exact backup paths, and journaled temporary names. Every mutation is revalidated and executed relative to retained root descriptors. A crash before, during, or after replacement is recovered on the next run; an unprovable state fails closed behind the upgrade marker. Ownership manifests commit last.

Uninstall considers only allowlisted regular files whose current hash matches the relevant manifest and retains the shared kernel while any managed launcher remains. Alpha.5 must be uninstalled before reinstalling alpha.4 because alpha.4 does not know Pickup paths.

The shared home’s records, config, legacy sources, migration receipts, and backups remain user data and are not deletion targets.

## Migration

V1 records are inventoried before mutation. Records containing symlinks are refused. Apply copies each safe legacy directory into private staging, writes its envelope there, atomically places it under `sessions/<project>/claude/`, rebuilds the view, and emits a receipt. Every source directory remains in place.

## Degraded modes

- Missing stable session ID → client + slug fallback.
- Missing rename/archive tools → print manual guidance.
- Missing historical chat access → disable sweep outside visible chats.
- Missing context or filesystem permission → abort rather than fabricate a save.
- Legacy records awaiting migration → doctor reports not ready and skills stop.
