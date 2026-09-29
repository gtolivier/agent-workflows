---
name: feature
description: Develop one feature test-first on its own branch — agree on a list of behaviors with the user, run one red/green/refactor cycle per behavior through the red, green and refactor subagents, then ask for approval before anything is pushed. Use when the user asks to build a feature in TDD, or when the project's AGENTS.md requires test-first development.
---

# Develop a feature test-first

The feature to build is the user's request. You are the **orchestrator**: you
never write tests or implementation yourself. You delegate each step to its
subagent (`red`, `green`, `refactor` — in Claude Code, `tdd:red`, `tdd:green`,
`tdd:refactor`), check what it did, and keep the history.

When delegating, **never override the subagent's model**: each definition
picks the model suited to its step.

## 1. Preconditions

Stop and tell the user if any of these fails:

- the working tree is clean and you are on the default branch, up to date;
- the project's `AGENTS.md` (or README) states the test command, and the full
  suite is green right now.

## 2. Branch

Create `feature/<slug>` from the default branch, `<slug>` being a short
kebab-case name for the feature.

## 3. Behaviors — the one checkpoint before the end

Read the relevant code, tests and any specification or reference the user
pointed to. Split the feature into **behaviors**: each one observable, each
one specified by exactly one test, ordered so that each builds on what is
already green (leaves before the code that uses them).

Write them as a checklist in `.tdd/<slug>.md` (`- [ ] <behavior>`), and add
`.tdd/` to `.git/info/exclude` if it is not there yet: the checklist is
working state, never committed.

Show the list to the user and **wait for their approval**. Adjust it until
they approve. This is the only interruption before the feature is complete.

## 4. One cycle per behavior

Work through the unchecked behaviors in order, without stopping to report
between cycles. For each one:

1. **Red.** Delegate to `red` with the behavior sentence and the context it
   needs (relevant paths, reference behavior). Then check:
   - `git status --porcelain`: only paths inside the test directory changed;
   - run the test command yourself: exactly the new test fails, for the
     reason the report states.
2. **Green.** Delegate to `green`. Then check: no path inside the test
   directory changed, and the full suite and the linter are clean.
3. **Refactor.** Delegate to `refactor`. Then check: no path inside the test
   directory changed, and the full suite and the linter are clean.
4. **Commit** the cycle — one commit per behavior, message = the behavior —
   and tick it in the checklist.

**When a check fails**, restore only the out-of-zone paths
(`git restore` / `git clean` on those paths), then rerun the same subagent
once with a reminder of its write zone. A second violation stops the loop.

**When a subagent does not report success:**

| Report | Action |
|---|---|
| `red` → `ALREADY_GREEN` | Keep the test, commit it, note it for the final review. |
| `red` → `REFUSED` (ambiguous behavior) | Stop and ask the user. |
| `green` → `REFUSED` (test looks wrong) | Send the explanation back to `red` once. If it persists, stop and ask. |
| `refactor` → `REFUSED` | The suite was not green: that is a bug in the previous step. Stop and report. |

## 5. Stop conditions

Hand back to the user only when:

- every behavior is checked (go to step 6);
- a subagent refuses twice, or asks a question only the user can answer;
- three attempts on the same behavior failed;
- the list turns out to be wrong — a behavior is missing or impossible. Do
  not change the approved list silently: propose the change.

## 6. Review and approval

With the full suite and the linter clean, write a review for the user:

- the checklist, all ticked;
- `git log --oneline <default-branch>..HEAD`;
- `git diff --stat <default-branch>...HEAD`;
- anything notable: `ALREADY_GREEN` tests, refusals, restored violations.

Ask for approval. **Do not push anything before an explicit go-ahead.**

## 7. After approval

1. Push the branch and open a pull request whose description is the
   checklist.
2. Wait for CI. If it fails, stop and report — do not fix it silently.
3. If CI is green: squash-merge (one commit per feature on the default
   branch), delete the branch, switch back to the default branch and pull.
4. Delete `.tdd/<slug>.md`.
