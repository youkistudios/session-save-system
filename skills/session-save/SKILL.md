---
name: session-save
description: Save a source-attributed mid-session checkpoint into the shared local Session Save home. Use when the user asks to save, checkpoint, preserve current state, or pause unfinished work. Not an end-of-session close-out.
license: MIT
compatibility: Requires Python 3 and local filesystem write access. Installed adapters support Claude Code and Codex.
---

# Session save — checkpoint

Resolve this skill directory as `SKILL_DIR`. Read `CLIENT.md` beside this file for the installed `client_id`. Read the shared home’s `GUIDE.md`.

1. Run `python3 "$SKILL_DIR/scripts/session_save.py" doctor --client <client_id>`. Stop unless `ok` is true and `migration_required` is zero.
2. Locate the current record with `locate --client <client_id> --session-id <id>` when a real stable host ID exists, otherwise `locate --client <client_id> --slug <known-slug>`.
3. If no record exists, resolve project and name as the guide requires, then run `begin --client <client_id> --project <project> --name <name> --status provisional --gist "Checkpoint saved; run session-tag to tag this session."`. Never invent a verdict. This is the single provisional record.
4. Run `checkpoint-path --client <client_id> --record <record>` and write one Markdown checkpoint to the returned unique path. Use `### <HH:MM> — <client_id>` followed by **Now**, **Working on**, **Next**, and **Watch**. Keep it approximately 100–300 words.
5. Run `sync --client <client_id> --record <record> --operation checkpoint-written`. Do not change an existing open record back to provisional.
6. Print the compact checkpoint receipt with the client label and real path.

Checkpoints are immutable event files. Never append to another client’s file, create a second record for the same client session, write a close-out here, or edit `_INDEX.md` directly.
