# Contributing

Contributions must preserve the four-moment product and safety laws in `GUIDE.md`.

1. Open an issue with a synthetic example; never upload real logs.
2. Keep the kernel Python-standard-library-only and installer behavior POSIX-compatible unless an ADR approves a new platform requirement.
3. Treat Claude Code and Codex behavior as one semantic contract with separate client adapters.
4. Run `./tests/run.sh` and `python3 scripts/validate_repo.py`.
5. Regenerate `MANIFEST.sha256`, rerun validation, and report the test count.
6. Describe every user-owned path that can change and the recovery procedure.

Changes to identity, schema, client namespaces, locking, atomicity, migration, ownership, uninstall behavior, archive rules, or home resolution require a decision record under `docs/decisions/`.

A new client adapter must pass the existing conformance and concurrency suite without changing the four moments or forking the record schema.
