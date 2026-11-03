## Commands

- Hugo: @RUNTIME@ or later, standard edition, and Go for Hugo modules.
  Node: the major version in `.nvmrc` (`nvm use`, fnm or volta read it).
- Install: `npm ci`, then once per machine
  `npx playwright install chromium` (the browser of the tests)
- Run: `npm start` (`hugo server` on the demo site, http://localhost:1313/)
- Test: `npm test` (Playwright in Chromium and a phone's viewport, with
  axe, against the demo site's production build, which `hugo server`
  renders in memory on port 1314)
- Lint: `npm run lint` (ESLint: typescript-eslint strict type-checked,
  Playwright's rules; stylelint's standard config on `assets/**/*.css`)
- Format: `npm run format` — check: `npm run format:check` (Prettier;
  not the Go templates of `layouts/` and `archetypes/`)
- Type check: `npm run typecheck` (the tests and `playwright.config.ts`)
- Build: `npm run build` (the demo site, into `exampleSite/public/`:
  minified, any Hugo warning fails it) — then `npm run validate`
  (html-validate on the built HTML, linkinator on its internal links)

## Layout

A Hugo theme, published as the Hugo module `@MODULE@`: sites import it
under `[module]` in their `hugo.toml`, and get a version with
`hugo mod get @MODULE@@<tag or commit>`.

- `hugo.toml` — the theme's settings: under `[module]`, the minimum Hugo
  version.
- `layouts/`, `assets/` (CSS and JS, which Hugo bundles), `static/`
  (served as is), `archetypes/` — what the theme gives a site.
- `exampleSite/` — the demo site the build and the tests use: its
  `hugo.toml` imports the theme from this folder. Its content shows every
  layout the theme has.
- `e2e/` — the Playwright tests of the demo site, and the accessibility
  tests (axe), one per page.

## Test-driven development

The `/tdd:feature` skill of the `tdd` plugin builds a feature test-first,
one behavior at a time. Its conventions for this repository:

- **Test, lint, type-check and format commands:** those of the Commands
  section above.
- **Test files:** everything under `e2e/`. Nothing else is a test file:
  a behavior is tested on the built pages.
- **Focused test command:** `npx playwright test {files}`.
