# Using Session Save

One shared habit works in Claude Code and Codex. The behavior is identical; invocation differs.

| Moment | Claude Code | Codex |
|---|---|---|
| Tag | `/session-tag` or `/st` | mention `$session-tag` or choose it through `/skills` |
| Save | `/session-save` or `/ss` | `$session-save` / Skills |
| Summarize | `/session-summary` or `/ssum` | `$session-summary` / Skills |
| Audit | `/session-audit` or `/sa` | `$session-audit` / Skills |

## The 10-second version

```text
While working ───────► Save       preserve Now / Next / Watch
Wrapping a session ──► Tag        name it, judge it, route it
Finished ────────────► Summarize  bank human + technical state
End of week ─────────► Audit      combine Claude + Codex by project
```

If you remember one moment, use **Tag** when finishing a meaningful chat.

## Choose the project explicitly

Tag and the first Checkpoint list user-approved projects. Select an exact existing name, or explicitly confirm a genuinely new project before Session Save registers it. Similar tags, filenames, repositories, and topic words never create or merge projects.

Registration creates no content folder. The first approved record does. Historical unregistered labels remain separate in Audit until the user deliberately resolves them.

## Tag — the router

Tag names the session for what it exists to produce, records its client and assets, judges FINISHED/LIVE/STALE, and routes to Save or Summarize. If the client exposes rename/archive controls, it asks before using them. Otherwise it prints a manual action.

A sweep is always client-local. Claude cannot claim to see Codex’s chat list or vice versa. The combined view comes from saved records, not hidden transcript access.

## Save — the checkpoint

Save writes a short **Now / Working on / Next / Watch** checkpoint. Checkpoints are immutable files, so simultaneous Claude and Codex saves do not append to the same document.

If Save runs before Tag, it creates one provisional record in the active client namespace. It does not guess a verdict.

## Summarize — the close-out

Summarize requires an existing tagged record. It writes:

- `human.md` for readable recall;
- `agent.md` for technical resumption.

It then marks that client record closed. It never creates a missing record or silently closes a similarly named session from another client.

## Audit — the shared project view

Audit reads saved tags and summaries from every client namespace, groups them by project, and writes one report. Every factual bullet retains a client label and source record.

```markdown
## Harness Axis

### Achieved
- [Claude] Foundation boundaries ratified. ([record](...))
- [Codex] Adversarial fixtures implemented. ([record](...))
```

Contradictions are surfaced rather than merged. Missing close-outs are named as debt.

## Where records live

The shared home comes from `~/.config/session-save/config.json` unless an explicit test or environment override is used. Default:

```text
~/Desktop/session-logs/
```

Within each project:

```text
sessions/<project>/claude/...
sessions/<project>/codex/...
```

`_INDEX.md` is generated across both. You can open every record without Session Save.

## Existing v1 users

Run the migration dry run before invoking the v2 skills. The installer prints the exact command. Apply copies records into the Claude namespace and preserves all originals.

## Honest boundary

Session Save can preserve only the context visible to the current client. It does not recover hidden history, guarantee summary correctness, or synchronize transcripts. Its durable promise is the local record it actually writes.
