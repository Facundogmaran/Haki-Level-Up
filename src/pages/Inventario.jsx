import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import AvatarAnimado from '../components/AvatarAnimado'
import IconoEquipo from '../components/IconoEquipo'
import { NOMBRES_CATEGORIA, bonusTexto, claveVisual, requisitosFaltantes, requisitosTexto } from '../lib/equipoDisplay'
import { desequiparItem, equiparItem, getCharacter, getInventory, venderItem } from '../lib/game'

function ordenarInventario(inventario) {
  const equipados = inventario.filter((i) => i.equipado).sort((a, b) => a.item.nombre.localeCompare(b.item.nombre))
  const noEquipados = inventario.filter((i) => !i.equipado).sort((a, b) => a.item.nombre.localeCompare(b.item.nombre))
  return { equipados, noEquipados }
}

export default function Inventario() {
  const navigate = useNavigate()
  const [personaje, setPersonaje] = useState(null)
  const [inventario, setInventario] = useState([])
  const [error, setError] = useState('')
  const [ocupado, setOcupado] = useState(false)

  async function cargar() {
    try {
      const [p, inv] = await Promise.all([getCharacter(), getInventory()])
      setPersonaje(p)
      setInventario(inv)
    } catch (e) {
      setError(e.message)
    }
  }

  useEffect(() => {
    cargar()
  }, [])

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

  async function handleVender(inventoryId) {
    setOcupado(true)
    setError('')
    try {
      await venderItem(inventoryId)
      await cargar()
    } catch (e) {
      setError(e.message)
    }
    setOcupado(false)
  }

  if (!personaje) return <p className="pagina">Cargando...</p>

  const equipado = inventario.filter((i) => i.equipado)
  const { equipados, noEquipados } = ordenarInventario(inventario)

  function tarjetaItem(inv) {
    const faltantes = requisitosFaltantes(inv.item, personaje)
    const bloqueado = faltantes.length > 0
    const claveIcono = claveVisual(inv.item.material?.nombre, inv.color?.nombre)
    return (
      <div key={inv.id} className="tarjeta item-catalogo">
        <div className="item-catalogo-con-icono">
          <IconoEquipo
            carpeta={inv.item.base.lpc_sprite_folder}
            variante={claveIcono}
            tieneBg={inv.item.base.lpc_zpos_bg != null}
          />
          <div>
            <strong>
              {bloqueado && '🔒 '}
              {inv.item.nombre}
            </strong>
            <p className="detalle-item">
              {NOMBRES_CATEGORIA[inv.item.base.category]} · {bonusTexto(inv.item.bonus)}
              {inv.color && <> · Color: {inv.color.nombre}</>}
            </p>
            {bloqueado && (
              <p className="detalle-item fallo">
                Requiere: {requisitosTexto(inv.item)} — te faltan: {faltantes.join(', ')}
              </p>
            )}
          </div>
        </div>
        <div className="acciones-item-inventario">
          <button disabled={ocupado || bloqueado} onClick={() => handleEquipar(inv.id, inv.equipado)}>
            {inv.equipado ? 'Desequipar' : 'Equipar'}
          </button>
          <button disabled={ocupado} className="boton-vender" onClick={() => handleVender(inv.id)}>
            Vender 🪙{Math.round(inv.item.precio_oro * (2 / 3))}
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="pantalla-avatar-fijo">
      <div className="avatar-contenedor">
        <AvatarAnimado apariencia={personaje.apariencia} equipado={equipado} />
      </div>

      <div className="contenido-scrollable">
        <button onClick={() => navigate('/')} className="boton-volver">‹ Volver</button>

        {error && <p className="error">{error}</p>}

        {inventario.length === 0 && <p className="detalle-item">Todavía no tenés equipamiento.</p>}

        {equipados.length > 0 && (
          <div className="tarjeta">
            <h3>Equipados</h3>
            <div className="lista-items">{equipados.map(tarjetaItem)}</div>
          </div>
        )}

        {noEquipados.length > 0 && (
          <div className="tarjeta">
            <h3>Inventario</h3>
            <div className="lista-items">{noEquipados.map(tarjetaItem)}</div>
          </div>
        )}
      </div>
    </div>
  )
}
