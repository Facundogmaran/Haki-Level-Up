import { useEffect, useState } from 'react'
import MapaCaminata from '../components/MapaCaminata'
import { getCharacter, getZones, getZonasCompletadas, intentarEncuentro, previsualizarEncuentro } from '../lib/game'

function formatearChance(chance) {
  const pct = chance * 100
  if (pct < 1) return `${pct.toFixed(2)}%`
  if (pct < 10) return `${pct.toFixed(1)}%`
  return `${Math.round(pct)}%`
}

const NOMBRES_SLOT = {
  head: 'el casco',
  neck: 'el collar',
  ring: 'el anillo',
  shoulder: 'la hombrera',
  gloves: 'los guantes',
  torso: 'la armadura',
  legs: 'las piernas',
  feet: 'las botas',
  weapon: 'el arma',
  shield: 'el escudo',
}

export default function Mapa() {
  const [zonas, setZonas] = useState([])
  const [personaje, setPersonaje] = useState(null)
  const [previews, setPreviews] = useState({})
  const [completadas, setCompletadas] = useState(new Set())
  const [error, setError] = useState('')

  const [zonaSeleccionadaId, setZonaSeleccionadaId] = useState(null)
  const [zonaActiva, setZonaActiva] = useState(null)
  const [resultado, setResultado] = useState(null)
  const [luchando, setLuchando] = useState(false)

  async function cargar() {
    try {
      const [z, p, comp] = await Promise.all([getZones(), getCharacter(), getZonasCompletadas()])
      setZonas(z)
      setPersonaje(p)
      setCompletadas(comp)

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
        completadas={completadas}
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
            <>
              <p className={`chance-exito ${porDebajoDeLoRecomendado ? 'chance-baja' : ''}`}>
                Probabilidad de éxito: {formatearChance(previewActiva.chance)}
              </p>
              <p className="detalle-item">Intentos hoy: {previewActiva.intentos_restantes} / 3</p>
            </>
          )}

          {!resultado && (
            <button disabled={luchando || previewActiva?.intentos_restantes === 0} onClick={handleIntentar}>
              {luchando
                ? 'Resolviendo...'
                : previewActiva?.intentos_restantes === 0
                  ? 'Sin intentos hoy'
                  : 'Explorar'}
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
                <p className="detalle-item fallo">
                  ¡Perdiste {NOMBRES_SLOT[resultado.item_perdido_slot] ?? 'un ítem'} equipado: {resultado.item_perdido_nombre}!
                </p>
              )}
              <button onClick={() => setResultado(null)}>Cerrar</button>
            </>
          )}
        </div>
      )}
    </div>
  )
}
