# Client witness — 2026-07-23

## Scope

Synthetic local checkpoint invocation against a temporary shared home. No personal session record or production home was used.

## Environment

- Codex CLI `0.145.0`
- Claude Code `2.1.217`
- macOS
- Python 3 standard-library kernel
- Temporary repo-scoped Agent Skill named `session-save-v2-witness`

## Codex result — PASS

Codex was explicitly asked to invoke the installed witness skill, create a first checkpoint for project `Dual Client Witness`, and execute rather than explain.

Observed sequence:

1. Codex discovered and loaded the repo-scoped Agent Skill.
2. Adapter identity resolved as `codex`.
3. Kernel doctor resolved the temporary shared home.
4. No existing record was found.
5. One provisional Codex-namespaced record was created.
6. One immutable checkpoint path was allocated and written.
7. The source envelope was synchronized.
8. Two operation events were emitted.
9. The global index contained one attributed Codex row.

Resulting shape:

```text
sessions/dual-client-witness/codex/
└── 2026-07-23_dual-client-witness-codex/
    ├── record.json
    └── checkpoints/<timestamp>_<event>.md
```

Envelope evidence:

```json
{
  "schema_version": "2.0",
  "client_id": "codex",
  "project": "Dual Client Witness",
  "status": "provisional",
  "model_id": null,
  "provider_session_id": null
}
```

Null model/session identity was correct: the adapter did not fabricate unavailable metadata.

## Claude Code result — BLOCKED BY AUTHENTICATION

Claude Code discovered sufficiently to launch, but the non-interactive request stopped before skill execution:

```text
Failed to authenticate: OAuth session expired and could not be refreshed
```

This is not a persistence-kernel failure and is not counted as a Claude pass. Claude Code support remains structurally and deterministically tested through the adapter/install suite; live skill invocation is still pending re-authentication.

## Evidence boundary

This witness proves one real Codex skill-to-filesystem checkpoint path. It does not prove all four moments, Claude live invocation, Desktop UI behavior, summary correctness, stable session IDs, rename/archive controls, or production readiness.
