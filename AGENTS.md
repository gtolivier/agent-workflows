# agent-workflows

A plugin marketplace: `.claude-plugin/marketplace.json` lists the plugins
under `plugins/<name>/`.

## Commands

```sh
claude plugin validate .                  # marketplace + every listed plugin
claude plugin validate plugins/<name>     # one plugin
claude --plugin-dir plugins/<name>        # try a plugin without installing it
```

## Rules

- Scaffold a new plugin with `claude plugin init <name> --with <components>`,
  then move it under `plugins/` and add its entry to `marketplace.json`.
- The rules of a workflow live in skills whose frontmatter uses only the
  portable [Agent Skills](https://agentskills.io) fields (`name`,
  `description`). Tool-specific files — Claude Code subagents — stay thin:
  model, effort, tools, preloaded skills, and a one-paragraph prompt.
- A subagent must refuse to work when its preloaded skill is missing:
  Claude Code skips a missing skill silently.
- Write model IDs in full (`claude-opus-5-5`), never an alias.
- Everything in this repository is public and in English.
- No `CLAUDE.md`: this file is the only instruction file.
