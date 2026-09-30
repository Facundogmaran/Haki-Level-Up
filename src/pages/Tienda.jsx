import { useEffect, useState } from 'react'
import {
  comprarItem,
  desequiparItem,
  equiparItem,
  getCategoriasEquipo,
  getCharacter,
  getConteoPorCategoria,
  getEquipmentPorCategoria,
  getInventory,
  venderItem,
} from '../lib/game'

const NOMBRES_CATEGORIA = {
  head: 'Cabeza',
  neck: 'Collar',
  ring: 'Anillo',
  shoulder: 'Hombrera',
  gloves: 'Guantes',
  torso: 'Torso',
  legs: 'Piernas',
  feet: 'Calzado',
  weapon: 'Arma',
  shield: 'Escudo',
}

const NOMBRES_ATRIBUTO = {
  fuerza: 'Fuerza',
  resistencia: 'Resistencia',
  agilidad: 'Agilidad',
  vitalidad: 'Vitalidad',
  mente: 'Mente',
}

function bonusTexto(bonus) {
  return Object.entries(bonus || {})
    .map(([atributo, valor]) => `${valor > 0 ? '+' : ''}${valor} ${NOMBRES_ATRIBUTO[atributo] ?? atributo}`)
    .join(', ')
}

function requisitosFaltantes(variante, personaje) {
  if (!personaje) return []
  const faltan = []
  if (personaje.nivel < variante.requisito_nivel) faltan.push(`Nivel +${variante.requisito_nivel - personaje.nivel}`)
  for (const atributo of ['fuerza', 'resistencia', 'agilidad', 'vitalidad', 'mente']) {
    const requerido = variante[`requisito_${atributo}`] ?? 0
    if (requerido > 0 && personaje[atributo] < requerido) {
      faltan.push(`${NOMBRES_ATRIBUTO[atributo]} +${requerido - personaje[atributo]}`)
    }
  }
  return faltan
}

function requisitosTexto(variante) {
  const partes = []
  if (variante.requisito_nivel > 1) partes.push(`Nivel ${variante.requisito_nivel}`)
  for (const atributo of ['fuerza', 'resistencia', 'agilidad', 'vitalidad', 'mente']) {
    const requerido = variante[`requisito_${atributo}`] ?? 0
    if (requerido > 0) partes.push(`${NOMBRES_ATRIBUTO[atributo]} ${requerido}`)
  }
  return partes.join(' · ')
}

