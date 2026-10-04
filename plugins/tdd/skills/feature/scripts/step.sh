#!/usr/bin/env bash
# One step of a /tdd:feature cycle, checked and committed in one call.
#
#   step.sh red <behavior>            the new test fails; commits "red: …"
#   step.sh already-green <behavior>  the new test passes; commits
#                                     "red: … (already green)", ticks
#   step.sh green <behavior>          all clean; commits "green: …"
#   step.sh refactor [<what changed>] all clean; commits "refactor: …" if
#                                     anything changed, ticks
#   step.sh tests                     all clean, test files only; never
#                                     commits (the diff needs reading first)
#
# The orchestrator runs it after each subagent's report, from the
# repository, on its feature/<slug> branch. It checks the write zone first
# (only test files for red, already-green and tests; none for green and
# refactor), then runs the test, lint and type-check commands of the
# checklist, and commits only when every check passes. Ticking marks the
# first unchecked behavior of the checklist.
#
# It prints one line per check and the last lines of each failing command;
# the full output goes to <git-dir>/tdd/<slug>.log. Exit status: 0 when the
# step is committed (or checked, for tests), 1 when a check fails — nothing
# is committed then — and 2 on a usage or setup error.
#
# Judging what the output means stays with the orchestrator: whether a red
# fails for the right reason, whether the test counts are unchanged. Unlike
# the Stop hook, this script runs the checklist's commands: it runs only when
# the orchestrator calls it through its Bash tool, and the user approves
# those commands with the behavior list.

set -u

# Lines of output shown for each failing command.
TAIL_LINES=30

die() {
  echo "step.sh: $1" >&2
  exit 2
}

step=${1:-}
message=${2:-}
case $step in
red | already-green | green) [ -n "$message" ] || die "$step needs the behavior as its second argument" ;;
refactor | tests) ;;
*) die "usage: step.sh red|already-green|green|refactor|tests [<message>]" ;;
esac

top=$(git rev-parse --show-toplevel 2>/dev/null) || die "not in a Git repository"
cd "$top" || die "cannot enter $top"
branch=$(git branch --show-current)
case $branch in feature/*) ;; *) die "not on a feature/<slug> branch" ;; esac
git_dir=$(git rev-parse --absolute-git-dir)
slug=${branch#feature/}
checklist="$git_dir/tdd/$slug.md"
log="$git_dir/tdd/$slug.log"
# A red the commit hooks rejected, waiting to be committed with its green:
# its changes stay in the index meanwhile, and the file holds their tree.
pending="$git_dir/tdd/$slug.red-pending"
[ -f "$checklist" ] || die "no checklist at $checklist"

header() { sed -n "s/^$1:[[:space:]]*//p" "$checklist" | head -n 1; }
test_cmd=$(header 'Test command')
lint_cmd=$(header 'Lint command')
types_cmd=$(header 'Type-check command')
read -r -a test_paths <<<"$(header 'Test pathspecs')"
[ -n "$test_cmd" ] || die "no 'Test command:' line in $checklist"
[ "${#test_paths[@]}" -gt 0 ] || die "no 'Test pathspecs:' line in $checklist"

if [ -f "$pending" ]; then
  [ "$step" = green ] || die "a red is pending (rejected by a commit hook): only green can follow it"
elif ! git diff --cached --quiet; then
  die "the index has staged changes: unstage them first"
fi

# The write zone. Changes are counted against the index, which matches HEAD
# except while a red is pending.
excludes=()
for p in "${test_paths[@]}"; do
  case $p in
  ':('*) excludes+=(":(exclude,${p#:(}") ;;
  *) excludes+=(":(exclude)$p") ;;
  esac
done
changed() {
  {
    git diff --name-only --no-renames -- "$@"
    git ls-files --others --exclude-standard -- "$@"
  } | sort -u
}
test_changes=$(changed "${test_paths[@]}")
code_changes=$(changed . "${excludes[@]}")

refuse_zone() {
  echo "$step: NOT COMMITTED — $1:"
  printf '%s\n' "$2" | sed 's/^/  /'
  exit 1
}
case $step in
red | already-green | tests)
  [ -z "$code_changes" ] || refuse_zone "files outside the test files changed" "$code_changes"
  ;;
