#!/bin/sh
# Make a hugo site, set up by init-repo and not yet committed, take its
# theme from a Hugo module: remove the starter's layouts, CSS, JS and
# static files, import the module, and fetch it with hugo mod get. With
# --local, development (npm start) uses the theme's working copy instead;
# the build, the tests and the CI take the published module.
#
# Usage: theme.sh <dir> <module> [--local <path>]
#   <module>  the theme's module path, such as github.com/owner/name: it
#             must be published (pushed, and public)
#   --local   the theme's working copy, relative to <dir> (../name in a
#             workspace) or absolute
set -eu

die() {
  echo "theme: $*" >&2
  exit 1
}

[ $# -ge 2 ] || die "usage: $0 <dir> <module> [--local <path>]"
dir=$1 module=$2 local=''
shift 2
case ${1-} in
  --local) local=${2-}; [ -n "$local" ] || die "--local needs a path" ;;
  '') ;;
  *) die "usage: theme.sh <dir> <module> [--local <path>]" ;;
esac
printf '%s' "$module" | grep -Eq '^[A-Za-z0-9._~/-]+$' ||
  die "'$module': a module path such as github.com/owner/name"

cd "$dir"
grep -q '^stack: "hugo"$' .project-init.yml 2>/dev/null || die "$dir is not a hugo site set up by init-repo"
! grep -q '^ *\[\[module\.imports\]\]' hugo.toml || die "hugo.toml already imports a module"

if [ -n "$local" ]; then
  [ -f "$local/hugo.toml" ] || [ -f "$local/go.mod" ] || die "$local: no Hugo module there"
  [ ! -e config/development ] || die "config/development already exists"
  # Hugo resolves a relative replacement from themesDir (themes/), one
  # level below the site.
  case $local in
    /*) replacement=$local ;;
    *) replacement=../$local ;;
  esac
fi

# Import and fetch the module first; put the site back if that fails.
backup=$(mktemp -d)
cp hugo.toml go.mod "$backup/"
restore() {
  cp "$backup/hugo.toml" "$backup/go.mod" .
  rm -rf go.sum config/development "$backup"
  rmdir config 2>/dev/null || :
  die "could not fetch $module: is it published (pushed, and public)? The site is unchanged."
}
printf "  [[module.imports]]\n    path = '%s'\n" "$module" >>hugo.toml
if [ -n "$local" ]; then
  mkdir -p config/development
  {
    echo "# In development (npm start), the theme's working copy instead of the"
    echo "# published module. Hugo resolves the path from themesDir (themes/)."
    echo "[module]"
    printf "  replacements = '%s -> %s'\n" "$module" "$replacement"
  } >config/development/hugo.toml
fi
# The production environment ignores the replacement: go.mod and go.sum
# pin the published module. hugo mod get hands its flags to go get, hence
# HUGO_ENVIRONMENT rather than --environment.
HUGO_ENVIRONMENT=production hugo mod get "$module" || restore
HUGO_ENVIRONMENT=production hugo mod tidy || restore
rm -rf "$backup"

# The module brings the layouts, the CSS, the JS and the static files.
rm -rf layouts assets static
echo "The site imports $module. Run commit.sh to check and commit it."
