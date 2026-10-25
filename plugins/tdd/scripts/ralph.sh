#!/usr/bin/env bash
# Ralph loop for /tdd:feature — a Stop hook.
#
# While a feature's checklist says "Status: running", stopping is premature:
# the hook blocks the stop and tells Claude to carry on. It lets the session
# stop when there is no running feature (no checklist, or a "Status:
# waiting…" line), and after MAX_IDLE_BLOCKS relaunches without progress.
#
# It looks at the repository holding the session's current directory (the
# hook input's cwd, which follows the session's cd). From a folder above
# several repositories, it never blocks: it cannot tell which session runs
# a feature found there, and would relaunch one session for another's
# feature. It only reports the running features then.
#
# The hook only reads the checklist: it never runs the project's tests, so
# no command written into the checklist escapes Claude Code's permissions.

set -u

# Relaunches allowed without progress before the hook gives the hand back.
# Progress is a newly ticked behavior or a new commit; it resets the count.
MAX_IDLE_BLOCKS=3

input=$(cat)

# The session's directory, from the hook input. A plain sed is enough for
# this one string field and avoids requiring jq.
session_dir=$(printf '%s' "$input" |
  sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
[ -d "$session_dir" ] || session_dir=$PWD

json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

# Repositories to look at: the one the session is in, or, when the session
# is in a folder holding several repositories, each of them.
if top=$(git -C "$session_dir" rev-parse --show-toplevel 2>/dev/null); then
  repos=$top
  parent=no
else
  repos=$(for d in "$session_dir"/*/; do
    git -C "$d" rev-parse --show-toplevel 2>/dev/null
  done | sort -u)
  parent=yes
fi

running=""
found=""
while IFS= read -r repo; do
  [ -n "$repo" ] || continue
  branch=$(git -C "$repo" branch --show-current 2>/dev/null)
  case "$branch" in feature/*) ;; *) continue ;; esac
  git_dir=$(git -C "$repo" rev-parse --absolute-git-dir 2>/dev/null) || continue
  slug=${branch#feature/}
  checklist="$git_dir/tdd/$slug.md"
  state="$git_dir/tdd/$slug.ralph"
  [ -f "$checklist" ] || continue
  if grep -q '^Status: running' "$checklist"; then
    running=$repo
    found="$found, $branch in $repo"
  else
    rm -f "$state" # a pause or a hand-back ends the idle streak
  fi
done <<EOF
$repos
EOF

[ -n "$running" ] || exit 0

if [ "$parent" = yes ]; then
  printf '{"systemMessage": "tdd: running feature(s): %s. This session is in %s, outside their repositories, so the Stop hook does not relaunch it: to keep a feature going, cd into its repository."}\n' \
    "$(json_escape "${found#, }")" "$(json_escape "$session_dir")"
  exit 0
fi

repo=$running
branch=$(git -C "$repo" branch --show-current)
git_dir=$(git -C "$repo" rev-parse --absolute-git-dir)
slug=${branch#feature/}
checklist="$git_dir/tdd/$slug.md"
state="$git_dir/tdd/$slug.ralph"

ticked=$(grep -c '^- \[x\]' "$checklist")
remaining=$(grep -c '^- \[ \]' "$checklist")
progress="$(git -C "$repo" rev-parse HEAD 2>/dev/null):$ticked"

last_progress=""
blocks=0
[ -f "$state" ] && read -r last_progress blocks <"$state"
[ "$progress" = "$last_progress" ] || blocks=0

where=$(json_escape "$branch in $repo")
done_count="$ticked of $((ticked + remaining)) behaviors ticked"

if [ "$blocks" -ge "$MAX_IDLE_BLOCKS" ]; then
  # Give the hand back, and record why in the checklist so a resumed session
  # sees it and sets "Status: running" again.
  reason="Ralph: no progress after $MAX_IDLE_BLOCKS relaunches"
  sed -i.bak "s/^Status: running.*/Status: waiting-for-user — $reason/" "$checklist" &&
    rm -f "$checklist.bak"
  rm -f "$state"
  printf '{"systemMessage": "tdd: %s on %s (%s). The session stops for you to decide."}\n' \
    "$reason" "$where" "$done_count"
  exit 0
fi

blocks=$((blocks + 1))
if ! { echo "$progress $blocks" >"$state"; } 2>/dev/null; then
  # Without a counter the loop could never end: do not block.
  printf '{"systemMessage": "tdd: cannot write the Ralph counter for %s; not relaunching."}\n' "$where"
  exit 0
fi

if [ "$remaining" -gt 0 ]; then
  next="Carry on with the next unchecked behavior."
else
  next="All behaviors are ticked: carry on with the pull request and its reviews."
fi
checklist_json=$(json_escape "$checklist")
printf '{"decision": "block", "reason": "%s is still running (%s). %s Before stopping on purpose, set the Status line of %s: \\"waiting-for-user — <reason>\\" to hand back, \\"waiting — <what>\\" to wait for background work; if the feature was abandoned, delete that file. (Relaunch %s of %s without progress.)"}\n' \
  "$where" "$done_count" "$next" "$checklist_json" "$blocks" "$MAX_IDLE_BLOCKS"
