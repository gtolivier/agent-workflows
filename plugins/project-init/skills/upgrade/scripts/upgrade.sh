#!/bin/sh
# Bring a repository set up by init-repo, or a workspace set up by
# init-workspace, to this version of project-init. It renders the common
# layer twice — as the version in the register wrote it (base) and as this
# version writes it (theirs) — and merges the difference into each file
# with git merge-file, so that the repository's own changes stay. Before
# rendering this version, it runs the migrations of the versions in
# between on the register. A repository is upgraded on a branch of its
# own, a workspace on its current branch. Commits nothing: settle what the
# report asks with deviation.sh, then run finish.sh.
#
# Usage: upgrade.sh <dir> [--base <plugin-dir>]
#
# --base: the project-init plugin of the version in the register, instead
# of the copy in Claude Code's plugin cache or the release on GitHub.
#
# Per file of the common layer, the report says:
#   updated   this version's file, or the merge of both changes
#   created   a file this version adds
#   deleted   a file this version no longer writes, unchanged here
#   kept      merged; the deviation recorded for it stays
#   adopted   already here as this version writes it: now managed
#   dropped   now the same as this version: its deviation record is gone
# and, to settle with the user:
#   ask       merged, but it differs from this version with no deviation
#             recorded (or its record lapsed)
#   conflict  both changed the same lines: conflict markers written
#   missing   managed, deleted here, and changed by this version
#   nobase    no earlier version to merge from: the file is left as is
#   exists    a file this version adds is already here, different
#   removed   this version no longer writes it, and it was changed here
#   expired   a temporary deviation past its date
set -eu

here=$(cd "$(dirname "$0")" && pwd)
plugin=$(cd "$here/../../.." && pwd)
release_url=https://github.com/gtolivier/agent-workflows/archive/refs/tags

die() {
  echo "upgrade: $*" >&2
  exit 1
}
usage() { die "usage: upgrade.sh <dir> [--base <plugin-dir>]"; }

[ $# -eq 1 ] || [ $# -eq 3 ] || usage
dir=$(cd "$1" 2>/dev/null && pwd) || die "$1: no such folder"
base_plugin=''
if [ $# -eq 3 ]; then
  [ "$2" = --base ] || usage
  base_plugin=$(cd "$3" 2>/dev/null && pwd) || die "--base $3: no such folder"
fi
for tool in git jq uv curl; do
  command -v "$tool" >/dev/null || die "$tool is missing"
done

cd "$dir"
[ -f .project-init.yml ] || die "$dir has no .project-init.yml: set it up with init-repo or init-workspace first"
[ -e .git ] || die "$dir is not the top of a git repository"
read_register() { uv run --quiet --script "$here/register.py" .project-init.yml; }
register=$(read_register)
get() { printf '%s' "$register" | jq -r "$1"; }
kind=$(get .kind)
case $kind in
  repo) skill_name=init-repo ;;
  workspace) skill_name=init-workspace ;;
  *) die "$dir/.project-init.yml: unknown kind '$kind'" ;;
esac
render=$plugin/skills/$skill_name/scripts/render.sh
from=$(get '."project-init"')
to=$(jq -r .version "$plugin/.claude-plugin/plugin.json")
printf '%s' "$from" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' ||
  die "$dir/.project-init.yml: project-init '$from' is not a version"
work=$(cd "$(git rev-parse --git-dir)" && pwd)/project-init-upgrade
[ ! -e "$work" ] || die "an upgrade is in progress in $dir: finish it with finish.sh, or discard it (git reset --hard, git clean -fd, git switch back, delete the upgrade branch, rm -rf $work)"
git rev-parse -q --verify HEAD >/dev/null || die "$dir has no commit yet: run init-repo's commit.sh first"
[ -z "$(git status --porcelain)" ] || die "$dir has uncommitted changes: commit or stash them first"
if [ "$from" = "$to" ]; then
  echo "$dir is up to date (project-init $to)."
  exit 0
fi
# Versions: is $1 older than $2?
older() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n 1)" = "$1" ]; }
older "$from" "$to" || die "$dir was set up by project-init $from, newer than this one ($to): update the plugin"

