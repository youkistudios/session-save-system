# ADR 0004 — One installed kernel with thin compatibility launchers

- Status: Accepted for implementation
- Date: 2026-07-26

## Context

Session Save v2 installs the complete persistence kernel into each of four skills for both Claude Code and Codex. The eight copies are currently byte-identical, but every upgrade must replace all of them successfully or risk client and skill drift.

The skills currently invoke `scripts/session_save.py` relative to their own directory. Requiring a new shell command on `PATH` would be fragile in GUI clients, and rewriting all skill contracts during packaging convergence would combine unrelated risks.

## Decision

Install one canonical standard-library kernel at:

```text
~/.local/share/session-save/session_save.py
```

Keep `scripts/session_save.py` inside each installed skill as a small compatibility launcher. The launcher resolves the canonical path and replaces itself with the current Python interpreter running that kernel. `SESSION_SAVE_KERNEL` and `SESSION_SAVE_LIB_DIR` exist only as explicit administration/test overrides.

The shared kernel and version file receive their own exact SHA-256 ownership manifest. Managed replacements are backed up. An unmanifested conflicting shared kernel fails installation rather than being claimed. Uninstall removes the shared package only when no managed Claude or Codex adapter manifest remains, and only when its files still match the shared manifest.

Repository development and migration commands continue to use `scripts/session_save.py` directly. Installed skills continue to invoke their local `scripts/session_save.py`, so no user ritual or skill instruction changes.

## Consequences

- One kernel implementation serves every installed skill and client.
- GUI clients do not depend on shell `PATH` configuration.
- Existing skills, commands, aliases, records, schema, and invocation behavior remain unchanged.
- The eight launchers are intentionally duplicated adapter code, not duplicated persistence implementations.
- A missing or symlinked canonical kernel fails clearly and does not fall back to an embedded copy.
- Custom library paths require the same explicit environment override at runtime.
- Version-directory switching and automatic rollback are deferred until there is evidence that a stable manifest-owned path is insufficient.
