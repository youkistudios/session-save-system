# ADR 0001: Use exact manifest ownership for installed files

- Status: Accepted
- Date: 2026-07-23

## Context

Searching file text for product words is not proof of ownership. An unrelated
file can contain the same phrase, and a locally modified managed file may no
longer contain it.

## Decision

Record the SHA-256 and allowlisted relative path of every installed skill,
command, and home-pointer file. Skip unmanifested collisions, back up all
managed replacements, and uninstall only when the current file hash equals the
manifest.

## Consequences

Locally modified files survive uninstall and may require manual review. Legacy
installations without a manifest are not automatically removed. This favors
preservation over convenience.
