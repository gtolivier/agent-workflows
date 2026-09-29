#!/usr/bin/env bash
# Ralph loop for /tdd:feature — a Stop hook.
#
# While a feature's checklist says "Status: running", stopping is premature:
# the hook blocks the stop and tells Claude to carry on. It lets the session
# stop when there is no running feature (the checklist is absent, or says
# "Status: waiting-for-user"), and after MAX_IDLE_BLOCKS relaunches without
# progress.
#
# The hook only reads the checklist: it never runs the project's tests, so
# no command written into the checklist escapes Claude Code's permissions.

set -u

# Relaunches allowed without a newly ticked behavior before the hook gives
# the hand back. Progress (one more "- [x]") resets the count.
MAX_IDLE_BLOCKS=3

cat >/dev/null # the hook input is not needed: the hook runs in the session's directory

git_dir=$(git rev-parse --git-dir 2>/dev/null) || exit 0
branch=$(git branch --show-current 2>/dev/null)
case "$branch" in
  feature/*) slug=${branch#feature/} ;;
  *) exit 0 ;;
esac

checklist="$git_dir/tdd/$slug.md"
state="$git_dir/tdd/$slug.ralph"
[ -f "$checklist" ] || exit 0
grep -q '^Status: running' "$checklist" || exit 0

ticked=$(grep -c '^- \[x\]' "$checklist")
remaining=$(grep -c '^- \[ \]' "$checklist")

last_ticked=-1
blocks=0
[ -f "$state" ] && read -r last_ticked blocks <"$state"
if [ "$ticked" -gt "$last_ticked" ]; then
  blocks=0
fi

if [ "$blocks" -ge "$MAX_IDLE_BLOCKS" ]; then
  # Give the hand back, and record why in the checklist so a resumed session
  # sees it and sets "Status: running" again.
  reason="Ralph: no progress after $MAX_IDLE_BLOCKS relaunches"
  sed -i.bak "s/^Status: running.*/Status: waiting-for-user — $reason/" "$checklist" &&
    rm -f "$checklist.bak"
  rm -f "$state"
  printf '{"systemMessage": "tdd: %s on feature/%s (%s of %s behaviors ticked). The session stops for you to decide."}\n' \
    "$reason" "$slug" "$ticked" "$((ticked + remaining))"
  exit 0
fi

blocks=$((blocks + 1))
echo "$ticked $blocks" >"$state"

if [ "$remaining" -gt 0 ]; then
  next="Carry on with the next unchecked behavior."
else
  next="All behaviors are ticked: carry on with the pull request and its reviews."
fi
printf '{"decision": "block", "reason": "feature/%s is still running (%s of %s behaviors ticked). %s If you need the user, first set \\"Status: waiting-for-user — <reason>\\" in the checklist. (Relaunch %s of %s without progress.)"}\n' \
  "$slug" "$ticked" "$((ticked + remaining))" "$next" "$blocks" "$MAX_IDLE_BLOCKS"
