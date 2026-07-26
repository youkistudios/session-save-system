# Safety Model

## Assets to protect

1. Existing Claude Code and Codex skills that share a name.
2. Local modifications to previously installed adapter files or the shared kernel.
3. Shared config, session records, summaries, indexes, events, and project registry.
4. Legacy v1 records during migration.
5. Client provenance and the user’s authority over rename/archive actions.

## Installer guarantees

- Claude and Codex use separate exact SHA-256 ownership manifests.
- One canonical kernel and version file use a separate shared ownership manifest.
- A target without a matching manifest identity is unrelated unless already byte-identical; an unowned conflicting shared kernel aborts installation.
- Unrelated files and symlinks are skipped and never claimed.
- Managed replacements are backed up before refresh.
- The shared home config is created only when absent and is not installer-owned.
- Isolated tests can redirect home, config, Claude, and Codex locations.

## Persistence guarantees

- Client/project/path components reject traversal.
- Claude and Codex write separate source namespaces.
- Mutating commands require the active client and reject another client’s record.
- Every source envelope and derived view is written through atomic replacement.
- A local file lock serializes mutations across simultaneous clients.
- Checkpoints and events receive unique immutable paths.
- `_INDEX.md` is derived and can be rebuilt from source envelopes.
- Skills do not edit machine envelopes or the global index directly.

## Migration guarantees

- Dry-run inventory precedes apply and reports legacy symlinks.
- Records containing symlinks are refused rather than imported.
- Apply copies through private staging and atomic placement; it never moves or deletes a legacy record.
- Destination collisions are skipped.
- Every migrated record receives a source reference and event.
- A migration receipt states that sources were preserved.
- Historical model identity remains null unless proven.

## Uninstaller guarantees

- No manifest means no deletion.
- Only allowlisted paths are considered.
- Only regular files matching their recorded hash are removed.
- The shared kernel remains installed while any managed client launcher remains.
- Modified, unknown, missing, symlinked, and non-file targets are preserved.
- Shared config, log home, legacy sources, migration receipts, and backups are never targets.
- Directories use `rmdir` only and therefore disappear only when empty.

## Workflow guarantees

- Archive, never delete.
- Capture before archive.
- One record per client session.
- No cross-client merge based on title similarity.
- A first Save may create one provisional record without a verdict.
- Tag upgrades that record; Summary requires an existing tag and closes it.
- Audits retain source-client labels and surface contradictions.

## Recovery

Adapter backups live below each client config root:

- `<Claude config>/session-save-system-backups/<timestamp>/`
- `<Agents config>/session-save-system-backups/<timestamp>/`

Customized guide backups use `~/.local/state/session-save/backups/` by default. Copy a desired file back only after inspection. Records are unaffected by adapter uninstall.

## Out of scope

Session Save does not encrypt logs, control operating-system or cloud sync, verify model-authored summaries, ingest hidden transcript stores, or guarantee stable session-management APIs. Choose a home and permissions appropriate to the work’s sensitivity.
