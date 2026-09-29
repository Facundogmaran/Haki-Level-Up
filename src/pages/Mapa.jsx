import { useEffect, useState } from 'react'
import MapaCaminata from '../components/MapaCaminata'
import { getCharacter, getZones, intentarEncuentro, previsualizarEncuentro } from '../lib/game'

function formatearChance(chance) {
  const pct = chance * 100
  if (pct < 1) return `${pct.toFixed(2)}%`
  if (pct < 10) return `${pct.toFixed(1)}%`
  return `${Math.round(pct)}%`
}

export default function Mapa() {
  const [zonas, setZonas] = useState([])
  const [personaje, setPersonaje] = useState(null)
  const [previews, setPreviews] = useState({})
  const [error, setError] = useState('')

  const [zonaSeleccionadaId, setZonaSeleccionadaId] = useState(null)
  const [zonaActiva, setZonaActiva] = useState(null)
  const [resultado, setResultado] = useState(null)
  const [luchando, setLuchando] = useState(false)

  async function cargar() {
    try {
      const [z, p] = await Promise.all([getZones(), getCharacter()])
      setZonas(z)
      setPersonaje(p)

      const entries = await Promise.all(
        z.map(async (zona) => [zona.id, await previsualizarEncuentro(zona.id)]),
      )
      setPreviews(Object.fromEntries(entries))
    } catch (e) {
      setError(e.message)
    }
  }

  useEffect(() => {
    cargar()
  }, [])

  function handleTocarNodo(zona) {
    setResultado(null)
    setZonaActiva(null)
    setZonaSeleccionadaId(zona.id)
  }

  function handleLlegar(zonaId) {
    const zona = zonas.find((z) => z.id === zonaId)
    setZonaActiva(zona ?? null)
  }

  async function handleIntentar() {
    if (!zonaActiva) return
    setLuchando(true)
    setError('')
    setResultado(null)
    try {
      const r = await intentarEncuentro(zonaActiva.id)
      setResultado(r)
      await cargar()
    } catch (e) {
      setError(e.message)
    }
    setLuchando(false)
  }

  if (error) return <p className="error">{error}</p>
  if (!personaje || zonas.length === 0) return <p>Cargando mapa...</p>

  const previewActiva = zonaActiva ? previews[zonaActiva.id] : null
  const porDebajoDeLoRecomendado = zonaActiva ? personaje.nivel < zonaActiva.requisito_nivel : false

  return (
    <div className="pagina">
      <MapaCaminata
        zonas={zonas}
        nivel={personaje.nivel}
        apariencia={personaje.apariencia}
        zonaSeleccionadaId={zonaSeleccionadaId}
        onSeleccionar={(zona) => handleTocarNodo(zona)}
        onLlegar={handleLlegar}
      />

      {zonaActiva && (
        <div className="tarjeta resultado-encuentro">
          <strong>{zonaActiva.nombre}</strong>
          <p className="detalle-item">
            {zonaActiva.enemigo?.nombre} · Poder {zonaActiva.enemigo?.poder} · Nivel recomendado {zonaActiva.requisito_nivel}
          </p>
          {previewActiva && (
            <p className={`chance-exito ${porDebajoDeLoRecomendado ? 'chance-baja' : ''}`}>
              Probabilidad de éxito: {formatearChance(previewActiva.chance)}
            </p>
          )}

          {!resultado && (
            <button disabled={luchando} onClick={handleIntentar}>
              {luchando ? 'Resolviendo...' : 'Explorar'}
            </button>
          )}

          {resultado && (
            <>
              <p className={resultado.gano ? 'exito' : 'fallo'}>
                {resultado.gano ? `¡Venciste a ${resultado.enemigo}!` : `${resultado.enemigo} fue demasiado. No esta vez.`}
              </p>
              <p className="detalle-item">Probabilidad de éxito: {formatearChance(resultado.chance)}</p>
              {resultado.gano && <p className="detalle-item">Ganaste 🪙 {resultado.oro_ganado}</p>}
              {resultado.gano && resultado.item_ganado_id && (
                <p className="detalle-item">¡También encontraste un objeto! Revisalo en la Tienda &gt; Inventario.</p>
              )}
              {!resultado.gano && resultado.oro_perdido > 0 && (
                <p className="detalle-item fallo">Perdiste 🪙 {resultado.oro_perdido} en la huida.</p>
              )}
              {!resultado.gano && resultado.item_perdido_nombre && (
                <p className="detalle-item fallo">¡Perdiste {resultado.item_perdido_nombre} en el combate!</p>
              )}
              <button onClick={() => setResultado(null)}>Cerrar</button>
            </>
          )}
        </div>
      )}
    </div>
  )
}
