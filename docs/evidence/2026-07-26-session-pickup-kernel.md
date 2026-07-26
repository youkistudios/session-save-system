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

## Live Claude ↔ Codex evidence

Two real client directions passed on macOS against an isolated approved project named `Website Launch Pickup Witness`.

### Claude → Codex

1. A real Claude Code session `95aa1ec2-e257-4f03-909e-537aee37993b` created the Tag and immutable Checkpoint for record `ce6b9e06577c4a93b83fd060e5946ba9`.
2. A second same-project Claude record contained unselected canaries, forcing real record selection.
3. Fresh Codex thread `019f9d8e-4f53-7e43-99e3-02c9e3ee7bab` listed approved projects, then both saved sessions, without narrative content.
4. Codex disclosed the exact Tag and Checkpoint paths and sizes.
5. Refusing consent caused no content request.
6. Fresh corrected Codex thread `019f9d9d-13dc-7a81-bcf3-6975d56fc606` used the exact selection token and produced a brief whose saved-work factual claims cited exact narrative paths.
7. The referenced external-secret contents and unselected record canaries did not enter output; the reference path itself remained visible as intended.
8. Codex asked for the missing affected workspace rather than inferring it, then stopped at the semantic-homepage-shell confirmation without editing or acting.
9. Complete before/after tree manifests were byte-identical.

### Codex → Claude

1. A real Codex session created and checkpointed record `cdfb2d9ada344f808b20429156ef2f20` under the same approved project.
2. A malformed same-project envelope was added as an adversarial fixture.
3. Fresh Claude Code session `ac0c128c-dce6-46db-8e36-eda9c364cfba` disclosed two exact Codex narrative paths, reported one sanitized corrupt-record count, and waited for consent.
4. Command-level stream evidence retained the exact selection-token content call and returned source narratives.
5. Claude omitted the empty Files section, asked for the missing affected workspace rather than inferring it, and then stopped at an exact scoped action confirmation.
6. External-secret contents did not enter output and the complete before/after tree manifests were byte-identical.

The retained evidence bundle is:

```text
~/.local/state/session-save/evidence/20260726-pickup-live/
```

Its `SHA256SUMS` digest is:

```text
37d82aa0c0fe6b00bd4e9294d84271600a995e44d27d8b28f894f8ecbc329ce6
```

The witnesses prove user-confirmed cross-client Pickup, not automatic continuation lineage. No `continuation_of` value was created or changed.

## Exclusions

This receipt does not claim transcript recovery, semantic search, automatic continuation lineage, automatic artifact reads, summary truth, encryption, Windows support, or background capture.
