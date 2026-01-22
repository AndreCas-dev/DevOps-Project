export const config = {
  port: parseInt(process.env.PORT || '8000'),
  database: {
    host: process.env.POSTGRES_HOST || 'db',
    port: parseInt(process.env.POSTGRES_PORT || '5432'),
    user: process.env.POSTGRES_USER || 'postgres',
    password: process.env.POSTGRES_PASSWORD || 'postgres',
    database: process.env.POSTGRES_DB || 'Test',
  },
  debug: process.env.DEBUG === 'true',
};
