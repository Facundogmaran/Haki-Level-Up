import { useEffect, useState } from 'react'
import {
  comprarItem,
  desequiparItem,
  equiparItem,
  getCharacter,
  getEquipmentCatalog,
  getInventory,
} from '../lib/game'

const NOMBRES_SLOT = {
  cabeza: 'Cabeza',
  torso: 'Torso',
  arma: 'Arma',
  piernas: 'Piernas',
  pies: 'Pies',
  accesorio: 'Accesorio',
}

function bonusTexto(bonus) {
  return Object.entries(bonus || {})
    .map(([atributo, valor]) => `${valor > 0 ? '+' : ''}${valor} ${atributo}`)
    .join(', ')
}

export default function Tienda() {
  const [tab, setTab] = useState('tienda')
  const [catalogo, setCatalogo] = useState([])
  const [inventario, setInventario] = useState([])
  const [oro, setOro] = useState(0)
  const [error, setError] = useState('')
  const [ocupado, setOcupado] = useState(false)

  async function cargar() {
    try {
      const [c, inv, personaje] = await Promise.all([getEquipmentCatalog(), getInventory(), getCharacter()])
      setCatalogo(c)
      setInventario(inv)
      setOro(personaje.oro)
    } catch (e) {
      setError(e.message)
    }
  }

  useEffect(() => {
    cargar()
  }, [])

  const idsEnInventario = new Set(inventario.map((i) => i.item.id))

  async function handleComprar(itemId) {
    setOcupado(true)
    setError('')
    try {
      await comprarItem(itemId)
      await cargar()
    } catch (e) {
      setError(e.message)
    }
    setOcupado(false)
  }

  async function handleEquipar(inventoryId, yaEquipado) {
    setOcupado(true)
    setError('')
    try {
      if (yaEquipado) await desequiparItem(inventoryId)
      else await equiparItem(inventoryId)
      await cargar()
    } catch (e) {
      setError(e.message)
    }
    setOcupado(false)
  }

  return (
    <div className="pagina">
      <div className="tarjeta fila-stats-top">
        <span>🪙 {oro}</span>
      </div>

      <div className="tabs">
        <button className={tab === 'tienda' ? 'activo' : ''} onClick={() => setTab('tienda')}>
          Tienda
        </button>
        <button className={tab === 'inventario' ? 'activo' : ''} onClick={() => setTab('inventario')}>
          Inventario
        </button>
      </div>

      {error && <p className="error">{error}</p>}

      {tab === 'tienda' && (
        <div className="lista-items">
          {catalogo.map((item) => {
            const yaLoTiene = idsEnInventario.has(item.id)
            return (
              <div key={item.id} className="tarjeta item-catalogo">
                <div>
                  <strong>{item.nombre}</strong>
                  <p className="detalle-item">
                    {NOMBRES_SLOT[item.slot]} · {bonusTexto(item.bonus)}
                  </p>
                  {item.descripcion && <p className="descripcion-item">{item.descripcion}</p>}
                </div>
                <button
                  disabled={ocupado || yaLoTiene || oro < item.precio_oro}
                  onClick={() => handleComprar(item.id)}
                >
                  {yaLoTiene ? 'Ya lo tenés' : `🪙 ${item.precio_oro}`}
                </button>
              </div>
            )
          })}
        </div>
      )}

      {tab === 'inventario' && (
        <div className="lista-items">
          {inventario.length === 0 && <p>Todavía no tenés equipamiento.</p>}
          {inventario.map((inv) => (
            <div key={inv.id} className="tarjeta item-catalogo">
              <div>
                <strong>{inv.item.nombre}</strong>
                <p className="detalle-item">
                  {NOMBRES_SLOT[inv.item.slot]} · {bonusTexto(inv.item.bonus)}
                </p>
              </div>
              <button disabled={ocupado} onClick={() => handleEquipar(inv.id, inv.equipado)}>
                {inv.equipado ? 'Equipado' : 'Equipar'}
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
