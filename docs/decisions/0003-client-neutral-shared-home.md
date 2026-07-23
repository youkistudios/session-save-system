# ADR 0003 — Client-neutral shared home

- Status: Accepted for v2 alpha
- Date: 2026-07-23

## Context

The original system installed only into Claude Code and stored records directly below each project. Supporting Codex by pointing both clients at the same mutable files would erase provenance and create concurrent index/checkpoint races.

## Decision

Support Claude Code and Codex through the same four open-format Agent Skills and one shared home. Namespace source records as `sessions/<project>/<client>/<session>/`. Require `client_id`; keep `model_id` optional. Add a dependency-free local kernel that serializes mutations, writes atomically, allocates immutable event/checkpoint paths, and rebuilds global views from source envelopes.

Keep client invocation and optional chat capabilities in thin adapters. Preserve legacy records through explicit dry-run and copy-first migration into the Claude namespace.

## Consequences

- Work can be audited by project across clients without losing source identity.
- The system now requires Python 3 and POSIX file locking for its claimed platforms.
- `_INDEX.md` becomes a generated view rather than a directly edited record.
- Checkpoints become immutable files instead of one append-only Markdown file.
- Claude Desktop/Cowork, Cursor, Windows, and other clients remain outside the implemented claim.
- A future adapter must conform to the same schema and four moments rather than forking the core.
