# Safety Model

## Assets to protect

1. Existing Claude skills and commands that happen to share a name.
2. Local modifications to previously installed Session Save files.
3. Session logs, summaries, indexes, and project registries.
4. The user’s authority over renaming and archive actions.

## Installer guarantees

- A target without a matching manifest entry is treated as unrelated unless it
  is already byte-identical to the distribution file.
- Unrelated collisions are skipped, not overwritten.
- Every replacement of a previously managed file is copied into a timestamped
  backup tree before installation.
- The ownership manifest records exact SHA-256 identities and relative paths.
- Tests may redirect both Claude config and log home; production defaults are
  never required for validation.

## Uninstaller guarantees

- No ownership manifest means no deletion.
- Only allowlisted relative paths are considered.
- Only regular files whose current SHA-256 equals the recorded hash are removed.
- Modified files, unknown paths, symbolic links, other non-files, log homes, and
  backup trees are preserved.
- Skill directories are removed only with `rmdir`, and therefore only when
  empty.

## Workflow guarantees

- Archive, never delete.
- Capture before archive.
- A sweep proposes changes and waits for approval.
- `/ss` may establish one provisional index row when it is the first command;
  it does not infer FINISHED/LIVE/STALE.
- `/st` upgrades the same row; `/ssum` closes it. Duplicate rows are a defect.

## Recovery

Installer backups live under
`<Claude config>/session-save-system-backups/<timestamp>/`. Copy the desired file
back manually after inspection. Uninstall intentionally leaves this directory
and the entire log home untouched.

## Out of scope

The system does not encrypt logs, control filesystem backups or cloud sync,
verify model-generated summaries, or guarantee that a host exposes complete
session history. Users should choose a log location and permissions appropriate
to the sensitivity of their work.
