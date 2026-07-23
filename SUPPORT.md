# Support

Use GitHub Discussions for workflow questions and Issues for reproducible defects. Use private vulnerability reporting for security-sensitive behavior.

Include:

- client and surface (`claude` / Claude Code or `codex` / desktop, CLI, IDE);
- client version, operating system, Python version, and shell;
- the command used;
- whether `SESSION_SAVE_HOME`, `SESSION_SAVE_CONFIG`, `CLAUDE_CONFIG_DIR`, or `AGENTS_CONFIG_DIR` was overridden;
- the output of `session_save.py doctor --client <id>`;
- a synthetic directory tree.

Never post real session logs, config contents containing sensitive paths, or secrets. Live client capabilities vary by version, so distinguish persistence-kernel defects from unavailable rename/archive/history controls.

This is a community-maintained alpha; response times and client compatibility are not guaranteed.
