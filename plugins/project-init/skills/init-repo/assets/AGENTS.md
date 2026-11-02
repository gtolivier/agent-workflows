# AGENTS.md

Instructions for coding agents working in this repository. Read
[README.md](README.md) first for what this project is.

@STACK_SECTIONS@

## Rules

@STACK_RULES@
- **Language:** @LANGUAGE_RULE@
- **Common layer:** [project-init](https://github.com/gtolivier/agent-workflows)
  set this repository up. `.project-init.yml` records its version, the
  choices made and the files it manages (`managed`). At the end of a pull
  request that changes one of those files, ask the user whether to record
  the change under `deviations`, with its path, reason and status:
  `generalize` (worth bringing to project-init: also open an issue there),
  `local` (kept here only), `temporary` (removed later: say when in
  `until`) or `abandon` (project-init no longer manages that file here).
- **No `CLAUDE.md`:** this file is the single source of agent instructions.
  A `CLAUDE.md` next to it would make Claude Code ignore it.
