import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import ItemForm from '../src/components/ItemForm';

describe('ItemForm', () => {
  it('renders form fields', () => {
    render(<ItemForm onSubmit={vi.fn()} />);

    expect(screen.getByLabelText(/nome/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/descrizione/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /invia/i })).toBeInTheDocument();
  });

  it('submit button is disabled when name is empty', () => {
    render(<ItemForm onSubmit={vi.fn()} />);

    const submitButton = screen.getByRole('button', { name: /invia/i });
    expect(submitButton).toBeDisabled();
  });

  it('submit button is enabled when name has value', async () => {
    render(<ItemForm onSubmit={vi.fn()} />);

    const nameInput = screen.getByLabelText(/nome/i);
    await userEvent.type(nameInput, 'Test Item');

    const submitButton = screen.getByRole('button', { name: /invia/i });
    expect(submitButton).not.toBeDisabled();
  });

  it('calls onSubmit with form data', async () => {
    const mockOnSubmit = vi.fn().mockResolvedValue(undefined);
    render(<ItemForm onSubmit={mockOnSubmit} />);

    const nameInput = screen.getByLabelText(/nome/i);
    const descriptionInput = screen.getByLabelText(/descrizione/i);

    await userEvent.type(nameInput, 'Test Item');
    await userEvent.type(descriptionInput, 'Test Description');

    const submitButton = screen.getByRole('button', { name: /invia/i });
    await userEvent.click(submitButton);

    await waitFor(() => {
      expect(mockOnSubmit).toHaveBeenCalledWith({
        name: 'Test Item',
        description: 'Test Description',
      });
    });
  });

  it('clears form after successful submit', async () => {
    const mockOnSubmit = vi.fn().mockResolvedValue(undefined);
    render(<ItemForm onSubmit={mockOnSubmit} />);

    const nameInput = screen.getByLabelText(/nome/i) as HTMLInputElement;
    await userEvent.type(nameInput, 'Test Item');

    const submitButton = screen.getByRole('button', { name: /invia/i });
    await userEvent.click(submitButton);

    await waitFor(() => {
      expect(nameInput.value).toBe('');
    });
  });
});