# On a failure, put the folder back as it was: its tree was clean, so
# nothing of the user's is lost.
start=$(git branch --show-current)
[ -n "$start" ] || start=$(git rev-parse HEAD)
branch=''
rollback() {
  rm -rf "$work"
  git reset --quiet --hard
  git clean --quiet -fd
  if [ -n "$branch" ] && [ "$(git branch --show-current)" = "$branch" ]; then
    git -c advice.detachedHead=false checkout --quiet "$start"
    git branch --quiet -D "$branch"
  fi
  echo "upgrade: failed; $dir is back as it was" >&2
}
mkdir -p "$work"
trap rollback EXIT

# The plugin of the version in the register: next to this one in Claude
# Code's cache, else its release on GitHub.
if [ -z "$base_plugin" ]; then
  for d in "$plugin/../$from" "$HOME/.claude/plugins/cache/agent-workflows/project-init/$from"; do
    if [ -f "$d/.claude-plugin/plugin.json" ] && [ "$(jq -r .version "$d/.claude-plugin/plugin.json")" = "$from" ]; then
      base_plugin=$(cd "$d" && pwd)
      break
    fi
  done
fi
if [ -z "$base_plugin" ]; then
  echo "Downloading project-init $from..."
  mkdir -p "$work/release"
  curl -fsSL "$release_url/project-init-v$from.tar.gz" | tar -xzf - -C "$work/release" ||
    die "could not download project-init $from from $release_url: pass --base"
  base_plugin=$(echo "$work/release"/*/plugins/project-init)
fi
[ -d "$base_plugin/skills/$skill_name" ] || die "$base_plugin has no $skill_name skill"

if [ "$kind" = repo ]; then
  ! git rev-parse -q --verify "refs/heads/project-init/upgrade-$to" >/dev/null ||
    die "branch project-init/upgrade-$to already exists: delete it, or finish the upgrade on it"
  git switch --quiet --create "project-init/upgrade-$to"
  branch=project-init/upgrade-$to
fi
echo "Upgrading $dir from project-init $from to $to:"

# Base: as the version in the register wrote the files, from the register
# as that version left it. A version without a render.sh of its own (0.6.0
# and before) renders with this one's, from its templates.
old_skill=$base_plugin/skills/$skill_name
if [ -f "$old_skill/scripts/render.sh" ]; then
  sh "$old_skill/scripts/render.sh" . "$work/base"
else
  sh "$render" . "$work/base" --skill "$old_skill"
fi

# The migrations of each version after the register's, up to this one.
checks_before=$(get '.host["required-checks"] // []' | jq -c .)
export REGISTER_PY="$here/register.py" REGISTER_EDIT_PY="$here/register-edit.py" PLUGIN_DIR="$plugin"
for m in $(ls "$here/../migrations" | sort -V); do
  v=${m%%-*}
  older "$from" "$v" && ! older "$to" "$v" || continue
  echo "  migrate   ${m%.sh}"
  sh "$here/../migrations/$m" "$dir"
done
register=$(read_register)
checks_after=$(get '.host["required-checks"] // []' | jq -c .)

# Theirs: as this version writes them.
sh "$render" . "$work/theirs"

today=$(date +%Y-%m-%d)
set --
: >"$work/items"
item() {
  printf '%s\t%s\t%s\n' "$path" "$1" "${2-}" >>"$work/items"
  printf '  %-9s %s%s\n' "$1" "$path" "${2:+ — $2}"
}
json() { jq -Rn --arg s "$1" '$s'; }
# The state of a generalize deviation's issue: OPEN, COMPLETED, NOT_PLANNED,
# or empty when gh cannot tell.
issue_state() {
  command -v gh >/dev/null || return 0
  [ -n "$1" ] || return 0
  gh issue view "$1" -R gtolivier/agent-workflows --json state,stateReason \
    --jq 'if .state == "OPEN" then "OPEN" else .stateReason end' 2>/dev/null || :
}

files=$(
  { (cd "$work/base" && find . -type f); (cd "$work/theirs" && find . -type f); } |
    sed 's|^\./||' | sort -u
)
# The loop reads the list on fd 3: git, gh and uv inside keep stdin.
while IFS= read -r path <&3; do
  [ -n "$path" ] || continue
  b=$work/base/$path t=$work/theirs/$path
  dev=$(printf '%s' "$register" | jq -c --arg p "$path" '(.deviations // []) | map(select(.path == $p)) | first // {}')
  status=$(printf '%s' "$dev" | jq -r '.status // empty')
  [ "$status" != abandon ] || continue
  if ! printf '%s' "$register" | jq -e --arg p "$path" '(.managed // []) | index($p)' >/dev/null; then
    # A file this version adds; any other unmanaged file is the repository's.
    if [ -f "$t" ] && [ ! -f "$b" ]; then
      if [ ! -e "$path" ]; then
        mkdir -p "$(dirname "$path")"
        cp "$t" "$path"
        item created
      elif cmp -s "$path" "$t"; then
        item adopted
      else
        item exists "already here, not managed: keep it as the repository's, or take this version's"
        continue
      fi
      set -- "$@" add managed "$(json "$path")"
    fi
    continue
  fi
  if [ ! -f "$t" ]; then
    if [ ! -e "$path" ] || { [ -f "$b" ] && cmp -s "$path" "$b"; }; then
      rm -f "$path"
      set -- "$@" remove managed "$(json "$path")"
      [ -z "$status" ] || set -- "$@" deviation "$path" null
      item deleted "${status:+its $status deviation goes too}"
    else
      item removed "changed here: delete it, or keep it as the repository's own"
    fi
    continue
  fi
  if [ -f "$path" ] && cmp -s "$path" "$t"; then
    if [ -n "$status" ]; then
      set -- "$@" deviation "$path" null
      item dropped "the $status deviation is now project-init's"
    fi
    continue
  fi
  until=$(printf '%s' "$dev" | jq -r '.until // empty')
  lapsed=false
  if [ "$status" = temporary ] && [ -n "$until" ] && expr "$until" \< "$today" >/dev/null; then
    lapsed=true
  fi
  if [ -f "$b" ] && cmp -s "$b" "$t"; then
    [ "$lapsed" = false ] || item expired "temporary until $until: settle it now"
    continue
  fi
  if [ ! -e "$path" ]; then
    item missing "deleted here, changed by project-init $to"
    continue
  fi
  if [ ! -f "$b" ]; then
    item nobase "no project-init $from version to merge from: left as is"
    continue
  fi
  if cmp -s "$path" "$b"; then
    cp "$t" "$path"
    item updated
    continue
  fi
  pinned=false note=''
  case $status in
    local) pinned=true ;;
    temporary)
      if [ "$lapsed" = true ]; then note="temporary until $until: lapsed"; else pinned=true; fi ;;
    generalize)
      issue=$(printf '%s' "$dev" | jq -r '.issue // empty')
      case $(issue_state "$issue") in
        COMPLETED)
          # Brought into project-init: this version holds it.
          cp "$t" "$path"
          set -- "$@" deviation "$path" null
          item updated "issue #$issue completed: this version's file"
          continue ;;
        NOT_PLANNED) note="issue #$issue closed as not planned" ;;
        *) pinned=true ;;
      esac ;;
  esac
  rc=0
  git merge-file -p -L "this repository" -L "project-init $from" -L "project-init $to" \
    "$path" "$b" "$t" >"$work/merged" || rc=$?
  [ "$rc" -lt 128 ] || die "git merge-file failed on $path"
  cat "$work/merged" >"$path"
  if [ "$rc" -gt 0 ]; then
    item conflict "both changed the same lines: edit the markers out"
  elif cmp -s "$path" "$t"; then
    item updated
  elif [ "$pinned" = true ]; then
    item kept "$status deviation"
  else
    item ask "${note:-differs from project-init $to, with no deviation recorded}"
  fi
done 3<<EOF
$files
EOF
[ $# -eq 0 ] || uv run --quiet --script "$REGISTER_EDIT_PY" .project-init.yml "$@"
rm -f "$work/merged"

jq -Rn --arg from "$from" --arg to "$to" --arg kind "$kind" --arg base "$base_plugin" \
  --argjson before "$checks_before" --argjson after "$checks_after" '{
    from: $from, to: $to, kind: $kind, base: $base,
    checks: {before: $before, after: $after},
    items: [inputs | split("\t") | {path: .[0], outcome: .[1], note: .[2]}]
  }' <"$work/items" >"$work/report.json"
rm "$work/items"
trap - EXIT

[ "$checks_before" = "$checks_after" ] ||
  echo "  The required checks change: $checks_before -> $checks_after (finish.sh says what to run)."
pending=$(jq -r '.items[] | select(.outcome | IN("ask", "conflict", "missing", "nobase", "exists", "removed", "expired")) | .path' "$work/report.json")
if [ -n "$pending" ]; then
  echo "To settle with the user, each with deviation.sh (resolve or record), then run finish.sh:"
  printf '%s\n' "$pending" | sed 's/^/  /'
else
  echo "Nothing to settle: run finish.sh."
fi
