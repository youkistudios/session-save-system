# ADR 0006: Session Pickup is a bounded read-only access layer

- Status: Accepted for 2.0.0-alpha.5
- Date: 2026-07-26

## Context

Session Save could capture and review memory but a fresh Claude Code or Codex session still required a manual sequence of finding paths, opening selected notes, and asking for a restart brief. Automatic semantic recall would weaken explicit project identity, provenance, and user control. Reading saved text directly through the model would also make file bounds, symlink resistance, and consent difficult to enforce.

## Decision

Add `session-pickup` as an access command, not a fifth capture state.

The kernel exposes `pickup-sources` with:

- approved-project listing;
- exact project candidate listing;
- repeatable exact same-project record IDs, maximum five;
- metadata disclosure separate from content;
- an exact selection token binding envelope and narrative fingerprints;
- descriptor-relative no-follow reads;
- 64 KiB per narrative and 256 KiB per request;
- strict record, client, project, physical-path, status, ID, and timestamp validation;
- deterministic latest immutable Checkpoint selection;
- sanitized malformed-record reporting;
- no mutation.

The client skill requires provider disclosure and user consent before narrative content, treats all saved material as untrusted evidence, cites the exact narrative file for every factual claim, asks only bounded evidence questions, and waits for a separate scoped action confirmation.

Pickup does not create records, register projects, persist briefs or answers, emit read receipts, populate `continuation_of`, add `thread_id`, or claim continuation lineage.

Installation is upgraded in the same release to one globally locked and journaled cross-surface transaction so adding the new client unit cannot leave a mixed package after interruption.

## Consequences

- A new session can safely move from exact saved evidence to a confirmed first step.
- Cross-client content transfer is visible and consent-bound.
- Natural-language convenience cannot become project-identity evidence.
- Artifact references remain references and are never automatically opened.
- The four capture moments remain Tag · Checkpoint · Close · Review.
- Live two-direction client evidence remains distinct from isolated kernel evidence.
