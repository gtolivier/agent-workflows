## Commands

- Install: `uv sync`
- Test: `uv run pytest`
- Lint: `uv run ruff check` — format: `uv run ruff format`
- Type check: `uv run --group typecheck mypy` (strict)

Always go through `uv run`; do not rely on an activated virtualenv.

## Layout

- `src/@PACKAGE@/` — the package (src layout: tests run against the
  installed package, not the working directory).
- `tests/` — pytest tests (`test_*.py`).

## Test-driven development

The `/tdd:feature` skill of the `tdd` plugin builds a feature test-first,
one behavior at a time. Its conventions for this repository:

- **Test, lint, type-check and format commands:** those of the Commands
  section above.
- **Test files:** everything under `tests/`. Nothing outside `tests/` is a
  test file.
- **Focused test command:** `uv run pytest {files}`.
