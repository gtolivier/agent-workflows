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

Each plugin is released on its own, with a `<plugin>-v<version>` tag, a
GitHub release and a `CHANGELOG.md` at its root (`plugins/<name>/`).

## Plugins

### `tdd` — test-driven development, one feature at a time

A red → green → refactor loop where each step is done by its own subagent,
and the main session only orchestrates and checks.

| Step | Subagent | Model | Writes | Stops when |
|---|---|---|---|---|
| Red | `tdd:red` | Opus 5.5, high effort | test files only | exactly one new test fails, for the right reason |
| Green | `tdd:green` | Sonnet 5.5 | everything but test files | the full suite is green |
| Refactor | `tdd:refactor` | Opus 5.5, high effort | everything but test files — in tests mode, test files only; existing files only | the suite stayed green after every change — "nothing to refactor" is valid |

The strongest model goes where the test suite cannot judge the work: nothing
tells you a red test is the *right* test, or that a refactor was worth it.

Run a feature with:

```
/tdd:feature <what the feature should do>
```

The skill creates a `feature/<slug>` branch, proposes a list of behaviors
(one test each) and waits for your approval, then runs one cycle per
behavior without interrupting you, with one commit per step (`red: …`,
`green: …`, `refactor: …`, and `refactor(tests): …` for the final tests
pass) so that each step can be checked on its own.
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

**Clean code.** The refactor step checks each cycle's code against explicit
criteria: no magic numbers or strings, intention-revealing names, small
single-purpose functions, no flag arguments, no duplicated knowledge,
comments that say why, type annotations where the project uses them. Once
every behavior is done, one last refactor looks at the whole feature, to
catch what no single cycle showed, in two passes: the production code
first, then the tests alone. The tests pass leaves the production code
untouched and keeps the same tests, every assertion, every expected value
and every input; the orchestrator checks its zone, the test counts and the
diff. The
plugin needs no configuration for this, but rules a linter or type checker
can enforce are better enforced there, in the project's own tool settings:
every step must leave both clean.

**Foreground subagents.** The orchestrator runs each subagent in the
foreground (`run_in_background: false` on Claude Code's Agent tool) and
reads its report within the same turn. Should one run in the background
anyway, the skill marks the wait in its checklist (`Status: waiting — …`),
so the Stop hook lets the session wait instead of relaunching it. No
environment variable is needed: `CLAUDE_CODE_FORK_SUBAGENT=0` made no
difference in our tests.

**Ralph loop.** A Stop hook keeps a running feature going. The skill keeps a
`Status:` line at the top of its checklist; while it says `running`, the hook
blocks the session from stopping and relaunches it, until three relaunches
pass without progress (a newly ticked behavior or a new commit). It finds
the feature whether the session runs in its repository or in the folder
above it — in that second case, with one running feature at a time (see the
[roadmap](ROADMAP.md) for parallel features). It lets the session stop
whenever the skill waits for you or for CI and reviews. The hook only reads
the checklist — it never runs a command — and does nothing outside a
running `/tdd:feature`.

**No file writes through the shell.** The red, green and refactor
subagents change files only with their Edit and Write tools, the ones
permission prompts and hooks see. A `PreToolUse` hook on `Bash`, active only
while one of them runs, refuses the usual shortcuts — a redirection to a
file, `tee`, `sed -i`, `cp`, `mv`, `rm`, a `git` command that changes the
working tree, interpreter code (inline or in a heredoc) that writes. A
subagent that needs what its tools cannot do — creating, moving or deleting
a file — stops with `NEEDS_FILE_OPERATION`; the orchestrator makes the
operation, inside that subagent's write zone, and resumes it. The hook
matches patterns, so it stops an honest shortcut, not a determined one. Commands that write as a
side effect of their job — the test runner, the formatter, a generator such
as `makemigrations` — are not affected.

The plugin is language-agnostic and needs no per-project configuration. It
reads the project's conventions from its `AGENTS.md` (or, failing that, its
README and build files): the test command, the lint, type-check and format
commands if any, and where test files live — a test directory, or a naming
pattern next to the code such as `*_test.go` or `*.test.ts`. Stating them in
`AGENTS.md` makes them unambiguous. A test file that fails to load — an
import error, a compile error — because the symbol it tests does not exist
yet counts as a valid red, and so does a call the function's current
signature does not accept yet, or an exception the code under test raises
because the behavior is missing. A behavior about types alone — what a
signature accepts or rejects — can be red in the type checker only, with a
passing test.

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
