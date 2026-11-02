- **Dependencies:** add or remove them with `npm install` /
  `npm uninstall`, or `ng add` for a package with a schematic, never by
  editing `package.json` by hand — a manual edit leaves
  `package-lock.json` stale.
- **Generated files:** when an official tool can produce a file, use it
  instead of writing the file: `ng generate` (component, service, guard…),
  `ng add`, `ng update` for Angular's versions and their migrations,
  `npm run format`, `npx ng lint --fix`.
- **Clean code, enforced where a tool can:** TypeScript runs in strict
  mode; ESLint flags magic numbers (outside tests), complexity, extraneous
  classes, unsafe `any`s and floating promises (typescript-eslint's strict
  type-checked rules), Angular's conventions and template accessibility.
  An `eslint-disable` comment must name the rule it silences and say why
  after `--` (ESLint enforces it, and reports one that silences nothing);
  so must a `@ts-expect-error`.
- **Styles:** native CSS first (nesting, custom properties); Sass only for
  what CSS lacks, mixins and functions, through `@use`, never `@import`.
- **Accessibility:** WCAG 2.2 AA. `e2e/accessibility.spec.ts` runs axe on
  each page: add a test there for every new page or state of a page.
- **Supported versions:** Node @RUNTIME@ (`.nvmrc`, which the CI reads).
  Angular moves with `ng update`, never by editing versions by hand.
