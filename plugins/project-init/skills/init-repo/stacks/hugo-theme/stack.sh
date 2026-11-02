# Stack "hugo-theme": a Hugo theme, published as a Hugo module, with a demo
# site in exampleSite/ — hugo new theme; npm for the tooling: Prettier,
# stylelint, ESLint (typescript-eslint strict), html-validate, linkinator,
# Playwright with axe on the demo site. Sourced by init-repo.sh and
# commit.sh. The functions run from inside the repository; STACK_DIR is
# this folder.

STACK_SUMMARY="Hugo theme (a Hugo module) with a demo site: npm, Prettier, stylelint, ESLint (typescript-eslint strict), html-validate, linkinator, Playwright with axe"
HUGO_SITE=exampleSite
. "$STACK_DIR/../_hugo/hugo.sh"

# Generate the theme with Hugo. Environment: NAME, DESCRIPTION, RUNTIME,
# LICENSE (SPDX id or "none"), MODULE.
stack_generate() {
  hugo_prerequisites
  hugo_gitignore

  tmp=$(mktemp -d)
  hugo new theme "$NAME" --themesDir "$tmp" >/dev/null
  cp -R "$tmp/$NAME/." .
  rm -rf "$tmp"
  # hugo new theme writes a site: its content and its settings become the
  # demo site, which imports the theme; the theme keeps [module].
  mkdir exampleSite
  mv content exampleSite/
  grep -q '^\[module\]$' hugo.toml || die "hugo.toml: no [module] — has hugo new theme changed?"
  awk '/^\[module\]$/ { exit } { print }' hugo.toml >exampleSite/hugo.toml
  render "$STACK_DIR/exampleSite.toml" >>exampleSite/hugo.toml
  awk '/^\[module\]$/ { p = 1 } p' hugo.toml >hugo.toml.new
  mv hugo.toml.new hugo.toml
  replace_line exampleSite/hugo.toml "title = 'My New Hugo Project'" "title = '$NAME'"
  replace_line hugo.toml "    min = '0.146.0'" "    min = '$RUNTIME'"
  hugo mod init "$MODULE" >/dev/null
  hugo_remove_empty_dirs

  hugo_tooling
}

# Files this stack sets up beyond the common ones, for the register.
stack_managed() {
  printf '%s\n' .nvmrc .prettierignore package.json tsconfig.json eslint.config.mjs \
    playwright.config.ts e2e/accessibility.spec.ts go.mod hugo.toml exampleSite/hugo.toml
}
