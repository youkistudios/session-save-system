# Changelog

All notable changes to Session Save System are documented here.

## 2.0.0-alpha.4 — 2026-07-26

- Add the clearer `session-checkpoint`, `session-close`, and `session-review` lifecycle skills and Claude slash commands.
- Retain the canonical `session-save`, `session-summary`, and `session-audit` implementations plus all short aliases unchanged.
- Keep each new name as a thin adapter to the existing canonical behavior rather than forking the kernel or schema.
- Install alias skill components atomically; preserve unrelated command collisions without withholding the complete skill.
- Present Tag · Checkpoint · Close · Review consistently in installation and usage guidance.
- Define Session Save explicitly as a local session-memory architecture with an artifact-reference boundary.
- Replace the public site with a dependency-light operating manual, manual lifecycle console, early evidence boundary, and accessible copy feedback.

## 2.0.0-alpha.3 — 2026-07-26

- Add exact user-approved project list/check/register kernel primitives.
- Add strict project enforcement for normal Tag and first-Checkpoint creation.
- Make project registration receipted and folder-free until the first approved record.
- Report unregistered historical project labels in Audit without mutation or semantic merging.
- Reject approved names that collide on one project folder slug.
- Explicitly exclude semantic project clustering, automatic stage inference, and master-plan mutation.
- Expand the isolated suite to 25 tests.

## 2.0.0-alpha.2 — 2026-07-26

- Converge eight installed persistence-kernel copies into one manifest-owned canonical kernel under `~/.local/share/session-save/`.
- Preserve existing skill behavior through tiny path-local compatibility launchers, avoiding GUI-client `PATH` assumptions.
- Back up managed shared-kernel replacements, reject unowned conflicts, and remove the shared package only when no managed launcher remains.
- Add continuity-first planning and ADR evidence while keeping schema, commands, aliases, records, and four-moment behavior unchanged.
- Expand the isolated suite to 23 tests covering shared-kernel ownership, launcher execution, partial uninstall, and modified-kernel preservation.

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
