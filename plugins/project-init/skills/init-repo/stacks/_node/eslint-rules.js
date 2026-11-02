  // Clean code, enforced where a tool can (added by project-init).
  {
    linterOptions: {
      reportUnusedDisableDirectives: 'error',
    },
  },
  {
    files: ['**/*.ts'],
    extends: [comments.recommended],
    rules: {
      complexity: ['error', 10],
      // A class a framework decorates (an Angular component, directive or
      // service) may need no member of its own.
      '@typescript-eslint/no-extraneous-class': ['error', { allowWithDecorator: true }],
      '@typescript-eslint/no-magic-numbers': [
        'error',
        {
          ignore: [-1, 0, 1],
          ignoreEnums: true,
          ignoreNumericLiteralTypes: true,
          ignoreReadonlyClassProperties: true,
          ignoreTypeIndexes: true,
        },
      ],
      // Every eslint-disable comment says why.
      '@eslint-community/eslint-comments/require-description': 'error',
    },
  },
  // Literal examples are what tests are made of.
  {
    files: ['**/*.spec.ts', 'e2e/**/*.ts', 'playwright.config.ts'],
    rules: {
      '@typescript-eslint/no-magic-numbers': 'off',
    },
  },
