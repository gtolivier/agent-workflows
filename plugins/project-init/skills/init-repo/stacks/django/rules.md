- **Dependencies:** add or remove them with `uv add` / `uv remove`, never by
  editing `pyproject.toml` by hand — a manual edit leaves `uv.lock` stale.
- **Generated files:** when an official tool can produce a file, use it
  instead of writing the file:
  - `config/` comes from `django-admin startproject config .`: change its
    files, never recreate them by hand.
  - A new app: `uv run python manage.py startapp <name>`, then add it to
    `INSTALLED_APPS` and run `uv run ruff check --fix` and
    `uv run ruff format` over it.
  - Migrations: `uv run python manage.py makemigrations`, never written by
    hand, then `uv run ruff format`; commit them with the model change.
    Squash them with `squashmigrations`.
  - Otherwise: `uv add`, `ruff format`, `ruff check --fix`…
- **Settings and secrets:** the values that differ between environments
  (secret key, debug, allowed hosts, database) come from environment
  variables, read in `config/settings.py` through django-environ; `.env`
  provides them locally and is never committed. A new one goes in
  `.env.example` (never with a secret value), in the CI's `env` and in the
  settings. `DJANGO_SECRET_KEY` has no default: never give it one.
- **Clean code, enforced where a tool can:** ruff flags magic values in
  comparisons (numbers and strings, outside tests), complexity, naming,
  unused arguments, commented-out code and departures from Django's
  conventions (its `DJ` rules); mypy runs in strict mode with django-stubs,
  so every function is annotated. A `# noqa` or `# type: ignore` must name
  the error it silences (both tools enforce it) and come with a comment
  saying why.
- **Supported versions:** Python @RUNTIME@ and later — keep
  `requires-python`, mypy's `python_version` and the CI matrix in sync
  when this changes. PostgreSQL @POSTGRES_VERSION@ — keep `compose.yaml`
  and the CI's `postgres` service in sync.
