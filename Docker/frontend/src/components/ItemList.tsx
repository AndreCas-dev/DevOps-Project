import { Item } from '../types/item'

interface ItemListProps {
  items: Item[]
  onDelete: (id: number) => Promise<void>
}

function ItemList({ items, onDelete }: ItemListProps) {
  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString('it-IT', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  return (
    <div className="items-container">
      <h2>Items ({items.length})</h2>

      {items.length === 0 ? (
        <p className="empty-message">Nessun item presente. Creane uno!</p>
      ) : (
        <ul className="items-list">
          {items.map((item) => (
            <li key={item.id} className="item-card">
              <div className="item-info">
                <h3>{item.name}</h3>
                {item.description && <p>{item.description}</p>}
                <div className="item-date">
                  Creato: {formatDate(item.created_at)}
                </div>
              </div>
              <button
                className="btn btn-danger"
                onClick={() => onDelete(item.id)}
              >
                Elimina
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

export default ItemList
