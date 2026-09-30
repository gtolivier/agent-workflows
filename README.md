# agent-workflows

Reusable workflows for AI coding agents, packaged as
[Claude Code plugins](https://code.claude.com/docs/en/plugins).

## Install

```sh
claude plugin marketplace add gtolivier/agent-workflows
claude plugin install tdd@agent-workflows
```

To update, refresh the marketplace, then the plugin, and restart Claude
Code:

```sh
claude plugin marketplace update agent-workflows
claude plugin update tdd@agent-workflows
```

## Plugins

### `tdd` — test-driven development, one feature at a time

A red → green → refactor loop where each step is done by its own subagent,
and the main session only orchestrates and checks.

| Step | Subagent | Model | Writes | Stops when |
|---|---|---|---|---|
| Red | `tdd:red` | Opus 5.5, high effort | test files only | exactly one new test fails, for the right reason |
| Green | `tdd:green` | Sonnet 5.5 | everything but test files | the full suite is green |
| Refactor | `tdd:refactor` | Opus 5.5, high effort | everything but test files, existing files only | the suite stayed green after every change — "nothing to refactor" is valid |

The strongest model goes where the test suite cannot judge the work: nothing
tells you a red test is the *right* test, or that a refactor was worth it.

Run a feature with:

```
/tdd:feature <what the feature should do>
```

The skill creates a `feature/<slug>` branch, proposes a list of behaviors
(one test each) and waits for your approval, then runs one cycle per
behavior without interrupting you, with one commit per step (`red: …`,
`green: …`, `refactor: …`) so that each step can be checked on its own.
Once the feature is
complete, it opens a pull request, lets CI and review bots run alongside an
independent review, triages their comments and yours (fix, propose, or
reply why not) — anyone else's are reported to you, not acted on — and only
then asks for your approval. Nothing is merged without it; the merge is a
squash, one commit per feature.

**Baby steps.** Each behavior is the smallest observable increment, ordered
from the simplest case to the most general (Zero, One, Many, Boundaries,
Interfaces, Exceptions). The green step may fake the first example with a
hard-coded value; the next example forces the generalization. When a green
step still needs a lot of code, the skill proposes to split the remaining
behaviors.

**Foreground subagents.** The cycle runs smoothest when each subagent runs
in the foreground and returns its report within the turn. Claude Code's fork
mode, on by default in interactive sessions, runs every subagent in the
background; set `CLAUDE_CODE_FORK_SUBAGENT=0` in the shell environment
Claude Code is launched from (for instance in `~/.zshrc`) to turn it off. In
our tests, setting it in the `env` section of a settings file did not change
the mode: that section reached the commands Claude ran, not the Claude Code
process itself. Without it, the loop still works: the skill marks each wait
in its checklist.

**Ralph loop.** A Stop hook keeps a running feature going. The skill keeps a
`Status:` line at the top of its checklist; while it says `running`, the hook
blocks the session from stopping and relaunches it, until three relaunches
pass without progress (a newly ticked behavior or a new commit). It finds
the feature whether the session runs in its repository or in the folder
above it — in that second case, with one running feature at a time (see the
[roadmap](ROADMAP.md) for parallel features). It lets the session stop
whenever the skill waits for you or for CI and reviews. The hook only reads the checklist
— it never runs a command — and does nothing outside a running
`/tdd:feature`.

The plugin is language-agnostic and needs no per-project configuration. It
reads the project's conventions from its `AGENTS.md` (or, failing that, its
README and build files): the test command, the lint and format commands if
any, and where test files live — a test directory, or a naming pattern next
to the code such as `*_test.go` or `*.test.ts`. Stating them in `AGENTS.md`
makes them unambiguous. A test file that fails to load — an import error, a
compile error — because the symbol it tests does not exist yet counts as a
valid red, and so does a call the function's current signature does not
accept yet.

## Portability

The rules of each step live in standard [Agent Skills](https://agentskills.io)
(`SKILL.md` with `name` and `description` only); the subagent files are thin
Claude Code wrappers that pick a model and preload those skills. Porting to
another agent (Codex, for example) means writing its own thin wrappers, not
rewriting the rules.

## Roadmap

Postponed ideas, and what would trigger them: [ROADMAP.md](ROADMAP.md).

## License

MIT
