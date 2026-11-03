#!/bin/sh
# Create a new repository for a stack: the stack's official generator and
# tools, then the common layer — .gitignore, LICENSE, README.md and
# AGENTS.md skeletons, CI and CodeRabbit on GitHub, and the register
# .project-init.yml. Commits nothing: fill the TODO(project-init)
# placeholders, then run commit.sh.
#
# Usage: init-repo.sh <stack> <dir> --description <text>
#          --license <spdx-id|none> --host github|other|none --tdd on|off
#          [--visibility public|private] [--owner <owner>] [--remote <url>]
#          [--runtime <version>] [--pr-lang <code>] [--roadmap-lang <code>]
#          [--no-coderabbit]
#
# In a workspace (the folder above holds a workspace register), the owner,
# the roadmap's place and, unless the repository is public, the languages
# default to the workspace's.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
skill=$(dirname "$here")

usage() {
  sed -n '/^# Usage:/,/^#$/p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}
die() {
  echo "init-repo: $*" >&2
  exit 1
}

. "$here/lib.sh"

[ $# -ge 2 ] || usage
stack=$1 dir=$2
shift 2
license='' host='' visibility='' owner='' remote='' description=''
runtime='' pr_lang='' roadmap_lang='' coderabbit=true tdd=''
while [ $# -gt 0 ]; do
  case $1 in
    --license) license=${2-} ;;
    --host) host=${2-} ;;
    --visibility) visibility=${2-} ;;
    --owner) owner=${2-} ;;
    --remote) remote=${2-} ;;
    --description) description=${2-} ;;
    --runtime) runtime=${2-} ;;
    --pr-lang) pr_lang=${2-} ;;
    --roadmap-lang) roadmap_lang=${2-} ;;
    --tdd) tdd=${2-} ;;
    --no-coderabbit) coderabbit=false; shift; continue ;;
    *) usage ;;
  esac
  [ $# -ge 2 ] || usage
  shift 2
done

# A stack is a folder of stacks/; those starting with "_" hold code the
# stacks share.
stack_dir=$skill/stacks/$stack
case $stack in _* | */*) stack_dir='' ;; esac
[ -n "$stack_dir" ] && [ -f "$stack_dir/stack.sh" ] ||
  die "unknown stack '$stack' (known: $(ls "$skill/stacks" | grep -v '^_' | tr '\n' ' '))"
STACK_DIR=$stack_dir
. "$stack_dir/stack.sh"

name=$(basename -- "$dir")
printf '%s' "$name" | grep -Eq '^[A-Za-z0-9._][A-Za-z0-9._-]*$' ||
  die "'$name': a repository name takes only letters, digits, '.', '_' and '-', not '-' first"
stack_valid_name "$name" || die "'$name' is not a valid $stack project name: $STACK_NAME_RULE"
[ -n "$description" ] || die "--description is required: one line, for the README, the package and GitHub"
case $description in
  *[\"\\]* | *"
"*) die "--description: one line, without '\"' or '\\'" ;;
esac
[ -n "$license" ] || die "--license is required: ask the user (an SPDX id such as MIT, or none)"
[ "$license" = none ] || printf '%s' "$license" | grep -Eq '^[A-Za-z0-9.+-]+$' ||
  die "--license '$license': an SPDX id such as MIT, or none"
case $tdd in
  on | off) ;;
  *) die "--tdd on|off is required: ask the user whether every behavior goes test-first now" ;;
esac
case $host in
  github | other) [ "$visibility" = public ] || [ "$visibility" = private ] ||
    die "--visibility public|private is required with --host $host" ;;
  none) visibility=none ;;
  *) die "--host github|other|none is required" ;;
esac
if [ -z "$runtime" ]; then
  # A stack may compute its default, such as the latest release, instead
  # of setting RUNTIME_DEFAULT.
  if command -v stack_runtime_default >/dev/null 2>&1; then
    runtime=$(stack_runtime_default) || die "could not compute the $stack stack's default runtime: pass --runtime"
  else
    runtime=$RUNTIME_DEFAULT
  fi
fi
# RUNTIME_MIN, if the stack sets one: the oldest runtime it supports.
if [ -n "${RUNTIME_MIN-}" ] &&
  [ "$(printf '%s\n%s\n' "$RUNTIME_MIN" "$runtime" | sort -V | head -n 1)" != "$RUNTIME_MIN" ]; then
  die "--runtime $runtime: the $stack stack needs $RUNTIME_MIN or later"
fi
[ "$host" = github ] || coderabbit=false
[ "$visibility" = public ] || coderabbit=false
for tool in git jq curl uv; do
  command -v "$tool" >/dev/null || die "$tool is missing"
done

if [ -e "$dir" ] && [ -n "$(ls -A "$dir")" ]; then
  die "$dir is not empty: init-repo starts a new repository"
fi

# The workspace above, if any: its choices are the defaults.
parent=$(cd "$(dirname "$dir")" 2>/dev/null && pwd) || parent=''
roadmap_place=repos
if [ -n "$parent" ] && [ -f "$parent/.project-init.yml" ]; then
  ws=$(uv run --quiet --script "$here/register.py" "$parent/.project-init.yml")
  if [ "$(printf '%s' "$ws" | jq -r .kind)" = workspace ]; then
    [ -n "$owner" ] || owner=$(printf '%s' "$ws" | jq -r '.host.owner // empty')
    # A public repository speaks English unless asked otherwise.
    if [ "$visibility" != public ]; then
      [ -n "$pr_lang" ] || pr_lang=$(printf '%s' "$ws" | jq -r '.choices.language.prs // empty')
      [ -n "$roadmap_lang" ] || roadmap_lang=$(printf '%s' "$ws" | jq -r '.choices.language.roadmap // empty')
    fi
    roadmap_place=$(printf '%s' "$ws" | jq -r '.choices.roadmap // "repos"')
  fi
fi
[ -n "$pr_lang" ] || pr_lang=en
[ -n "$roadmap_lang" ] || roadmap_lang=en

# The license text, from GitHub's public API (no login needed). GitHub
# names the GPL family by ids SPDX has deprecated (GPL-3.0): the SPDX id
# says -only or -or-later, and the build tools require it.
if [ "$license" != none ]; then
  suffix=''
  case $license in
    *-only) suffix=-only ;;
    *-or-later) suffix=-or-later ;;
  esac
  key=$(printf '%s' "${license%"$suffix"}" | tr '[:upper:]' '[:lower:]')
  license_json=$(curl -fsSL "https://api.github.com/licenses/$key") ||
    die "unknown license '$license' (see https://api.github.com/licenses)"
  license=$(printf '%s' "$license_json" | jq -r .spdx_id)
  case $license in
    *GPL-* | GFDL-*)
      [ -n "$suffix" ] ||
        die "--license $license: ask the user whether it is $license-only or $license-or-later" ;;
    *) [ -z "$suffix" ] || die "--license: $license takes no $suffix" ;;
  esac
  license=$license$suffix
  holder=$(git config user.name) || die "git config user.name is not set: the license needs a copyright holder"
fi

if [ "$host" = github ]; then
  if [ -z "$owner" ]; then
    owner=$(gh api user --jq .login 2>/dev/null) || die "--owner is required (gh is not logged in)"
  fi
  github_repo=$owner/$name
  [ -n "$remote" ] || remote=https://github.com/$github_repo.git
else
  github_repo=''
fi

# Every check passed: create the folder only now. If a later step fails,
# remove what this script made, so that it can run again.
existed=false
[ ! -e "$dir" ] || existed=true
mkdir -p "$dir"
dir=$(cd "$dir" && pwd)
cleanup() {
  [ "$1" -ne 0 ] || return 0
  cd /
  if [ "$existed" = true ]; then
    find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  else
    rm -rf "$dir"
  fi
  echo "init-repo: failed; $dir is back as it was" >&2
}
trap 'cleanup $?' EXIT

export NAME="$name" DESCRIPTION="$description" RUNTIME="$runtime" \
  LICENSE="$license" STACK_DIR="$stack_dir" REMOTE="$remote"
stack_render_env

cd "$dir"
git init --quiet --initial-branch=main
echo "Generating the $stack project ($STACK_SUMMARY)..."
stack_generate

managed='.project-init.yml AGENTS.md .gitignore'

# .gitignore: the generator's, else GitHub's template for the stack.
if [ ! -f .gitignore ]; then
  template=$(curl -fsSL "https://api.github.com/gitignore/templates/$GITIGNORE_TEMPLATE") ||
    die "could not download GitHub's $GITIGNORE_TEMPLATE .gitignore template"
  printf '%s' "$template" | jq -er .source >.gitignore
fi
grep -qxF .DS_Store .gitignore || printf '\n# macOS\n.DS_Store\n' >>.gitignore

if [ "$license" != none ]; then
  printf '%s' "$license_json" | jq -r .body |
    YEAR=$(date +%Y) HOLDER=$holder awk '
      # Literal replacement: gsub would expand a "&" in the name.
      function replace(s, from, to,   i, out) {
        out = ""
        while ((i = index(s, from)) > 0) {
          out = out substr(s, 1, i - 1) to
          s = substr(s, i + length(from))
        }
        return out s
      }
      { print replace(replace($0, "[year]", ENVIRON["YEAR"]), "[fullname]", ENVIRON["HOLDER"]) }
    ' >LICENSE
  managed="$managed LICENSE"
fi

# README.md: a skeleton, unless the generator wrote a non-empty one.
[ -s README.md ] || render "$skill/assets/README.md" >README.md

if [ "$roadmap_place" = repos ] && [ ! -f ROADMAP.md ]; then
  printf '# Roadmap\n' >ROADMAP.md
fi

[ -z "$remote" ] || git remote add origin "$remote"

# The register, then the files of the common layer it describes: AGENTS.md
# (with the Test-first rule when TDD is on), the CI and CodeRabbit's
# settings on GitHub, and the files the stack renders. render.sh writes
# them as the upgrade skill renders them again later.
checks='[]'
if [ "$host" = github ]; then
  managed="$managed .github/workflows/ci.yml"
  [ "$coderabbit" != true ] || managed="$managed .coderabbit.yaml"
  checks=$({ stack_checks; echo gitleaks; } | jq -R . | jq -sc .)
fi
# shellcheck disable=SC2086 # word splitting wanted: one path per word
managed=$(printf '%s\n' $managed $(stack_managed) | jq -R . | jq -sc .)
version=$(jq -r .version "$skill/../../.claude-plugin/plugin.json" 2>/dev/null || echo unknown)
register=$(jq -n --arg version "$version" --arg name "$name" --arg stack "$stack" \
  --arg description "$description" --arg visibility "$visibility" --arg license "$license" \
  --arg runtime "$runtime" --arg prs "$pr_lang" --arg roadmap_lang "$roadmap_lang" \
  --arg roadmap "$roadmap_place" --argjson coderabbit "$coderabbit" --arg tdd "$tdd" \
  --arg host "$host" --arg repo "$github_repo" --arg remote "$remote" \
  --argjson checks "$checks" --argjson managed "$managed" '{
    "project-init": $version, kind: "repo", name: $name, stack: $stack,
    description: $description,
    choices: {visibility: $visibility, license: $license, runtime: $runtime,
      language: {prs: $prs, roadmap: $roadmap_lang}, roadmap: $roadmap,
      coderabbit: $coderabbit, tdd: ($tdd == "on")},
    host: {kind: $host, repo: $repo, remote: $remote, "required-checks": $checks,
      "squash-body": "commit-messages"},
    managed: $managed, deviations: []
  }')
uv run --quiet --script "$here/register-edit.py" .project-init.yml load "$register"
sh "$here/render.sh" . .

echo
echo "Created $dir ($stack, host $host, license $license, TDD $tdd)."
echo "Placeholders to fill before commit.sh:"
grep -rn --exclude-dir=.git --exclude-dir=.venv --exclude-dir=node_modules 'TODO(project-init)' . | sed 's/^\.\//  /' || true
