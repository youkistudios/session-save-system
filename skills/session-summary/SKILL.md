---
name: session-summary
description: Close an existing source-attributed Session Save record with a human summary and technical resume state. Use when the user asks to summarize, close out, or preserve a finished session. Not a mid-session checkpoint.
license: MIT
compatibility: Requires Python 3 and local filesystem write access. Installed adapters support Claude Code and Codex.
---

# Session summary — close-out

Resolve this skill directory as `SKILL_DIR`. Read `CLIENT.md` beside this file for the installed `client_id`. Read the shared home’s `GUIDE.md`.

1. Run `python3 "$SKILL_DIR/scripts/session_save.py" doctor --client <client_id>`. Stop unless `ok` is true and `migration_required` is zero.
2. Locate the existing record by real host session ID or known slug with `locate --client <client_id> ...`. If no record exists, stop and ask the user to run session-tag first. A close-out never invents a record.
3. Require `<record>/tag.md`. Promote its GIST content without recomputing it.
4. Write or refresh `<record>/human.md`: GIST, bottom line, assets, problems, solutions, achieved, actioned, insights, and next.
5. Write or refresh `<record>/agent.md`: technical state, decisions and reasons, proven versus unproven, source client, and open threads. Reconcile later checkpoints against the tag explicitly.
6. Run `sync --client <client_id> --record <record> --status closed --operation summary-written` to update the source envelope and rebuild the global index atomically.
7. Print the compact close-out receipt with the client label and both real paths.

Refresh the same two files on rerun. Never close another client’s record, merge records because names look similar, create a duplicate index row, or edit `_INDEX.md` directly.
