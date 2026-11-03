#!/bin/sh
# Print a link to GitHub's form for a new fine-grained personal access token
# for the Claude Code sessions of a workspace or of a repository on its own,
# pre-filled with its name, owner, expiration and permissions, and the
# repositories to select: a workspace's own and each repository in it
# hosted on GitHub, or the repository alone. A repository in a workspace
# takes the workspace's token: its sessions start there. GitHub cannot
# pre-select repositories from a URL; the user ticks them on the form.
#
# Usage: token-url.sh <dir>
set -eu

here=$(cd "$(dirname "$0")" && pwd)
die() {
  echo "token-url: $*" >&2
  exit 1
}
[ $# -eq 1 ] || { echo "usage: $0 <dir>" >&2; exit 2; }
dir=$(cd "$1" && pwd)
for tool in git jq uv; do
  command -v "$tool" >/dev/null || die "$tool is missing"
done
read_register() { uv run --quiet --script "$here/register.py" "$1/.project-init.yml"; }
kind_of() { [ ! -f "$1/.project-init.yml" ] || read_register "$1" | jq -r '.kind // empty'; }

# owner/name from a GitHub remote URL, without credentials or ".git".
github_repo() {
  printf '%s' "$1" | sed -nE 's#^(https://([^/@]*@)?github\.com/|git@github\.com:|ssh://git@github\.com/)([^/]+/[^/]+)$#\3#p' |
    sed 's/\.git$//'
}
# A repository's owner/name on GitHub: its register's, else its origin's.
repo_of() {
  if [ -f "$1/.project-init.yml" ]; then
    r=$(read_register "$1")
    [ "$(printf '%s' "$r" | jq -r '.host.kind // empty')" = github ] || return 0
    printf '%s' "$r" | jq -r '.host.repo // empty'
  else
    github_repo "$(git -C "$1" remote get-url origin 2>/dev/null || true)"
  fi
}

kind=$(kind_of "$dir")
if [ "$kind" != workspace ]; then
  [ -e "$dir/.git" ] || die "$dir is neither a workspace nor the top of a git repository"
  parent=$(dirname "$dir")
  if [ "$(kind_of "$parent")" = workspace ]; then
    echo "$(basename "$dir") is in the $parent workspace: its sessions start there, with the workspace's token."
    echo
    dir=$parent kind=workspace
  fi
fi

# One owner/name per line: the workspace, then its repositories; or the
# repository alone.
if [ "$kind" = workspace ]; then
  ws=$(read_register "$dir")
  [ "$(printf '%s' "$ws" | jq -r .host.kind)" = github ] || die "$dir is not on GitHub: no token to make"
  name=$(printf '%s' "$ws" | jq -r .name)
  owner=$(printf '%s' "$ws" | jq -r '.host.owner // empty')
  what="the $name workspace"
  repos=$(printf '%s' "$ws" | jq -r '.host.repo // empty')
  for child in "$dir"/*/; do
    child=${child%/}
    [ -e "$child/.git" ] || continue
    repo=$(repo_of "$child")
    [ -z "$repo" ] || repos="$repos
$repo"
  done
else
  name=''
  [ ! -f "$dir/.project-init.yml" ] || name=$(read_register "$dir" | jq -r '.name // empty')
  [ -n "$name" ] || name=$(basename "$dir")
  owner=''
  what="the $name repository"
  repos=$(repo_of "$dir")
fi
repos=$(printf '%s\n' "$repos" | sed '/^$/d' | sort -u)
[ -n "$repos" ] || die "no repository on GitHub in $dir"
[ -n "$owner" ] || owner=$(printf '%s\n' "$repos" | head -n 1 | cut -d/ -f1)

# A token reaches the repositories of one owner only.
others=$(printf '%s\n' "$repos" | grep -v "^$owner/" || true)
mine=$(printf '%s\n' "$repos" | grep "^$owner/" | cut -d/ -f2)
[ -n "$mine" ] || die "no repository of $owner on GitHub in $dir"

# GitHub caps a token's name at 40 characters.
token_name=$(printf 'Claude Code - %s' "$name" | cut -c1-40)
query=$(jq -rn --arg name "$token_name" --arg owner "$owner" '
  [["name", $name], ["target_name", $owner],
   ["expires_in", "90"],
   ["contents", "write"], ["pull_requests", "write"], ["issues", "write"],
   ["workflows", "write"], ["actions", "read"], ["statuses", "read"]]
  | map("\(.[0])=\(.[1] | @uri)") | join("&")')

echo "Create the token for $what (pre-filled; GitHub cannot pre-select repositories):"
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
settings=$dir/.claude/settings.local.json
echo "Then paste it into $settings, under \"env\", as \"GH_TOKEN\"."
if [ ! -f "$settings" ]; then
  if [ -f "$dir/.project-init.yml" ]; then
    echo "That file is missing: the upgrade skill creates it, with the rules that keep credentials out of reach."
  else
    echo "That file is missing: create it as {\"env\": {\"GH_TOKEN\": \"<token>\"}}, and keep it out of git."
  fi
fi
echo "Already have \"$token_name\"? Edit it at https://github.com/settings/personal-access-tokens"
echo "and tick the repositories above that it misses."
