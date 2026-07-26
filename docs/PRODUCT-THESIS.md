# Product Thesis

## Claim

The durable unit of AI-assisted work should belong to the user—not to the model, vendor, or chat application that happened to produce it.

Session Save is a client-neutral local session-memory architecture. Claude Code and Codex invoke the same four moments while writing captured context, decisions, progress, artifact references, open questions, and resumption state into one user-owned, source-attributed home.

## User and job

The primary user works across long or branching sessions and may move one project between Claude Code and Codex. They need to stop, resume, close, and review work without reconstructing state from transcripts or losing which client produced a decision.

## Product model

1. **Tag:** establish client, project, name, gist, assets, and honest state.
2. **Checkpoint:** preserve in-flight state as an immutable client-owned checkpoint.
3. **Close:** close the source record for human reading and agent resumption.
4. **Review:** synthesize recent records across clients, grouped by project.

The four moments share one rulebook and one record contract. Client adapters own invocation differences; the kernel owns persistence. `_INDEX.md` is a rebuildable view, not a second source of truth.

## Why client-neutral, not merely model-neutral

Cursor can run several models; Claude and Codex can appear in several interfaces. The storage boundary therefore distinguishes `client_id` from optional `model_id`. Implemented clients are `claude` (Claude Code) and `codex`. Model identity never selects a directory and is recorded only when reliable.

## Value

- one project memory surface across supported clients;
- provenance retained on every record and audit statement;
- no account, database, daemon, telemetry, or hosted lock-in;
- ordinary Markdown/JSON records that remain readable without the product;
- safe simultaneous saves through isolated namespaces and atomic derived views;
- a future adapter boundary that does not require a schema fork.

## Product laws

1. One home, namespaced writers.
2. Project first in human views; client always present in provenance.
3. No silent cross-client merging.
4. Source records are primary; global views are derived.
5. Manual invocation remains a feature.
6. Capture before archive; archive never delete.
7. Unsupported client capabilities degrade honestly.
8. Cross-client support must not add a fifth user ritual.
9. Project identity is explicit; semantic resemblance never creates or merges a project.
10. Review summarizes evidence but cannot own or update an authoritative master plan.

## Proof standard

The repository proves dual-adapter installation, schema separation, serialized atomic writes, index rebuilding, migration behavior, and uninstall safety through isolated tests. It does not yet prove complete live skill behavior in every Claude Code and Codex version or guarantee model-authored summary quality.
