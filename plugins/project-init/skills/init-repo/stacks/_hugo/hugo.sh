# Shared by the stacks "hugo" (a site) and "hugo-theme" (a theme, a Hugo
# module): sourced by their stack.sh once it has set HUGO_SITE, the folder
# of the site Hugo builds ("." for a site, "exampleSite" for a theme).
# Not a stack itself: init-repo lists no folder whose name starts with "_".
# init-repo takes the templates a stack's folder lacks (ci.yml, rules.md)
# from here, SHARED_DIR.

. "$STACK_DIR/../_node/node.sh"
HUGO_DIR=$STACK_DIR/../_hugo
SHARED_DIR=$HUGO_DIR

# GitHub's .gitignore template; hugo_gitignore adds Hugo's.
GITIGNORE_TEMPLATE=Node
# The runtime version (--runtime): Hugo's, the minimum of
# module.hugoVersion and the version the CI installs. By default the
# latest release (stack_runtime_default). hugo new theme writes 0.146.0 as
# its minimum, but its templates call css.Build, new in 0.158.0.
RUNTIME_MIN=0.158.0
# The unscoped packages stack_generate adds: npm refuses a project that
# depends on itself.
HUGO_NODE_DEPENDENCIES="eslint globals html-validate linkinator prettier stylelint stylelint-config-standard typescript typescript-eslint eslint-plugin-playwright playwright"
# The port of the server the end-to-end tests start: not hugo server's
# 1313, which npm start may hold.
HUGO_TEST_PORT=1314

# A name npm takes for the package: lowercase letters, digits, '.', '_' and
# '-', starting with a letter or a digit.
STACK_NAME_RULE="lowercase letters, digits, '.', '_' and '-', starting with a letter or a digit, and none of: $HUGO_NODE_DEPENDENCIES"
stack_valid_name() {
  printf '%s' "$1" | grep -Eq '^[a-z0-9][a-z0-9._-]*$' || return 1
  for dependency in $HUGO_NODE_DEPENDENCIES; do
    [ "$1" != "$dependency" ] || return 1
  done
}

# The default runtime: the latest Hugo release.
stack_runtime_default() {
  curl -fsSL --max-time 30 https://api.github.com/repos/gohugoio/hugo/releases/latest |
    jq -er '.tag_name | ltrimstr("v")'
}

# Fail unless the Hugo on PATH is version $1 or later, and Go, which Hugo
# modules need, is there.
hugo_matches() {
  command -v hugo >/dev/null || {
    echo "Hugo $1 or later is missing: install it (https://gohugo.io/installation/)." >&2
    return 1
  }
  current=$(hugo version | sed -E 's/^hugo v([0-9.]+).*/\1/')
  [ "$(printf '%s\n%s\n' "$1" "$current" | sort -V | head -n 1)" = "$1" ] || {
    echo "Hugo $current is on PATH, the project needs $1 or later: upgrade it." >&2
    return 1
  }
  command -v go >/dev/null || {
    echo "Go is missing: Hugo modules need it (https://go.dev/doc/install)." >&2
    return 1
  }
}

# The module path: the remote without its scheme, user, port and ".git"
# (github.com/owner/name), else the name alone.
hugo_module_path() {
  if [ -z "${REMOTE-}" ]; then
    printf '%s\n' "$NAME"
  else
    printf '%s\n' "$REMOTE" |
      sed -E 's#^([a-z+]+://([^@/]*@)?[^/:]+):[0-9]+/#\1/#; s#^[a-z+]+://##; s#^[^@/]*@##
        s#^([^/:]+):#\1/#; s#/$##; s#\.git$##'
  fi
}

# Variables for the templates: MODULE, the module path.
stack_render_env() {
  MODULE=$(hugo_module_path)
  export MODULE
}

# Fail early, before any generator runs, unless the runtime is a version
# and the tools are there.
hugo_prerequisites() {
  printf '%s' "$RUNTIME" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' ||
    die "--runtime $RUNTIME: give a Hugo version, such as 0.169.0"
  hugo_matches "$RUNTIME" || die "Hugo $RUNTIME is needed to generate the project"
  NODE_MAJOR=$(node_lts_major) || die "could not find the latest Node LTS"
  node_matches "$NODE_MAJOR" || die "Node $NODE_MAJOR is needed to generate the project"
}

# .gitignore: GitHub's Node template and its community Hugo one, written
# before npm init playwright, which writes one of its own when none exists.
hugo_gitignore() {
  {
    curl -fsSL --max-time 30 "https://api.github.com/gitignore/templates/$GITIGNORE_TEMPLATE" |
      jq -er .source &&
      echo &&
      curl -fsSL --max-time 30 https://raw.githubusercontent.com/github/gitignore/main/community/Golang/Hugo.gitignore
  } >.gitignore || die "could not download GitHub's Node and Hugo .gitignore templates"
  [ "$HUGO_SITE" = . ] ||
    printf '\n# The demo site'"'"'s build\n/%s/public/\n/%s/resources/_gen/\n/%s/.hugo_build.lock\n' \
      "$HUGO_SITE" "$HUGO_SITE" "$HUGO_SITE" >>.gitignore
}

# hugo's flags for the folder of the site, if not ".".
hugo_source() {
  [ "$HUGO_SITE" = . ] || printf ' --source %s' "$HUGO_SITE"
}

