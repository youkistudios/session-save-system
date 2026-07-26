# Public site release plan

Status: release gates passed for `v2.0.0-alpha.4`

## Purpose

The page is a sixty-second operating manual for a local session-memory architecture. It must let a first-time visitor understand what memory is preserved, install from a verifiable Git command, choose Tag / Checkpoint / Close / Review, and see the evidence boundary without marketing inflation.

## Deliberate constraints

- Native HTML, CSS, and minimal JavaScript only.
- No analytics, cookies, external fonts, framework, video, or autoplay.
- One install command presentation; no duplicated conversion blocks.
- “Memory” means deliberately captured context, decisions, progress, artifact references, open questions, and resumption state—not automatic artifact copying or transcript harvesting.
- Lifecycle explanation lives in one manual terminal, not repeated feature cards.
- New lifecycle names are shown as additive wrappers; established canonical names remain visible.
- Project identity is explicit and deterministic; no semantic grouping claim.
- “No product upload” is paired with a warning about user-configured folder sync.
- Current evidence appears directly below installation, not at the end of the page.

## Information order

1. Outcome and exact installation.
2. Evidence line and sync boundary.
3. Manual four-moment terminal.
4. First-use sequencing.
5. User-owned file model.
6. Verified, pending, and excluded claims.
7. Four practical questions.

## Interaction contract

The terminal is manual rather than autoplaying. Native tab semantics, arrow/Home/End keys, visible focus, and no-JavaScript fallback are required. Copy feedback is announced through a polite live region. Reduced motion removes smooth scrolling; no instructional content depends on motion.

## Release gates

- repository suite and manifest pass;
- HTML/JS/local-link checks pass;
- 320, 375, 768, 1440, and 1920 px layouts have no horizontal document overflow;
- keyboard tabs and copy feedback work;
- no-JavaScript exposes all lifecycle panels;
- browser console remains clean;
- Hallmark and Taste report no unresolved high/blocker finding;
- public text reflects merged `main` only.
