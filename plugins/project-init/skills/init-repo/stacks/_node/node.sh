# Shared by the stacks built on Node and npm: sourced by their stack.sh.
# Not a stack itself: init-repo lists no folder whose name starts with "_".
# The files next to this one are copied or inserted by those stacks:
# eslint-rules.js (the clean-code rules) and accessibility.spec.ts (axe on
# every page).

NODE_DIR=$STACK_DIR/../_node

# The major version of the latest Node LTS.
node_lts_major() {
  curl -fsSL --max-time 30 https://nodejs.org/dist/index.json |
    jq -er '[.[] | select(.lts != false)][0].version | ltrimstr("v") | split(".")[0]'
}

# Fail unless the Node on PATH has the major version $1.
node_matches() {
  command -v node >/dev/null && command -v npx >/dev/null || {
    echo "Node $1 is missing: install it (nvm install $1, fnm, volta…)." >&2
    return 1
  }
  current=$(node -p 'process.versions.node.split(".")[0]')
  [ "$current" = "$1" ] || {
    echo "Node $current is on PATH, the project uses Node $1: switch to it (nvm use $1, fnm, volta…)." >&2
    return 1
  }
}

# Replace a whole line of a generated file, and fail if the generator no
# longer writes it. "\n" in the new line starts another line.
replace_line() {
  awk -v old="$2" -v new="$3" '$0 == old { print new; n++; next } { print }
    END { exit n != 1 }' "$1" >"$1.new" ||
    die "$1: expected the line '$2' once — has a generator's template changed?"
  mv "$1.new" "$1"
}

# Replace the lines $2 of a generated file with the lines $3 (empty: delete
# them), and fail unless the file holds $2 exactly once.
replace_block() {
  OLD=$2 NEW=$3 awk '{ s = s $0 "\n" } END {
    old = ENVIRON["OLD"] "\n"; new = ENVIRON["NEW"]
    if (new != "") new = new "\n"
    i = index(s, old)
    if (i == 0 || index(substr(s, i + length(old)), old) > 0) exit 1
    printf "%s%s%s", substr(s, 1, i - 1), new, substr(s, i + length(old))
  }' "$1" >"$1.new" ||
    die "$1: expected these lines once — has a generator's template changed?
$2"
  mv "$1.new" "$1"
}

# Insert the clean-code rules (eslint-rules.js) before the closing "]);" of
# the ESLint config $1: no CLI adds rules. The config must name the
# eslint-comments plugin's configs "comments".
eslint_rules() {
  awk 'NR == FNR { rules = rules $0 "\n"; next }
    $0 == "]);" { printf "%s", rules; n++ } { print }
    END { exit n != 1 }' "$NODE_DIR/eslint-rules.js" "$1" >"$1.new" ||
    die "$1: expected one closing ']);' — has its template changed?"
  mv "$1.new" "$1"
}
