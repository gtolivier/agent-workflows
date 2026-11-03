---
name: init-workspace
description: Turn a folder into a workspace — a private git repository of its own that holds the repositories of one project and versions only their shared files (AGENTS.md with the list of repositories, DECISIONS.md, ROADMAP.md, the register .project-init.yml) — on a new folder or one that already holds repositories. Use when the user asks to set up or create a workspace, a parent folder for several repositories, or the shared AGENTS.md above them.
---

# init-workspace

A workspace is the folder above a project's repositories. It is a private
git repository whose `.gitignore` is an allowlist: it versions its own
files, and each repository below keeps its own history. The scripts do the
work; your part is to ask the choices, write the prose they leave as
`TODO(project-init)`, and report.

## What it sets up

| File | Content |
|---|---|
| `.gitignore` | an allowlist: only the files below, `*.code-workspace`, `.claude/settings.json` and `.claude/hooks/`, plus each `--track` path |
| `AGENTS.md` | the purpose (yours to write), the list of repositories (generated), how this folder works, roadmap, decisions, language, workflow |
| `DECISIONS.md` | decisions that span several repositories, newest first |
| `ROADMAP.md` | with `--roadmap workspace` only: one roadmap for every repository |
| `.claude/settings.local.json` | never committed: denies the commands that read or change credentials; on GitHub, makes git authenticate with `gh` |
| `.project-init.yml` | the register: project-init's version, the choices, the files it manages, the deviations |

An existing file is kept, never overwritten. A folder that already has a
`.project-init.yml` is set up already: the script refuses.

## Steps

1. Ask the user, in one message:
   - **Where it lives:** `github`, `other` (another host: ask the remote
     URL) or `none` (this machine only). On GitHub, the owner (default:
     their `gh` login) and the repository (default: `<owner>/<folder>`).
   - **Roadmap:** one `ROADMAP.md` in the workspace, or one per repository
     (default).
   - **Languages:** of pull requests and their comments, and of the
     roadmap (default English). Code, comments, documentation, commits
     and issues are always in English.
   - **What else to version here,** in an existing folder: list what is
     neither a repository nor a file above (`ls -A`), and ask which ones
     to track, such as `_Documents/`: files or folders at the top of the
     workspace only.
2. Run `scripts/init-workspace.sh <dir> --host <github|other|none>`
   (relative to this skill's folder), with `--owner`, `--repo`,
   `--remote`, `--roadmap`, `--pr-lang`, `--roadmap-lang` (codes such as
   `fr`) and one `--track <path>` per extra path. It prints the
   placeholders left.
3. Replace each `TODO(project-init)` with the prose it asks for, in
   English: read the repositories' README and AGENTS.md to write it. Ask
   the user what you cannot find.
4. Run `scripts/commit.sh <dir>`. It refreshes the list of repositories,
   then commits on `main`. It refuses while a placeholder remains, or when
   the commit would take in a repository or
   `.claude/settings.local.json`, or the `.gitignore` is not an
   allowlist; fix the cause, never the check.
5. On GitHub: the init-github skill creates the private repository and
   pushes. For git and `gh` to work from Claude Code sessions started at
   the workspace's root, the user adds their own token to
   `.claude/settings.local.json`, under `"env"`, as `"GH_TOKEN"`. Tell
   them; never ask for the token, never read or print that file's values.
6. Report what was created or kept, the commit, and the next step:
   init-repo for each new repository, init-github if it lives on GitHub.

Later commits of the workspace's files go through `scripts/commit.sh <dir>
--message "<conventional commit message>"`: it keeps the list of
repositories up to date.

`scripts/render.sh <dir> <out-dir>` writes the workspace's common layer —
`AGENTS.md`, `DECISIONS.md`, `.gitignore` — as this version writes them,
keeping its description and list of repositories: the upgrade skill
merges from it.
