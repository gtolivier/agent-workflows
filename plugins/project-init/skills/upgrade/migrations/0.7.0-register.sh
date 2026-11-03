#!/bin/sh
# project-init 0.7.0: the register names the repository or workspace, a
# repository on GitHub requires the gitleaks check, and a hugo site that
# imports its theme registers it, with the files the import added.
#
# A migration runs from upgrade.sh on the register of a version before its
# own, in the folder being upgraded; it must change nothing when run twice.
# REGISTER_PY reads the register as JSON, REGISTER_EDIT_PY changes it.
#
# Usage: 0.7.0-register.sh <dir>
set -eu

cd "$1"
register=$(uv run --quiet --script "$REGISTER_PY" .project-init.yml)
get() { printf '%s' "$register" | jq -r "$1"; }
set --
# The name: a GitHub repository's, else the folder's.
name=$(get '(.host.repo // "") | split("/") | last // empty')
[ -n "$(get '.name // empty')" ] || set -- set name "$(jq -Rn --arg n "${name:-$(basename "$PWD")}" '$n')"
if [ "$(get .kind)" = repo ] && [ "$(get '.host.kind // empty')" = github ]; then
  set -- "$@" add host.required-checks '"gitleaks"'
fi
if [ "$(get .stack)" = hugo ]; then
  # The imported theme: hugo.toml's [[module.imports]] path, and the
  # working copy that config/development/hugo.toml puts in its place.
  module=$(awk '
    /^ *\[\[module\.imports\]\]/ { m = 1; next }
    m && /^ *path *=/ { sub(/^ *path *= *["\047]/, ""); sub(/["\047] *$/, ""); print; exit }
  ' hugo.toml 2>/dev/null || :)
  if [ -n "$module" ] && [ -z "$(get '.choices.theme // empty')" ]; then
    local_copy=$(sed -n "s|^ *replacements *= *[\"']$module -> \(.*\)[\"'] *\$|\1|p" config/development/hugo.toml 2>/dev/null || :)
    # Hugo resolves the replacement from themes/: one "../" more than the site.
    case $local_copy in ../*) local_copy=${local_copy#../} ;; esac
    theme=$(jq -nc --arg module "$module" --arg local "$local_copy" \
      '{module: $module} + (if $local == "" then {} else {local: $local} end)')
    set -- "$@" set choices.theme "$theme"
  fi
  for f in go.sum config/development/hugo.toml; do
    [ ! -f "$f" ] || set -- "$@" add managed "\"$f\""
  done
fi
[ $# -eq 0 ] || uv run --quiet --script "$REGISTER_EDIT_PY" .project-init.yml "$@"
