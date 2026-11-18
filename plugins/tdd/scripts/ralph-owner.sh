#!/usr/bin/env bash
# Owner of a /tdd:feature for the Ralph loop — a PostToolUse hook on Write
# and Edit.
#
# The Stop hook (ralph.sh) relaunches a session while the feature of its
# repository says "Status: running". Every session open in that repository
# stops there, not only the one running the feature: without an owner, the
# hook would relaunch them all. Claude does not know its own session id, but
# hooks receive it. So when a session writes a checklist,
# <git-dir>/tdd/<slug>.md, through its Write or Edit tool, this hook records
# that session's id in <git-dir>/tdd/<slug>.session, and ralph.sh relaunches
# only that session.
#
# The skill writes the checklist when it creates it and whenever it changes
# the Status line: the session that creates a feature owns it, and one that
# resumes it takes it over when it sets "Status: running" again. Ticking a
# behavior goes through step.sh, a shell command: it changes no owner.
# Subagents share the session's id, so a write of theirs would change
# nothing either.

set -u

input=$(cat)

# A top-level string field of the hook input, still JSON-escaped. A plain
# sed is enough here and avoids requiring jq.
field() {
  printf '%s' "$input" |
    sed -n -E 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' |
    head -n 1
}

session_id=$(field session_id)
case $session_id in '' | *[!A-Za-z0-9_-]*) exit 0 ;; esac

file=$(field file_path | sed -e 's/\\"/"/g' -e 's/\\\\/\\/g')

# Only a checklist: a .md file in a tdd folder right inside a Git directory.
case $file in */tdd/*.md) ;; *) exit 0 ;; esac
[ -f "$file" ] || exit 0
tdd_dir=$(dirname "$file")
[ "$(basename "$tdd_dir")" = tdd ] || exit 0
git_dir=$(dirname "$tdd_dir")
actual=$(git -C "$git_dir" rev-parse --absolute-git-dir 2>/dev/null) || exit 0
[ "$(cd "$git_dir" && pwd -P)" = "$(cd "$actual" && pwd -P)" ] || exit 0

slug=$(basename "$file" .md)
owner_file="$tdd_dir/$slug.session"
[ "$(head -n 1 "$owner_file" 2>/dev/null)" = "$session_id" ] && exit 0

# A new owner starts with a fresh idle count: the relaunches the previous
# owner used up are not its own.
rm -f "$tdd_dir/$slug.ralph"
printf '%s\n' "$session_id" >"$owner_file" 2>/dev/null || true
exit 0
