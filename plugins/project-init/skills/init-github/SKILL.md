---
name: init-github
description: Put on GitHub a workspace or repositories set up by init-workspace or init-repo — create the GitHub repository if missing, push, and for a repository set squash-only merges, a "Protect main" ruleset requiring a pull request and the CI checks, and push protection — from their .project-init.yml, with a script the user runs in a normal terminal. Use when the user asks to publish, push or protect a new repository or workspace on GitHub, or to apply its GitHub settings again.
---

# init-github

Creates the GitHub side of what init-workspace and init-repo set up, from
each folder's `.project-init.yml`. A Claude Code session's token cannot
change repository settings: the user runs the script, in a normal
terminal, with their own `gh` login. Your part is to give them the
command, check the dry run with them, and read their output.

## What it does

| For | Does |
|---|---|
| a workspace | creates the private repository if missing, pushes `main` |
| a repository | creates it (public or private, with its description) if missing, pushes `main` |
| | merges: squash only, title = pull request title, body = commit messages (`squash-body: blank` → empty, for release-please), branch deleted after merge |
| | ruleset "Protect main": no deletion, no force push, linear history, pull request required (no approval), squash only, the register's `required-checks` required |
| | public only: secret scanning and push protection; a reminder to give the CodeRabbit app access when `coderabbit` is on |

It is safe to run again: an existing repository is pushed to, the ruleset
is updated in place. A folder whose host is not `github` is skipped. On a
private repository, rulesets need GitHub Pro (or Team): without it the
script says so and goes on.

## Steps

1. Check that each folder has its first commit (`commit.sh` of
   init-workspace or init-repo) and a `.project-init.yml` with
   `host.kind: github`.
2. Run the dry run yourself:
   `sh <this skill's folder>/scripts/setup-github.sh --dry-run <dir>...`.
   It changes nothing and prints each command and request. Show the user
   what it would do.
3. Give the user the command to run **in a normal terminal**:
   `sh <this skill's folder>/scripts/setup-github.sh <dir>...`
   (workspace first, then its repositories).
4. Read their output. Report what was created and set, and what was not:
   a ruleset refused on a private repository, CodeRabbit to install.
