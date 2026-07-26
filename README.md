# Session Save System

![Session Save System — one memory home for Claude Code and Codex](docs/assets/session-save-header.svg)

**One memory home. Two agent clients. Four deliberate moments.** Session Save is a local session-memory architecture that turns captured context, decisions, progress, artifact references, and next state into source-attributed records you own.

[Open the site](https://youkistudios.github.io/session-save-system/) · [Read the usage guide](USAGE.md) · [See the architecture](docs/ARCHITECTURE.md) · [Review the safety model](docs/SAFETY-MODEL.md)

> **Status: v2.0 alpha.5, tested local kernel.** Installer, recovery, migration, namespace, concurrency, index, audit-input, Pickup read boundaries, and uninstall behavior are exercised in isolated tests. Live end-to-end Pickup behavior remains a separate release witness; the two-direction Claude ↔ Codex gate depends on both clients being available.

## The problem

AI work now crosses clients, but session memory remains trapped inside each chat list. Claude can research a project, Codex can implement it, and neither record naturally tells the same project story. Throwing both into one undifferentiated folder creates collisions and erases provenance.

Session Save keeps one local home while preserving both truths:

1. all records belong to the user’s projects;
2. every record retains the client session that produced it.

## The product model

| Moment | Claude Code | Codex | Outcome |
|---|---|---|---|
| **Tag** | `/session-tag` or `/st` | `$session-tag` / Skills | Name, project, gist, assets, honest verdict |
| **Checkpoint** | `/session-checkpoint` | `$session-checkpoint` / Skills | Immutable in-flight checkpoint |
| **Close** | `/session-close` | `$session-close` / Skills | Human close-out and technical resume state |
| **Review** | `/session-review` | `$session-review` / Skills | One source-attributed project view across clients |

The public lifecycle names are additive wrappers. The established canonical skills—`session-save` (`/ss`), `session-summary` (`/ssum`), and `session-audit` (`/sa`)—remain installed and unchanged.

**Pickup is the way back in, not a fifth moment.** In a fresh session use `/session-pickup` in Claude Code or `$session-pickup` in Codex. Select one exact approved project and saved session, review which bounded notes would be read, consent to the cited handover, then confirm the proposed next action. Pickup creates no record or continuation lineage.

## Shared file model

```text
session-logs/
├── _INDEX.md                         generated global view
├── GUIDE.md                          shared behavioral rulebook
├── sessions/
│   ├── _PROJECTS.md
│   └── <project>/
│       ├── claude/<date>_<slug>/
│       │   ├── record.json
│       │   ├── tag.md
│       │   ├── checkpoints/<event>.md
│       │   ├── human.md
│       │   └── agent.md
│       └── codex/<date>_<slug>/...
├── events/<date>/<event>.json
└── audits/global/<week>_audit.md
```

A client directory appears lazily on its first save. Project views aggregate Claude and Codex only under an exact user-approved project name, while the `client_id` remains present in every envelope, index row, and audit claim. Similar tags or keywords never create or merge projects.

## Install

Requirements: macOS or Linux, Python 3, Claude Code and/or Codex.

```bash
git clone https://github.com/youkistudios/session-save-system
cd session-save-system
./install.sh
```

The default installs both adapters:

- Claude Code → `~/.claude/skills/` plus lifecycle and compatibility slash commands; an unrelated existing command is preserved and the corresponding skill remains available through Skills;
- Codex → `~/.agents/skills/`;
- one canonical kernel → `~/.local/share/session-save/session_save.py`;
- shared config → `~/.config/session-save/config.json`;
- records → `~/Desktop/session-logs/` unless configured otherwise.

Choose another home before first install:

```bash
SESSION_SAVE_HOME="$HOME/Documents/session-logs" ./install.sh
```

Install only one adapter when needed:

```bash
SESSION_SAVE_CLIENTS=claude ./install.sh
SESSION_SAVE_CLIENTS=codex ./install.sh
```

GUI clients may require permission to write the chosen directory. Unsupported rename/archive controls degrade to a printed manual instruction; saving does not depend on them.

## Existing v1 records

The installer never silently moves them. It reports a required copy-first migration:

```bash
python3 scripts/session_save.py --home "$HOME/Desktop/session-logs" \
  migrate-v1 --client claude --dry-run

# Inspect every source and destination, then explicitly apply:
python3 scripts/session_save.py --home "$HOME/Desktop/session-logs" \
  migrate-v1 --client claude --apply
```

Migration copies legacy records under the Claude namespace, generates identity envelopes and a receipt, and preserves every original directory.

## Why there is a small kernel

An instruction-only system can write Markdown, but two open desktop clients must not race while editing one index. The dependency-free Python kernel owns only persistence mechanics:

- safe client/project paths;
- globally unique record and event IDs;
- client namespaces;
- immutable checkpoint allocation;
- serialized and atomic metadata writes;
- rebuildable global index;
- source-attributed audit input;
- bounded, descriptor-safe read-only Pickup sources;
- copy-first migration.

Models still author the summaries. The four-moment product stays small.

## Verify

```bash
./tests/run.sh
python3 scripts/generate_manifest.py
python3 scripts/validate_repo.py
```

The 41-test suite covers one-kernel installation, thin launchers, deterministic approved-project safety, audit and Pickup non-mutation, exact session selection, consent-bound content tokens, per-file and total read bounds, migrated checkpoints, shared/client collisions, cross-surface transaction rollback, hard-crash recovery, single-client installs, partial and proof-based uninstall, isolated namespaces, uniquely named checkpoints, 24 simultaneous writes, copy-first migration, global audits, client ownership, symlink containment, traversal rejection, and static skill-contract alignment.

## Safety contract

- **One home, namespaced writers.** Claude and Codex never share a source record directory.
- **Project first, provenance always.** Global views aggregate without erasing the client.
- **Derived index.** `_INDEX.md` can be rebuilt from source envelopes.
- **No silent merging.** Similar titles, tags, keywords, and files are not project identity proof.
- **No automatic project plans.** Audit reports cited evidence; it cannot create projects, invent stages, or update a master plan.
- **Archive, never delete. Capture before archive.**
- **Prove before uninstall.** Only hash-matching managed adapter files are removed.
- **Records are user data.** Shared config, logs, migrations, and backups are outside uninstall scope.
- **Pickup is read-only and consent-bound.** Metadata contains no free-form saved narrative; selected notes are fingerprinted, bounded, and returned only with the exact disclosure token.
- **Saved text is untrusted.** It cannot authorize commands, browsing, external-file reads, or tool use.

## Honest limits

- This does not synchronize raw transcripts or recover context a client does not expose.
- Pickup does not automatically open referenced artifacts, resolve contradictions, or guarantee that saved summaries are true.
- Cross-provider Pickup sends selected note content to the active AI provider only after explicit disclosure and consent.
- Model-authored summaries can be incomplete or wrong.
- Stable session IDs, chat renaming, history listing, and archive controls vary by client.
- Claude Desktop/Cowork is not claimed by the Claude Code adapter.
- Windows support and non-Claude/Codex adapters are not yet claimed.
- A local directory may still be synchronized by iCloud or another service.

## License

MIT © 2026 Youki Studios. See [LICENSE](LICENSE), [PROVENANCE.md](PROVENANCE.md), and [SECURITY.md](SECURITY.md).