green | refactor)
  [ -z "$test_changes" ] || refuse_zone "test files changed" "$test_changes"
  ;;
esac
case $step in
red | already-green) [ -n "$test_changes" ] || refuse_zone "no test file changed" "(none)" ;;
green) [ -n "$code_changes" ] || refuse_zone "no production file changed" "(none)" ;;
esac

tick() {
  local next
  next=$(grep -m 1 '^- \[ \]' "$checklist" | sed 's/^- \[ \] //')
  [ -n "$next" ] || return 0
  awk '!done && /^- \[ \]/ { sub(/^- \[ \]/, "- [x]"); done = 1 } { print }' \
    "$checklist" >"$checklist.tmp" && mv "$checklist.tmp" "$checklist" &&
    echo "ticked: $next"
}

if [ "$step" = refactor ] && [ -z "$code_changes" ]; then
  echo "refactor: no change, nothing to commit"
  tick
  exit 0
fi
[ "$step" != refactor ] || [ -n "$message" ] || die "refactor changed files: say what changed as the second argument"

# run <label> <command>: runs it, logs its output, sets <label>_rc (empty
# when the command is "none") and adds to the report.
: >"$log"
summary=""
details=""
run() {
  local label=$1 cmd=$2 out rc=0
  case $cmd in '' | none)
    eval "${label}_rc="
    summary="$summary | $label: none"
    return
    ;;
  esac
  out=$(bash -c "$cmd" </dev/null 2>&1) || rc=$?
  eval "${label}_rc=$rc"
  printf '=== %s: %s (exit %s)\n%s\n\n' "$label" "$cmd" "$rc" "$out" >>"$log"
  if [ "$rc" -eq 0 ]; then
    summary="$summary | $label: ok"
    # The suite's last line usually holds its counts.
    [ "$label" = tests ] && summary="$summary ($(printf '%s\n' "$out" | grep -v '^[[:space:]]*$' | tail -n 1))"
  else
    summary="$summary | $label: FAIL (exit $rc)"
    details="$details
--- $label: last $TAIL_LINES lines ---
$(printf '%s\n' "$out" | tail -n "$TAIL_LINES")"
  fi
}
run tests "$test_cmd"
run lint "$lint_cmd"
run types "$types_cmd"
clean=no
[ "$tests_rc" = 0 ] && [ "${lint_rc:-0}" = 0 ] && [ "${types_rc:-0}" = 0 ] && clean=yes

report() {
  echo "$step checks:${summary# |}"
  [ -z "$details" ] || printf '%s\n' "${details#?}"
  echo "(full output: $log)"
}
not_committed() {
  report
  echo "$step: NOT COMMITTED — $1"
  exit 1
}

suffix=""
case $step in
red)
  if [ "$tests_rc" != 0 ]; then
    :
  elif [ -n "$types_rc" ] && [ "$types_rc" != 0 ]; then
    suffix=" (type checker only)"
  else
    not_committed "the suite and the type checker pass: this is not a red"
  fi
  commit_message="red: $message$suffix"
  ;;
already-green) commit_message="red: $message (already green)" ;;
green) commit_message="green: $message" ;;
refactor) commit_message="refactor: $message" ;;
esac
[ "$step" = red ] || [ "$clean" = yes ] || not_committed "a check failed"

report
if [ "$step" = tests ]; then
  echo "tests: checked, not committed"
  exit 0
fi

if [ -f "$pending" ]; then
  commit_message="red+green: $message"
fi
git add -A
if ! out=$(git commit -q -m "$commit_message" 2>&1); then
  printf '%s\n' "$out" | tail -n "$TAIL_LINES"
  if [ "$step" = red ]; then
    git write-tree >"$pending"
    echo "red: NOT COMMITTED — a commit hook rejected it; its changes stay staged, and the next green commits both as \"red+green: …\""
  else
    # Back to the index the step started from.
    if [ -f "$pending" ]; then git read-tree "$(cat "$pending")"; else git reset -q; fi
    echo "$step: NOT COMMITTED — a commit hook rejected it"
  fi
  exit 1
fi
rm -f "$pending"
echo "committed $(git rev-parse --short HEAD) $commit_message"
case $step in
green | refactor) git show --shortstat --format= HEAD | sed 's/^ */  /' ;;
esac
case $step in
already-green | refactor) tick ;;
esac
exit 0
