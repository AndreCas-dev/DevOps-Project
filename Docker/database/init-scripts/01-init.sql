-- Database initialization script
-- This runs automatically when PostgreSQL container starts for the first time

-- Create items table (will be created by SQLAlchemy, but this is a fallback)
CREATE TABLE IF NOT EXISTS items (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create index on name for faster searches
CREATE INDEX IF NOT EXISTS idx_items_name ON items(name);

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;
