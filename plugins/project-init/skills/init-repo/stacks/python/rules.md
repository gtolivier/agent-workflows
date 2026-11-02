- **Dependencies:** add or remove them with `uv add` / `uv remove`, never by
  editing `pyproject.toml` by hand — a manual edit leaves `uv.lock` stale.
- **Generated files:** when an official tool can produce a file (`uv init`,
  `uv add`, `ruff format`, `ruff check --fix`…), use it instead of writing
  the file.
- **Clean code, enforced where a tool can:** ruff flags magic values in
  comparisons (numbers and strings, outside `tests/`), complexity, naming,
  unused arguments and commented-out code; mypy runs in strict mode, so
  every function is annotated. A `# noqa` or `# type: ignore` must name
  the error it silences (both tools enforce it) and come with a comment
  saying why.
- **Supported versions:** Python @RUNTIME@ and later. Keep `requires-python`,
  mypy's `python_version` and the CI matrix, if any, in sync when this
  changes.
