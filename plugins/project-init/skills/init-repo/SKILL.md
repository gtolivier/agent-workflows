---
name: init-repo
description: Create a new repository for a stack (python) with its official generator and tools, and the common layer — .gitignore, LICENSE, README.md, AGENTS.md with test-first rules, GitHub Actions CI and CodeRabbit when on GitHub, and the register .project-init.yml — inside a workspace or on its own, on GitHub, another host or this machine only. Use when the user asks to create, start, scaffold or set up a new repository or project.
---

# init-repo

Creates a repository: the stack's official generator writes the project,
then the script adds the common layer and the register. The scripts do the
work; your part is to ask the choices, write the prose they leave as
`TODO(project-init)`, and report.

## Stacks

| Stack | Generator and tools | Checks (CI and `commit.sh`) |
|---|---|---|
| `python` | `uv init --lib`; pytest, ruff, mypy (strict) | `lint`, `typecheck`, `test (python <version>)` from the oldest supported version to the newest |

Each stack lives in `stacks/<stack>/`: `stack.sh` and its templates.

## What it sets up

| File | Content |
|---|---|
| `.gitignore` | the generator's, else GitHub's template for the stack |
| `LICENSE` | the chosen license's text from GitHub, with the year and `git config user.name` |
| `README.md` | the name and description, and a paragraph for you to write |
| `ROADMAP.md` | unless the workspace keeps the roadmap |
| `AGENTS.md` | the stack's commands and layout, test-driven development, and the rules: dependencies, generated files, clean code, supported versions, test-first, language, common layer |
| `.github/workflows/ci.yml` | on GitHub: the stack's checks |
| `.coderabbit.yaml` | on GitHub, public repositories, unless `--no-coderabbit` |
| `.project-init.yml` | the register: project-init's version, the choices, the CI checks to require, the files it manages, the deviations |

## Steps

1. Ask the user, in one message — never choose for them:
   - **Name** (the folder: letters, digits, `.`, `_`, `-`) and a
     **one-line description** (no `"` or `\`).
   - **License:** an SPDX id (`MIT`, `Apache-2.0`, `AGPL-3.0-or-later`…)
     or `none`. Ask for every repository: there is no default. For the GPL
     family, ask whether it is `-only` or `-or-later`.
   - **Where it lives:** `github`, `other` (another host: ask the remote
     URL) or `none` (this machine only); then **public or private**.
   - **Oldest supported runtime version** (python: default 3.12).
   - **Languages,** for a private repository: of pull requests and their
     comments, and of the roadmap (default English; in a workspace, the
     workspace's). A public repository keeps English. Code, comments,
     documentation, commits and issues are always in English.
   In a workspace (the folder above has a workspace `.project-init.yml`),
   the owner, the languages and the roadmap's place come from it.
2. Run `scripts/init-repo.sh <stack> <dir> --description "<text>"
   --license <id|none> --host <github|other|none>` (relative to this
   skill's folder), with `--visibility`, `--owner`, `--remote`,
   `--runtime`, `--pr-lang`, `--roadmap-lang` or `--no-coderabbit` as
   chosen. The folder must be new or empty. It prints the placeholders
   left.
3. Replace each `TODO(project-init)` with the prose it asks for, in
   English, from what the user said about the project. Ask what you
   cannot infer. Add no code: the first behavior comes test-first, in its
   own pull request.
4. Run `scripts/commit.sh <dir>`. It refuses while a placeholder remains
   or a stack check fails, then makes the first commit on `main`. In a
   workspace, it also adds the repository to the workspace's list and
   commits that there.
5. On GitHub: the init-github skill creates the repository, pushes and
   sets its protections. A repository that will use release-please needs
   a blank squash body: before that, set `squash-body: blank` under
   `host` in `.project-init.yml`.
6. Report the stack, the choices, the commit, and the next step.

## Not covered yet

CI for hosts other than GitHub: on `other` or `none`, the checks run only
through `commit.sh` and locally.
