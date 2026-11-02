import AxeBuilder from '@axe-core/playwright';
import { expect, test } from '@playwright/test';

// Every page passes axe's WCAG 2.2 AA rules: add a test for each new page.
test('home page has no accessibility violation', async ({ page }) => {
  await page.goto('/');
  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
    .analyze();
  expect(results.violations).toEqual([]);
});
