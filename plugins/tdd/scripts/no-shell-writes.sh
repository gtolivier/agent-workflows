#!/usr/bin/env bash
# No file writes through the shell — a PreToolUse hook on Bash.
#
# The red, green and refactor subagents change files only through their Edit
# and Write tools: those are what permission prompts and Edit/Write hooks
# see. While one of them runs, this hook refuses the shell commands an agent
# reaches for as a shortcut to write a file — a redirection, tee, sed -i, a
# heredoc, cp/mv/rm, a git command that changes the working tree, inline
# interpreter code that writes. It matches patterns: it stops an honest
# shortcut, not an adversary. Commands that write as a side effect of their
# job — the test runner's caches, the formatter, a generator such as
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

case $(field agent_type) in
tdd:red | tdd:green | tdd:refactor) ;;
*) exit 0 ;;
esac

# The command, unescaped well enough for matching: line breaks become
# command separators.
command=$(field command |
  sed -E -e 's/\\n/; /g' -e 's/\\t/ /g' -e 's/\\"/"/g' -e 's/\\\\/\\/g')
[ -n "$command" ] || exit 0

# The same command without the content of its quoted strings, so that a
# '>' or a command name inside a grep pattern or a message does not count.
bare=$(printf '%s' "$command" |
  sed -E -e "s/'[^']*'/''/g" -e 's/"([^"\\]|\\.)*"/""/g')

# Where a command name starts: the beginning, after a separator, or after a
# wrapper that runs the next word as a command.
start='(^|[;&|(`!{]|\$\()[[:space:]]*(((xargs|env|command|exec|nohup|time|sudo|uv[[:space:]]+run)([[:space:]]+-[^[:space:]]*)*)[[:space:]]+)*'

refuse() {
  cat >&2 <<EOF
tdd: refused — $1.
In the red, green and refactor steps, files change only through your Edit
and Write tools: use them instead. If this command does not write any file,
rephrase it (the Read, Grep and Glob tools read files). If the change cannot
be made with your tools — deleting, moving or renaming a file, or a
generator that writes through a redirection — do not work around this
check: say so in your report, and the orchestrator will do it.
EOF
  exit 2
}

# Redirections, once those that write no file are set aside: to /dev/null or
# a standard stream, between descriptors (2>&1), and arrows (->, =>).
redirections=$(printf '%s' "$bare" | sed -E \
  -e 's/(&|[0-9]*)>>?[[:space:]]*\/dev\/(null|stdout|stderr)//g' \
  -e 's/[0-9]*>&[0-9-]+//g' \
  -e 's/[-=]>//g')
case $redirections in *'>'*) refuse "a redirection to a file" ;; esac

case $bare in *'<<'*) refuse "a heredoc or here-string" ;; esac

if printf '%s' "$bare" |
  grep -Eq "$start(tee|cp|mv|rm|rmdir|touch|mkdir|ln|truncate|dd|install|patch)([[:space:]]|$)"; then
  refuse "a command that creates, copies, moves or deletes files"
fi

if printf '%s' "$bare" |
  grep -Eq "$start(sed|perl)[[:space:]]([^;&|]*[[:space:]])?(-[a-zA-Z]*i|--in-place)"; then
  refuse "an in-place edit"
fi

if printf '%s' "$bare" |
  grep -Eq '(^|[[:space:]])(-delete|-exec(dir)?[[:space:]]+(rm|mv|cp|tee|touch|truncate|(sed|perl)[[:space:]]+-[a-zA-Z]*i))([[:space:]]|$)'; then
  refuse "find writing or deleting files"
fi

if printf '%s' "$bare" |
  grep -Eq "${start}git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?(apply|checkout|restore|reset|stash|clean|mv|rm)([[:space:]]|$)"; then
  refuse "a git command that changes the working tree"
fi

if printf '%s' "$bare" |
  grep -Eq "$start(python[0-9.]*|perl|ruby|node)([[:space:]]+-[a-zA-Z]+)*[[:space:]]+-[a-zA-Z]*[ce]([[:space:]]|$)" &&
  printf '%s' "$command" |
  grep -Eq 'write|unlink|remove|rename|rmtree|shutil|mkdir|touch|truncate|chmod|os\.replace|(^|[^a-z])dump\('; then
  refuse "inline interpreter code that writes files"
fi

exit 0
