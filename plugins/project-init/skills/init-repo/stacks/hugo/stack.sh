# Stack "hugo": a Hugo site — hugo new theme's starter at the site's root,
# or a theme module imported with theme.sh; npm for the tooling: Prettier,
# stylelint, ESLint (typescript-eslint strict), html-validate, linkinator,
# Playwright with axe. Sourced by init-repo.sh and commit.sh. The functions
# run from inside the repository; STACK_DIR is this folder.

STACK_SUMMARY="Hugo site: Hugo modules, npm, Prettier, stylelint, ESLint (typescript-eslint strict), html-validate, linkinator, Playwright with axe"
HUGO_SITE=.
. "$STACK_DIR/../_hugo/hugo.sh"

# Generate the site with Hugo. Environment: NAME, DESCRIPTION, RUNTIME,
# LICENSE (SPDX id or "none"), MODULE.
stack_generate() {
  hugo_prerequisites
  hugo_gitignore

  # hugo new site writes empty folders and a three-line hugo.toml: the
  # starter theme of hugo new theme is a whole site (layouts, CSS, JS,
  # menus), which theme.sh removes when the site takes a theme of its own.
  tmp=$(mktemp -d)
  hugo new theme starter --themesDir "$tmp" >/dev/null
  cp -R "$tmp/starter/." .
  rm -rf "$tmp"
  # The sample posts and their menus: content of the user's own comes
  # with hugo new content.
  rm -rf content/posts
  replace_block hugo.toml "
  [[menus.main]]
    name = 'Posts'
    pageRef = '/posts'
    weight = 20

  [[menus.main]]
    name = 'Tags'
    pageRef = '/tags'
    weight = 30" ''
  replace_line hugo.toml "title = 'My New Hugo Project'" "title = '$NAME'"
  replace_line hugo.toml "    min = '0.146.0'" "    min = '$RUNTIME'"
  hugo mod init "$MODULE" >/dev/null
  hugo_remove_empty_dirs

  hugo_tooling
}

# Files this stack sets up beyond the common ones, for the register.
stack_managed() {
  printf '%s\n' .nvmrc .prettierignore package.json tsconfig.json eslint.config.mjs \
    playwright.config.ts e2e/accessibility.spec.ts go.mod hugo.toml
}
