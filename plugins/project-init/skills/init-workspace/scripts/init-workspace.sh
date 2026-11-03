#!/bin/sh
# Turn a folder into a workspace: a private git repository of its own that
# tracks an allowlist of files — AGENTS.md, DECISIONS.md, ROADMAP.md, the
# register .project-init.yml — while the repositories it holds keep their
# own history. Works on a new folder or on one that already holds
# repositories; an existing file is kept, never overwritten. Commits
# nothing: fill the TODO(project-init) placeholders, then run commit.sh.
#
# Usage: init-workspace.sh <dir> --host github|other|none
#          [--owner <owner>] [--repo <owner/name>] [--remote <url>]
#          [--roadmap workspace|repos] [--pr-lang <code>]
#          [--roadmap-lang <code>] [--track <path>]...
#
# --owner: the GitHub user or organization of the workspace's repositories
# (default: the gh login). --roadmap: one ROADMAP.md here, or one per
# repository (default). --track: one more file or folder to version here,
# such as _Documents/ or a prototype that is not a repository.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
skill=$(dirname "$here")

usage() {
  sed -n '/^# Usage:/,/^#$/p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}
die() {
  echo "init-workspace: $*" >&2
  exit 1
}
# Write a file only if it does not exist yet.
create() {
  if [ -e "$1" ]; then
    echo "  kept     $1 (already there)"
    cat >/dev/null
  else
    cat >"$1"
    echo "  created  $1"
  fi
}

[ $# -ge 1 ] || usage
dir=$1
shift
host='' owner='' repo='' remote='' roadmap=repos pr_lang=en roadmap_lang=en
tracked=''
while [ $# -gt 0 ]; do
  [ $# -ge 2 ] || usage
  case $1 in
    --host) host=$2 ;;
    --owner) owner=$2 ;;
    --repo) repo=$2 ;;
    --remote) remote=$2 ;;
    --roadmap) roadmap=$2 ;;
    --pr-lang) pr_lang=$2 ;;
    --roadmap-lang) roadmap_lang=$2 ;;
    --track)
      # One path per line: a path may hold spaces.
      path=$(printf '%s' "$2" | sed 's|^\./||; s|^/||')
      case ${path%/} in
        '' | */* | *[][*?\\]* | '#'* | '!'* | ' '* | *' ' | *"
"*) die "--track '$2': a file or folder at the top of the workspace, without '*?[]\\', a leading '#' or '!', or spaces around it" ;;
      esac
      tracked="$tracked$path
" ;;
    *) usage ;;
  esac
  shift 2
done
case $host in github | other | none) ;; *) die "--host github|other|none is required" ;; esac
case $roadmap in workspace | repos) ;; *) die "--roadmap is workspace or repos" ;; esac
for tool in git jq uv; do
  command -v "$tool" >/dev/null || die "$tool is missing"
done

mkdir -p "$dir"
dir=$(cd "$dir" && pwd)
name=$(basename "$dir")
[ ! -f "$dir/.project-init.yml" ] ||
  die "$dir already has a .project-init.yml: it is set up (upgrade is for later versions)"
while IFS= read -r path; do
  [ -n "$path" ] || continue
  [ -e "$dir/$path" ] || die "--track $path: no such file or folder in $dir"
  [ ! -e "$dir/${path%/}/.git" ] || die "--track $path: a repository keeps its own history; it is listed, not tracked"
done <<EOF
$tracked
EOF
# The workspace's .gitignore must be an allowlist: its "/*" ignores
# everything, the repositories included, and "!/<path>" lines let in its own
# files. An existing one without it would let the repositories in.
if [ -f "$dir/.gitignore" ] && ! grep -qx '/\*' "$dir/.gitignore"; then
  die "$dir/.gitignore is not an allowlist (no \"/*\" line): move it aside, or merge it into $skill/assets/gitignore, then run again"
fi

if [ "$host" = github ]; then
  if [ -z "$owner" ]; then
    owner=$(gh api user --jq .login 2>/dev/null) || die "--owner is required (gh is not logged in)"
  fi
  [ -n "$repo" ] || repo=$owner/$name
  printf '%s' "$repo" | grep -Eq '^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$' ||
    die "'$repo' is not a GitHub repository name (owner/name: letters, digits, '.', '_', '-')"
  [ -n "$remote" ] || remote=https://github.com/$repo.git
fi

cd "$dir"
[ -d .git ] || git init --quiet --initial-branch=main
echo "Workspace $dir:"

# The register first, then the files of the common layer it describes:
# render.sh writes them as the upgrade skill renders them again later.
version=$(jq -r .version "$skill/../../.claude-plugin/plugin.json" 2>/dev/null || echo unknown)
tracked_list=$(printf '%s' "$tracked" | jq -R 'select(. != "")' | jq -sc .)
register=$(jq -n --arg version "$version" --arg name "$name" --arg roadmap "$roadmap" \
  --arg prs "$pr_lang" --arg roadmap_lang "$roadmap_lang" --argjson tracked "$tracked_list" \
  --arg host "$host" --arg owner "$owner" --arg repo "$repo" --arg remote "$remote" '{
    "project-init": $version, kind: "workspace", name: $name,
    choices: {roadmap: $roadmap, language: {prs: $prs, roadmap: $roadmap_lang}, tracked: $tracked},
    host: {kind: $host, owner: $owner, repo: $repo, remote: $remote},
    managed: [".gitignore", "AGENTS.md", "DECISIONS.md", ".project-init.yml"], deviations: []
  }')
uv run --quiet --script "$here/register-edit.py" .project-init.yml load "$register"
echo "  created  .project-init.yml"
rendered=$(mktemp -d)
trap 'rm -rf "$rendered"' EXIT
sh "$here/render.sh" . "$rendered"
for f in .gitignore AGENTS.md DECISIONS.md; do
  create "$f" <"$rendered/$f"
done
[ "$roadmap" != workspace ] || printf '# Roadmap\n' | create ROADMAP.md

# This machine's Claude Code settings for the workspace: commands that would
# read or change credentials are denied; on GitHub, git authenticates with
# gh, so that a GH_TOKEN the user adds under "env" also serves git.
mkdir -p .claude
if [ "$host" = github ]; then
  create .claude/settings.local.json <"$skill/assets/settings.local.json"
else
  jq 'del(.env)' "$skill/assets/settings.local.json" | create .claude/settings.local.json
fi
# The user adds a token to it: readable by them only.
chmod 600 .claude/settings.local.json

if [ -n "$remote" ] && ! git remote get-url origin >/dev/null 2>&1; then
  git remote add origin "$remote"
fi

sh "$here/repos.sh" "$dir"

echo
echo "Placeholders to fill before commit.sh:"
left=$(grep -n 'TODO(project-init)' AGENTS.md DECISIONS.md 2>/dev/null || true)
if [ -n "$left" ]; then printf '%s\n' "$left" | sed 's/^/  /'; else echo "  none"; fi
