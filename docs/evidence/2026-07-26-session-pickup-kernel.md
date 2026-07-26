# Session Pickup alpha.5 evidence — 2026-07-26

## Scope

Evidence for the read-only `pickup-sources` kernel contract, Pickup installation unit, and transactional install/uninstall recovery. This receipt distinguishes isolated deterministic tests from live client behavior.

## Baseline

- Source baseline: `b99f8ca3131269e0fd8ff181fb906139889d0674`
- Baseline release: `2.0.0-alpha.4`
- Production rollback baseline: `~/.local/state/session-save/baselines/20260726-121908/`
- Frozen record count: 32
- Frozen manifest SHA-256: `d57505dedfdd001a14c194ff70cbe1b2af3855e2303616c62732a0005cc5e1fd`

## Isolated evidence

`./tests/run.sh` passes 41 grouped cases, including:

- exact approved-project and record selection;
- metadata/content separation;
- withheld free-form pre-consent fields;
- exact selection-token enforcement and stale-token rejection;
- 64 KiB/file and 256 KiB/request enforcement;
- unselected and external canaries;
- full-tree non-mutation;
- corruption exclusion and sanitized reporting;
- migrated `checkpoints.md` marker behavior;
- root and narrative symlink refusal;
- Pickup skill static disclosure, citation, question, and confirmation contracts;
- 37-file Claude and 24-file Codex clean manifests;
- Pickup unit and command collision handling;
- Claude-only and Codex-only installation truth;
- cross-surface rollback after injected failure;
- hard-crash recovery before and after replacement;
- journaled temporary cleanup;
- exclusive global lock serialization;
- malformed journal fail-closed behavior;
- all earlier deterministic project, migration, concurrency, uninstall, and lifecycle regressions.

Independent read-only implementation reviews reached:

- Security: **PASS** after descriptor-rooted rollback and operation-specific journal allowlists.
- Product contract: no unresolved implementation blocker; live skill behavior remains a separate witness.

## Production non-mutation witness

The alpha.5 kernel listed five approved production projects and 32 valid records through Pickup without changing source content. Before active installation, and again after installation, the complete frozen production-record hash set must equal the rollback baseline.

## Live evidence boundary

A real Codex Pickup journey may be recorded once the release candidate is installed. Claude → Codex and Codex → Claude witnesses remain required before claiming two-direction live continuity. If Claude access is quota-blocked, the limitation must remain explicit; isolated tests do not substitute for the live witness.

## Exclusions

This receipt does not claim transcript recovery, semantic search, automatic continuation lineage, automatic artifact reads, summary truth, encryption, Windows support, or background capture.
