# Deterministic project safety witness — 2026-07-26

## Scope

Isolated kernel and skill-contract witness for explicit project approval. No production record or project registry was modified.

## Positive witnesses

1. A fresh home returned an empty approved registry.
2. `project-register` recorded `Website Alpha` and emitted an immutable receipt.
3. Registration alone created no project content folder.
4. Strict Claude record creation succeeded after exact registration.
5. A separate `Website Beta` registration and Codex record remained in its own project folder.
6. Audit returned approved-project inventory and registration state for each source.

## Rejection witnesses

The kernel rejected:

- strict record creation for an unapproved project;
- punctuation-changed and word-changed project lookup while permitting letter-case-only migrated labels;
- a second approved name resolving to an existing project folder slug;
- a fenced Markdown example presented as if it were an approved entry.

Non-ASCII-only project identity produced one stable digest-based folder slug across registration, lookup, and strict record creation. Escaped Markdown characters round-tripped through the registry. A legacy-compatible direct caller retained previously valid bracket/pipe project naming outside strict mode. A migrated case-only label reused its existing source record while Audit returned the canonical approved project name. Full-width punctuation, compatibility numerals, and case-fold expansions remained distinct and unapproved.

## Non-mutation witness

A legacy-compatible direct record using the unregistered label `Website Creation Notes` was visible to Audit as unregistered. Audit did not:

- add it to `_PROJECTS.md`;
- merge it with either approved website project;
- create another project directory;
- alter any source record.

Registry and project-directory inventories were hashed before and after Audit and remained unchanged. A direct Audit against a nonexistent home returned zero sources without creating the home or registry.

## Evidence boundary

This proves deterministic kernel primitives and portable skill instructions. It does not prove model compliance in every live host interaction. Live Tag/Checkpoint ambiguity prompts remain a release witness.
