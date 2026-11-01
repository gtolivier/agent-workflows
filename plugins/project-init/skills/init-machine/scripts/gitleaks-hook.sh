#!/bin/sh
# Stop a secret before it leaves the machine. Git runs this script from its
# config-based hooks (hook.gitleaks-<event> in the global config), then the
# repository's own hook, which still runs: see install.sh.
#
# Usage: gitleaks-hook.sh <pre-commit|commit-msg|pre-push> [hook arguments]
set -u

event=$1
arg=${2:-} # commit-msg: the message file; pre-push: the remote name or URL
url=${3:-$arg} # pre-push: the URL pushed to (a push URL, if one is set)

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "gitleaks-hook: gitleaks is not installed (brew install gitleaks)." >&2
  exit 1
fi

# gitleaks reads the output of git diff and git log: colors would hide every
# change from it.
GIT_CONFIG_PARAMETERS="${GIT_CONFIG_PARAMETERS:+$GIT_CONFIG_PARAMETERS }'color.diff=never'"
export GIT_CONFIG_PARAMETERS

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
  stdin_rc=0
  for config; do
    # shellcheck disable=SC2086 # $flags holds several flags.
    printf '%s\n' "$input" | gitleaks stdin --config "$config" $flags ||
      stdin_rc=1
  done
  return $stdin_rc
}

# The commits the remote already has, among those this repository knows,
# as one line of SHAs. Asked once per push, and only when needed: the
# remote-tracking refs can be stale, or missing when pushing to a URL.
remote_commits=
remote_listed=
list_remote_commits() {
  [ -n "$remote_listed" ] && return 0
  listing=$(git ls-remote "$url" </dev/null) || return 1
  known=$(printf '%s\n' "$listing" |
    sed -n 's/^\([0-9a-f]*\)[[:space:]].*/\1^{commit}/p' |
    git cat-file --batch-check='%(objectname)' |
    grep -v ' missing$' | sort -u)
  # Only the tips no other one contains: --log-opts stays one short argument.
  if [ -n "$known" ]; then
    # shellcheck disable=SC2086 # one SHA per word.
    known=$(git merge-base --independent $known) || return 1
  fi
  remote_commits=$(printf '%s\n' "$known" | paste -sd ' ' -)
  remote_listed=1
}

# Scans the commits of <commit> that the remote does not have yet, given
# the remote tip of the pushed ref, plus their messages and <ref names>.
scan_commits() { # <commit> <remote sha> <ref names> -- <configs>
  commit=$1 remote_sha=$2 names=$3
  shift 4
  if git cat-file -e "$remote_sha^{commit}" 2>/dev/null; then
    range="$remote_sha..$commit"
  elif list_remote_commits; then
    range="$commit${remote_commits:+ --not $remote_commits}"
  else
    echo "gitleaks-hook: cannot list what the remote has." >&2
    return 1
  fi
  # gitleaks splits --log-opts at every space, and passes when git fails:
  # no empty word, and a range git can read.
  range=$(printf '%s\n' "$range" | tr -s ' ' | sed 's/^ //; s/ $//')
  # shellcheck disable=SC2086 # $range holds several git log arguments.
  git rev-list --quiet $range || return 1
  commits_rc=0
  for config; do
    # --text: files marked binary in .gitattributes are scanned too.
    # shellcheck disable=SC2086
    gitleaks git --config "$config" $flags --log-opts="--text -m $range" . \
      </dev/null || commits_rc=1
  done
  # Commit messages and ref names, which "gitleaks git" does not read.
  # shellcheck disable=SC2086
  messages=$(git log --format=%B $range) || return 1
  printf '%s\n%s\n' "$messages" "$names" | scan_stdin "$@" || commits_rc=1
  return $commits_rc
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
    # The message, without the diff "git commit --verbose" appends below
    # the scissors line. Comment lines stay: git keeps them in some modes.
    sed '/ -\{24\} >8 -\{24\}$/,$d' "$arg" | scan_stdin "$@" || status=1
    ;;
  pre-push)
    # One line per pushed ref: <local ref> <local sha> <remote ref> <remote
    # sha>. Read first: the scans below must not consume it.
    refs=$(cat)
    while read -r local_ref local_sha remote_ref remote_sha; do
      [ -n "$local_sha" ] || continue
      case $local_sha in
        *[!0]*) ;;
        *) continue ;; # a deleted ref pushes nothing
      esac
      names="$local_ref
$remote_ref"
      # An annotated tag: its message, then what it points to.
      if [ "$(git cat-file -t "$local_sha")" = tag ]; then
        git cat-file -p "$local_sha" | scan_stdin "$@" || status=1
      fi
      target=$(git rev-parse --verify --quiet "$local_sha^{}")
      case $(git cat-file -t "$target" 2>/dev/null) in
        commit)
          scan_commits "$target" "$remote_sha" "$names" -- "$@" || status=1
          ;;
        blob)
          { git cat-file -p "$target"; printf '%s\n' "$names"; } |
            scan_stdin "$@" || status=1
          ;;
        *)
          echo "gitleaks-hook: cannot scan $local_ref ($local_sha)." >&2
          status=1
          ;;
      esac
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
gitleaks-hook: $event refused. Remove the secret: from a file, or from a
commit message with git commit --amend (git rebase -i for an older commit).
An accepted finding in a file goes in .gitleaksignore, at the repository
root, by the fingerprint printed above.
EOF
fi
exit "$status"
