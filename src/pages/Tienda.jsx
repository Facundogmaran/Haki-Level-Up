import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import AvatarAnimado from '../components/AvatarAnimado'
import IconoBolsa from '../components/IconoBolsa'
import IconoEquipo from '../components/IconoEquipo'
import { NOMBRES_CATEGORIA, bonusTexto, claveVisual, requisitosFaltantes, requisitosTexto } from '../lib/equipoDisplay'
import {
  comprarItem,
  getCategoriasEquipo,
  getCharacter,
  getConteoPorCategoria,
  getEquipmentPorCategoria,
  getInventory,
} from '../lib/game'

export default function Tienda() {
  const navigate = useNavigate()
  const [categoriaActual, setCategoriaActual] = useState(null)
  const [baseActual, setBaseActual] = useState(null)
  const [conteo, setConteo] = useState({})
  const [basesCategoria, setBasesCategoria] = useState([])
  const [colorElegido, setColorElegido] = useState(null)
  const [previewVarianteId, setPreviewVarianteId] = useState(null)
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

  useEffect(() => {
    setPreviewVarianteId(baseActual?.variantes[0]?.id ?? null)
  }, [baseActual])

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

  const colorSeleccionado = baseActual?.colores?.find((c) => c.id === colorElegido) ?? null
  const previewVariante = baseActual?.variantes.find((v) => v.id === previewVarianteId) ?? null

  const equipadoParaPreview = baseActual
    ? [
        ...inventario.filter((i) => i.equipado && i.item.base.category !== baseActual.category),
        {
          id: 'preview',
          equipado: true,
          color: colorSeleccionado,
          item: { base: baseActual, material: previewVariante?.material ?? null },
        },
      ]
    : []

  return (
    <div className="pagina">
      <div className="tarjeta fila-stats-top">
        <span>🪙 {oro}</span>
        <button className="boton-volver boton-ver-inventario" onClick={() => navigate('/personaje/inventario')}>
          <IconoBolsa size={16} /> Ver inventario
        </button>
      </div>

      {error && <p className="error">{error}</p>}

      {!categoriaActual && (
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

      {categoriaActual && !baseActual && (
        <>
          <button className="boton-volver" onClick={() => setCategoriaActual(null)}>
            ← Volver a categorías
          </button>
          <h3>{NOMBRES_CATEGORIA[categoriaActual]}</h3>
          <div className="lista-items">
            {basesCategoria.length === 0 && <p>No hay equipamiento disponible en esta categoría todavía.</p>}
            {basesCategoria.map((base) => {
              const primera = base.variantes[0]
              const claveIcono = claveVisual(primera?.material?.nombre, base.colores?.[0]?.nombre)
              return (
                <button
                  key={base.id}
                  className="tarjeta item-catalogo item-catalogo-boton"
                  onClick={() => setBaseActual(base)}
                >
                  <div className="item-catalogo-con-icono">
                    <IconoEquipo carpeta={base.lpc_sprite_folder} variante={claveIcono} tieneBg={base.lpc_zpos_bg != null} />
                    <div>
                      <strong>{base.nombre}</strong>
                      {base.descripcion && <p className="descripcion-item">{base.descripcion}</p>}
                    </div>
                  </div>
                  <span className="detalle-item">
                    {base.variantes.length === 1
                      ? `🪙 ${base.variantes[0].precio_oro}`
                      : `🪙 ${base.variantes[0].precio_oro} - ${base.variantes[base.variantes.length - 1].precio_oro}`}
                  </span>
                </button>
              )
            })}
          </div>
        </>
      )}

      {baseActual && (
        <>
          <button className="boton-volver" onClick={() => setBaseActual(null)}>
            ← Volver a {NOMBRES_CATEGORIA[categoriaActual]}
          </button>
          <h3>{baseActual.nombre}</h3>

          {personaje && (
            <div className="tarjeta vista-previa-equipo">
              <div className="avatar-contenedor">
                <AvatarAnimado apariencia={personaje.apariencia} equipado={equipadoParaPreview} />
              </div>
              <p className="detalle-item">Así se vería puesto (con el resto de tu equipo actual).</p>
            </div>
          )}

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
              {colorElegido === null && <p className="detalle-item">Elegí un color para poder comprar.</p>}
            </div>
          )}

          <div className="lista-items">
            {baseActual.variantes.map((variante) => {
              const yaLoTiene = idsEnInventario.has(variante.id)
              const sinColorElegido = baseActual.admite_colores && colorElegido === null
              const claveIcono = claveVisual(variante.material?.nombre, colorSeleccionado?.nombre)
              const faltantes = requisitosFaltantes(variante, personaje)
              return (
                <div
                  key={variante.id}
                  className={`tarjeta item-catalogo item-catalogo-clicable${previewVarianteId === variante.id ? ' item-catalogo-previsualizado' : ''}`}
                  onClick={() => setPreviewVarianteId(variante.id)}
                >
                  <div className="item-catalogo-con-icono">
                    <IconoEquipo carpeta={baseActual.lpc_sprite_folder} variante={claveIcono} tieneBg={baseActual.lpc_zpos_bg != null} />
                    <div>
                      <strong>{variante.nombre}</strong>
                      {faltantes.length > 0 ? (
                        <p className="detalle-item fallo">
                          🔒 Requiere: {requisitosTexto(variante)} — te faltan: {faltantes.join(', ')}
                        </p>
                      ) : (
                        <p className="detalle-item">{bonusTexto(variante.bonus)}</p>
                      )}
                    </div>
                  </div>
                  <button
                    disabled={ocupado || yaLoTiene || oro < variante.precio_oro || sinColorElegido}
                    onClick={(e) => {
                      e.stopPropagation()
                      handleComprar(variante.id)
                    }}
                  >
                    {yaLoTiene ? 'Ya lo tenés' : `🪙 ${variante.precio_oro}`}
                  </button>
                </div>
              )
            })}
          </div>
        </>
      )}
    </div>
  )
}
