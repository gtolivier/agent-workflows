---
name: init-repo
description: Create a new repository for a stack (python, django) with its official generator and tools, and the common layer — .gitignore, LICENSE, README.md, AGENTS.md with the stack's rules and, when chosen, test-first development, GitHub Actions CI and CodeRabbit when on GitHub, and the register .project-init.yml — inside a workspace or on its own, on GitHub, another host or this machine only. Use when the user asks to create, start, scaffold or set up a new repository or project.
---

# init-repo

Creates a repository: the stack's official generator writes the project,
then the script adds the common layer and the register. The scripts do the
work; your part is to ask the choices, write the prose they leave as
`TODO(project-init)`, and report.

## Stacks

| Stack | Generator and tools | Checks (CI and `commit.sh`) |
|---|---|---|
| `python` | a library: `uv init --lib`; pytest, ruff, mypy (strict) | `lint`, `typecheck`, `test (python <version>)` for the oldest supported version and the newest |
| `django` | a site: `uv init --bare`, `django-admin startproject config .`; PostgreSQL (`compose.yaml`), django-environ, pytest-django, ruff, mypy (strict) with django-stubs | the same, the tests running `manage.py check` and `makemigrations --check` too |

Each stack lives in `stacks/<stack>/`: `stack.sh` and its templates. A
folder starting with `_` holds code the stacks share, not a stack.

## What it sets up

| File | Content |
|---|---|
| `.gitignore` | the generator's, else GitHub's template for the stack |
| `LICENSE` | the chosen license's text from GitHub, with the year and `git config user.name` |
| `README.md` | the name and description, and a paragraph for you to write |
| `ROADMAP.md` | unless the workspace keeps the roadmap |
| `AGENTS.md` | the stack's commands and layout, the `/tdd:feature` conventions, and the rules: test-first (with `--tdd on`), dependencies, generated files, clean code, supported versions, language, common layer |
| `.github/workflows/ci.yml` | on GitHub: the stack's checks |
| `.coderabbit.yaml` | on GitHub, public repositories, unless `--no-coderabbit` |
| `compose.yaml`, `.env.example`, `.env` | django: the local PostgreSQL, and the settings that differ between environments — `.env`, ignored by git, gets a secret key of its own |
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
   - **Test-driven development now or later:** `on` makes every behavior
     go test-first through `/tdd:feature` (AGENTS.md requires it); `off`
     leaves it available on request, to turn on later with `tdd.sh`.
     Ask: there is no default.
   - **Oldest supported runtime version** (python: default 3.12; django:
     default and minimum 3.12, which Django 6 requires).
   - **Languages,** for a private repository: of pull requests and their
     comments, and of the roadmap (default English; in a workspace, the
     workspace's). A public repository keeps English. Code, comments,
     documentation, commits and issues are always in English.
   In a workspace (the folder above has a workspace `.project-init.yml`),
   the owner, the languages and the roadmap's place come from it.
2. Run `scripts/init-repo.sh <stack> <dir> --description "<text>"
   --license <id|none> --host <github|other|none> --tdd <on|off>` (relative to this
   skill's folder), with `--visibility`, `--owner`, `--remote`,
   `--runtime`, `--pr-lang`, `--roadmap-lang` or `--no-coderabbit` as
   chosen. The folder must be new or empty. It prints the placeholders
   left.
3. Replace each `TODO(project-init)` with the prose it asks for, in
   English, from what the user said about the project. Ask what you
   cannot infer. Add no code: the first behavior comes in its own pull
   request, test-first when TDD is on.
4. Django: start the database first, `docker compose up -d --wait` in the
   repository — if port 5432 is taken (Postgres.app…), set
   `POSTGRES_PORT` and the port of `DATABASE_URL` in its `.env`, or point
   `DATABASE_URL` to that PostgreSQL after creating the database there
   (`createdb <name>`). Then run `scripts/commit.sh <dir>`.
   It refuses while a placeholder remains
   or a stack check fails, then makes the first commit on `main`. In a
   workspace, it also adds the repository to the workspace's list and
   commits that there.
5. On GitHub: the init-github skill creates the repository, pushes and
   sets its protections. A repository that will use release-please needs
   a blank squash body: before that, set `squash-body: blank` under
   `host` in `.project-init.yml`.
6. Report the stack, the choices, the commit, and the next step.

## Test-driven development later

`scripts/tdd.sh on <dir>` adds the Test-first rule to `AGENTS.md` and sets
`choices.tdd` in `.project-init.yml`; `off` removes it. It commits nothing:
the change goes through a pull request like any other.

## Not covered yet

- CI for hosts other than GitHub: on `other` or `none`, the checks run
  only through `commit.sh` and locally.
- A reusable Django app (a package other sites install): `django` makes a
  site; the app will be a stack of its own.
