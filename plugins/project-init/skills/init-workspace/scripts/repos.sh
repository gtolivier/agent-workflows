#!/bin/sh
# Rewrite the list of repositories in a workspace's AGENTS.md, between the
# project-init:repositories markers: every folder of the workspace that is
# a git repository with a commit, with its stack, host and description from
# its .project-init.yml ("—" for a repository without one). A repository
# being set up joins the list with its first commit.
#
# Usage: repos.sh <workspace-dir>
set -eu

here=$(cd "$(dirname "$0")" && pwd)
[ $# -eq 1 ] || { echo "usage: $0 <workspace-dir>" >&2; exit 2; }
cd "$1"
[ -f AGENTS.md ] || { echo "repos: no AGENTS.md in $1" >&2; exit 1; }
if ! grep -q '^<!-- project-init:repositories' AGENTS.md; then
  echo "repos: AGENTS.md has no project-init:repositories markers: list left as is." >&2
  exit 0
fi
# Without the end marker, the rewrite would drop the rest of the file.
grep -q '^<!-- /project-init:repositories -->' AGENTS.md || {
  echo "repos: AGENTS.md lacks the end marker <!-- /project-init:repositories -->: put it back after the list" >&2
  exit 1
}

cell() { printf '%s' "$1" | tr '\n' ' ' | sed 's/|/\\|/g'; }

table=$(mktemp)
trap 'rm -f "$table"' EXIT
{
  echo '| Repository | Stack | Hosted at | Description |'
  echo '|---|---|---|---|'
} >"$table"
count=0
for child in */; do
  child=${child%/}
  [ -e "$child/.git" ] || continue
  git -C "$child" rev-parse --verify --quiet HEAD >/dev/null || continue
  count=$((count + 1))
  stack='—' description='—'
  # The remote without its credentials, if its URL holds some.
  hosted=$(git -C "$child" remote get-url origin 2>/dev/null |
    sed -E 's#^([A-Za-z][A-Za-z0-9+.-]*://)[^/@]*@#\1#' || true)
  [ -n "$hosted" ] || hosted='this machine only'
  if [ -f "$child/.project-init.yml" ]; then
    r=$(uv run --quiet --script "$here/register.py" "$child/.project-init.yml")
    stack=$(printf '%s' "$r" | jq -r '.stack // "—"')
    description=$(printf '%s' "$r" | jq -r '.description // "—"')
    repo=$(printf '%s' "$r" | jq -r '.host.repo // empty')
    [ -z "$repo" ] || hosted="[$repo](https://github.com/$repo)"
  fi
  # <…> keeps a link with spaces whole.
  printf '| [`%s`](<%s/>) | %s | %s | %s |\n' "$child" "$child" \
    "$(cell "$stack")" "$(cell "$hosted")" "$(cell "$description")" >>"$table"
done
[ "$count" -gt 0 ] || printf 'None yet: create one with the init-repo skill.\n' >"$table"

awk -v table="$table" '
  /^<!-- project-init:repositories/ { print; while ((getline line < table) > 0) print line; skip = 1; next }
  /^<!-- \/project-init:repositories -->/ { skip = 0 }
  !skip { print }
' AGENTS.md >AGENTS.md.new && mv AGENTS.md.new AGENTS.md
[ "$count" -eq 1 ] && noun=repository || noun=repositories
echo "Listed $count $noun in $(pwd)/AGENTS.md."
