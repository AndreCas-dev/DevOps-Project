import { useState } from 'react'
import { ItemCreate } from '../types/item'

interface ItemFormProps {
  onSubmit: (item: ItemCreate) => Promise<void>
}

function ItemForm({ onSubmit }: ItemFormProps) {
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [submitting, setSubmitting] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!name.trim()) return

    setSubmitting(true)
    try {
      await onSubmit({
        name: name.trim(),
        description: description.trim() || undefined,
      })
      // Reset form on success
      setName('')
      setDescription('')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="form-container">
      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label htmlFor="name">Nome *</label>
          <input
            type="text"
            id="name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Inserisci il nome"
            required
            disabled={submitting}
          />
        </div>

        <div className="form-group">
          <label htmlFor="description">Descrizione</label>
          <textarea
            id="description"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Inserisci una descrizione (opzionale)"
            disabled={submitting}
          />
        </div>

        <button
          type="submit"
          className="btn btn-primary"
          disabled={submitting || !name.trim()}
        >
          {submitting ? 'Invio...' : 'Invia'}
        </button>
      </form>
    </div>
  )
}

export default ItemForm
