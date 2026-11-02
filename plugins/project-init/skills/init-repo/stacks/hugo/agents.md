## Commands

- Hugo: @RUNTIME@ or later, standard edition, and Go for Hugo modules.
  Node: the major version in `.nvmrc` (`nvm use`, fnm or volta read it).
- Install: `npm ci`, then once per machine
  `npx playwright install chromium` (the browser of the tests)
- Run: `npm start` (`hugo server`, http://localhost:1313/, drafts
  excluded)
- New content: `hugo new content <section>/<name>.md`, from
  `archetypes/`
- Test: `npm test` (Playwright in Chromium and a phone's viewport, with
  axe, against the production build that `hugo server` renders in memory
  on port 1314)
- Lint: `npm run lint` (ESLint: typescript-eslint strict type-checked,
  Playwright's rules; stylelint's standard config on `assets/**/*.css`)
- Format: `npm run format` — check: `npm run format:check` (Prettier;
  not the Go templates of `layouts/` and `archetypes/`)
- Type check: `npm run typecheck` (the tests and `playwright.config.ts`)
- Build: `npm run build` (into `public/`: minified, any Hugo warning
  fails it) — then `npm run validate` (html-validate on the built HTML,
  linkinator on its internal links)

## Layout

- `hugo.toml` — the site's settings: title, menus, and under `[module]`
  the minimum Hugo version and the imported theme module, if any.
  `config/development/` overrides it for `hugo server`.
- `content/` — the pages, in Markdown, one folder per section.
- `layouts/`, `assets/` (CSS and JS, bundled by Hugo), `static/` (served
  as is) — the site's own, or a theme module's, imported in `hugo.toml`
  (`go.mod` and `go.sum` pin its version).
- `archetypes/` — the front matter of `hugo new content`.
- `e2e/` — the Playwright tests of the built site, and the accessibility
  test of every page.

## Test-driven development

The `/tdd:feature` skill of the
[`tdd` plugin](https://github.com/gtolivier/agent-workflows) builds a
feature test-first, one behavior at a time. Its conventions for this
repository:

- **Test, lint, type-check and format commands:** those of the Commands
  section above.
- **Test files:** everything under `e2e/`. Nothing else is a test file:
  a behavior is tested on the built pages.
- **Focused test command:** `npx playwright test {files}`.
