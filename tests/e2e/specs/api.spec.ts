import { test, expect } from '@playwright/test';

test.describe('API E2E Tests', () => {
  const apiUrl = process.env.API_URL || 'http://localhost:8000';

  test('health endpoint returns healthy status', async ({ request }) => {
    const response = await request.get(`${apiUrl}/health`);

    expect(response.ok()).toBeTruthy();

    const body = await response.json();
    expect(body).toHaveProperty('status');
    expect(body).toHaveProperty('version');
  });

  test('root endpoint returns API info', async ({ request }) => {
    const response = await request.get(`${apiUrl}/`);

    expect(response.ok()).toBeTruthy();

    const body = await response.json();
    expect(body.message).toBe('DevOps Test API');
    expect(body.status).toBe('running');
  });

  test('metrics endpoint returns prometheus metrics', async ({ request }) => {
    const response = await request.get(`${apiUrl}/metrics`);

    expect(response.ok()).toBeTruthy();

    const text = await response.text();
    expect(text).toContain('http_requests_total');
  });

  test('CRUD operations on items', async ({ request }) => {
    // Create
    const createResponse = await request.post(`${apiUrl}/items`, {
      data: {
        name: `E2E Test Item ${Date.now()}`,
        description: 'Created by Playwright E2E test',
      },
    });
    expect(createResponse.status()).toBe(201);

    const createdItem = await createResponse.json();
    expect(createdItem).toHaveProperty('id');
    expect(createdItem).toHaveProperty('name');

    // Read
    const getResponse = await request.get(`${apiUrl}/items`);
    expect(getResponse.ok()).toBeTruthy();

    const items = await getResponse.json();
    expect(Array.isArray(items)).toBeTruthy();
    expect(items.some((item: any) => item.id === createdItem.id)).toBeTruthy();

    // Delete
    const deleteResponse = await request.delete(`${apiUrl}/items/${createdItem.id}`);
    expect(deleteResponse.status()).toBe(204);

    // Verify deletion
    const deleteAgain = await request.delete(`${apiUrl}/items/${createdItem.id}`);
    expect(deleteAgain.status()).toBe(404);
  });

  test('validation - empty name returns 400', async ({ request }) => {
    const response = await request.post(`${apiUrl}/items`, {
      data: {
        description: 'No name provided',
      },
    });

    expect(response.status()).toBe(400);

    const body = await response.json();
    expect(body.error).toBe('Name is required');
  });
});
