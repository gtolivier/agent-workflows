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
render() {
  awk '{
    out = ""; s = $0
    while (match(s, /@[A-Z_]+@/)) {
      out = out substr(s, 1, RSTART - 1) ENVIRON[substr(s, RSTART + 1, RLENGTH - 2)]
      s = substr(s, RSTART + RLENGTH)
    }
    print out s
  }' "$1"
}
q() { jq -Rn --arg s "$1" '$s'; }
lang_name() {
  case $1 in
    en) echo English ;; fr) echo French ;; de) echo German ;;
    es) echo Spanish ;; it) echo Italian ;; *) echo "$1" ;;
  esac
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
    --track) tracked="$tracked $(printf '%s' "$2" | sed 's|^\./||; s|^/||')" ;;
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
for path in $tracked; do
  [ -e "$dir/$path" ] || die "--track $path: no such file or folder in $dir"
  [ ! -e "$dir/${path%/}/.git" ] || die "--track $path: a repository keeps its own history; it is listed, not tracked"
done

if [ "$host" = github ]; then
  if [ -z "$owner" ]; then
    owner=$(gh api user --jq .login 2>/dev/null) || die "--owner is required (gh is not logged in)"
  fi
  [ -n "$repo" ] || repo=$owner/$name
  [ -n "$remote" ] || remote=https://github.com/$repo.git
fi

cd "$dir"
[ -d .git ] || git init --quiet --initial-branch=main
echo "Workspace $dir:"

{
  cat "$skill/assets/gitignore"
  if [ -n "$tracked" ]; then
    echo "# Also tracked here (--track):"
    for path in $tracked; do echo "!/$path"; done
  fi
  echo "# Never: macOS folder metadata, in the tracked folders too."
  echo ".DS_Store"
} | create .gitignore

if [ "$roadmap" = workspace ]; then
  ROADMAP_TEXT="The roadmap of every repository is [\`ROADMAP.md\`](ROADMAP.md), in this
folder: the next step comes from there."
  printf '# Roadmap\n' | create ROADMAP.md
else
  ROADMAP_TEXT="Each repository keeps its own roadmap, in its \`ROADMAP.md\`: the next
step of a repository comes from there."
fi
PR_LANG=$(lang_name "$pr_lang") ROADMAP_LANG=$(lang_name "$roadmap_lang")
export NAME="$name" ROADMAP_TEXT PR_LANG ROADMAP_LANG
render "$skill/assets/AGENTS.md" | create AGENTS.md
create DECISIONS.md <"$skill/assets/DECISIONS.md"

# This machine's Claude Code settings for the workspace: commands that would
# read or change credentials are denied; on GitHub, git authenticates with
# gh, so that a GH_TOKEN the user adds under "env" also serves git.
mkdir -p .claude
if [ "$host" = github ]; then
  create .claude/settings.local.json <"$skill/assets/settings.local.json"
else
  jq 'del(.env)' "$skill/assets/settings.local.json" | create .claude/settings.local.json
fi

if [ -n "$remote" ] && ! git remote get-url origin >/dev/null 2>&1; then
  git remote add origin "$remote"
fi

version=$(jq -r .version "$skill/../../.claude-plugin/plugin.json" 2>/dev/null || echo unknown)
# shellcheck disable=SC2086 # word splitting wanted: one path per word
tracked_list=$(printf '%s\n' $tracked | jq -R 'select(. != "")' | jq -sc .)
{
  echo "# project-init register: the version that set this workspace up and the"
  echo "# choices made. Read by project-init's scripts; record deviations from the"
  echo "# common layer under \"deviations\"."
  echo "project-init: $(q "$version")"
  echo "kind: workspace"
  echo "choices:"
  echo "  roadmap: $roadmap"
  echo "  language: {prs: $pr_lang, roadmap: $roadmap_lang}"
  echo "  tracked: $tracked_list"
  echo "host:"
  echo "  kind: $host"
  echo "  owner: $(q "$owner")"
  echo "  repo: $(q "$repo")"
  echo "  remote: $(q "$remote")"
  echo 'managed: [".gitignore", "AGENTS.md", "DECISIONS.md", ".project-init.yml"]'
  echo "deviations: []"
} | create .project-init.yml

sh "$here/repos.sh" "$dir"

echo
echo "Placeholders to fill before commit.sh:"
grep -n 'TODO(project-init)' AGENTS.md DECISIONS.md 2>/dev/null | sed 's/^/  /' || echo "  none"
