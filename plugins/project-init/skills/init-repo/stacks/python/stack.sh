# Stack "python": a Python library — uv, pytest, ruff, mypy (strict).
# Sourced by init-repo.sh and commit.sh. The functions run from inside the
# repository; STACK_DIR is this folder.

STACK_SUMMARY="Python library: uv, pytest, ruff, mypy (strict)"
# GitHub's .gitignore template, used when the generator writes none.
GITIGNORE_TEMPLATE=Python
# The runtime version (--runtime): the oldest supported Python.
RUNTIME_DEFAULT=3.12
# The newest Python, for development and the CI. Bump it when one is out.
PYTHON_NEWEST=3.14

# A project name as PEP 508 has it: letters, digits, '.', '_', '-', starting
# and ending with a letter or digit.
STACK_NAME_RULE="letters, digits, '.', '_' and '-', starting and ending with a letter or digit"
stack_valid_name() {
  printf '%s' "$1" | grep -Eq '^([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9._-]*[A-Za-z0-9])$'
}

# Generate the project with its official tools. Environment: NAME,
# DESCRIPTION, RUNTIME, LICENSE (SPDX id or "none").
stack_generate() {
  uv init --quiet --lib --name "$NAME" --description "$DESCRIPTION" \
    --vcs none --author-from git --no-workspace --python "$RUNTIME" .
  uv python pin --quiet "$PYTHON_NEWEST"
  uv add --quiet --dev pytest ruff
  uv add --quiet --group typecheck mypy

  package=$(printf '%s' "$NAME" | tr '[:upper:]-.' '[:lower:]__')
  # uv's sample function is a behavior without a test: the package starts
  # empty.
  : >"src/$package/__init__.py"
  mkdir -p tests
  PACKAGE=$package render "$STACK_DIR/test_package.py" >tests/test_package.py
  # Tool settings: no CLI writes them.
  render "$STACK_DIR/pyproject.toml" >>pyproject.toml
  if [ "$LICENSE" != none ]; then
    # PEP 639 metadata, right after the description uv wrote.
    awk -v id="$LICENSE" '{ print }
      /^description = / { print "license = \"" id "\""; print "license-files = [\"LICENSE\"]" }' \
      pyproject.toml >pyproject.toml.new && mv pyproject.toml.new pyproject.toml
  fi
  # Re-lock: the metadata changed.
  uv lock --quiet
}

# The Python versions the CI tests: the oldest supported and the newest.
stack_pythons() {
  if [ "$RUNTIME" = "$PYTHON_NEWEST" ]; then echo "$RUNTIME"; else echo "$RUNTIME $PYTHON_NEWEST"; fi
}

# Variables for ci.yml and agents.md.
stack_render_env() {
  PYTHON_MATRIX=$(stack_pythons | sed 's/[^ ][^ ]*/"&"/g; s/ /, /g')
  export PYTHON_NEWEST PYTHON_MATRIX
  export PACKAGE="$(printf '%s' "$NAME" | tr '[:upper:]-.' '[:lower:]__')"
}

# The CI checks a merge requires, one per line: the job names of ci.yml.
stack_checks() {
  echo lint
  echo typecheck
  for v in $(stack_pythons); do echo "test (python $v)"; done
}

# Files this stack sets up beyond the common ones, for the register.
stack_managed() {
  printf '%s\n' pyproject.toml .python-version tests/test_package.py
}

# Everything the CI checks, locally, with the tests on each Python of the
# CI. The oldest runs in an environment of its own; its interpreter is
# looked up from outside the repository, whose .python-version pyenv would
# apply too. Without it on this machine, only the CI tests it.
stack_check() {
  uv lock --check &&
    uv run ruff check &&
    uv run ruff format --check &&
    uv run --group typecheck mypy || return 1
  for v in $(stack_pythons); do
    if [ "$v" = "$PYTHON_NEWEST" ]; then
      uv run pytest || return 1
    elif py=$(cd / && uv python find "$v" 2>/dev/null); then
      uv run --isolated --python "$py" pytest || return 1
    else
      echo "Python $v is not on this machine: the CI tests it, not this check." >&2
    fi
  done
}
