# Security Policy

Session Save writes local Markdown/JSON and installs Agent Skills for Claude Code and Codex. It has no network client, account, telemetry, daemon, transcript collector, or credential store.

## Supported version

Security fixes target the latest release on `main`. Alpha releases may change record contracts; migration safety remains mandatory.

## Reporting

Use GitHub private vulnerability reporting. Do not attach real session logs, credentials, or personal data to a public report; provide a minimal synthetic reproduction.

## Trust boundaries

### Adapters

Claude and Codex use separate ownership manifests. The installer skips unrelated files and symlinks, backs up managed replacements, and records exact SHA-256 identities. Uninstall removes only allowlisted, hash-matching regular files.

### Shared home

The config, log home, source records, events, migration receipts, and backups are user data—not managed installation files. Uninstall never targets them.

### Persistence kernel

The Python standard-library kernel validates client, project, and date path components; rejects symlinked descendants; enforces client ownership on mutation; refuses writes outside the resolved home; serializes mutations with a local file lock; and publishes metadata/views by atomic replacement. Checkpoints and events receive unique names. The global index is rebuildable and is not a source of truth.

### Model output

Narrative summaries remain model-authored and untrusted. The kernel proves persistence mechanics, not factual correctness. Raw hidden transcript stores are never read.

## User responsibilities

Choose filesystem permissions and synchronization policies appropriate to the sensitivity of your work. Desktop or Documents may be synchronized by iCloud or another service. Grant local clients access only to the intended home, inspect migration dry runs, and keep a separate backup of important records.
