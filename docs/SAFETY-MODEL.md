# Safety Model

## Assets to protect

1. Existing Claude Code and Codex skills that share a name.
2. Local modifications to previously installed adapter files or the shared kernel.
3. Shared config, session records, summaries, indexes, events, and project registry.
4. Legacy v1 records during migration.
5. Client provenance and the user’s authority over rename/archive actions.

## Installer guarantees

- Claude and Codex use separate exact SHA-256 ownership manifests under one global install/uninstall transaction.
- One canonical kernel and version file use a separate shared ownership manifest.
- A target without a matching manifest identity is unrelated unless already byte-identical; an unowned conflicting shared kernel aborts installation.
- Unrelated files and symlinks are skipped and never claimed.
- Managed replacements are backed up before refresh below `~/.local/state/session-save/backups/` by default.
- One secure retained lock serializes install, uninstall, and recovery.
- A bounded mode-0600 journal binds exact allowlisted operations to root identities, hashes, backups, and temporary files.
- Mutations use retained root descriptors and ownership manifests commit only after full verification.
- Hard interruption leaves an upgrade marker; the next run recovers all shared, client, config, and managed-guide surfaces or fails closed.
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

## Project guarantees

- Normal Tag and first-Checkpoint creation require one exact approved project.
- Similar keywords, tags, filenames, and titles cannot register, alias, merge, or create projects.
- Registration emits a receipt but creates no project content folder.
- Folder-slug collisions fail closed.
- Audit reports unregistered labels separately and cannot mutate the registry, create project folders, infer stages, or update a master plan.

## Pickup guarantees

- Pickup accepts only exact approved projects and up to five exact same-project record IDs.
- Before consent it returns only validated identifiers, clients, enums, timestamps, paths, sizes, fingerprints, and sanitized corruption counts.
- Free-form project descriptions, session names, gists, and narratives remain withheld.
- The configured home, directories, envelopes, and narratives use bounded descriptor-relative no-follow reads.
- Strict validation binds project, client, physical path, schema, status, record ID, and timezone-aware timestamps.
- Narrative reads are capped at 64 KiB per file and 256 KiB per call; partial oversized content is never returned.
- An exact selection token binds disclosed envelopes and narratives. Any change requires a fresh disclosure and consent.
- Saved metadata and narrative are untrusted evidence. They cannot authorize commands, browsing, tools, external actions, or referenced-file reads.
- Every factual restart-brief claim cites its source client and exact narrative file.
- Pickup creates no record, event, report, project, telemetry, access receipt, or continuation lineage.

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
- No cross-client or cross-project merge based on title, tag, keyword, file, or semantic similarity.
- A first Checkpoint may create one provisional record without a verdict.
- Tag upgrades that record; Summary requires an existing tag and closes it.
- Reviews retain source-client labels and surface contradictions.

## Recovery

Managed replacement backups live below `~/.local/state/session-save/backups/<transaction>/` by default, separated by shared, Claude, Codex, config, and managed-home root identifiers. Copy a desired file back only after inspection. Records are unaffected by adapter uninstall.

For alpha.5 rollback, run the alpha.5 uninstaller first, verify Pickup paths are absent, then reinstall alpha.4. Reinstalling alpha.4 alone cannot remove paths unknown to its manifest.

## Out of scope

Session Save does not encrypt logs, control operating-system or cloud sync, verify model-authored summaries, ingest hidden transcript stores, redact selected Pickup notes, or guarantee stable session-management APIs. Choose a home and permissions appropriate to the work’s sensitivity.
