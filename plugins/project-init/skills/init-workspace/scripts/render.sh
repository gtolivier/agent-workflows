#!/bin/sh
# Write the files of the common layer that a workspace's register describes
# — AGENTS.md, DECISIONS.md, the allowlist .gitignore — into a folder, as
# this version of init-workspace writes them. init-workspace.sh writes them
# into the new workspace; the upgrade skill renders them for the version
# that set a workspace up and for this one, and merges the difference. The
# list of repositories in AGENTS.md is the workspace's own: repos.sh writes
# it. Offline: it reads only the register, the workspace's AGENTS.md and
# the templates.
#
# Usage: render.sh <workspace-dir> <out-dir> [--skill <dir>]
#
# --skill: the init-workspace skill of an earlier version that has no
# render.sh of its own (0.6.0 and before): its templates, with this
# version's code.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
skill=$(dirname "$here")

die() {
  echo "render: $*" >&2
  exit 1
}
# Replace each @VAR@ of a template with the environment variable VAR.
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
lang_name() {
  case $1 in
    en) echo English ;; fr) echo French ;; de) echo German ;;
    es) echo Spanish ;; it) echo Italian ;; *) echo "$1" ;;
  esac
}

[ $# -eq 2 ] || [ $# -eq 4 ] || die "usage: $0 <workspace-dir> <out-dir> [--skill <dir>]"
dir=$(cd "$1" && pwd) out=$2 templates=$skill
if [ $# -eq 4 ]; then
  [ "$3" = --skill ] || die "usage: $0 <workspace-dir> <out-dir> [--skill <dir>]"
  templates=$(cd "$4" && pwd)
fi
[ -f "$dir/.project-init.yml" ] || die "$dir has no .project-init.yml"
register=$(uv run --quiet --script "$here/register.py" "$dir/.project-init.yml")
get() { printf '%s' "$register" | jq -r "$1"; }
[ "$(get .kind)" = workspace ] || die "$dir is not a workspace set up by init-workspace"

mkdir -p "$out"
{
  cat "$templates/assets/gitignore"
  tracked=$(get '.choices.tracked // [] | .[]')
  if [ -n "$tracked" ]; then
    echo "# Also tracked here (--track):"
    printf '%s\n' "$tracked" | while IFS= read -r path; do echo "!/$path"; done
  fi
  echo "# Never: macOS folder metadata, in the tracked folders too."
  echo ".DS_Store"
} >"$out/.gitignore"

if [ "$(get '.choices.roadmap // "repos"')" = workspace ]; then
  ROADMAP_TEXT="The roadmap of every repository is [\`ROADMAP.md\`](ROADMAP.md), in this
folder: the next step comes from there."
else
  ROADMAP_TEXT="Each repository keeps its own roadmap, in its \`ROADMAP.md\`: the next
step of a repository comes from there."
fi
# The name init used: before 0.7.0 the register had none, and the folder
# may have been renamed since — a GitHub repository keeps it.
NAME=$(get '.name // ((.host.repo // "") | split("/") | last) // empty')
[ -n "$NAME" ] || NAME=$(basename "$dir")
PR_LANG=$(lang_name "$(get '.choices.language.prs // "en"')")
ROADMAP_LANG=$(lang_name "$(get '.choices.language.roadmap // "en"')")
export NAME ROADMAP_TEXT PR_LANG ROADMAP_LANG
# Two parts of AGENTS.md are the workspace's: its description — the lines
# between the title and "Instructions for coding agents", the
# TODO(project-init) of a new workspace — and the list of repositories,
# between its markers.
list=$(mktemp) about=$(mktemp)
trap 'rm -f "$list" "$about"' EXIT
if [ -f "$dir/AGENTS.md" ]; then
  awk '
    /^<!-- \/project-init:repositories -->/ { p = 0 }
    p
    /^<!-- project-init:repositories/ { p = 1 }
  ' "$dir/AGENTS.md" >"$list"
  ! grep -q '^Instructions for coding agents' "$templates/assets/AGENTS.md" || awk '
    /^Instructions for coding agents/ { found = 1; exit }
    NR > 1 { text = text $0 "\n" }
    END { if (found) printf "%s", text }
  ' "$dir/AGENTS.md" >"$about"
fi
render "$templates/assets/AGENTS.md" | awk -v list="$list" -v about="$about" '
  BEGIN { while ((getline line < about) > 0) { kept = kept line "\n"; has = 1 } }
  NR == 1 { print; skip = has; next }
  skip && /^Instructions for coding agents/ { printf "%s", kept; skip = 0 }
  skip { next }
  { print }
  /^<!-- project-init:repositories/ { while ((getline line < list) > 0) print line }
' >"$out/AGENTS.md"
cp "$templates/assets/DECISIONS.md" "$out/DECISIONS.md"
