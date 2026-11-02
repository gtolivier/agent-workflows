# Shared by the Python stacks: sourced by their stack.sh, which sets
# RUNTIME_DEFAULT and PYTHON_NEWEST. Not a stack itself: init-repo lists
# no folder whose name starts with "_".

# The Python versions the CI tests: the oldest supported and the newest.
stack_pythons() {
  if [ "$RUNTIME" = "$PYTHON_NEWEST" ]; then echo "$RUNTIME"; else echo "$RUNTIME $PYTHON_NEWEST"; fi
}

# PYTHON_NEWEST and PYTHON_MATRIX, the versions as a YAML flow list, for
# ci.yml.
python_render_env() {
  PYTHON_MATRIX=$(stack_pythons | sed 's/[^ ][^ ]*/"&"/g; s/ /, /g')
  export PYTHON_NEWEST PYTHON_MATRIX
}

# The test jobs' CI checks, one per line.
python_test_checks() {
  for v in $(stack_pythons); do echo "test (python $v)"; done
}

# Run a shell command, through uv run, on each Python of the CI. The
# oldest runs in an environment of its own; its interpreter is looked up
# from outside the repository, whose .python-version pyenv would apply
# too. Without it on this machine, only the CI tests it.
python_each() {
  for v in $(stack_pythons); do
    if [ "$v" = "$PYTHON_NEWEST" ]; then
      uv run sh -c "$1" || return 1
    elif py=$(cd / && uv python find "$v" 2>/dev/null); then
      uv run --isolated --python "$py" sh -c "$1" || return 1
    else
      echo "Python $v is not on this machine: the CI tests it, not this check." >&2
    fi
  done
}
