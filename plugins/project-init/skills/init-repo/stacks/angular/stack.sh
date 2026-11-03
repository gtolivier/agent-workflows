# Stack "angular": an Angular application — npm, ng new, Vitest in
# Chromium, Playwright with axe, ESLint (angular-eslint), Prettier.
# Sourced by init-repo.sh and commit.sh. The functions run from inside the
# repository; STACK_DIR is this folder.

STACK_SUMMARY="Angular application: npm, Vitest in Chromium, Playwright with axe, ESLint (angular-eslint, typescript-eslint strict), Prettier"
# GitHub's .gitignore template, used when the generator writes none.
GITIGNORE_TEMPLATE=Node
# The runtime version (--runtime): the Node major version of .nvmrc, for
# development and the CI. By default the latest LTS (stack_runtime_default);
# Angular needs 22 or later.
RUNTIME_MIN=22
# The unscoped packages stack_generate adds, jsdom (from ng new) included:
# npm refuses a project that depends on itself.
NODE_DEPENDENCIES="rxjs tslib angular-eslint eslint prettier typescript typescript-eslint vitest jsdom playwright"

# A project name as Angular has it: lowercase words of letters and digits
# joined by '-', starting with a letter. Used as is for the npm package and
# the project of angular.json.
STACK_NAME_RULE="lowercase letters and digits in words joined by single '-', starting with a letter, and none of: $NODE_DEPENDENCIES"
stack_valid_name() {
  printf '%s' "$1" | grep -Eq '^[a-z][a-z0-9]*(-[a-z0-9]+)*$' || return 1
  for dependency in $NODE_DEPENDENCIES; do
    [ "$1" != "$dependency" ] || return 1
  done
}

. "$STACK_DIR/../_node/node.sh"

# The default runtime: the major version of the latest Node LTS.
stack_runtime_default() {
  node_lts_major
}

# Generate the project with its official tools. Environment: NAME,
# DESCRIPTION, RUNTIME, LICENSE (SPDX id or "none").
stack_generate() {
  printf '%s' "$RUNTIME" | grep -Eq '^[0-9]+$' || die "--runtime $RUNTIME: give a Node major version, such as 24"
  node_matches "$RUNTIME" || die "Node $RUNTIME is needed to generate the project"
  export NG_CLI_ANALYTICS=false

  # No SSR: ng add @angular/ssr adds it later. --ai-config writes Angular's
  # best practices for agents, which go into AGENTS.md.
  npx -y @angular/cli@latest new "$NAME" --directory . --skip-git \
    --routing --zoneless --style scss --ssr=false --ai-config claude-code \
    --package-manager npm --interactive=false
  ANGULAR_PRACTICES=$(awk 'started || /^## / { started = 1; sub(/^## /, "### "); print }' CLAUDE.md)
  [ -n "$ANGULAR_PRACTICES" ] || die "CLAUDE.md: no section of best practices — has ng new's --ai-config changed?"
  export ANGULAR_PRACTICES
  # AGENTS.md is the single instruction file; init-repo writes the README.
  rm -f CLAUDE.md .mcp.json README.md

  npx ng add angular-eslint --skip-confirmation --interactive=false \
    --tseslint-preset strictTypeChecked
  # Unit tests in a real browser, not jsdom.
  npx ng add @vitest/browser-playwright --skip-confirmation --interactive=false
  npm uninstall --silent jsdom
  npm init -y playwright@latest -- --quiet --browser=chromium --no-examples \
    --lang=TypeScript --no-browsers
  npm install --silent --save-dev @axe-core/playwright @eslint-community/eslint-plugin-eslint-comments
  npx playwright install chromium

  playwright_config
  # Type-check the e2e tests and playwright.config.ts, which typescript-eslint
  # needs in a project too.
  replace_line tsconfig.json '      "path": "./tsconfig.spec.json"' \
    '      "path": "./tsconfig.spec.json"\n    },\n    {\n      "path": "./e2e/tsconfig.json"'
  replace_line src/main.ts 'bootstrapApplication(App, appConfig).catch((err) => console.error(err));' \
    'bootstrapApplication(App, appConfig).catch((error: unknown) => {\n  console.error(error);\n});'
  eslint_config
  npx ng config "projects.$NAME.architect.lint.options.lintFilePatterns" \
    '["src/**/*.ts","src/**/*.html","e2e/**/*.ts","playwright.config.ts"]'

  # ng new's welcome page is a behavior without a test: the application
  # starts empty, its root component a router outlet.
  replace_line src/app/app.ts "import { Component, signal } from '@angular/core';" \
    "import { Component } from '@angular/core';"
  replace_line src/app/app.ts "  protected readonly title = signal('$NAME');" ''
  echo '<router-outlet />' >src/app/app.html
  cp "$STACK_DIR/app.spec.ts" src/app/app.spec.ts
  stack_render .

  npm pkg set description="$DESCRIPTION" \
    scripts.format='prettier --write .' \
    scripts.format:check='prettier --check .' \
    scripts.typecheck='tsc --noEmit -p tsconfig.app.json && tsc --noEmit -p e2e/tsconfig.json' \
    scripts.test:ci='ng test --headless --watch=false' \
    scripts.e2e='playwright test'
  [ "$LICENSE" = none ] || npm pkg set license="$LICENSE"
  echo "$RUNTIME" >.nvmrc
  npx prettier --write --log-level warn .
}

