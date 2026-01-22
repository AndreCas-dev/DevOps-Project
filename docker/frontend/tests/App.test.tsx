import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import App from '../src/App';

// Mock fetch
const mockFetch = vi.fn();
global.fetch = mockFetch;

describe('App', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders the app title', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve([]),
    });

    render(<App />);

    expect(screen.getByText('DevOps Test App')).toBeInTheDocument();
  });

  it('shows loading state initially', () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve([]),
    });

    render(<App />);

    expect(screen.getByText('Caricamento...')).toBeInTheDocument();
  });

  it('displays items after loading', async () => {
    const mockItems = [
      { id: 1, name: 'Test Item', description: 'Test description', created_at: '2024-01-01T00:00:00Z' },
    ];

    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve(mockItems),
    });

    render(<App />);

    await waitFor(() => {
      expect(screen.getByText('Test Item')).toBeInTheDocument();
    });
  });

  it('shows error message on fetch failure', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: false,
    });

    render(<App />);

    await waitFor(() => {
      expect(screen.getByText('Errore nel caricamento degli items')).toBeInTheDocument();
    });
  });

  it('shows empty message when no items', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve([]),
    });

    render(<App />);

    await waitFor(() => {
      expect(screen.getByText('Nessun item presente. Creane uno!')).toBeInTheDocument();
    });
  });
});
