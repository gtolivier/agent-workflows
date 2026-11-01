---
name: init-machine
description: Set up this machine so that no secret leaves it through git — gitleaks hooks on every commit, commit message and push, in every repository, alongside each repository's own hooks — and turn on GitHub push protection. Use when the user asks to set up or check their machine, to install the gitleaks or secret-scanning git hooks, to enable push protection, or after an update of this skill.
---

# init-machine

Installs, for every repository on the machine, git hooks that run
[gitleaks](https://github.com/gitleaks/gitleaks) before a secret can leave
it, then helps the user turn on GitHub push protection. The scripts do the
work; your part is to run them, read their output and report.

## What the hooks do

| Event | Scans | Blocks when |
|---|---|---|
| `pre-commit` | the staged changes | a finding |
| `commit-msg` | the commit message | a finding |
| `pre-push` | the pushed commits the remote does not have yet, merges included, their messages, and the pushed ref names | a finding |

- Rules: the repository's `.github/gitleaks/*.toml` if it has some, else its
  `.gitleaks.toml`, else the global configs — gitleaks' default rules
  (`secrets.toml`) and absolute paths to a home folder (`paths.toml`), each
  in its own pass. Secrets are redacted in the output.
- A known and accepted finding goes in `.gitleaksignore`, at the repository
  root, by the fingerprint the hook prints.
- They are git config-based hooks (`hook.gitleaks-<event>` in the global
  git config, git 2.54 or later): git runs them, then the repository's own
  hook, from `.git/hooks` or a local `core.hooksPath`. Nothing to change in
  a repository.
- One repository opts out of one hook with
  `git config hook.gitleaks-<event>.enabled false`; one command skips the
  hooks with `--no-verify`. Neither is yours to use without the user's
  explicit request.
- Without gitleaks, the hooks refuse.

## Steps

1. Run `scripts/install.sh` (relative to this skill's folder). It installs
   gitleaks with Homebrew if missing, copies the hook and configs to
   `~/.config/git/gitleaks/`, and sets the hooks in the global git config.
   It replaces a previous install: run it again after an update of this
   skill.
2. Check: in a repository, `git hook list --show-scope pre-commit` lists
   `global gitleaks-pre-commit`, followed by the repository's own hook if
   it has one.
3. Push protection: list the user's repositories with
   `gh repo list <owner> --json nameWithOwner,visibility`, ask which ones
   to cover, then give the user the command to run **in a normal
   terminal** — this session's token cannot change repository settings:
   `sh <this skill's folder>/scripts/enable-push-protection.sh <owner/repo>...`.
   It is free on public repositories; a private one needs GitHub Secret
   Protection (organizations only), and the local hooks are then its only
   protection. Also suggest checking that "Push protection for yourself" is
   on in the user's GitHub settings (Code security), which covers their
   pushes to every public repository.
4. Report what was installed, the check's output, and the push protection
   command.
