# Using the Session Save System

> GUIDE.md is the rulebook the AI follows. **This file is for you** — when to use which command, with real scenarios.

## The 10-second version

```
While working ──────────► /session-save   (/ss)    "checkpoint me"
Finishing a chat ───────► /session-tag    (/st)    "name it, judge it, tell me what's next"
        └─ it says FINISHED ─► /session-summary (/ssum)  "close it out properly"
        └─ it says LIVE ─────► /session-save     (/ss)   "checkpoint, keep it in recents"
Chat list is a mess ────► /session-tag all (/st all)     "sweep everything"
Sunday / end of week ───► /session-audit  (/sa)          "what did I actually do this week?"
```

**If you only remember one command, make it `/session-tag`.** It figures out what state your session is in and tells you what to run next.

---

## `/session-tag` (`/st`) — the one you run at the end of every chat

**What it does:** reads your session, names it for what it *actually did* (not what the auto-title says), judges whether the work is FINISHED / LIVE (still going) / STALE (dead), saves a bullet-point summary + a list of what the session produced, renames the chat, and points you to the right next command.

**Use it when:**
- You're wrapping up a chat — even mid-task.
- A chat wandered ("started as CSS help, became a full redesign") and the title no longer matches.
- You're about to close your laptop and want the session findable next week.

**Real scenario:** You spent 2 hours on a landing page. `/st` renames the chat `Website Hero-Section`, logs that you built the hero + fixed the nav, judges it LIVE (mobile layout unfinished), and suggests `/ss` so it stays in your recents.

### `/session-tag all` (`/st all`) — the sweep
**Use it when** your chat list has 15+ conversations and you can't find anything. It reviews every session, writes a proposal file (suggested names, keep/archive verdicts), and **waits for your approval** before touching anything. Archives are always reversible.

---

## `/session-save` (`/ss`) — the checkpoint

**What it does:** appends a timestamped "Now / Working on / Next / Watch" block to the session's log. 30 seconds, no ceremony.

**Use it when:**
- Mid-way through a long session, so a crash/compaction loses nothing.
- Stepping away — future-you (or a future chat) can pick up exactly where you stopped.
- `/st` judged the session LIVE.

**Not for:** closing a finished session — that's `/session-summary`.

**Real scenario:** Deep in a debugging session, dinner's ready. `/ss` logs "Now: narrowed the bug to the auth middleware. Next: test the token refresh path." Tomorrow's chat reads that one block and continues.

---

## `/session-summary` (`/ssum`) — the close-out

**What it does:** writes two files — `human.md` (a readable summary: what you achieved, decided, learned, and what's next) and `agent.md` (technical state so a future AI session can resume cold) — then marks the session ✅ closed in your index.

**Use it when:**
- `/st` judged the session FINISHED.
- You're done with a piece of work and want it *properly* remembered before archiving the chat.

**Not for:** sessions with real work still in flight (checkpoint those instead).

**Real scenario:** The hero section shipped. `/ssum` writes the summary, closes the session, and next month when you wonder "how did I set up those animations?", the answer is one file away — no scrolling through a dead chat.

---

## `/session-audit` (`/sa`) — the weekly bird's-eye

**What it does:** reads *all* your session logs for the week, groups them by project, and writes one report: what you achieved, plans you created but never actioned, the valuable things you built, how projects depend on each other, and a prioritized "do next" list.

**Use it when:**
- End of the week — "what actually happened?"
- You feel scattered across projects and want one picture.
- Monday planning — the "do next" list is your starting point.

**Real scenario:** Sunday night, `/sa` shows: Website (shipped hero, mobile still open), Job Search (two applications, one interview to prep), Side Project (untouched for 9 days — decide or archive it). One glance, one plan.

---

## How they fit together

`/session-tag` is the **router** — it decides. `/session-save` and `/session-summary` are the two **destinations** — quick checkpoint vs. full close-out. `/session-audit` is the **reader** — it turns a week of logs into one picture. Everything lands in `~/Desktop/session-logs/`, plain markdown you own, one folder per session, one index to catch up from.

**The habit that makes it work:** end every real working chat with `/st`. That's it — the system handles the rest.
