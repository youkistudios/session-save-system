# Session Save System

![Session Save System — a local memory layer for working chats](docs/assets/session-save-header.svg)

**A local, human-triggered memory layer for Claude Code sessions.** Four
commands turn a drifting chat into a named, indexed, resumable set of Markdown
records you control.

[Start with the usage guide](USAGE.md) ·
[Read the safety model](docs/SAFETY-MODEL.md) ·
[See the architecture](docs/ARCHITECTURE.md) ·
[Open the site](https://youkistudios.github.io/session-save-system/)

> Status: **v1.1, local instruction system.** Logging works anywhere Claude Code
> can write files. Automatic chat rename/archive depends on host-provided session
> tools and is not guaranteed.

## The problem

Working chats accumulate context but lose identity: titles drift, decisions hide
in transcripts, and a new session cannot tell finished work from a half-built
thread. Search helps only when you remember what to search for.

Session Save System creates a compact file model instead: one session, one
folder, one index row, and explicit state transitions.

## Four commands, one habit

| Command | Alias | Outcome |
|---|---|---|
| `/session-tag` | `/st` | Name the session, capture its gist and assets, decide FINISHED / LIVE / STALE, then route onward |
| `/session-save` | `/ss` | Append a small mid-session checkpoint; if used first, create one provisional index row |
| `/session-summary` | `/ssum` | Write human and agent close-outs, then mark the existing row closed |
| `/session-audit` | `/sa` | Read a week of summaries into a project-level report and prioritized next list |

If you remember one command, use `/st` at the end of a working chat.

## Install

```bash
git clone https://github.com/youkistudios/session-save-system
cd session-save-system
./install.sh
```

To keep logs outside Desktop or iCloud, choose a location before installing:

```bash
SAVE_SYSTEM_HOME="$HOME/Documents/session-logs" ./install.sh
```

The installer records exact SHA-256 identities for files it manages. It skips
unrelated collisions, backs up managed files before replacement, and gives the
uninstaller enough evidence to remove only byte-identical owned files.

## File model

```text
session-logs/
├── _INDEX.md                         one row per session
├── GUIDE.md                          operational rulebook
├── sessions/
│   ├── _PROJECTS.md                  user-approved registry
│   └── <Project>/<date>_<slug>/
│       ├── tag.md                    identity, gist, assets, verdict
│       ├── checkpoints.md            append-only working state
│       ├── human.md                  readable close-out
│       └── agent.md                  technical resume state
└── audits/<year>-W<week>_audit.md    weekly synthesis
```

`/st` normally creates the index row as open. If `/ss` comes first, it may
create one clearly marked provisional row; `/st` upgrades that same row in
place. `/ssum` closes an existing row and never creates a duplicate.

## Safety contract

- **Archive, never delete.** Session-management actions remain reversible.
- **Capture before archive.** Knowledge is saved before a chat leaves recents.
- **One identity, one record.** Session id, then slug, resolves updates in place.
- **Propose before sweep.** `/st all` writes a review and waits for approval.
- **Prove before uninstall.** Only manifest-listed files whose current hashes
  still match are removed; modified and unknown files are preserved.
- **Logs are user data.** Install, uninstall, and repository validation never
  remove the log home or backup directory.

See [SAFETY-MODEL.md](docs/SAFETY-MODEL.md) for boundaries and recovery.

## Validate locally

```bash
./tests/run.sh
python3 scripts/generate_manifest.py
python3 scripts/validate_repo.py
```

The isolated tests use temporary homes; they do not touch your Claude config or
session logs. Workflow definitions are staged under `automation/workflows/` and
remain inactive until a maintainer deliberately moves them into
`.github/workflows/`.

## Privacy and limits

Records stay as local Markdown; the system contains no network client,
telemetry, database, or account. Your chosen folder may still be synchronized
by the operating system or another service. The skills summarize available
session context; they cannot recover context that the host no longer exposes,
guarantee a model’s summary is correct, or rename chats where session tools are
absent.

## License

MIT © 2026 Youki Studios. See [LICENSE](LICENSE).
