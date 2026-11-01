#!/bin/sh
# Stop a secret before it leaves the machine. Git runs this script from its
# config-based hooks (hook.gitleaks-<event> in the global config), then the
# repository's own hook, which still runs: see install.sh.
#
# Usage: gitleaks-hook.sh <pre-commit|commit-msg|pre-push> [hook arguments]
set -u

event=$1
arg=${2:-} # commit-msg: the message file; pre-push: the remote name

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "gitleaks-hook: gitleaks is not installed (brew install gitleaks)." >&2
  exit 1
fi

# Git starts hooks at the root of the working tree, except during a push;
# a bare repository has no working tree and stays where it is.
top=$(git rev-parse --show-toplevel 2>/dev/null) && cd "$top"

# The configs, as positional parameters: the repository's own if it has
# some, else the global ones installed next to this script. One gitleaks
# pass per config, so that a rule kept in its own config escapes the path
# allowlist of gitleaks' default rules.
set --
for config in .github/gitleaks/*.toml; do
  [ -f "$config" ] && set -- "$@" "$config"
done
[ $# -eq 0 ] && [ -f .gitleaks.toml ] && set -- .gitleaks.toml
if [ $# -eq 0 ]; then
  for config in "$(dirname "$0")"/*.toml; do
    [ -f "$config" ] && set -- "$@" "$config"
  done
fi
if [ $# -eq 0 ]; then
  echo "gitleaks-hook: no gitleaks config found." >&2
  exit 1
fi

flags='--redact --no-banner --verbose --log-level warn'

# Scans stdin with each config given; fails if any finds a leak.
scan_stdin() {
  input=$(cat)
  rc=0
  for config; do
    # shellcheck disable=SC2086 # $flags holds several flags.
    printf '%s\n' "$input" | gitleaks stdin --config "$config" $flags || rc=1
  done
  return $rc
}

status=0

case $event in
  pre-commit)
    for config; do
      # shellcheck disable=SC2086
      gitleaks git --pre-commit --staged --config "$config" $flags . \
        </dev/null || status=1
    done
    ;;
  commit-msg)
    scan_stdin "$@" <"$arg" || status=1
    ;;
  pre-push)
    # One line per pushed ref: <local ref> <local sha> <remote ref> <remote
    # sha>. Read first: the scans below must not consume it.
    refs=$(cat)
    while read -r local_ref local_sha remote_ref remote_sha; do
      case $local_sha in
        *[!0]*) ;;
        *) continue ;; # a deleted ref pushes nothing
      esac
      # Only the commits the remote does not have yet. A new ref, or a
      # remote tip unknown here: what no remote-tracking ref of it holds.
      if git cat-file -e "$remote_sha^{commit}" 2>/dev/null; then
        range="$remote_sha..$local_sha"
      else
        range="$local_sha --not --remotes=$arg"
      fi
      for config; do
        # shellcheck disable=SC2086
        gitleaks git --config "$config" $flags --log-opts="-m $range" . \
          </dev/null || status=1
      done
      # Commit messages and ref names, which "gitleaks git" does not read.
      # shellcheck disable=SC2086 # $range holds several git log arguments.
      { git log --format=%B $range; printf '%s\n%s\n' "$local_ref" "$remote_ref"; } |
        scan_stdin "$@" || status=1
    done <<EOF
$refs
EOF
    ;;
  *)
    echo "gitleaks-hook: unknown event: $event" >&2
    exit 1
    ;;
esac

if [ "$status" -ne 0 ]; then
  cat >&2 <<EOF
gitleaks-hook: $event refused. Remove the secret, or declare an accepted
finding by its fingerprint in .gitleaksignore, at the repository root.
EOF
fi
exit "$status"
