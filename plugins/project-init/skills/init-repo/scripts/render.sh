#!/bin/sh
# Write the files of the common layer that a repository's register
# describes — AGENTS.md, the CI, CodeRabbit's settings and the files the
# stack renders from its templates — into a folder, as this version of
# init-repo writes them. init-repo.sh writes them into the new repository;
# the upgrade skill renders them for the version that set a repository up
# and for this one, and merges the difference. Then the stack's formatter
# formats them, as it did the repository's at init. Offline: it reads only
# the register, the repository's AGENTS.md (angular: Angular's best
# practices) and the templates, and runs the repository's own formatter.
#
# Usage: render.sh <repo-dir> <out-dir> [--skill <dir>]
#
# --skill: the init-repo skill of an earlier version that has no render.sh
# of its own (0.6.0 and before): its templates and stack.sh, with this
# version's code for the files it did not render through a function.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
skill=$(dirname "$here")
. "$here/lib.sh"

die() {
  echo "render: $*" >&2
  exit 1
}

[ $# -eq 2 ] || [ $# -eq 4 ] || die "usage: $0 <repo-dir> <out-dir> [--skill <dir>]"
REPO_DIR=$(cd "$1" && pwd) dest=$2 old=''
if [ $# -eq 4 ]; then
  [ "$3" = --skill ] || die "usage: $0 <repo-dir> <out-dir> [--skill <dir>]"
  old=$(cd "$4" && pwd)
fi
[ -f "$REPO_DIR/.project-init.yml" ] || die "$REPO_DIR has no .project-init.yml"
register=$(uv run --quiet --script "$here/register.py" "$REPO_DIR/.project-init.yml")
get() { printf '%s' "$register" | jq -r "$1"; }
[ "$(get .kind)" = repo ] || die "$REPO_DIR is not a repository set up by init-repo"

stack=$(get .stack)
# The name init used: before 0.7.0 the register had none, and the folder
# may have been renamed since — a GitHub repository keeps it.
NAME=$(get '.name // ((.host.repo // "") | split("/") | last) // empty')
[ -n "$NAME" ] || NAME=$(basename "$REPO_DIR")
DESCRIPTION=$(get .description) RUNTIME=$(get .choices.runtime)
LICENSE=$(get .choices.license) REMOTE=$(get '.host.remote // ""')
host=$(get .host.kind) coderabbit=$(get .choices.coderabbit) tdd=$(get .choices.tdd)
pr_lang=$(get '.choices.language.prs // "en"') roadmap_lang=$(get '.choices.language.roadmap // "en"')

STACK_DIR=$skill/stacks/$stack
[ -f "$STACK_DIR/stack.sh" ] || die "unknown stack '$stack'"
. "$STACK_DIR/stack.sh"
templates=$skill
if [ -n "$old" ]; then
  # The earlier stack.sh replaces the variables and the functions it
  # defines; this version's stack_render and stack_repo_env stay.
  STACK_DIR=$old/stacks/$stack
  [ -f "$STACK_DIR/stack.sh" ] || die "$old has no stack '$stack'"
  unset SHARED_DIR NODE_DIR HUGO_DIR
  . "$STACK_DIR/stack.sh"
  templates=$old
fi
export NAME DESCRIPTION RUNTIME LICENSE STACK_DIR REMOTE REPO_DIR
! command -v stack_repo_env >/dev/null 2>&1 || stack_repo_env
stack_render_env

# Rendered into a folder of its own, formatted there, then copied: the
# out-dir may be the repository itself, as for init-repo.sh.
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
STACK_SECTIONS=$(render "$(template agents.md)")
STACK_RULES=$(render "$(template rules.md)")
LANGUAGE_RULE="code, comments, documentation, commit messages and issues in English; pull requests and their comments in $(lang_name "$pr_lang"); the roadmap in $(lang_name "$roadmap_lang")."
export STACK_SECTIONS STACK_RULES LANGUAGE_RULE
render "$templates/assets/AGENTS.md" >"$out/AGENTS.md.new"
# With test-driven development on, the Test-first rule opens the Rules.
if [ "$tdd" = true ]; then
  awk -v rule="$templates/assets/test-first.md" '
    { print }
    /^## Rules$/ { found = 1; next }
    found && /^$/ {
      while ((getline line <rule) > 0) print line
      found = 0
    }
  ' "$out/AGENTS.md.new" >"$out/AGENTS.md"
  rm "$out/AGENTS.md.new"
else
  mv "$out/AGENTS.md.new" "$out/AGENTS.md"
fi

if [ "$host" = github ]; then
  render_file "$(template ci.yml)" "$out/.github/workflows/ci.yml"
  [ "$coderabbit" != true ] || copy_file "$templates/assets/coderabbit.yaml" "$out/.coderabbit.yaml"
fi
! command -v stack_render >/dev/null 2>&1 || stack_render "$out"
! command -v stack_format >/dev/null 2>&1 || stack_format "$out"
mkdir -p "$dest"
cp -R "$out"/. "$dest"/
