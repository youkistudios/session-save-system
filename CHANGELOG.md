# Changelog

All notable changes to Session Save System are documented here.

## Unreleased

- Replace heuristic text-search ownership with an exact SHA-256 install
  manifest and allowlisted uninstall behavior.
- Back up every previously managed file before replacement and preserve locally
  modified files during uninstall.
- Define `/ss` first-run behavior as one provisional index row that `/st`
  upgrades in place.
- Add isolated safety tests, deterministic repository validation, governance,
  provenance, architecture, and a dependency-free public site.

## 1.0.0

- Initial four-command release: tag, save, summarize, and audit.
