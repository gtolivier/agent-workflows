# Roadmap

Ideas that were discussed and deliberately postponed. Each entry says why
it is not done yet and what would trigger it.

## Parallel features in Git worktrees

**Status:** not supported yet. To be done when several features need to run
at the same time, typically across several repositories.

The `tdd` plugin was designed for one feature at a time per repository.
Reviewing its design against parallel features, each in its own Git
worktree:

**What already works**

- The checklist lives in `<git-dir>/tdd/`, and `git rev-parse --git-dir`
  returns a separate directory for each worktree: two features never share
  a checklist.
- Each feature has its own `feature/<slug>` branch; Git refuses to check out
  the same branch in two worktrees anyway.
- The Ralph Stop hook finds the right feature when the session is started
  inside its worktree.
- Test suites do not interfere as long as each worktree has its own
  environment and the tests use no shared external resource.

**What blocks**

1. **The default branch.** Step 1 of `/tdd:feature` requires being on the
   default branch, step 2 creates the feature branch from it, step 6
   compares against it before pushing, and step 8 switches back to it. In a
   worktree, the default branch is usually checked out in the main checkout
   already — Git refuses to check it out twice — and the local copy may be
   stale. Steps 1, 2 and 6 should work from `origin/<default-branch>` after
   a fetch; step 8 must not remove the worktree it runs in, and should leave
   the cleanup to the end of the session (Claude Code offers it when a
   worktree session exits).
2. **Sessions started in a parent folder.** When a session starts in a
   folder that holds several repositories, the Stop hook takes the first
   running feature it finds. This already goes wrong today, without
   worktrees, as soon as two sessions started in the same parent folder
   each run a feature: one session can be relaunched for the other's
   feature. Rule until then: one running feature per parent folder, or one
   session per repository or worktree, started inside it. Making the hook
   session-aware (it receives a `session_id`) would need the checklist to
   record its owning session, which breaks resuming a feature from a new
   session; the "one session per worktree" rule is simpler.
3. **Project settings.** A new worktree is a fresh checkout: git-ignored
   files such as `.claude/settings.local.json` (for example one holding a
   restricted GitHub token) are not in it. Claude Code can copy them with a
   `.worktreeinclude` file, and it saves permission approvals made in a
   worktree to the main checkout's `.claude/settings.local.json`, which
   suggests worktree sessions read that file; whether its `env` section
   applies too must be checked before any real use, or the session may run
   with broader credentials than intended.
4. **Claude Code's own worktrees.** `claude --worktree <name>` creates the
   worktree under `.claude/worktrees/<name>/` on a `worktree-<name>` branch,
   and `EnterWorktree` moves a running session into one. The Stop hook only
   looks at `feature/*` branches, and in parent-folder mode it does not look
   inside `.claude/worktrees/`. Either the skill creates its `feature/<slug>`
   branch inside such a worktree, or the hook learns to recognize them.
5. **Details.** Each new worktree needs its dependencies installed (for
   example `uv sync`). Review bots with a rate limit review one pull request
   at a time; the skill already never waits on them.

**Plan**

- Adapt steps 1, 2, 6 and 8 of `/tdd:feature` to worktrees, and document
  "one session per worktree, started inside it".
- Decide between Claude Code's `--worktree` and plain `git worktree`, and
  make the Stop hook and the branch naming agree.
- Check which project settings a worktree session reads, and use
  `.worktreeinclude` or a repository-root settings file if needed.
- Verify it end to end with two throwaway features running in parallel,
  including the Stop hook and the write-zone checks.

## Terminal multiplexers for coding agents

**Status:** not needed yet. To be reconsidered with parallel features (see
above), several agents side by side, or agents running on an always-on
machine.

Tools such as [Herdr](https://herdr.dev) (open source, Apache 2.0) run
several coding-agent sessions — Claude Code, Codex and others — in panes,
show which one is working, blocked or idle, restore them after a restart,
and can gather machines over SSH.

**Why not now**

- The workflow is sequential on purpose: one feature at a time, approved by
  the user before the next one. The red, green and refactor subagents are
  orchestrated inside a single Claude Code session.
- Remote follow-up is already covered by Claude Code's own remote access,
  and the Ralph Stop hook relaunches a session that stops too early.
- "Agents keep working when you close the lid" only holds when the
  multiplexer runs on another, always-on machine.

**When it would help**

- Several features in parallel, each in its own session, with one view of
  which one waits for the user.
- Claude Code and other agents working side by side.
- Agents running on an always-on machine while the laptop is closed.

**Precautions, when the time comes**

- Read the install script before running it: the documented install pipes
  a remote script into the shell.
- It overlaps with features Claude Code already has (background sessions,
  remote access); decide which one owns what.
- It lets agents prompt each other, which falls outside the plugin's
  guardrails (write zones, one orchestrator, the user's approval). How the
  two coexist must be checked first.
