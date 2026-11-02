## Commands

- Node: the major version in `.nvmrc` (`nvm use`, fnm or volta read it)
- Install: `npm install`, then once per machine `npx playwright install chromium`
  (the browser of the unit and end-to-end tests)
- Run: `npm start` (http://localhost:4200/)
- Test: `npm run test:ci` (Vitest in headless Chromium, once) — `npm test`
  watches
- End-to-end tests: `npm run e2e` (Playwright in Chromium, against the
  server it starts, with axe)
- Lint: `npm run lint` (ESLint: angular-eslint, typescript-eslint strict
  type-checked)
- Format: `npm run format` — check: `npm run format:check` (Prettier)
- Type check: `npm run typecheck` (the application and the e2e tests;
  `ng test` type-checks the specs and the templates it compiles)
- Build: `npm run build` (production build, AOT)

## Layout

- `src/app/` — the application: one folder per feature, created with
  `ng generate`. Each `*.spec.ts` sits next to the file it tests.
- `e2e/` — the Playwright tests of the assembled application, and the
  accessibility test of every page.
- `public/` — static files, served as is.
- No server-side rendering: `ng add @angular/ssr` adds it.

## Angular best practices

Written by `ng new --ai-config` for this version of Angular.

@ANGULAR_PRACTICES@

## Test-driven development

The `/tdd:feature` skill of the
[`tdd` plugin](https://github.com/gtolivier/agent-workflows) builds a
feature test-first, one behavior at a time. Its conventions for this
repository:

- **Test, lint, type-check and format commands:** those of the Commands
  section above.
- **Test files:** the `*.spec.ts` files under `src/`, and everything under
  `e2e/`. The e2e tests check the assembled application, outside the TDD
  cycles.
- **Focused test command:**
  `npm run test:ci -- $(printf -- '--include %s ' {files})`.
