# Contributing

Contributions must preserve the file model and safety invariants in `GUIDE.md`.

1. Open an issue with a minimal synthetic example; never upload real logs.
2. Keep changes dependency-free and POSIX-shell compatible unless a decision
   record approves a new requirement.
3. Run `./tests/run.sh` and `python3 scripts/validate_repo.py`.
4. Regenerate `MANIFEST.sha256` and rerun validation.
5. Describe which user-owned paths can change and how recovery works.

Changes to ownership, uninstall behavior, index identity, archive rules, or the
home-resolution order require a decision record under `docs/decisions/`.
