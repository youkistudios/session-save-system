# Provenance

Session Save System was developed by Youki Studios as a local Markdown workflow for naming, checkpointing, closing, and auditing AI-assisted sessions. Its four-moment behavior, rulebook, persistence design, installer, safety tests, artwork, and public documentation are original to this repository.

Version 2 refactors the original Claude-oriented instruction suite around the open Agent Skills format and adds original Claude Code and Codex adapters plus a dependency-free Python persistence kernel. The kernel design—client namespaces, immutable operation events, atomic derived views, source-attributed audit input, and copy-first migration—was newly authored for this project with disclosed AI assistance under human direction.

No third-party source code or runtime package is bundled. Python’s standard library and operating-system file locking are used at runtime.

## External specifications consulted

- Agent Skills open specification: <https://agentskills.io/specification>
- Claude Code skills documentation: <https://code.claude.com/docs/en/skills>
- OpenAI Codex skills documentation: <https://developers.openai.com/codex/skills/>

These sources informed compatible packaging locations and invocation boundaries. They are not copied implementation code and do not imply endorsement.

See [`provenance/COMPONENTS.json`](provenance/COMPONENTS.json) for component classifications. The MIT license remains unchanged.
