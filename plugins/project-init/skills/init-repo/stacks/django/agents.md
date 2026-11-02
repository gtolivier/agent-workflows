## Commands

- Install: `uv sync`
- Database: `docker compose up -d --wait` (PostgreSQL; its port and
  `DATABASE_URL` are in `.env`)
- Run: `uv run python manage.py runserver`
- Test: `uv run pytest`
- Lint: `uv run ruff check` — format: `uv run ruff format`
- Type check: `uv run --group typecheck mypy` (strict, with django-stubs)
- Django checks: `uv run python manage.py check` and
  `uv run python manage.py makemigrations --check --dry-run` (no model
  change without its migration)

Always go through `uv run`; do not rely on an activated virtualenv.

## Layout

- `config/` — the project: settings, root URLconf, WSGI and ASGI entry
  points.
- `manage.py` — Django's command-line entry point.
- One folder per app, at the root, created with `manage.py startapp`. Each
  app holds its own tests: `tests.py`, or a `tests/` package of
  `test_*.py` files.
- `compose.yaml` — the local PostgreSQL.
- `.env.example` — the local settings that `.env` holds (`.env` is never
  committed).

## Test-driven development

The `/tdd:feature` skill of the
[`tdd` plugin](https://github.com/gtolivier/agent-workflows) builds a
feature test-first, one behavior at a time. Its conventions for this
repository:

- **Test, lint, type-check and format commands:** those of the Commands
  section above.
- **Test files:** `tests.py`, `test_*.py` and everything under a `tests/`
  folder, in `config/` or in an app. Nothing else is a test file.
- **Focused test command:** `uv run pytest {files}`.
