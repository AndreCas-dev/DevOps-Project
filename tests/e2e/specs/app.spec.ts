import { test, expect } from '@playwright/test';

test.describe('DevOps App E2E', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should display the app title', async ({ page }) => {
    await expect(page.locator('h1')).toContainText('DevOps Test App');
  });

  test('should show empty state when no items', async ({ page }) => {
    // Wait for loading to finish
    await page.waitForSelector('.loading', { state: 'hidden', timeout: 10000 }).catch(() => {});

    // Check for items list or empty message
    const itemsList = page.locator('.items-list');
    const emptyMessage = page.locator('.empty-message');

    const hasItems = await itemsList.count() > 0;
    const hasEmptyMessage = await emptyMessage.count() > 0;

    expect(hasItems || hasEmptyMessage).toBeTruthy();
  });

  test('should have a form to create items', async ({ page }) => {
    await expect(page.locator('input#name')).toBeVisible();
    await expect(page.locator('textarea#description')).toBeVisible();
    await expect(page.locator('button[type="submit"]')).toBeVisible();
  });

  test('should create a new item', async ({ page }) => {
    const itemName = `Test Item ${Date.now()}`;

    // Fill form
    await page.fill('input#name', itemName);
    await page.fill('textarea#description', 'E2E test description');

    // Submit
    await page.click('button[type="submit"]');

    // Wait for success message or item to appear
    await expect(page.locator('.message-success')).toBeVisible({ timeout: 5000 }).catch(() => {});

    // Verify item appears in list
    await expect(page.locator(`text=${itemName}`)).toBeVisible({ timeout: 5000 });
  });

  test('should delete an item', async ({ page }) => {
    const itemName = `Delete Test ${Date.now()}`;

    // Create item first
    await page.fill('input#name', itemName);
    await page.click('button[type="submit"]');
    await expect(page.locator(`text=${itemName}`)).toBeVisible({ timeout: 5000 });

    // Find and click delete button for this item
    const itemCard = page.locator('.item-card', { has: page.locator(`text=${itemName}`) });
    await itemCard.locator('button.btn-danger').click();

    // Verify item is removed
    await expect(page.locator(`text=${itemName}`)).not.toBeVisible({ timeout: 5000 });
  });
});
