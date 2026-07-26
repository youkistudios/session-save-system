# ADR 0005 — Deterministic approved projects

- Status: Accepted
- Date: 2026-07-26

## Context

Session Save combines Claude Code and Codex records by project. Similar tags and language are not reliable project identity: unrelated websites may share words such as navigation, launch, onboarding, or redesign. Semantic grouping could create incorrect folders, false progress, cross-context disclosure, and authoritative-looking plans from unrelated evidence.

The existing human registry at `sessions/_PROJECTS.md` already represents user-approved project categories, but the kernel did not expose deterministic registration/check commands or a strict creation gate.

## Decision

Project identity is explicit and deterministic. Unicode normalization and letter-case folding preserve compatibility with migrated display labels; punctuation, words, tags, and themes are never normalized or inferred.

- `project-list` returns approved registry entries and observed unregistered record labels.
- `project-register` appends one explicitly approved project, emits an immutable receipt, and creates no project content folder.
- `project-check` requires an exact approved display name.
- Normal Tag and first-Checkpoint flows call `begin --require-registered-project`.
- Audit annotates registration state and reports unregistered labels without mutation.
- Slug collisions fail closed.
- Existing records and direct kernel callers remain backward-readable; strict enforcement is additive.

Session Save does not perform semantic project matching, automatic aliases, automatic project creation, lifecycle-stage inference, or master-plan updates.

## Consequences

Users may answer an occasional project-selection question. This visible friction is preferable to silent false grouping. Existing historical labels remain readable and appear as unregistered audit evidence until the user explicitly approves the corresponding project name.

The registry remains user-readable Markdown. No database, embedding service, graph, background classifier, or migration rewrite is introduced.
