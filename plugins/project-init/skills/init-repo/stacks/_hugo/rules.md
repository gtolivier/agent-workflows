- **Dependencies:** add or remove npm packages with `npm install` /
  `npm uninstall`, Hugo modules with `hugo mod get` then `hugo mod tidy`,
  never by editing `package.json` or `go.mod` by hand — a manual edit
  leaves `package-lock.json` or `go.sum` stale.
- **Generated files:** when an official tool can produce a file, use it
  instead of writing the file: `hugo new content` (from the archetypes),
  `hugo mod get` / `hugo mod tidy`, `npm run format`,
  `npx stylelint --fix`, `npx eslint --fix`.
- **Templates:** Hugo's current layout (`layouts/home.html`,
  `page.html`, `section.html`, `_partials/`…), never the pre-0.146
  `_default/` and `partials/` folders. Hugo warnings fail the build
  (`--panicOnWarning`): fix them, never silence them.
- **Clean code, enforced where a tool can:** TypeScript runs in strict
  mode; ESLint flags magic numbers (outside tests), complexity, unsafe
  `any`s and floating promises (typescript-eslint's strict type-checked
  rules) and Playwright's pitfalls; stylelint applies its standard
  config; html-validate checks the built HTML, and linkinator its internal
  links. An `eslint-disable` comment must name the rule it silences and
  say why after `--` (ESLint enforces it, and reports one that silences
  nothing); a `@ts-expect-error` must say why too (typescript-eslint
  enforces it).
- **Styles and scripts:** native CSS (nesting, custom properties) and
  plain JavaScript in `assets/`, bundled by Hugo (`css.Build`,
  `js.Build`); no Sass, no npm bundler.
- **Accessibility:** WCAG 2.2 AA. `e2e/accessibility.spec.ts` runs axe on
  each page: add a test there for every new page or state of a page.
- **Supported versions:** Hugo @RUNTIME@ and later, standard edition —
  keep `min` under `[module.hugoVersion]` in `hugo.toml` and the CI's
  `HUGO_VERSION` in sync. Node: the major version in `.nvmrc`, which the
  CI reads.
