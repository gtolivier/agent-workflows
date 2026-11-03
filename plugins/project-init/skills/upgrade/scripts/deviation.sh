#!/bin/sh
# Record and settle the deviations of a repository or workspace from the
# common layer of project-init, in its register (.project-init.yml): during
# an upgrade, for each file its report asks about, and at the end of any
# pull request that changes a file of the common layer.
#
# Usage: deviation.sh <dir> record <path> <status> <reason> [--until <date>] [--issue <n>]
#        deviation.sh <dir> resolve <path> theirs|ours
#        deviation.sh <dir> forget <path>
#        deviation.sh <dir> check
#        deviation.sh <dir> status
#
# record   keep the file as it is now, with the reason. Its status:
#            local       for good: this repository needs it
#            temporary   until <date> (YYYY-MM-DD): the upgrade after it asks again
#            generalize  better for every repository: issue <n> of
#                        gtolivier/agent-workflows proposes it to project-init;
#                        once it is completed, the upgrade takes the new version
#            abandon     no longer project-init's: never updated again
# resolve  for a file of the upgrade in progress: theirs takes this version's
#          file (or deletes it, if this version no longer writes it) and
#          forgets the deviation; ours keeps a file this version no longer
#          writes, or an unmanaged one it adds, as the repository's own
# forget   drop the deviation recorded for a file
# check    the deviations recorded are well formed; lists the lapsed ones
# status   the files the upgrade in progress has yet to settle
set -eu

here=$(cd "$(dirname "$0")" && pwd)
die() {
  echo "deviation: $*" >&2
  exit 1
}
usage() { sed -n '/^# Usage:/,/^#$/p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

[ $# -ge 2 ] || usage
dir=$(cd "$1" 2>/dev/null && pwd) || die "$1: no such folder"
op=$2
shift 2
cd "$dir"
[ -f .project-init.yml ] || die "$dir has no .project-init.yml"
register=$(uv run --quiet --script "$here/register.py" .project-init.yml)
get() { printf '%s' "$register" | jq -r "$@"; }
edit() { uv run --quiet --script "$here/register-edit.py" .project-init.yml "$@"; }
json() { jq -Rn --arg s "$1" '$s'; }
work=$(cd "$(git rev-parse --git-dir)" && pwd)/project-init-upgrade
report=$work/report.json

# The outcome of a file in the upgrade in progress, empty if none.
outcome() {
  [ -f "$report" ] || return 0
  jq -r --arg p "$1" '.items[] | select(.path == $p) | .outcome' "$report"
}
settled() {
  [ -f "$report" ] || return 0
  jq --arg p "$1" '.items |= map(if .path == $p then .resolved = true else . end)' "$report" >"$report.new"
  mv "$report.new" "$report"
}
has_markers() { grep -Eq '^(<<<<<<< this repository|>>>>>>> project-init [0-9.]+)$' "$1"; }
managed() { get -e --arg p "$1" '(.managed // []) | index($p)' >/dev/null; }

case $op in
  record)
    [ $# -ge 3 ] || usage
    path=$1 status=$2 reason=$3
    shift 3
    until='' issue=''
    while [ $# -gt 0 ]; do
      case $1 in
        --until) until=${2-} ;;
        --issue) issue=${2-} ;;
        *) usage ;;
      esac
      [ $# -ge 2 ] || usage
      shift 2
    done
    case $status in
      local | abandon) [ -z "$until$issue" ] || die "$status takes neither --until nor --issue" ;;
      temporary)
        printf '%s' "$until" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' ||
          die "temporary needs --until YYYY-MM-DD: the date the upgrade asks again"
        [ -z "$issue" ] || die "temporary takes no --issue" ;;
      generalize)
        printf '%s' "$issue" | grep -Eq '^[0-9]+$' ||
          die "generalize needs --issue <n>: the issue of gtolivier/agent-workflows that proposes it"
        [ -z "$until" ] || die "generalize takes no --until" ;;
      *) die "status '$status': local, temporary, generalize or abandon" ;;
    esac
    case $reason in
      '' | *"
