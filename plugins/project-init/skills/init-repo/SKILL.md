---
name: init-repo
description: Create a new repository for a stack (python, django, angular, hugo, hugo-theme) with its official generator and tools, and the common layer — .gitignore, LICENSE, README.md, AGENTS.md with the stack's rules and, when chosen, test-first development, GitHub Actions CI and CodeRabbit when on GitHub, and the register .project-init.yml — inside a workspace or on its own, on GitHub, another host or this machine only. Use when the user asks to create, start, scaffold or set up a new repository or project.
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
| `angular` | an application: `ng new` (zoneless, SCSS, no SSR), `ng add angular-eslint` (typescript-eslint `strictTypeChecked`), `ng add @vitest/browser-playwright`, `npm init playwright`; npm, Prettier, Vitest in Chromium, Playwright with axe | `lint` (ESLint and Prettier), `typecheck`, `test`, `build`, `e2e` |
| `hugo` | a site: the starter of `hugo new theme` copied to the root, `hugo mod init` (Hugo modules, standard edition); npm, Prettier, stylelint, ESLint (typescript-eslint `strictTypeChecked`), TypeScript, html-validate, linkinator, Playwright with axe (`npm init playwright`) | `lint` (ESLint, stylelint and Prettier), `typecheck`, `build` (strict, then html-validate and linkinator on the internal links), `test` |
| `hugo-theme` | a theme, published as a Hugo module: `hugo new theme`, its content moved to a demo site in `exampleSite/`; the same tools, run on the demo site | the same |

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
| `.nvmrc`, `.prettierignore`, `e2e/` | angular, hugo, hugo-theme: the Node major version, which the CI reads; the register (and for Hugo the Go templates), left out of Prettier; an accessibility test of the home page with axe |
| `go.mod`, `exampleSite/` | hugo, hugo-theme: the Hugo module, its path from the remote (`github.com/<owner>/<name>`), else the name; hugo-theme: the demo site, which imports the theme from the repository |
| `.project-init.yml` | the register: project-init's version, the choices, the CI checks to require, the files it manages, the deviations |

## Steps

1. Ask the user, in one message — never choose for them:
   - **Name** (the folder; python and django: letters, digits, `.`, `_`,
     `-`; angular: lowercase letters and digits, words joined by `-`;
     hugo and hugo-theme: lowercase letters, digits, `.`, `_`, `-`) and a
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
   - **Runtime version** (python: the oldest supported, default 3.12;
     django: the oldest supported, default and minimum 3.12, which Django 6
     requires; angular: the Node major version of development and the CI,
     default the latest LTS, minimum 22 — the Node on `PATH` must have that
     major version, at a release Angular supports, such as 24.15 or later;
     hugo and hugo-theme: the oldest Hugo supported, default the latest
     release, minimum 0.158.0 — the Hugo on `PATH` must be that version or
     later, with Go: if it is older than the latest, ask whether to
     upgrade it or to take its version; Node gets the latest LTS).
   - **Hugo site: its theme in the site or beside it.** In the site, the
     theme is the site's own `layouts/` and `assets/`: one `hugo`
     repository. Beside it, the theme is a `hugo-theme` repository the
     site imports as a Hugo module: create the theme first, commit it
     (`commit.sh`) and publish it (init-github: the push publishes the
     module, which must be public), then the site, then run
     `stacks/hugo/theme.sh <site-dir> <module> --local <path>` before the
     site's `commit.sh` — `<module>` as the theme's `AGENTS.md` names it,
     `--local` the theme's folder from the site (`../<theme>` in a
     workspace), which `npm start` then uses instead of the published
     version.
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
   (`createdb <name>`). Angular, hugo and hugo-theme: run
   `npm run format` first — Prettier checks the prose you wrote. Angular:
   stop any `npm start`, as the end-to-end tests start a server of their
   own on port 4200; hugo and hugo-theme: they use port 1314, which must
   be free. Then run
   `scripts/commit.sh <dir>`.
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
- A Hugo theme the site cannot fetch — private, or not yet pushed:
  `theme.sh` refuses it and leaves the site unchanged.
- Deploying a Hugo site (GitHub Pages, Netlify…): the CI builds and
  checks it, nothing more.
