---
name: init-github
description: Put on GitHub a workspace or repositories set up by init-workspace or init-repo — create the GitHub repository if missing, push, and for a repository set squash-only merges, a "Protect main" ruleset requiring a pull request and the CI checks, and push protection — from their .project-init.yml, with a script the user runs in a normal terminal; then give a pre-filled link to a fine-grained token limited to the workspace's repositories, or to the repository on its own, for Claude Code's sessions. Use when the user asks to publish, push or protect a new repository or workspace on GitHub, to apply its GitHub settings again, or for a GitHub token for Claude Code limited to a project's repositories.
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
| Claude Code's sessions | `token-url.sh`: a link to a new fine-grained token for a workspace's repositories, or a repository on its own |

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
5. The token for Claude Code's sessions, once the repositories exist: run
   `sh <this skill's folder>/scripts/token-url.sh <dir>` yourself — the
   workspace, or the repository on its own; a repository in a workspace
   gives the workspace's token, which must now reach it too. Give the
   user what it prints: a link to GitHub's token form, pre-filled with
   the name (`Claude Code - <name>`), owner, 90 days of validity and
   the permissions (contents, pull requests, issues and workflows to
   write, actions and commit statuses to read), and the repositories to
   tick — a link cannot select them. They paste the token into
   `.claude/settings.local.json`, under `"env"`, as `"GH_TOKEN"`:
   init-workspace and init-repo create
   that file, never committed; git and `gh` then authenticate with it.
   Tell them the session can read the token, so it can do on those
   repositories what these permissions allow, nothing more; an
   organization may have to approve it. Never ask for the token, never
   read or print that file's values.
