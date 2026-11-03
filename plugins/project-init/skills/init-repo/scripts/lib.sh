# Shared by init-repo.sh and render.sh, and by the stacks' functions they
# call: sourced, never run. STACK_DIR is the stack's folder.

# Replace each @VAR@ of a template with the environment variable VAR.
render() {
  awk '{
    out = ""; s = $0
    while (match(s, /@[A-Z_]+@/)) {
      out = out substr(s, 1, RSTART - 1) ENVIRON[substr(s, RSTART + 1, RLENGTH - 2)]
      s = substr(s, RSTART + RLENGTH)
    }
    print out s
  }' "$1"
}

# Render the template $1 to the file $2, or copy it as is with "copy_file":
# nothing when the template does not exist, as in an earlier version that
# did not write that file.
render_file() {
  [ -f "$1" ] || return 0
  mkdir -p "$(dirname "$2")"
  render "$1" >"$2"
}
copy_file() {
  [ -f "$1" ] || return 0
  mkdir -p "$(dirname "$2")"
  cp "$1" "$2"
}

# A stack's template: in its folder, else in the folders of shared code it
# names (SHARED_DIR, NODE_DIR); the path in its folder when none has it.
template() {
  for d in "$STACK_DIR" "${SHARED_DIR-}" "${NODE_DIR-}"; do
    if [ -n "$d" ] && [ -f "$d/$1" ]; then
      echo "$d/$1"
      return
    fi
  done
  echo "$STACK_DIR/$1"
}

# Format the files of the folder $1 as the repository REPO_DIR formats its
# own — with its tools, settings and ignore file — so that a render matches
# what init-repo wrote, its formatter run: Prettier, or ruff's fixes then
# its formatter. Each file is formatted as if it were at its path in the
# repository.
format_prettier() {
  bin=$REPO_DIR/node_modules/.bin/prettier
  [ -x "$bin" ] || die "$REPO_DIR has no node_modules/.bin/prettier: run npm ci there first"
  rendered_files "$1" | while IFS= read -r f; do
    info=$(cd "$REPO_DIR" && "$bin" --file-info "$f" </dev/null)
    [ "$(printf '%s' "$info" | jq -r '.ignored or .inferredParser == null')" = false ] || continue
    (cd "$REPO_DIR" && "$bin" --log-level warn --stdin-filepath "$f") <"$1/$f" >"$1/$f.fmt" ||
      die "Prettier could not format $f"
    mv "$1/$f.fmt" "$1/$f"
  done
}
format_ruff() {
  rendered_files "$1" | grep '\.py$' | while IFS= read -r f; do
    (cd "$REPO_DIR" &&
      uv run --quiet ruff check --fix --exit-zero --quiet --stdin-filename "$f" - |
      uv run --quiet ruff format --quiet --stdin-filename "$f" -) <"$1/$f" >"$1/$f.fmt" ||
      die "ruff could not format $f"
    mv "$1/$f.fmt" "$1/$f"
  done
}
rendered_files() { (cd "$1" && find . -type f) | sed 's|^\./||'; }

lang_name() {
  case $1 in
    en) echo English ;; fr) echo French ;; de) echo German ;;
    es) echo Spanish ;; it) echo Italian ;; *) echo "$1" ;;
  esac
}
