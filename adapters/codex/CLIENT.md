# Installed client adapter

- `client_id`: `codex`
- Surface: Codex desktop, CLI, or IDE local session
- Canonical invocation: select or mention `session-tag`, `session-save`, `session-summary`, `session-audit`, or `session-pickup` (`$skill-name` and `/skills` are supported in Codex CLI/IDE)
- Short aliases are not part of the portable contract.

Pass `--client codex` to client-owned capture and mutation commands. `pickup-sources` is a client-neutral read command and deliberately omits `--client`; use this adapter identity only for Pickup disclosure. Record a model name only when the host exposes it reliably. Renaming, archiving, listing chat history, and stable session IDs are optional capabilities; never claim or simulate them when unavailable.
