// @ts-check
import eslint from '@eslint/js';
import comments from '@eslint-community/eslint-plugin-eslint-comments/configs';
import playwright from 'eslint-plugin-playwright';
import { defineConfig, globalIgnores } from 'eslint/config';
import globals from 'globals';
import tseslint from 'typescript-eslint';

export default defineConfig([
  globalIgnores(['**/public/', '**/resources/', 'playwright-report/', 'test-results/']),
  eslint.configs.recommended,
  // The site's scripts, bundled by Hugo's js.Build for the browser.
  {
    files: ['assets/js/**/*.js'],
    extends: [comments.recommended],
    languageOptions: { globals: globals.browser },
    rules: {
      complexity: ['error', 10],
      'no-magic-numbers': ['error', { ignore: [-1, 0, 1] }],
      '@eslint-community/eslint-comments/require-description': 'error',
    },
  },
  {
    files: ['**/*.ts'],
    extends: [tseslint.configs.strictTypeChecked],
    languageOptions: {
      globals: globals.node,
      parserOptions: { projectService: true },
    },
  },
  {
    files: ['e2e/**/*.ts'],
    extends: [playwright.configs['flat/recommended']],
  },
]);
