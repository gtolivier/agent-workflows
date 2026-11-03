#!/bin/sh
# Finish the upgrade in progress in a repository or workspace: refuses
# while a file of the report is unsettled or holds conflict markers, or a
# deviation is malformed, or (in a repository) a stack check fails. Then
# sets the register to the new version and commits — on the upgrade's
# branch in a repository, on the current branch in a workspace.
#
# Usage: finish.sh <dir> [--no-check]
#
# --no-check: skip the stack's checks, when the user runs them elsewhere
# (a database or a browser this machine lacks); the CI runs them anyway.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
plugin=$(cd "$here/../../.." && pwd)
die() {
  echo "finish: $*" >&2
  exit 1
}

[ $# -ge 1 ] && [ $# -le 2 ] || die "usage: finish.sh <dir> [--no-check]"
dir=$(cd "$1" 2>/dev/null && pwd) || die "$1: no such folder"
check=true
if [ $# -eq 2 ]; then
  [ "$2" = --no-check ] || die "usage: finish.sh <dir> [--no-check]"
  check=false
fi
cd "$dir"
work=$(cd "$(git rev-parse --git-dir)" && pwd)/project-init-upgrade
report=$work/report.json
[ -f "$report" ] || die "no upgrade in progress in $dir: run upgrade.sh first"

pending=$(sh "$here/deviation.sh" "$dir" status)
[ -z "$pending" ] || die "settle these files with deviation.sh first:
$pending"
markers=$(jq -r '.items[].path' "$report" | while IFS= read -r path; do
  [ ! -f "$path" ] || ! grep -Eq '^(<<<<<<< this repository|>>>>>>> project-init [0-9.]+)$' "$path" || echo "$path"
done)
[ -z "$markers" ] || die "conflict markers left in:
$markers"
sh "$here/deviation.sh" "$dir" check

to=$(jq -r .to "$report")
kind=$(jq -r .kind "$report")
checks_changed=$(jq -r '.checks.before != .checks.after' "$report")
register=$(uv run --quiet --script "$here/register.py" .project-init.yml)
if [ "$kind" = repo ] && [ "$check" = true ]; then
  stack=$(printf '%s' "$register" | jq -r .stack)
  RUNTIME=$(printf '%s' "$register" | jq -r .choices.runtime)
  STACK_DIR=$plugin/skills/init-repo/stacks/$stack
  [ -f "$STACK_DIR/stack.sh" ] || die "unknown stack '$stack'"
  export RUNTIME STACK_DIR
  . "$STACK_DIR/stack.sh"
  echo "Running the $stack checks..."
  stack_check || die "a check failed: fix it, then run finish.sh again (or --no-check)"
fi

uv run --quiet --script "$here/register-edit.py" .project-init.yml set project-init "\"$to\""
# A workspace's list of repositories, as its commit.sh keeps it.
[ "$kind" != workspace ] || sh "$plugin/skills/init-workspace/scripts/repos.sh" "$dir"
git add --all
git commit --quiet --message "chore: upgrade project-init to $to"
rm -rf "$work"
echo "Committed in $dir: $(git log -1 --format='%h %s')"

echo "Next:"
if [ "$kind" = repo ]; then
  branch=$(git branch --show-current)
  lang=$(printf '%s' "$register" | jq -r '.choices.language.prs // "en"')
  host=$(printf '%s' "$register" | jq -r '.host.kind // "none"')
  if [ "$host" = none ]; then
    echo "  merge $branch into main."
  else
    echo "  push $branch and open a pull request (in the PR language: $lang)."
  fi
  [ "$checks_changed" = false ] || [ "$host" != github ] ||
    echo "  once it is merged, the required checks change: the user runs init-github's setup-github.sh $dir again, in a normal terminal."
else
  echo "  push the workspace."
fi
