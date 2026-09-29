# agent-workflows

Reusable workflows for AI coding agents, packaged as
[Claude Code plugins](https://code.claude.com/docs/en/plugins).

## Install

```sh
claude plugin marketplace add gtolivier/agent-workflows
claude plugin install tdd@agent-workflows
```

## Plugins

### `tdd` — test-driven development, one feature at a time

A red → green → refactor loop where each step is done by its own subagent,
and the main session only orchestrates and checks.

| Step | Subagent | Model | Writes | Stops when |
|---|---|---|---|---|
| Red | `tdd:red` | Opus 5.5, high effort | the test directory only | exactly one new test fails, for the right reason |
| Green | `tdd:green` | Sonnet 5.5 | everything but tests | the full suite is green |
| Refactor | `tdd:refactor` | Opus 5.5, high effort | everything but tests, existing files | the suite stayed green after every change — "nothing to refactor" is valid |

The strongest model goes where the test suite cannot judge the work: nothing
tells you a red test is the *right* test, or that a refactor was worth it.

Run a feature with:

```
/tdd:feature <what the feature should do>
```

The skill creates a `feature/<slug>` branch, proposes a list of behaviors
(one test each) and waits for your approval, then runs one cycle per
behavior — one commit each — without interrupting you. Once the feature is
complete, it asks for your approval before pushing; after it, it opens a
pull request and squash-merges it when CI is green.

The subagents read the test command from the project's `AGENTS.md` (or its
README / `pyproject.toml`), so the plugin needs no per-project
configuration: state the command there.

## Portability

The rules of each step live in standard [Agent Skills](https://agentskills.io)
(`SKILL.md` with `name` and `description` only); the subagent files are thin
Claude Code wrappers that pick a model and preload those skills. Porting to
another agent (Codex, for example) means writing its own thin wrappers, not
rewriting the rules.

## License

MIT
