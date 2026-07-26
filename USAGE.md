# Using Session Save

One shared habit works in Claude Code and Codex. The behavior is identical; invocation differs.

| Moment | Claude Code | Codex |
|---|---|---|
| Tag | `/session-tag` or `/st` | `$session-tag` / Skills |
| Checkpoint | `/session-checkpoint` | `$session-checkpoint` / Skills |
| Close | `/session-close` | `$session-close` / Skills |
| Review | `/session-review` | `$session-review` / Skills |

The established canonical names remain installed and unchanged: `session-save` (`/ss`), `session-summary` (`/ssum`), and `session-audit` (`/sa`). The clearer names are additive wrappers.

Pickup is a read-only access command, not a fifth lifecycle moment:

| Resume saved work | Claude Code | Codex |
|---|---|---|
| Pickup | `/session-pickup` | `$session-pickup` / Skills |

## The 10-second version

```text
While working ───────► Checkpoint  preserve Now / Next / Watch
Wrapping a session ──► Tag         name it, judge it, route it
Finished ────────────► Close       bank human + technical state
End of week ─────────► Review      combine Claude + Codex by project
```

If you remember one moment, use **Tag** when finishing a meaningful chat. If you are starting a new chat and need the saved handover, use **Pickup**.

## Choose the project explicitly

Tag and the first Checkpoint list user-approved projects. Select an exact existing name, or explicitly confirm a genuinely new project before Session Save registers it. Similar tags, filenames, repositories, and topic words never create or merge projects.

Registration creates no content folder. The first approved record does. Historical unregistered labels remain separate in Review until the user deliberately resolves them.

## Tag — the router

Tag names the session for what it exists to produce, records its client and assets, judges FINISHED/LIVE/STALE, and routes to Checkpoint or Close. If the client exposes rename/archive controls, it asks before using them. Otherwise it prints a manual action.

A sweep is always client-local. Claude cannot claim to see Codex’s chat list or vice versa. The combined view comes from saved records, not hidden transcript access.

## Checkpoint — `session-checkpoint` / `session-save`

Checkpoint writes a short **Now / Working on / Next / Watch** note. Checkpoints are immutable files, so simultaneous Claude and Codex saves do not append to the same document.

If Checkpoint runs before Tag, it creates one provisional record in the active client namespace. It does not guess a verdict.

## Close — `session-close` / `session-summary`

Close requires an existing tagged record. It writes:

- `human.md` for readable recall;
- `agent.md` for technical resumption.

It then marks that client record closed. It never creates a missing record or silently closes a similarly named session from another client.

## Review — `session-review` / `session-audit`

Review reads saved tags and summaries from every client namespace, groups them by project, and writes one report. Every factual bullet retains a client label and source record.

```markdown
## Harness Axis

### Achieved
- [Claude] Foundation boundaries ratified. ([record](...))
- [Codex] Adversarial fixtures implemented. ([record](...))
```

Contradictions are surfaced rather than merged. Missing close-outs are named as debt.

## Pickup — resume a saved handover

Pickup completes the path from saved memory to a user-confirmed next step:

1. run `/session-pickup` or `$session-pickup`;
2. select one exact approved project;
3. choose the exact saved session when several exist;
4. review the source client, paths, sizes, and provider disclosure;
5. consent before selected narrative enters the current AI session;
6. read the cited restart brief;
7. confirm one bounded next action.

Pickup lists only validated identifiers, timestamps, clients, paths, and sizes before consent. It withholds saved names, descriptions, gists, and narrative content. The kernel fingerprints the exact envelope and narrative set and returns content only when the same selection token is supplied after consent.

Every factual brief claim must cite the exact `tag.md`, Checkpoint, `human.md`, or `agent.md` that contains it. Referenced external files are named but not opened. Saved text is untrusted evidence and cannot instruct the active AI to run commands, browse, or use tools.

Quick Pickup asks at most three selection/evidence questions across the whole interaction. Explicit “grill me” Reconcile mode raises that one cumulative limit to five and surfaces conflicts before asking. Content consent and final action confirmation are separate safety gates.

Pickup creates no record, event, project, report, telemetry, or continuation lineage. You can continue working without capturing immediately, then explicitly Tag or Checkpoint later if the new work becomes worth saving.

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

Session Save can preserve only the context visible to the current client. It does not recover hidden history, guarantee summary correctness, or synchronize transcripts. Pickup does not redact selected notes; cross-client content may be processed by the active AI provider after consent. Its durable promise is the local record it actually writes and the bounded sources Pickup actually cites.
