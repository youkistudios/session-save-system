# Continuity-first implementation plan

Status: approved execution boundary, 2026-07-26.

## Product target

Prove that a user can checkpoint work in Claude Code, continue the correct thread in Codex, and later review both records together without merging their source ownership.

## Lean rule

Add only what the next witnessed behavior requires. A graph, daemon, cloud account, transcript collector, raw diff store, Git hook, workflow engine, MCP server, and analytics layer are not prerequisites.

## Phase loop

Every phase runs:

```text
baseline → smallest patch → isolated tests → adversarial review
→ remove unnecessary complexity → live witness → commit
```

Push occurs only when the phase is independently reversible and its evidence matches its claim.

## Phases

### SS0 — Baseline

Freeze repository commit, tests, installed copies, 32-record digest inventory, and rollback snapshot. Record live-client evidence limits.

### SS1 — One kernel

Replace eight installed kernel implementations with eight tiny launchers pointing to one manifest-owned canonical kernel. Change no schema or user behavior.

### SS2 — Minimal continuity contract

Add stable thread/workspace identity, explicit continuation links, and Business/Developer capture-policy presets. Prefer an additive 2.x envelope unless a breaking schema is proven necessary.

### SS3 — Claude↔Codex witness

Prove checkpoint → bounded handoff → acceptance → separately attributed continuation → combined chronology.

### SS4 — Deterministic recall

Add the smallest local search and bounded continuation compiler that meets frozen-corpus relevance and latency tests. No MCP initially.

### SS5 — Optional assistance

Dogfood reminders, then selected metadata. Automatic narrative, transcript, diff, and commit-trigger capture remain off.

### SS6 — Optional Git references

Observe repository, branch, current commit, and selected PR/issue only at explicit persistence moments. Hooks require a separate field-evidence gate.

### SS7 — OSKA bridge

Emit an allowlisted, cloud-safe, digest-bound projection. Distinguish prepared, submitted, accepted, pending review, imported/live, failed, and unknown destination states.

## Profile boundary

- Business: outcomes, decisions discussed, tasks, approvals, evidence references, handoffs.
- Developer: Business fields plus optional Git/debug/capability provenance when directly observed.
- Developer-light and Hybrid are overrides, not additional products.

Profiles set capture defaults. They never fork storage, ontology, skills, or kernel code.

## Current stop conditions

Stop if a phase:

- changes existing commands without aliases;
- rewrites the 32 records destructively;
- makes network access, a daemon, Git, MCP, or model API mandatory;
- allows one client to mutate another client’s source record;
- introduces automatic semantic truth promotion;
- adds infrastructure before a witnessed user behavior needs it.
