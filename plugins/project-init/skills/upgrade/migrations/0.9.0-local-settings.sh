#!/bin/sh
# project-init 0.9.0: a repository's .gitignore ignores
# .claude/settings.local.json, and a repository on its own — not in a
# workspace, whose settings serve its sessions — gets that file as
# init-repo writes it: the commands that read or change credentials
# denied and, on GitHub, git authenticating with gh. An existing file is
# kept.
#
# A migration runs from upgrade.sh on the register of a version before its
# own, in the folder being upgraded; it must change nothing when run twice.
# REGISTER_PY reads the register as JSON; PLUGIN_DIR is this version's
# project-init plugin.
#
# Usage: 0.9.0-local-settings.sh <dir>
set -eu

cd "$1"
register=$(uv run --quiet --script "$REGISTER_PY" .project-init.yml)
get() { printf '%s' "$register" | jq -r "$1"; }
[ "$(get .kind)" = repo ] || exit 0

grep -qxF .claude/settings.local.json .gitignore 2>/dev/null ||
  printf '\n# Claude Code, this machine only: may hold a token\n.claude/settings.local.json\n' >>.gitignore

parent=$(dirname "$PWD")
if [ -f "$parent/.project-init.yml" ] &&
  [ "$(uv run --quiet --script "$REGISTER_PY" "$parent/.project-init.yml" | jq -r .kind)" = workspace ]; then
  exit 0
fi
[ ! -e .claude/settings.local.json ] || exit 0
asset=$PLUGIN_DIR/skills/init-repo/assets/settings.local.json
mkdir -p .claude
if [ "$(get .host.kind)" = github ]; then
  cp "$asset" .claude/settings.local.json
else
  jq 'del(.env)' "$asset" >.claude/settings.local.json
fi
# The user adds a token to it: readable by them only.
chmod 600 .claude/settings.local.json
echo "            created .claude/settings.local.json (never committed)"
