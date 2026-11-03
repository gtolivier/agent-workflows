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
  the change as a deviation, with its reason and status: `generalize`
  (worth bringing to project-init: open an issue in
  gtolivier/agent-workflows and record its number), `local` (kept here
  only), `temporary` (kept until a date, YYYY-MM-DD) or `abandon`
  (project-init no longer manages that file here). The upgrade skill of
  project-init records it (`deviation.sh`), keeps it through upgrades and
  asks again once its date or its issue says so.
- **No `CLAUDE.md`:** this file is the single source of agent instructions.
  A `CLAUDE.md` next to it would make Claude Code ignore it.