"*) die "the reason: one line, the user's" ;;
    esac
    item=$(outcome "$path")
    [ "$item" != removed ] || die "$path: this version no longer writes it: resolve it, ours or theirs"
    managed "$path" || [ -n "$item" ] || die "$path is not a file of the common layer (see managed in .project-init.yml)"
    if [ -e "$path" ]; then
      ! has_markers "$path" || die "$path still holds conflict markers: edit them out first"
    else
      [ "$status" = abandon ] || die "$path does not exist: restore it, or record it as abandon"
    fi
    entry=$(jq -nc --arg status "$status" --arg reason "$reason" --arg until "$until" --arg issue "$issue" '
      {status: $status, reason: $reason}
      + (if $until == "" then {} else {until: $until} end)
      + (if $issue == "" then {} else {issue: ($issue | tonumber)} end)')
    if [ "$status" = abandon ]; then
      edit deviation "$path" "$entry" remove managed "$(json "$path")"
    else
      edit deviation "$path" "$entry" add managed "$(json "$path")"
    fi
    settled "$path"
    echo "Recorded: $path, $status."
    ;;
  resolve)
    [ $# -eq 2 ] || usage
    path=$1 side=$2
    item=$(outcome "$path")
    [ -n "$item" ] || die "$path is not a file of an upgrade in progress"
    case $side in
      theirs)
        if [ -f "$work/theirs/$path" ]; then
          mkdir -p "$(dirname "$path")"
          cp "$work/theirs/$path" "$path"
          edit deviation "$path" null add managed "$(json "$path")"
        else
          rm -f "$path"
          edit deviation "$path" null remove managed "$(json "$path")"
        fi ;;
      ours)
        case $item in
          removed) edit deviation "$path" null remove managed "$(json "$path")" ;;
          exists) ;;
          *) die "$path: to keep it as it is, record it as a deviation (record $path <status> <reason>)" ;;
        esac ;;
      *) usage ;;
    esac
    settled "$path"
    echo "Resolved: $path, $side."
    ;;
  forget)
    [ $# -eq 1 ] || usage
    edit deviation "$1" null
    echo "Forgotten: the deviation of $1."
    ;;
  check)
    [ $# -eq 0 ] || usage
    today=$(date +%Y-%m-%d)
    errors=$(get --arg today "$today" '
      (.managed // []) as $managed |
      (.deviations // [])[] | (.path // "?") as $p |
      if (.reason // "") == "" then "\($p): no reason"
      elif .status == "temporary" then
        if (.until // "" | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")) | not then "\($p): temporary without until (YYYY-MM-DD)" else empty end
      elif .status == "generalize" then
        if (.issue | type) != "number" then "\($p): generalize without an issue number" else empty end
      elif .status == "local" or .status == "abandon" then empty
      else "\($p): unknown status \(.status)" end,
      if .status != "abandon" and ($managed | index($p)) == null then "\($p): not in managed" else empty end')
    lapsed=$(get --arg today "$today" '(.deviations // [])[]
      | select(.status == "temporary" and (.until // "") < $today) | "\(.path) (until \(.until))"')
    [ -z "$lapsed" ] || { echo "Temporary deviations past their date — ask the user again:"; printf '%s\n' "$lapsed" | sed 's/^/  /'; }
    [ -z "$errors" ] || { printf '%s\n' "$errors" | sed 's/^/deviation: /' >&2; exit 1; }
    echo "Deviations: $(get '.deviations // [] | length') recorded, well formed."
    ;;
  status)
    [ $# -eq 0 ] || usage
    [ -f "$report" ] || die "no upgrade in progress in $dir"
    jq -r '.items[]
      | select((.outcome | IN("ask", "conflict", "missing", "nobase", "exists", "removed", "expired")) and (.resolved | not))
      | "  \(.outcome)\t\(.path)\(if .note != "" then " — " + .note else "" end)"' "$report"
    ;;
  *) usage ;;
esac
