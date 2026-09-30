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
  then move it under `plugins/`, add its entry to `marketplace.json`, and
  add it to `release-please-config.json` and `.release-please-manifest.json`
  (same shape as `plugins/tdd`).
- The rules of a workflow live in skills whose frontmatter uses only the
  portable [Agent Skills](https://agentskills.io) fields (`name`,
  `description`). Tool-specific files — Claude Code subagents — stay thin:
  model, effort, tools, preloaded skills, and a one-paragraph prompt.
- A subagent must refuse to work when its preloaded skill is missing:
  Claude Code skips a missing skill silently.
- Write model IDs in full (`claude-opus-5-5`), never an alias.
- Pull request titles are
  [Conventional Commits](https://www.conventionalcommits.org/), scoped by
  plugin (`feat(tdd): …`, `fix(tdd): …`, `docs: …`): the squash merge makes
  the title the commit, and CI checks it.
- Never edit a plugin's `version` or `CHANGELOG.md` by hand. release-please
  keeps a release pull request open that bumps them from the commits merged
  under `plugins/<name>/` since the last release: `fix` → patch, `feat` →
  minor, `!` (breaking) → minor while the version is below 1.0. Merging
  that pull request publishes the release; installed copies update only
  when `version` changes (see the README).
- Everything in this repository is public and in English.
- No `CLAUDE.md`: this file is the only instruction file.
