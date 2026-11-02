#!/bin/sh
# Make the first commit of a repository set up by init-repo.sh: refuses
# while a TODO(project-init) placeholder remains or a stack check fails.
# In a workspace, then updates the workspace's list of repositories and
# commits it there.
#
# Usage: commit.sh <dir> [--message <text>]
set -eu

here=$(cd "$(dirname "$0")" && pwd)
skill=$(dirname "$here")
die() {
  echo "commit: $*" >&2
  exit 1
}

[ $# -ge 1 ] || die "usage: $0 <dir> [--message <text>]"
dir=$(cd "$1" && pwd)
shift
message=''
if [ "${1-}" = --message ]; then message=${2-}; fi

[ -f "$dir/.project-init.yml" ] || die "$dir has no .project-init.yml: run init-repo.sh first"
register=$(uv run --quiet --script "$here/register.py" "$dir/.project-init.yml")
[ "$(printf '%s' "$register" | jq -r .kind)" = repo ] || die "$dir is not a repository set up by init-repo"
stack=$(printf '%s' "$register" | jq -r .stack)
RUNTIME=$(printf '%s' "$register" | jq -r .choices.runtime)
version=$(printf '%s' "$register" | jq -r '."project-init"')
[ -n "$message" ] || message="chore: set up the repository with project-init $version"

cd "$dir"
left=$(git ls-files --cached --others --exclude-standard -z |
  xargs -0 grep -ln 'TODO(project-init)' 2>/dev/null || true)
[ -z "$left" ] || die "placeholders left to fill, in: $(echo $left)"

. "$skill/stacks/$stack/stack.sh"
echo "Running the $stack checks..."
stack_check || die "a check failed: fix it, then run commit.sh again"

git add --all
if git diff --cached --quiet; then
  echo "Nothing to commit in $dir."
else
  git commit --quiet --message "$message"
  echo "Committed in $dir: $(git log -1 --format='%h %s')"
fi

# The workspace above, if any.
parent=$(dirname "$dir")
workspace_commit=$skill/../init-workspace/scripts/commit.sh
if [ -f "$parent/.project-init.yml" ] &&
  grep -q '^kind: workspace' "$parent/.project-init.yml"; then
  if [ -f "$workspace_commit" ]; then
    sh "$workspace_commit" "$parent" --message "chore: add $(basename "$dir")"
  else
    echo "In the workspace, run the init-workspace skill's commit.sh on $parent."
  fi
fi
