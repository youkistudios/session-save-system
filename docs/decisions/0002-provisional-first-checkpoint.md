# ADR 0002: Allow a provisional first index row from `/ss`

- Status: Accepted
- Date: 2026-07-23

## Context

A checkpoint is useful before end-of-session tagging, but the original guide
both said `/st` alone creates index rows and instructed `/ss` to ensure a row
exists.

## Decision

When `/ss` is the first command, it may create exactly one 🟡 provisional row
after resolving the session identity and folder. The gist states that a
checkpoint was saved and `/st` is still required. `/st` upgrades that row in
place and supplies the verdict. `/ssum` still requires an existing row.

## Consequences

The index can represent an intentionally untagged session without inventing
state. Implementations must treat a second row for the same identity as a defect.
