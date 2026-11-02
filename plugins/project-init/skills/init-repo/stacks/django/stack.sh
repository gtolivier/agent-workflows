# Stack "django": a Django site — uv, django-admin startproject, PostgreSQL,
# django-environ, pytest-django, ruff, mypy (strict) with django-stubs.
# Sourced by init-repo.sh and commit.sh. The functions run from inside the
# repository; STACK_DIR is this folder.

STACK_SUMMARY="Django site: uv, PostgreSQL, django-environ, pytest-django, ruff, mypy (strict)"
# GitHub's .gitignore template, used when the generator writes none.
GITIGNORE_TEMPLATE=Python
# The runtime version (--runtime): the oldest supported Python. Django 6
# needs 3.12: an older one would resolve an older Django, out of step with
# django-stubs.
RUNTIME_DEFAULT=3.12
RUNTIME_MIN=3.12
# The newest Python, for development and the CI. Bump it when one is out.
PYTHON_NEWEST=3.14
# The PostgreSQL major version of compose.yaml and the CI. Bump it when one
# is out.
POSTGRES_VERSION=18
# The packages stack_generate adds, PEP 503-normalized: no project may
# take their name.
PYTHON_DEPENDENCIES="django django-environ psycopg pytest pytest-django ruff django-stubs mypy"

. "$STACK_DIR/../_python/python.sh"

# Generate the project with its official tools. Environment: NAME,
# DESCRIPTION, RUNTIME, LICENSE (SPDX id or "none"), and the variables of
# stack_render_env.
stack_generate() {
  # --bare: a site is not a package, and uv's sample files would be
  # deleted right away.
  uv init --quiet --bare --name "$NAME" --description "$DESCRIPTION" \
    --vcs none --author-from git --no-workspace --python "$RUNTIME" .
  uv python pin --quiet "$PYTHON_NEWEST"
  uv add --quiet django django-environ 'psycopg[binary]'
  uv add --quiet --dev pytest pytest-django ruff
  uv add --quiet --group typecheck 'django-stubs[compatible-mypy]'
  uv run --quiet django-admin startproject config .

  django_settings config/settings.py
  # Annotations for mypy's strict mode.
  replace_line manage.py 'def main():' 'def main() -> None:'
  render "$STACK_DIR/test_settings.py" >config/tests.py

  # Local settings: .env.example is committed, .env (ignored by git) gets
  # a secret key of its own.
  render "$STACK_DIR/env.example" >.env.example
  key=$(uv run --quiet python -c 'import secrets; print(secrets.token_urlsafe(50))')
  # Readable by its owner only: it holds the key.
  (umask 077 && awk -v key="$key" '/^DJANGO_SECRET_KEY=/ { print "DJANGO_SECRET_KEY=" key; next } { print }' \
    .env.example >.env)
  render "$STACK_DIR/compose.yaml" >compose.yaml

  # Tool settings: no CLI writes them.
  render "$STACK_DIR/pyproject.toml" >>pyproject.toml
  python_license
  # Django's code style is not ruff's: sort the imports, then format.
  uv run --quiet ruff check --fix --quiet --exit-zero
  uv run --quiet ruff format --quiet
}

# Replace a whole line of a generated file, and fail if the generator no
# longer writes it.
replace_line() {
  awk -v old="$2" -v new="$3" '$0 == old { print new; n++; next } { print }
    END { exit n != 1 }' "$1" >"$1.new" ||
    die "$1: expected the line '$2' once — has Django's template changed?"
  mv "$1.new" "$1"
}

# The generated settings read the values that differ between environments
# from the environment, through django-environ; .env provides them
# locally. Fails if a line to replace is not there.
django_settings() {
  awk '
    function done(k) { if (k in seen) bad = 1; else n++; seen[k] = 1 }
    $0 == "from pathlib import Path" {
      print; print ""; print "import environ"; done("import"); next
    }
    $0 == "BASE_DIR = Path(__file__).resolve().parent.parent" {
      print
      print ""
      print "# The values that differ between environments come from environment variables,"
      print "# else from .env (never committed: .env.example lists them)."
      print "env = environ.Env()"
      print "environ.Env.read_env(BASE_DIR / \".env\")"
      done("env"); next
    }
    /^SECRET_KEY = / { print "SECRET_KEY = env.str(\"DJANGO_SECRET_KEY\")"; done("key"); next }
    $0 == "DEBUG = True" { print "DEBUG = env.bool(\"DJANGO_DEBUG\", default=False)"; done("debug"); next }
    $0 == "ALLOWED_HOSTS = []" {
      print "ALLOWED_HOSTS = env.list(\"DJANGO_ALLOWED_HOSTS\", default=[])"; done("hosts"); next
    }
    $0 == "DATABASES = {" { db = 1; next }
    db { if ($0 == "}") { print "DATABASES = {\"default\": env.db(\"DATABASE_URL\")}"; db = 0; done("db") }; next }
    { print }
    END { exit bad || n != 6 }
  ' "$1" >"$1.new" || die "$1: a line to replace is missing — has Django's template changed?"
  mv "$1.new" "$1"
}

# Variables for the templates.
stack_render_env() {
  python_render_env
  DB_NAME=$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n' '_')
  export DB_NAME POSTGRES_VERSION
}

# The CI checks a merge requires, one per line: the job names of ci.yml.
stack_checks() {
  echo lint
  echo typecheck
  python_test_checks
}

# Files this stack sets up beyond the common ones, for the register.
stack_managed() {
  printf '%s\n' pyproject.toml .python-version compose.yaml .env.example \
    config/settings.py config/tests.py
}

# Everything the CI checks, locally, with the tests on each Python of the
# CI. The database must be running.
stack_check() {
  # Only .gitignore keeps the secret key of .env out of the commits.
  git check-ignore -q .env || {
    echo ".env holds the secret key, and git does not ignore it: add it to .gitignore." >&2
    return 1
  }
  uv lock --check &&
    uv run ruff check &&
    uv run ruff format --check &&
    uv run --group typecheck mypy || return 1
  if ! error=$(uv run python manage.py shell -c \
    'from django.db import connection; connection.ensure_connection()' 2>&1 >/dev/null); then
    echo "The database at DATABASE_URL (.env) does not answer: $(printf '%s\n' "$error" | tail -n 1)" >&2
    echo "Start it with 'docker compose up -d --wait', or point DATABASE_URL to another" \
      "PostgreSQL where the database exists (createdb)." >&2
    return 1
  fi
  python_each 'python manage.py check --database default &&
    python manage.py makemigrations --check --dry-run &&
    pytest'
}
