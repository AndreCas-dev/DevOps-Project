import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import ItemList from '../src/components/ItemList';
import { Item } from '../src/types/item';

const mockItems: Item[] = [
  {
    id: 1,
    name: 'Item 1',
    description: 'Description 1',
    is_active: true,
    created_at: '2024-01-15T10:30:00Z',
    updated_at: null,
  },
  {
    id: 2,
    name: 'Item 2',
    description: null,
    is_active: true,
    created_at: '2024-01-16T14:00:00Z',
    updated_at: null,
  },
];

describe('ItemList', () => {
  it('renders empty message when no items', () => {
    render(<ItemList items={[]} onDelete={vi.fn()} />);

    expect(screen.getByText('Nessun item presente. Creane uno!')).toBeInTheDocument();
  });

  it('renders items count', () => {
    render(<ItemList items={mockItems} onDelete={vi.fn()} />);

    expect(screen.getByText('Items (2)')).toBeInTheDocument();
  });

  it('renders item names', () => {
    render(<ItemList items={mockItems} onDelete={vi.fn()} />);

    expect(screen.getByText('Item 1')).toBeInTheDocument();
    expect(screen.getByText('Item 2')).toBeInTheDocument();
  });

  it('renders item descriptions when present', () => {
    render(<ItemList items={mockItems} onDelete={vi.fn()} />);

    expect(screen.getByText('Description 1')).toBeInTheDocument();
  });

  it('renders delete button for each item', () => {
    render(<ItemList items={mockItems} onDelete={vi.fn()} />);

    const deleteButtons = screen.getAllByRole('button', { name: /elimina/i });
    expect(deleteButtons).toHaveLength(2);
  });

  it('calls onDelete with item id when delete button clicked', async () => {
    const mockOnDelete = vi.fn().mockResolvedValue(undefined);
    render(<ItemList items={mockItems} onDelete={mockOnDelete} />);

    const deleteButtons = screen.getAllByRole('button', { name: /elimina/i });
    await userEvent.click(deleteButtons[0]);

    expect(mockOnDelete).toHaveBeenCalledWith(1);
  });
});