# npm, Prettier, stylelint, ESLint (typescript-eslint strict type-checked),
# TypeScript, html-validate, linkinator, Playwright with axe.
hugo_tooling() {
  npm init -y >/dev/null
  npm pkg delete main scripts.test keywords author
  # ES modules, which TypeScript's verbatimModuleSyntax expects.
  npm pkg set private=true --json
  npm pkg set type=module description="$DESCRIPTION"
  if [ "$LICENSE" = none ]; then npm pkg delete license; else npm pkg set license="$LICENSE"; fi
  echo "$NODE_MAJOR" >.nvmrc

  # Its closing message names an example test --no-examples leaves out.
  npm init -y playwright@latest -- --quiet --browser=chromium --no-examples \
    --lang=TypeScript --no-browsers >/dev/null
  # npm init playwright sets "commonjs".
  npm pkg set type=module
  npm install --silent --save-dev @axe-core/playwright @eslint/js \
    @eslint-community/eslint-plugin-eslint-comments eslint \
    eslint-plugin-playwright globals html-validate linkinator prettier \
    stylelint stylelint-config-standard typescript@~6.0 typescript-eslint
  npx playwright install chromium
  playwright_config
  mkdir -p e2e
  cp "$NODE_DIR/accessibility.spec.ts" e2e/accessibility.spec.ts

  # TypeScript checks the end-to-end tests and playwright.config.ts.
  npx tsc --init --types node --noEmit --sourceMap false --declaration false \
    --declarationMap false >/dev/null
  # No CLI writes an ESLint flat config without asking: the template is
  # written here, then gets the clean-code rules.
  cp "$HUGO_DIR/eslint.config.mjs" eslint.config.mjs
  eslint_rules eslint.config.mjs
  # Go templates and the register are not Prettier's.
  printf '%s\n' .project-init.yml layouts/ archetypes/ >.prettierignore
  npm pkg set prettier.singleQuote=true --json
  npm pkg set stylelint.extends=stylelint-config-standard

  source=$(hugo_source)
  public=$HUGO_SITE/public
  [ "$HUGO_SITE" != . ] || public=public
  npm pkg set \
    scripts.start="hugo server$source" \
    scripts.build="hugo build$source --gc --minify --cleanDestinationDir --panicOnWarning --printPathWarnings --printI18nWarnings" \
    scripts.validate="html-validate --preset standard,a11y $public && linkinator $public --recurse --verbosity error --skip '^(?!http://(localhost|127\\.0\\.0\\.1)[:/])'" \
    scripts.lint="eslint . && stylelint 'assets/**/*.css' --allow-empty-input" \
    scripts.format='prettier --write .' \
    scripts.format:check='prettier --check .' \
    scripts.typecheck=tsc \
    scripts.test='playwright test'
  npx stylelint 'assets/**/*.css' --fix --allow-empty-input
  npx prettier --write --log-level warn .
}

# Playwright's generated config: tests in e2e/, on Chromium and a phone,
# against the production build hugo server holds in memory.
playwright_config() {
  replace_line playwright.config.ts "  testDir: './tests'," "  testDir: './e2e',"
  # The HTML report for the CI's artifact, without opening a browser.
  replace_line playwright.config.ts "  reporter: 'html'," "  reporter: [['list'], ['html', { open: 'never' }]],"
  replace_line playwright.config.ts "    // baseURL: 'http://localhost:3000'," \
    "    baseURL: 'http://localhost:$HUGO_TEST_PORT',"
  # exactOptionalPropertyTypes (tsc --init) refuses undefined: 50% of the
  # cores is Playwright's default.
  replace_line playwright.config.ts '  workers: process.env.CI ? 1 : undefined,' \
    "  workers: process.env.CI ? 1 : '50%',"
  replace_block playwright.config.ts '    /* Test against mobile viewports. */
    // {
    //   name: '"'Mobile Chrome'"',
    //   use: { ...devices['"'Pixel 5'"'] },
    // },' '    /* Test against mobile viewports. */
    {
      name: '"'Mobile Chrome'"',
      use: { ...devices['"'Pixel 5'"'] },
    },'
  replace_block playwright.config.ts '  /* Run your local dev server before starting the tests */
  // webServer: {
  //   command: '"'npm run start'"',
  //   url: '"'http://localhost:3000'"',
  //   reuseExistingServer: !process.env.CI,
  // },' "  /* The production build, rendered in memory, without live reload. */
  webServer: {
    command:
      'hugo server$(hugo_source) --environment production --renderToMemory --disableLiveReload --port $HUGO_TEST_PORT',
    url: 'http://localhost:$HUGO_TEST_PORT',
    reuseExistingServer: !process.env.CI,
  },"
}

# Remove the empty folders the generators leave: git keeps none.
hugo_remove_empty_dirs() {
  find . -path ./.git -prune -o -path ./node_modules -prune -o -type d -empty -print |
    while read -r empty; do rmdir "$empty"; done
}

# The CI checks a merge requires, one per line: the job names of ci.yml.
stack_checks() {
  printf '%s\n' lint typecheck build test
}

# Everything the CI checks, locally, on the Node of .nvmrc and a Hugo of
# the runtime or later. CI=true: the tests start a server of their own,
# never reuse one.
stack_check() {
  node_matches "$(cat .nvmrc)" && hugo_matches "$RUNTIME" || return 1
  npm ci --silent &&
    npm run --silent lint &&
    npm run --silent format:check &&
    npm run --silent typecheck &&
    npm run --silent build &&
    npm run --silent validate &&
    CI=true npm run --silent test
}
