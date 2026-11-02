#!/bin/sh
# Commit a workspace's own files, directly on its branch: refreshes the list
# of repositories in AGENTS.md first, and refuses while a TODO(project-init)
# placeholder remains, or when the commit would take in a repository of the
# workspace or .claude/settings.local.json, or when the .gitignore is not an
# allowlist.
#
# Usage: commit.sh <workspace-dir> [--message <text>]
set -eu

here=$(cd "$(dirname "$0")" && pwd)
die() {
  echo "commit: $*" >&2
  exit 1
}

[ $# -ge 1 ] || die "usage: $0 <workspace-dir> [--message <text>]"
dir=$(cd "$1" && pwd)
shift
message=''
if [ "${1-}" = --message ]; then message=${2-}; fi

[ -f "$dir/.project-init.yml" ] || die "$dir has no .project-init.yml: run init-workspace.sh first"
grep -q '^kind: workspace' "$dir/.project-init.yml" || die "$dir is not a workspace"
if [ -z "$message" ]; then
  version=$(uv run --quiet --script "$here/register.py" "$dir/.project-init.yml" | jq -r '."project-init"')
  message="chore: set up the workspace with project-init $version"
fi

cd "$dir"
grep -qx '/\*' .gitignore 2>/dev/null ||
  die ".gitignore is not an allowlist (no \"/*\" line): the repositories would be committed into the workspace"
sh "$here/repos.sh" "$dir"
git add --all
staged=$(git diff --cached --name-only)
left=$(printf '%s\n' "$staged" | while IFS= read -r f; do
  [ -f "$f" ] && grep -l 'TODO(project-init)' "$f" || true
done)
embedded=$(git diff --cached --raw | awk '$2 == "160000" { print $NF }')
secret=$(printf '%s\n' "$staged" | grep -x '.claude/settings.local.json' || true)
if [ -n "$left$embedded$secret" ]; then
  git reset --quiet
  [ -z "$left" ] || echo "commit: placeholders left to fill, in: $(echo $left)" >&2
  [ -z "$embedded" ] || echo "commit: these repositories would be committed into the workspace: $(echo $embedded) — the .gitignore must stay an allowlist" >&2
  [ -z "$secret" ] || echo "commit: .claude/settings.local.json would be committed — the .gitignore must ignore it" >&2
  exit 1
fi

if git diff --cached --quiet; then
  echo "Nothing to commit in the workspace."
else
  git commit --quiet --message "$message"
  echo "Committed in the workspace: $(git log -1 --format='%h %s')"
fi
