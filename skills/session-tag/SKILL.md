---
name: session-tag
description: Name and classify the current AI work session, save its source-attributed handoff, and route it to checkpoint or close-out. Use when the user asks to tag, name, triage, or finish organizing the current session. This is the triage gate, not the close-out.
license: MIT
compatibility: Requires Python 3 and local filesystem write access. Installed adapters support Claude Code and Codex.
---

# Session tag — triage gate

Resolve this skill directory as `SKILL_DIR`. Read `CLIENT.md` beside this file for the installed `client_id`. Read `GUIDE.md` in the shared Session Save home for the complete behavioral contract.

1. Run `python3 "$SKILL_DIR/scripts/session_save.py" doctor --client <client_id>` and use the returned home. Stop unless `ok` is true and `migration_required` is zero.
2. Run `project-list`. Select one exact approved project only when the user’s intent is clear. Similar tags, filenames, repositories, and topic words are not identity proof. On ambiguity, ask from approved choices. For a genuinely new project, wait for explicit confirmation, then run `project-register --project <project> --description <description>`. Name the session `<Project> Topic`, purpose before work-done.
3. Determine FINISHED, LIVE, or STALE using the guide. Default to one arc; split only when the work target changed and new assets or a day boundary exists.
4. Run `begin --client <client_id> --project <project> --name <name> --slug <slug> --status open --require-registered-project [--session-id <id>] [--model <model>]`. A stable host session ID is optional; never invent one. Reuse the returned record path.
5. Write or refresh `<record>/tag.md` using the guide template. Preserve `record.json`. Updates are in place; never create another folder manually.
6. Run `sync --client <client_id> --record <record> --status open --gist <concise-gist> --operation tag-written` to atomically refresh metadata and the global index.
7. Route FINISHED → session-summary; LIVE → session-save; STALE → archive guidance. Rename/archive only if the current client exposes that capability and the user confirms.
8. Print the compact tag receipt with the client label and real record path.

For a sweep, produce `_SWEEP-REVIEW.md` first and wait for approval. Only sweep chat history the active client actually exposes. Never delete and never imply a cross-client chat sweep.
