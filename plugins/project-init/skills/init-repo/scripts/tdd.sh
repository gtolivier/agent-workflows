#!/bin/sh
# Turn test-driven development on or off in a repository set up by
# init-repo: "on" adds the Test-first rule at the top of AGENTS.md's Rules,
# which makes the /tdd:feature skill required for every behavior; "off"
# removes it, and /tdd:feature stays available on request. Records the
# choice as choices.tdd in .project-init.yml. Commits nothing: the change
# goes through a pull request like any other. Safe to run again.
#
# Usage: tdd.sh on|off <dir>
set -eu

here=$(cd "$(dirname "$0")" && pwd)
rule=$(dirname "$here")/assets/test-first.md

die() {
  echo "tdd: $*" >&2
  exit 1
}

[ $# -eq 2 ] || { echo "usage: $0 on|off <dir>" >&2; exit 2; }
case $1 in
  on) value=true ;;
  off) value=false ;;
  *) echo "usage: $0 on|off <dir>" >&2; exit 2 ;;
esac
dir=$2
[ -f "$dir/.project-init.yml" ] || die "$dir has no .project-init.yml: set it up with init-repo first"
[ "$(uv run --quiet --script "$here/register.py" "$dir/.project-init.yml" | jq -r .kind)" = repo ] ||
  die "$dir is not a repository set up by init-repo"
grep -Eq '^  tdd: (true|false)$' "$dir/.project-init.yml" ||
  die "$dir/.project-init.yml has no choices.tdd line"
grep -qx '## Rules' "$dir/AGENTS.md" || die "$dir/AGENTS.md has no '## Rules' section"

# AGENTS.md without the rule: from its first line to the next item,
# blank line or heading.
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
awk '
  /^- \*\*Test-first:\*\*/ { skip = 1; next }
  skip && /^  / { next }
  { skip = 0; print }
' "$dir/AGENTS.md" >"$tmp"

# On: the rule as the first item of Rules.
if [ "$value" = true ]; then
  awk -v rule="$rule" '
    { print }
    /^## Rules$/ { found = 1; next }
    found && /^$/ {
      while ((getline line <rule) > 0) print line
      found = 0
    }
  ' "$tmp" >"$tmp.on"
  mv "$tmp.on" "$tmp"
fi
cat "$tmp" >"$dir/AGENTS.md"

sed "s/^  tdd: .*/  tdd: $value/" "$dir/.project-init.yml" >"$tmp"
cat "$tmp" >"$dir/.project-init.yml"

echo "Test-driven development is $1 in $dir: commit AGENTS.md and .project-init.yml through a pull request."
