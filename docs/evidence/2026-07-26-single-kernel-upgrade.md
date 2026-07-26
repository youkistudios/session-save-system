# Single-kernel upgrade witness — 2026-07-26

## Scope

Behavior-preserving SS1 packaging convergence from `2.0.0-alpha.1` at commit `3f9525f` to the `2.0.0-alpha.2` candidate on branch `feature/continuity-first`.

No session schema, commands, aliases, record identity, or four-moment behavior changed.

## Frozen baseline

Before implementation:

- repository tests: 20/20 passed;
- production home doctor: ready for Claude and Codex;
- schema: `2.0`;
- records: 32;
- migration required: 0;
- installed full-kernel copies: 8;
- installed kernel SHA-256: `925929d15df584ef9c47c5d256b5ba306aa1ea4df0f5c2fc3aba78367213d5ec`.

A user-owned external baseline contains a copy and per-file digest inventory of all 32 validated v2 records. A legacy symlink outside the v2 record layout was detected, excluded, and left untouched.

## Isolated upgrade rehearsal — PASS

The actual `3f9525f` installer was run in a temporary environment to create an alpha.1 installation. The candidate installer then upgraded that environment.

Observed:

- one canonical shared kernel installed;
- eight full kernel copies replaced by eight 996-byte launchers;
- all eight prior kernels backed up;
- installed launcher successfully executed `doctor` through the canonical kernel;
- doctor returned ready.

## Test suite — PASS

The candidate suite passes 23 tests.

New coverage includes:

- one shared kernel plus exact thin Claude/Codex launchers;
- launcher-to-kernel execution;
- unowned shared-kernel conflict refusal;
- partial uninstall retaining the kernel for a remaining launcher;
- full uninstall removing an unneeded hash-proven shared kernel;
- modified shared-kernel preservation.

Existing concurrency, migration, ownership, symlink, traversal, audit, and record-isolation tests remain green.

## Real installed upgrade — PASS

The candidate installer was run against the current managed Claude Code and Codex installation.

Observed:

- canonical kernel: `~/.local/share/session-save/session_save.py`;
- shared manifest: `~/.local/share/session-save/install.manifest`;
- eight installed launchers: 996 bytes each;
- all eight prior full kernels backed up under the existing per-client backup trees;
- Claude launcher doctor: ready;
- Codex launcher doctor: ready;
- schema: `2.0`;
- records: 32;
- migration required: 0.

All baseline record files were compared by SHA-256 after installation:

```text
records checked: 32
missing files: 0
changed files: 0
result: PASS
```

The existing legacy-compatible Claude home pointer was unmanifested and therefore skipped rather than claimed. Shared config resolution remained authoritative and both clients resolved the correct home.

## Evidence boundary

This witness proves packaging convergence, installed launcher execution, and record-byte preservation on the current macOS installation.

It does not yet prove:

- all four live skill moments in current Claude Code;
- all four live skill moments in current Codex;
- cross-client thread continuation;
- profile behavior;
- a second POSIX operating environment;
- Windows support.

Those remain later gates.
