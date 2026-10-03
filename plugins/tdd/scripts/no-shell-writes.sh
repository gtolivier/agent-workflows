#!/usr/bin/env bash
# No file writes through the shell — a PreToolUse hook on Bash.
#
# The red, green and refactor subagents change files only through their Edit
# and Write tools: those are what permission prompts and Edit/Write hooks
# see. While one of them runs, this hook refuses the shell commands an agent
# reaches for as a shortcut to write a file — a redirection, tee, sed -i,
# cp/mv/rm, a git command that changes the working tree, interpreter code
# (inline or in a heredoc) that writes. It matches patterns: it stops an
# honest shortcut, not an adversary. Commands that write as a side effect of
# their job — the test runner's caches, the formatter, a generator such as
# `makemigrations` — match none of them and run as usual.
#
# Outside these three subagents the hook does nothing.

set -u

input=$(cat)

# A top-level string field of the hook input, still JSON-escaped. A plain
# sed is enough here and avoids requiring jq.
field() {
  printf '%s' "$input" |
    sed -n -E 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' |
    head -n 1
}

agent=$(field agent_type)
case $agent in
tdd:red | tdd:green) tools="Edit and Write tools" ;;
tdd:refactor) tools="Edit tool" ;;
*) exit 0 ;;
esac

# The command, unescaped well enough for matching: line breaks become
# command separators.
command=$(field command |
  sed -E -e 's/\\n/; /g' -e 's/\\t/ /g' -e 's/\\"/"/g' -e 's/\\\\/\\/g')
[ -n "$command" ] || exit 0

# The same command without the content of its quoted strings, in one
# left-to-right pass, so that a '>' or a command name inside a grep pattern
# or a message does not count.
bare=$(printf '%s' "$command" |
  sed -E "s/'[^']*'|\"([^\"\\\\]|\\\\.)*\"/''/g")

# Where a command name starts: the beginning, after a separator or a shell
# keyword, and after a wrapper that runs the next word as a command.
start='(^|[;&|(`{!]|\$\()([[:space:]]*(do|then|else|elif|if|while|until|time|!)[[:space:]])*[[:space:]]*((uv[[:space:]]+run|command|exec|nohup)([[:space:]]+-[^[:space:]]*)*[[:space:]]+|(xargs|env|sudo|nice|timeout)([[:space:]][^;&|]*)?[[:space:]]+)*'

# A shell running a quoted script: check the script as well.
if printf '%s' "$bare" | grep -Eq "${start}(ba|z|da)?sh[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*-[a-zA-Z]*c([[:space:];&|)]|$)"; then
  bare=$(printf '%s' "$command" | sed -E "s/['\"]/; /g")
fi

refuse() {
  cat >&2 <<EOF
tdd: refused — $1.
In the red, green and refactor steps, files change only through your
$tools: use them instead. If this command does not write any file, rephrase
it (the Read, Grep and Glob tools read files). If the change cannot be made
with your $tools — creating, moving or deleting a file, a generator that
writes through a redirection — do not work around this check: stop with
STATUS: NEEDS_FILE_OPERATION and name the operation in NOTES. The
orchestrator makes it and resumes your step.
EOF
  exit 2
}

# Redirections, once those that write no file are set aside: to /dev/null or
# a standard stream, between descriptors (2>&1), arrows (->, =>), arithmetic,
# and the body of a heredoc (everything after its first line).
redirections=$(printf '%s' "$bare" | sed -E \
  -e 's/(<<-?[^<;][^;]*);.*/\1/' \
  -e 's/\$\(\([^)]*\)\)//g' \
  -e 's/(&|[0-9]*)>>?[[:space:]]*\/dev\/(null|stdout|stderr)//g' \
  -e 's/[0-9]*>&[0-9-]+//g' \
  -e 's/[-=]>//g')
case $redirections in *'>'*) refuse "a redirection to a file" ;; esac

if printf '%s' "$bare" |
  grep -Eq "${start}(tee|cp|mv|rm|rmdir|touch|mkdir|ln|truncate|dd|install|patch)([[:space:];&|)]|$)"; then
  refuse "a command that creates, copies, moves or deletes files"
fi

if printf '%s' "$bare" |
  grep -Eq "${start}(sed|perl)[[:space:]]([^;&|]*[[:space:]])?(-[a-zA-Z]*i|--in-place)"; then
  refuse "an in-place edit"
fi

if printf '%s' "$bare" |
  grep -Eq '(^|[[:space:]])(-delete|-exec(dir)?[[:space:]]+(rm|mv|cp|tee|touch|truncate|(sed|perl)[[:space:]]+-[a-zA-Z]*i))([[:space:]]|$)'; then
  refuse "find writing or deleting files"
fi

# Git subcommands that change the working tree, minus their read-only forms.
git_bare=$(printf '%s' "$bare" | sed -E \
  -e 's/stash[[:space:]]+(list|show)//g' \
  -e 's/apply(([[:space:]]+-[^[:space:]]*)*[[:space:]]+--(check|stat|numstat|summary))+//g')
if printf '%s' "$git_bare" |
  grep -Eq "${start}git(([[:space:]]+(-C|-c|--git-dir|--work-tree))?[[:space:]]+-[^[:space:]]*|[[:space:]]+(-C|-c)[[:space:]]+[^[:space:]]+)*[[:space:]]+(apply|checkout|switch|restore|reset|stash|clean|mv|rm|merge|rebase|cherry-pick|revert|pull|am)([[:space:];&|)]|$)"; then
  refuse "a git command that changes the working tree"
fi

# Interpreter code, inline or in a heredoc, that writes, deletes or runs
# other commands. Writing to the standard output does not count.
if printf '%s' "$bare" |
  grep -Eq "${start}(python[0-9.]*|perl|ruby|node)([[:space:];&|)]|$)" &&
  printf '%s' "$command" |
  sed -E 's/(sys|process)\.(stdout|stderr)\.write//g' |
  grep -Eq '\.write(_text|_bytes|lines)?\(|open\([^)]*(, *["'"'"'][wax]|mode *=)|(^|[^a-zA-Z_.])os\.(remove|unlink|rename|replace|rmdir|mkdir|makedirs|truncate|chmod|system)|\.(unlink|rename|mkdir|touch|rmdir|chmod)\(|shutil\.|subprocess\.|json\.dump\(|(write|append)File|\.(unlink|rm|rmdir|rename|mkdir|copyFile)(Sync)?\(|File\.(write|delete|open)'; then
  refuse "interpreter code that writes files or runs commands"
fi

exit 0
