# Installed client adapter

- `client_id`: `claude`
- Surface: Claude Code local session
- Canonical invocation: `/session-tag`, `/session-save`, `/session-summary`, `/session-audit`, `/session-pickup`
- Optional local aliases: `/st`, `/ss`, `/ssum`, `/sa`

Pass `--client claude` to client-owned capture and mutation commands. `pickup-sources` is a client-neutral read command and deliberately omits `--client`; use this adapter identity only for Pickup disclosure. Record a model name only when the host exposes it reliably. Renaming, archiving, listing chat history, and stable session IDs are optional capabilities; never claim or simulate them when unavailable.
