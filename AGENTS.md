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
  then move it under `plugins/`, add its entry to `marketplace.json`, add
  it to `release-please-config.json` (same shape as `plugins/tdd`) and to
  `.release-please-manifest.json` with the exact `version` its
  `plugin.json` holds, and add its name to the `scopes` of
  `.github/workflows/pr-title.yml`.
- The rules of a workflow live in skills whose frontmatter uses only the
  portable [Agent Skills](https://agentskills.io) fields (`name`,
  `description`). Tool-specific files — Claude Code subagents — stay thin:
  model, effort, tools, preloaded skills, and a one-paragraph prompt.
- A subagent must refuse to work when its preloaded skill is missing:
  Claude Code skips a missing skill silently.
- Write model IDs in full (`claude-opus-5-5`), never an alias.
- Pull request titles are
  [Conventional Commits](https://www.conventionalcommits.org/): the squash
  merge makes the title the commit. CI checks the type, and that a scope,
  if any, names a plugin. Scope every change to a plugin with its name
  (`feat(tdd): …`); repository-level changes take no scope (`ci: …`).
- Never edit a plugin's `version` or `CHANGELOG.md` by hand. release-please
  keeps a release pull request open that bumps them from the commits merged
  under `plugins/<name>/` since the last release: `fix` → patch, `feat` →
  minor, `!` (breaking) → minor while the version is below 1.0. Merging
  that pull request publishes the release; installed copies update only
  when `version` changes (see the README).
- Only `feat`, `fix` and breaking changes release a plugin. A plugin's
  skills, agents and hooks are its code: a change users must receive —
  even a rule's wording — is a `fix` or a `feat`, never `docs`, `refactor`
  or `chore`.
- Merge the release pull request right after the plugin change it lists.
  Fresh installs take the plugin from `main`, so merged but unreleased
  changes already ship under the previous version number.
- Everything in this repository is public and in English.
- No `CLAUDE.md`: this file is the only instruction file.
