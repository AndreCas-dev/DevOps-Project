import express, { Request, Response } from 'express';
import cors from 'cors';
import { register, Counter, Histogram } from 'prom-client';
import { config } from './config';
import { pool, initDatabase, checkConnection } from './database';
import { Item, ItemCreate } from './types';

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Prometheus metrics
const httpRequestsTotal = new Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'endpoint', 'status'],
});

const httpRequestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request latency',
  labelNames: ['method', 'endpoint'],
});

// Logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestsTotal.inc({ method: req.method, endpoint: req.path, status: res.statusCode });
    httpRequestDuration.observe({ method: req.method, endpoint: req.path }, duration);
    console.log(JSON.stringify({
      time: new Date().toISOString(),
      method: req.method,
      path: req.path,
      status: res.statusCode,
      duration: `${duration}s`,
    }));
  });
  next();
});

// Routes

// Root
app.get('/', (req: Request, res: Response) => {
  res.json({
    message: 'DevOps Test API',
    status: 'running',
    docs: '/docs',
  });
});

// Health check
app.get('/health', async (req: Request, res: Response) => {
  const dbConnected = await checkConnection();
  res.json({
    status: dbConnected ? 'healthy' : 'unhealthy',
    database: dbConnected ? 'connected' : 'disconnected',
    version: '1.0.0',
  });
});

// Metrics
app.get('/metrics', async (req: Request, res: Response) => {
  res.set('Content-Type', register.contentType);
  res.send(await register.metrics());
});

// GET /items - List all items
app.get('/items', async (req: Request, res: Response) => {
  try {
    const result = await pool.query<Item>(
      'SELECT * FROM items ORDER BY created_at DESC'
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching items:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /items - Create item
app.post('/items', async (req: Request, res: Response) => {
  try {
    const { name, description }: ItemCreate = req.body;

    if (!name || name.trim() === '') {
      return res.status(400).json({ error: 'Name is required' });
    }

    const result = await pool.query<Item>(
      'INSERT INTO items (name, description) VALUES ($1, $2) RETURNING *',
      [name.trim(), description?.trim() || null]
    );

    console.log(`Created item: ${result.rows[0].id} - ${result.rows[0].name}`);
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error creating item:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /items/:id - Delete item
app.delete('/items/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      'DELETE FROM items WHERE id = $1 RETURNING id',
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Item not found' });
    }

    console.log(`Deleted item: ${id}`);
    res.status(204).send();
  } catch (error) {
    console.error('Error deleting item:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Export app for testing
export { app };

// Start server (only if run directly)
async function start() {
  try {
    await initDatabase();
    app.listen(config.port, '0.0.0.0', () => {
      console.log(`Server running on http://0.0.0.0:${config.port}`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  start();
}
