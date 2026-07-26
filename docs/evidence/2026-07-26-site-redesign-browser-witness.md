# Public site browser witness — 2026-07-26

Status: passed for the `v2.0.0-alpha.4` site candidate

This record covers presentation and interaction only. It does not upgrade product capability evidence.

## Candidate boundary

- Product category: local session-memory architecture.
- Public lifecycle: Tag · Checkpoint · Close · Review.
- Established canonical skill names remain visible and installed.
- Current test count: 26.
- macOS is witnessed; Linux remains pending.
- Project identity is explicit and deterministic.
- Artifact paths are captured as references; automatic artifact copying is not claimed.

## Browser witness

The candidate was served as static files and inspected through a connected browser portal.

Responsive document-width checks passed without horizontal overflow at:

- 320 × 700;
- 375 × 812;
- 768 × 900;
- 1440 × 1000;
- 1920 × 1080.

Desktop and mobile captures confirmed:

- the memory thesis, install path, current evidence line, and sync boundary appear in the opening experience;
- the headline remains within three rendered lines and installation enters the first mobile viewport;
- the mobile lifecycle control is a visible 2 × 2 grid rather than a clipped rail;
- the static header does not cover section content;
- the terminal contains no imitation operating-system chrome;
- the self-hosted IBM Plex Sans Condensed display face loaded successfully.

## Interaction and fallback witness

- Arrow-key movement from Checkpoint selected Close, moved focus to `tab-close`, and exposed only `panel-close`.
- Copy entered the `success` state and announced “Install command copied to clipboard.” through a polite live region.
- Copy implements explicit loading, success, and error states and disables during the asynchronous operation.
- All four lifecycle panels remain in source without `hidden`; JavaScript-scoped CSS performs enhancement, so no-JavaScript readers see every panel.
- Reduced-motion CSS disables smooth scrolling and no instruction depends on animation.
- Local assets and links resolve to regular files.
- Browser console capture contained no site errors.
- Contrast checks for muted body, terminal, light-panel, mint, and acid combinations exceeded 4.5:1.

## Independent design gates

Fresh reviews used the current source and four current browser captures.

- Hallmark: **PASS — safe to push**, with zero blocker, high, or major findings.
- Taste: **PASS**, with no unresolved material issue.

Earlier rejected versions and their findings were not reused as evidence for this verdict.