export default function Tienda() {
  const [tab, setTab] = useState('tienda')
  const [categoriaActual, setCategoriaActual] = useState(null)
  const [baseActual, setBaseActual] = useState(null)
  const [conteo, setConteo] = useState({})
  const [basesCategoria, setBasesCategoria] = useState([])
  const [colorElegido, setColorElegido] = useState(null)
  const [inventario, setInventario] = useState([])
  const [personaje, setPersonaje] = useState(null)
  const [oro, setOro] = useState(0)
  const [error, setError] = useState('')
  const [ocupado, setOcupado] = useState(false)

  const categorias = getCategoriasEquipo()

  async function cargarBase() {
    try {
      const [inv, p] = await Promise.all([getInventory(), getCharacter()])
      setInventario(inv)
      setPersonaje(p)
      setOro(p.oro)
    } catch (e) {
      setError(e.message)
    }
  }

  async function cargarConteo() {
    try {
      setConteo(await getConteoPorCategoria())
    } catch (e) {
      setError(e.message)
    }
  }

  useEffect(() => {
    cargarBase()
    cargarConteo()
  }, [])

  useEffect(() => {
    if (!categoriaActual) return
    setBaseActual(null)
    setColorElegido(null)
    getEquipmentPorCategoria(categoriaActual)
      .then(setBasesCategoria)
      .catch((e) => setError(e.message))
  }, [categoriaActual])

  const idsEnInventario = new Set(inventario.map((i) => i.item.id))

  async function handleComprar(variantId) {
    setOcupado(true)
    setError('')
    try {
      await comprarItem(variantId, colorElegido)
      await cargarBase()
      await cargarConteo()
      setColorElegido(null)
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
      await cargarBase()
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
      await cargarBase()
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

      {tab === 'tienda' && !categoriaActual && (
        <div className="grid-categorias">
          {categorias.map((cat) => (
            <button key={cat.id} className="tarjeta-categoria" onClick={() => setCategoriaActual(cat.id)}>
              <span className="tarjeta-categoria-icono">{cat.icono}</span>
              <span className="tarjeta-categoria-nombre">{cat.nombre}</span>
              <span className="tarjeta-categoria-conteo">{conteo[cat.id] ?? 0} disponibles</span>
            </button>
          ))}
        </div>
      )}

      {tab === 'tienda' && categoriaActual && !baseActual && (
        <>
          <button
            className="boton-volver"
            onClick={() => setCategoriaActual(null)}
          >
            ← Volver a categorías
          </button>
          <h3>{NOMBRES_CATEGORIA[categoriaActual]}</h3>
          <div className="lista-items">
            {basesCategoria.length === 0 && <p>No hay equipamiento disponible en esta categoría todavía.</p>}
            {basesCategoria.map((base) => (
              <button
                key={base.id}
                className="tarjeta item-catalogo item-catalogo-boton"
                onClick={() => setBaseActual(base)}
              >
                <div>
                  <strong>{base.nombre}</strong>
                  {base.descripcion && <p className="descripcion-item">{base.descripcion}</p>}
                </div>
                <span className="detalle-item">
                  {base.variantes.length === 1
                    ? `🪙 ${base.variantes[0].precio_oro}`
                    : `🪙 ${base.variantes[0].precio_oro} - ${base.variantes[base.variantes.length - 1].precio_oro}`}
                </span>
              </button>
            ))}
          </div>
        </>
      )}

      {tab === 'tienda' && baseActual && (
        <>
          <button className="boton-volver" onClick={() => setBaseActual(null)}>
            ← Volver a {NOMBRES_CATEGORIA[categoriaActual]}
          </button>
          <h3>{baseActual.nombre}</h3>

          {baseActual.admite_colores && (
            <div className="tarjeta selector-color">
              <span>Color:</span>
              <div className="fila-swatches">
                {baseActual.colores.map((color) => (
                  <button
                    key={color.id}
                    className={`swatch${colorElegido === color.id ? ' swatch-elegido' : ''}`}
                    style={{ backgroundColor: color.valor_hex }}
                    title={color.nombre}
                    onClick={() => setColorElegido(color.id)}
                  />
                ))}
              </div>
            </div>
          )}

          <div className="lista-items">
            {baseActual.variantes.map((variante) => {
              const yaLoTiene = idsEnInventario.has(variante.id)
              const sinColorElegido = baseActual.admite_colores && colorElegido === null
              return (
                <div key={variante.id} className="tarjeta item-catalogo">
                  <div>
                    <strong>{variante.nombre}</strong>
                    <p className="detalle-item">{bonusTexto(variante.bonus)}</p>
                  </div>
                  <button
                    disabled={ocupado || yaLoTiene || oro < variante.precio_oro || sinColorElegido}
                    onClick={() => handleComprar(variante.id)}
                  >
                    {yaLoTiene ? 'Ya lo tenés' : `🪙 ${variante.precio_oro}`}
                  </button>
                </div>
              )
            })}
          </div>
        </>
      )}

      {tab === 'inventario' && (
        <div className="lista-items">
          {inventario.length === 0 && <p>Todavía no tenés equipamiento.</p>}
          {inventario.map((inv) => {
            const faltantes = requisitosFaltantes(inv.item, personaje)
            const bloqueado = faltantes.length > 0
            return (
              <div key={inv.id} className="tarjeta item-catalogo">
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
                <div className="acciones-item-inventario">
                  <button
                    disabled={ocupado || bloqueado}
                    onClick={() => handleEquipar(inv.id, inv.equipado)}
                  >
                    {inv.equipado ? 'Equipado' : 'Equipar'}
                  </button>
                  <button disabled={ocupado} className="boton-vender" onClick={() => handleVender(inv.id)}>
                    Vender 🪙{Math.round(inv.item.precio_oro * (2 / 3))}
                  </button>
                </div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
