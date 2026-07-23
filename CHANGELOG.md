# Changelog

All notable changes to Session Save System are documented here.

## 2.0.0-alpha.1 — 2026-07-23

- Add portable Agent Skill adapters for Claude Code and Codex.
- Move source records into project/client namespaces under one shared home.
- Add a Python-standard-library persistence kernel for deterministic identity,
  immutable events and checkpoints, serialized atomic writes, rebuildable
  global indexes, and source-attributed audit input.
- Add explicit dry-run, copy-first v1 migration with preserved sources and
  receipts.
- Expand installer and uninstaller ownership to two separately manifested
  client roots while keeping config and records outside uninstall scope.
- Add 20 isolated tests, including 24 simultaneous cross-client writes,
  client-owned mutation checks, safe migration, and symlink containment.
- Reframe the public product, site, thesis, architecture, safety model, and
  usage guide around one memory home for Claude Code and Codex.
- Keep live end-to-end client invocation as an explicit alpha evidence gap.

## 1.1.0 — 2026-07-23

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
