import request from 'supertest';
import { app } from '../src/index';

// Mock the database module
jest.mock('../src/database', () => ({
  pool: {
    query: jest.fn(),
  },
  initDatabase: jest.fn().mockResolvedValue(undefined),
  checkConnection: jest.fn().mockResolvedValue(true),
}));

import { pool, checkConnection } from '../src/database';

const mockPool = pool as jest.Mocked<typeof pool>;
const mockCheckConnection = checkConnection as jest.MockedFunction<typeof checkConnection>;

describe('API Routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('GET /', () => {
    it('should return API info', async () => {
      const response = await request(app).get('/');

      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        message: 'DevOps Test API',
        status: 'running',
        docs: '/docs',
      });
    });
  });

  describe('GET /health', () => {
    it('should return healthy when database is connected', async () => {
      mockCheckConnection.mockResolvedValue(true);

      const response = await request(app).get('/health');

      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        status: 'healthy',
        database: 'connected',
        version: '1.0.0',
      });
    });

    it('should return unhealthy when database is disconnected', async () => {
      mockCheckConnection.mockResolvedValue(false);

      const response = await request(app).get('/health');

      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        status: 'unhealthy',
        database: 'disconnected',
        version: '1.0.0',
      });
    });
  });

  describe('GET /metrics', () => {
    it('should return prometheus metrics', async () => {
      const response = await request(app).get('/metrics');

      expect(response.status).toBe(200);
      expect(response.headers['content-type']).toMatch(/text\/plain/);
    });
  });

  describe('GET /items', () => {
    it('should return list of items', async () => {
      const mockItems = [
        { id: 1, name: 'Test Item', description: 'Test', is_active: true, created_at: new Date() },
      ];
      (mockPool.query as jest.Mock).mockResolvedValue({ rows: mockItems });

      const response = await request(app).get('/items');

      expect(response.status).toBe(200);
      expect(response.body).toEqual(mockItems);
    });

    it('should return 500 on database error', async () => {
      (mockPool.query as jest.Mock).mockRejectedValue(new Error('DB Error'));

      const response = await request(app).get('/items');

      expect(response.status).toBe(500);
      expect(response.body).toEqual({ error: 'Internal server error' });
    });
  });

  describe('POST /items', () => {
    it('should create a new item', async () => {
      const newItem = { name: 'New Item', description: 'Description' };
      const createdItem = { id: 1, ...newItem, is_active: true, created_at: new Date() };
      (mockPool.query as jest.Mock).mockResolvedValue({ rows: [createdItem] });

      const response = await request(app)
        .post('/items')
        .send(newItem);

      expect(response.status).toBe(201);
      expect(response.body).toEqual(createdItem);
    });

    it('should return 400 if name is missing', async () => {
      const response = await request(app)
        .post('/items')
        .send({ description: 'No name' });

      expect(response.status).toBe(400);
      expect(response.body).toEqual({ error: 'Name is required' });
    });

    it('should return 400 if name is empty', async () => {
      const response = await request(app)
        .post('/items')
        .send({ name: '   ' });

      expect(response.status).toBe(400);
      expect(response.body).toEqual({ error: 'Name is required' });
    });
  });

  describe('DELETE /items/:id', () => {
    it('should delete an existing item', async () => {
      (mockPool.query as jest.Mock).mockResolvedValue({ rows: [{ id: 1 }] });

      const response = await request(app).delete('/items/1');

      expect(response.status).toBe(204);
    });

    it('should return 404 if item not found', async () => {
      (mockPool.query as jest.Mock).mockResolvedValue({ rows: [] });

      const response = await request(app).delete('/items/999');

      expect(response.status).toBe(404);
      expect(response.body).toEqual({ error: 'Item not found' });
    });
  });
});
