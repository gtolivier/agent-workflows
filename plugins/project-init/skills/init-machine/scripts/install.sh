#!/bin/sh
# Install the gitleaks git hooks for every repository on this machine:
# gitleaks itself (Homebrew), the hook and its configs in
# ~/.config/git/gitleaks/, and one config-based hook per event in the global
# git config. Run it again after a plugin update; it replaces what it
# installed before.
#
# Config-based hooks (git 2.54 or later) run before the repository's own
# hook, which keeps running from .git/hooks or from a local core.hooksPath.
# A repository opts out with: git config hook.gitleaks-<event>.enabled false
set -eu

events='pre-commit commit-msg pre-push'
source_dir=$(cd "$(dirname "$0")/.." && pwd)
target_dir=${XDG_CONFIG_HOME:-$HOME/.config}/git/gitleaks

# git 2.54 is the first version with config-based hooks.
version=$(git version | sed 's/^git version \([0-9]*\)\.\([0-9]*\).*/\1 \2/')
set -- $version
if [ "$1" -lt 2 ] || { [ "$1" -eq 2 ] && [ "$2" -lt 54 ]; }; then
  echo "install: git 2.54 or later is needed; this is $(git version)." >&2
  exit 1
fi

if ! command -v gitleaks >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "install: install gitleaks (https://github.com/gitleaks/gitleaks), then run this again." >&2
    exit 1
  fi
  brew install gitleaks
fi
# gitleaks 8.19 is the first version with the git and stdin commands.
if ! gitleaks git --help >/dev/null 2>&1 || ! gitleaks stdin --help >/dev/null 2>&1; then
  echo "install: gitleaks $(gitleaks version) is too old; update it (brew upgrade gitleaks)." >&2
  exit 1
fi

mkdir -p "$target_dir"
rm -f "$target_dir"/*.toml
cp "$source_dir"/assets/*.toml "$target_dir"/
cp "$source_dir"/scripts/gitleaks-hook.sh "$target_dir"/
chmod +x "$target_dir"/gitleaks-hook.sh

for event in $events; do
  git config set --global --all "hook.gitleaks-$event.event" "$event"
  git config set --global --all "hook.gitleaks-$event.command" \
    "'$target_dir/gitleaks-hook.sh' $event"
done

echo "gitleaks $(gitleaks version) hooks installed in $target_dir:"
git config get --global --all --show-names --regexp '^hook\.gitleaks-'
