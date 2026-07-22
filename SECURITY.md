# Security Policy

Session Save System writes local Markdown and installs instruction files into a
Claude configuration directory. It has no network client, telemetry, daemon, or
credential store.

## Supported version

Security fixes target the latest release on `main`.

## Reporting

Use GitHub private vulnerability reporting when available. Otherwise contact a
maintainer privately. Do not attach real session logs, credentials, or personal
data to a public report; create a minimal synthetic reproduction.

## Trust boundary

The installer manages only the allowlisted skill, command, and home-pointer
paths recorded in `session-save-system.manifest`. The uninstaller removes a file
only when its current SHA-256 matches that record. Modified, unknown, and
non-regular files are preserved. Log homes and installer backups are never
uninstall targets.

Users remain responsible for permissions and synchronization policies on the
chosen log directory. A folder under Desktop may be synchronized by iCloud.
