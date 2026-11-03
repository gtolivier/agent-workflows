#!/bin/sh
# Print a link to GitHub's form for a new fine-grained personal access token
# for a workspace's Claude Code sessions, pre-filled with its name, owner,
# expiration and permissions, and the repositories to select: the
# workspace's own and each repository in it hosted on GitHub. GitHub cannot
# pre-select repositories from a URL; the user ticks them on the form.
#
# Usage: token-url.sh <workspace-dir>
set -eu

here=$(cd "$(dirname "$0")" && pwd)
die() {
  echo "token-url: $*" >&2
  exit 1
}
[ $# -eq 1 ] || { echo "usage: $0 <workspace-dir>" >&2; exit 2; }
dir=$(cd "$1" && pwd)
[ -f "$dir/.project-init.yml" ] || die "$dir has no .project-init.yml: set it up with init-workspace first"
for tool in git jq uv; do
  command -v "$tool" >/dev/null || die "$tool is missing"
done

ws=$(uv run --quiet --script "$here/register.py" "$dir/.project-init.yml")
[ "$(printf '%s' "$ws" | jq -r .kind)" = workspace ] || die "$dir is not a workspace"
[ "$(printf '%s' "$ws" | jq -r .host.kind)" = github ] || die "$dir is not on GitHub: no token to make"
name=$(printf '%s' "$ws" | jq -r .name)
owner=$(printf '%s' "$ws" | jq -r '.host.owner // empty')

# owner/name from a GitHub remote URL, without credentials or ".git".
github_repo() {
  printf '%s' "$1" | sed -nE 's#^(https://([^/@]*@)?github\.com/|git@github\.com:|ssh://git@github\.com/)([^/]+/[^/]+)$#\3#p' |
    sed 's/\.git$//'
}

# One owner/name per line: the workspace, then its repositories.
repos=$(printf '%s' "$ws" | jq -r '.host.repo // empty')
for child in "$dir"/*/; do
  child=${child%/}
  [ -e "$child/.git" ] || continue
  repo=''
  if [ -f "$child/.project-init.yml" ]; then
    r=$(uv run --quiet --script "$here/register.py" "$child/.project-init.yml")
    [ "$(printf '%s' "$r" | jq -r '.host.kind // empty')" = github ] &&
      repo=$(printf '%s' "$r" | jq -r '.host.repo // empty')
  fi
  # A repository without a register: its origin, if on GitHub.
  [ -n "$repo" ] || repo=$(github_repo "$(git -C "$child" remote get-url origin 2>/dev/null || true)")
  [ -z "$repo" ] || repos="$repos
$repo"
done
repos=$(printf '%s\n' "$repos" | sed '/^$/d' | sort -u)
[ -n "$repos" ] || die "no repository on GitHub in $dir"
[ -n "$owner" ] || owner=$(printf '%s\n' "$repos" | head -n 1 | cut -d/ -f1)

# A token reaches the repositories of one owner only.
others=$(printf '%s\n' "$repos" | grep -v "^$owner/" || true)
mine=$(printf '%s\n' "$repos" | grep "^$owner/" | cut -d/ -f2)
[ -n "$mine" ] || die "no repository of $owner on GitHub in $dir"

list=$(printf '%s\n' "$mine" | paste -sd, - | sed 's/,/, /g')
token_name=$(printf 'claude-%s' "$name" | cut -c1-40)
description=$(printf 'Claude Code sessions started in the %s workspace. Repository access: Only select repositories, then tick: %s.' "$name" "$list" | cut -c1-1024)
query=$(jq -rn --arg name "$token_name" --arg description "$description" --arg owner "$owner" '
  [["name", $name], ["description", $description], ["target_name", $owner],
   ["expires_in", "90"],
   ["contents", "write"], ["pull_requests", "write"], ["issues", "write"],
   ["workflows", "write"], ["actions", "read"], ["statuses", "read"]]
  | map("\(.[0])=\(.[1] | @uri)") | join("&")')

echo "Create the token (pre-filled; GitHub cannot pre-select repositories):"
echo
echo "  https://github.com/settings/personal-access-tokens/new?$query"
echo
echo "Under Repository access, choose Only select repositories and tick, owned by $owner:"
printf '%s\n' "$mine" | sed 's/^/  - /'
if [ -n "$others" ]; then
  echo
  echo "Not covered — a token reaches the repositories of one owner only:"
  printf '%s\n' "$others" | sed 's/^/  - /'
fi
echo
echo "Then paste it into $dir/.claude/settings.local.json, under \"env\", as \"GH_TOKEN\"."
echo "Already have $token_name? Edit it at https://github.com/settings/personal-access-tokens"
echo "and tick the repositories above that it misses."