# Playwright's generated config: tests in e2e/, against ng serve, which it
# starts. process.env['CI']: TypeScript's strict index signature rule.
playwright_config() {
  replace_line playwright.config.ts "  testDir: './tests'," "  testDir: './e2e',"
  replace_line playwright.config.ts '  forbidOnly: !!process.env.CI,' "  forbidOnly: !!process.env['CI'],"
  replace_line playwright.config.ts '  retries: process.env.CI ? 2 : 0,' "  retries: process.env['CI'] ? 2 : 0,"
  replace_line playwright.config.ts '  workers: process.env.CI ? 1 : undefined,' "  workers: process.env['CI'] ? 1 : undefined,"
  # The HTML report for the CI's artifact, without opening a browser.
  replace_line playwright.config.ts "  reporter: 'html'," "  reporter: [['list'], ['html', { open: 'never' }]],"
  replace_line playwright.config.ts "    // baseURL: 'http://localhost:3000'," "    baseURL: 'http://localhost:4200',"
  replace_line playwright.config.ts '  // webServer: {' '  webServer: {'
  replace_line playwright.config.ts "  //   command: 'npm run start'," "    command: 'npm run start',"
  replace_line playwright.config.ts "  //   url: 'http://localhost:3000'," "    url: 'http://localhost:4200',"
  replace_line playwright.config.ts '  //   reuseExistingServer: !process.env.CI,' "    reuseExistingServer: !process.env['CI'],"
  replace_line playwright.config.ts '  // },' '  },'
}

# The clean-code rules, at the end of angular-eslint's config.
eslint_config() {
  replace_line eslint.config.js "const angular = require('angular-eslint');" \
    "const angular = require('angular-eslint');\nconst comments = require('@eslint-community/eslint-plugin-eslint-comments/configs');"
  eslint_rules eslint.config.js
}

# Variables for ci.yml and agents.md: ANGULAR_PRACTICES comes from
# stack_generate, or from stack_repo_env.
stack_render_env() {
  :
}

# ANGULAR_PRACTICES from the AGENTS.md of the repository REPO_DIR, for an
# upgrade: between the markers of agents.md, else (0.6.0 and before) the
# text after the line "Written by `ng new --ai-config`…" up to the next
# section. Kept as is: they change with Angular, not with project-init.
stack_repo_env() {
  f=$REPO_DIR/AGENTS.md
  if [ -f "$f" ] && grep -qx '<!-- project-init:angular-practices -->' "$f"; then
    ANGULAR_PRACTICES=$(awk '$0 == "<!-- /project-init:angular-practices -->" { p = 0 }
      p; $0 == "<!-- project-init:angular-practices -->" { p = 1 }' "$f")
  elif [ -z "${ANGULAR_PRACTICES-}" ] && [ -f "$f" ]; then
    ANGULAR_PRACTICES=$(awk '/^Written by `ng new --ai-config`/ { p = 1; getline; next }
      p && /^## / { exit } p' "$f")
  fi
  export ANGULAR_PRACTICES
}

# The files copied from this stack's templates into the folder $1: run
# again by the upgrade skill, for the version that set a repository up and
# for this one.
stack_render() {
  copy_file "$STACK_DIR/e2e-tsconfig.json" "$1/e2e/tsconfig.json"
  copy_file "$(template accessibility.spec.ts)" "$1/e2e/accessibility.spec.ts"
  # The register is rewritten by project-init's scripts, not by Prettier.
  printf '%s\n' .project-init.yml >"$1/.prettierignore"
}
# The rendered files in $1, formatted by the project's Prettier.
stack_format() { format_prettier "$1"; }

# The CI checks a merge requires, one per line: the job names of ci.yml.
stack_checks() {
  printf '%s\n' lint typecheck test build e2e
}

# Files this stack sets up beyond the common ones, for the register.
stack_managed() {
  printf '%s\n' .nvmrc .prettierignore package.json angular.json tsconfig.json \
    eslint.config.js playwright.config.ts e2e/tsconfig.json e2e/accessibility.spec.ts
}

# Everything the CI checks, locally, on the Node of .nvmrc. CI=true: the
# e2e tests start a server of their own, never reuse one on port 4200.
stack_check() {
  node_matches "$(cat .nvmrc)" || return 1
  export NG_CLI_ANALYTICS=false
  npm ci --silent &&
    npm run --silent lint &&
    npm run --silent format:check &&
    npm run --silent typecheck &&
    npm run --silent test:ci &&
    npm run --silent build &&
    CI=true npm run --silent e2e
}
