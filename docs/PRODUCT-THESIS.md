# Product Thesis

## Claim

The durable unit of AI-assisted work should be a small, user-owned record—not a
transcript trapped behind a vague chat title. Session Save System turns a manual
save habit into a consistent local memory layer.

## User and job

The primary user works across several long or branching Claude Code sessions.
They need to stop, resume, archive, and review work without reconstructing state
from raw transcripts or trusting an opaque memory service.

## Product model

The system separates four moments:

1. **Tag:** establish identity, gist, assets, and honest state.
2. **Save:** preserve in-flight working state.
3. **Summarize:** close the record for both human reading and agent resumption.
4. **Audit:** synthesize recent records across projects.

These moments share one rulebook and one file identity. The index is a routing
surface, not a second source of truth.

## Value

The product reduces restart cost, forgotten decisions, and noisy recent-session
lists while keeping records inspectable and portable. Manual invocation is a
feature: the user knows when a checkpoint happened and retains authority over
renaming and archive decisions.

## Proof standard

The repository can prove installer ownership behavior, file-model consistency,
and isolated uninstall safety. It cannot prove that every host exposes complete
session context or management tools, nor that generated summaries are always
correct. Those limits are explicit.
