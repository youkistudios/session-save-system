# Session Save System

![Session Save System — one memory home for Claude Code and Codex](docs/assets/session-save-header.svg)

**Save work in Claude Code, resume it in Codex, or go the other way.** Session Save writes local records of decisions, progress, referenced files, and next steps while keeping the client that produced each record visible.

[Open the site](https://youkistudios.github.io/session-save-system/) · [Read the usage guide](USAGE.md) · [See the architecture](docs/ARCHITECTURE.md) · [Review the safety model](docs/SAFETY-MODEL.md)

> **Status: v2.0 alpha.5.** Isolated tests cover installation, recovery, migration, simultaneous writes, indexes, bounded reads, and uninstall behavior. Claude-to-Codex and Codex-to-Claude resume flows have also been run on macOS. Windows and clients other than Claude Code and Codex are not yet supported.

## Why use it

AI work often moves between clients, while each chat history stays separate. Claude Code might research a project and Codex might implement it, but neither client can reliably reconstruct the other conversation.

Session Save gives both clients one local record directory. Records are grouped by the project name you approve, and every record keeps the client session that created it.

## The four moments

| Moment | Claude Code | Codex | Outcome |
|---|---|---|---|
| **Tag** | `/session-tag` or `/st` | `$session-tag` / Skills | Name, project, gist, assets, honest verdict |
| **Checkpoint** | `/session-checkpoint` | `$session-checkpoint` / Skills | Immutable in-flight checkpoint |
| **Close** | `/session-close` | `$session-close` / Skills | Human close-out and technical resume state |
| **Review** | `/session-review` | `$session-review` / Skills | One source-attributed project view across clients |

The clearer lifecycle names are aliases. Existing users can continue to use `session-save` (`/ss`), `session-summary` (`/ssum`), and `session-audit` (`/sa`).

The four moments above write or summarize records. **Pickup is a separate, read-only resume command**, not a fifth writing moment. In a fresh session, run `/session-pickup` in Claude Code or `$session-pickup` in Codex. Choose an approved project and saved session, review which notes the command proposes to read, consent to that handover, and confirm the next action. Pickup does not create a new record.

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

Start new Claude Code and Codex sessions after installation. A minimal cross-client journey is:

1. In Claude Code, run `/session-tag`, choose or approve the project name, and follow the prompt to checkpoint or close the work.
2. Open a fresh Codex session and run `$session-pickup`.
3. Choose the same project and exact saved session, review the proposed files, and consent to the handover.
4. Confirm the next action. Run `$session-checkpoint` later if the new work should be saved.

The same journey works in the other direction by swapping the clients.

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
