import { useState, useEffect } from 'react'
import { Item, ItemCreate } from './types/item'
import ItemForm from './components/ItemForm'
import ItemList from './components/ItemList'

const API_URL = '/api'

function App() {
  const [items, setItems] = useState<Item[]>([])
  const [loading, setLoading] = useState(true)
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null)

  // Fetch items on mount
  useEffect(() => {
    fetchItems()
  }, [])

  // Clear message after 3 seconds
  useEffect(() => {
    if (message) {
      const timer = setTimeout(() => setMessage(null), 3000)
      return () => clearTimeout(timer)
    }
  }, [message])

  const fetchItems = async () => {
    try {
      const response = await fetch(`${API_URL}/items`)
      if (!response.ok) throw new Error('Errore nel caricamento')
      const data = await response.json()
      setItems(data)
    } catch (error) {
      setMessage({ type: 'error', text: 'Errore nel caricamento degli items' })
    } finally {
      setLoading(false)
    }
  }

  const handleSubmit = async (newItem: ItemCreate) => {
    try {
      const response = await fetch(`${API_URL}/items`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(newItem),
      })

      if (!response.ok) throw new Error('Errore nella creazione')

      const createdItem = await response.json()
      setItems([...items, createdItem])
      setMessage({ type: 'success', text: 'Item creato con successo!' })
    } catch (error) {
      setMessage({ type: 'error', text: 'Errore nella creazione dell\'item' })
    }
  }

  const handleDelete = async (id: number) => {
    try {
      const response = await fetch(`${API_URL}/items/${id}`, {
        method: 'DELETE',
      })

      if (!response.ok) throw new Error('Errore nella cancellazione')

      setItems(items.filter(item => item.id !== id))
      setMessage({ type: 'success', text: 'Item eliminato con successo!' })
    } catch (error) {
      setMessage({ type: 'error', text: 'Errore nella cancellazione dell\'item' })
    }
  }

  return (
    <div className="container">
      <h1>DevOps Test App</h1>

      {message && (
        <div className={`message message-${message.type}`}>
          {message.text}
        </div>
      )}

      <ItemForm onSubmit={handleSubmit} />

      {loading ? (
        <div className="loading">Caricamento...</div>
      ) : (
        <ItemList items={items} onDelete={handleDelete} />
      )}
    </div>
  )
}

export default App
