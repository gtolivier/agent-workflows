---
name: upgrade
description: Bring a repository set up by init-repo, or a workspace set up by init-workspace, to the current version of project-init — merge what changed in its common layer since the version in its .project-init.yml into its own files, migrate the register, and settle each difference with the user as a deviation (generalize, local, temporary, abandon) — and record a deviation at the end of a pull request that changes a file of the common layer. Use when the user asks to upgrade or update a repository or workspace set up by project-init, to bring it to the latest project-init, or to record or settle a deviation from its common layer.
---

# upgrade

Brings a repository or a workspace to this version of project-init. The
scripts do the work: they render the common layer as the version in the
register wrote it and as this version writes it, and merge the difference
into each file with `git merge-file`, so the repository's own changes stay.
Your part is to settle with the user each file the report asks about, and
report.

A repository is upgraded on its own, a workspace on its own: a
repository's upgrade reads only its own register and files, never the
workspace's, and a workspace's upgrade never touches its repositories.
Upgrade each one the user names, one after the other.

## What it upgrades

The files project-init renders from its templates: `AGENTS.md`, the CI,
`.coderabbit.yaml`, the stack's own templates (`e2e/`, `eslint.config.mjs`,
`compose.yaml`…), a workspace's `AGENTS.md`, `DECISIONS.md` and
`.gitignore`. The files a generator wrote (`package.json`, `pyproject.toml`,
`go.mod`, `hugo.toml`…) stay the repository's: no upgrade rewrites them.
Before rendering, the migrations of each version in between update the
register (`migrations/`).

## Deviations

A file of the common layer that differs from project-init's, on purpose,
is a deviation, recorded in `.project-init.yml` with a reason in English,
the user's, on one line:

| Status | Means | The upgrade |
|---|---|---|
| `local` | this repository needs it, for good | merges, keeps it |
| `temporary` | until a date (`--until YYYY-MM-DD`) | merges, keeps it; after the date, asks again |
| `generalize` | better for every repository: an issue of gtolivier/agent-workflows proposes it (`--issue <n>`) | merges, keeps it; once the issue is completed, takes this version's file; closed as not planned, asks again |
| `abandon` | no longer project-init's: dropped from `managed` | never touches it again |

## Steps

1. Check that the folder has a `.project-init.yml`, a commit and no
   uncommitted change. Angular, hugo and hugo-theme: its `node_modules`
   is installed (`npm ci`) — the render formats files with the
   repository's Prettier, python and django with its ruff (`uv`).
2. Run `scripts/upgrade.sh <dir>` (relative to this skill's folder). A
   repository moves to a new branch, `project-init/upgrade-<version>`; a
   workspace stays on its branch. The version in the register comes from
   Claude Code's plugin cache, else is downloaded from its release on
   GitHub. It commits nothing, and prints a report:

   | Outcome | Means | To settle |
   |---|---|---|
   | `updated`, `created`, `deleted`, `kept`, `adopted`, `dropped` | done: this version's file, the merge, or a deviation kept | — |
   | `ask` | merged, but it differs from this version with no deviation recorded (or its record lapsed) | `record`, or `resolve <path> theirs` |
   | `conflict` | both changed the same lines: conflict markers written | edit the markers out as the user chooses, then `record`, or `resolve <path> theirs` |
   | `missing` | deleted here, changed by this version | `resolve <path> theirs` restores it, or `record <path> abandon` |
   | `nobase` | no earlier version to merge from: left as is | `record`, or `resolve <path> theirs` |
   | `exists` | a file this version adds is already here, different | `resolve <path> ours` keeps it as the repository's, `theirs` takes this version's |
   | `removed` | this version no longer writes it, and it was changed here | `resolve <path> theirs` deletes it, `ours` keeps it as the repository's |
   | `expired` | a temporary deviation past its date | `record` again, or `resolve <path> theirs` |

3. For each file to settle, show the user the difference (`git diff`,
   and this version's file in `.git/project-init-upgrade/theirs/`) and
   ask what to do — never choose for them. Then run
   `scripts/deviation.sh <dir> resolve <path> theirs|ours` or
   `scripts/deviation.sh <dir> record <path> <status> "<reason>"
   [--until <date>] [--issue <n>]`. For `generalize`, open the issue
   first, with the user's go-ahead: `gh issue create -R
   gtolivier/agent-workflows`, its title and body in English.
   `deviation.sh <dir> status` lists what is left.
4. Run `scripts/finish.sh <dir>`. It refuses while a file is unsettled,
   holds conflict markers, or a deviation is malformed; in a repository,
   it runs the stack's checks as `commit.sh` does (django: the database
   up; angular: port 4200 free; hugo: port 1314 free). `--no-check` skips
   them when they cannot run here: the CI runs them anyway. Then it sets
   the new version in the register and commits.
5. Do what it prints next: push the branch and open a pull request, in
   the repository's language for pull requests; a workspace, push. When
   the CI checks to require changed, the user runs init-github's
   `setup-github.sh <dir>` again, in a normal terminal, once the pull
   request is merged.
6. Report the versions, each file's outcome, the deviations recorded, the
   commit and the next step.

To give up an upgrade in progress: `git reset --hard`, `git switch` back
to the earlier branch, delete `project-init/upgrade-<version>` and
`.git/project-init-upgrade`.

## A deviation at the end of a pull request

`AGENTS.md` asks, at the end of a pull request that changes a file of the
common layer (`managed` in `.project-init.yml`), whether to record the
change. When the user says yes, run `scripts/deviation.sh <dir> record
…` on the pull request's branch and commit the register with the change.
`deviation.sh <dir> forget <path>` drops a record; `deviation.sh <dir>
check` checks them all and lists the temporary ones past their date.
