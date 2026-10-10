import { useEffect, useState } from 'react'
import MapaCaminata from '../components/MapaCaminata'
import { getCharacter, getInventory, getZones, getZonasCompletadas, intentarEncuentro, previsualizarEncuentro } from '../lib/game'

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
  const [equipado, setEquipado] = useState([])
  const [error, setError] = useState('')

  // Misión abierta en el popup (al terminar de caminar hasta ella).
  const [zonaActiva, setZonaActiva] = useState(null)
  const [resultado, setResultado] = useState(null)
  const [luchando, setLuchando] = useState(false)

  async function cargar() {
    try {
      const [z, p, comp, inv] = await Promise.all([getZones(), getCharacter(), getZonasCompletadas(), getInventory()])
      setZonas(z)
      setPersonaje(p)
      setCompletadas(comp)
      setEquipado(inv.filter((i) => i.equipado))

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

  function handleLlegar(zonaId) {
    const zona = zonas.find((z) => z.id === zonaId)
    setResultado(null)
    setError('')
    setZonaActiva(zona ?? null)
  }

  async function handleCombatir() {
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

  function cerrar() {
    setZonaActiva(null)
    setResultado(null)
    setError('')
  }

  if (!personaje || zonas.length === 0) return error ? <p className="error">{error}</p> : <p>Cargando mapa...</p>

  const previewActiva = zonaActiva ? previews[zonaActiva.id] : null
  const porDebajoDeLoRecomendado = zonaActiva ? personaje.nivel < zonaActiva.requisito_nivel : false
  const sinIntentos = previewActiva?.intentos_restantes === 0

  return (
    <div className="pagina">
      <MapaCaminata
        zonas={zonas}
        nivel={personaje.nivel}
        apariencia={personaje.apariencia}
        equipado={equipado}
        completadas={completadas}
        bloqueado={!!zonaActiva}
        onLlegar={handleLlegar}
      />

      {error && !zonaActiva && <p className="error">{error}</p>}

      {zonaActiva && (
        <div className="overlay">
          <div className="tarjeta resultado-entrenamiento-overlay resultado-encuentro">
            <p className="resultado-titulo">{zonaActiva.nombre}</p>
            <strong>{zonaActiva.enemigo?.nombre}</strong>
            <p className="detalle-item">
              Poder {zonaActiva.enemigo?.poder} · Nivel recomendado {zonaActiva.requisito_nivel}
            </p>

            {previewActiva && (
              <>
                <p className={`chance-exito ${porDebajoDeLoRecomendado ? 'chance-baja' : ''}`}>
                  Probabilidad de éxito: {formatearChance(previewActiva.chance)}
                </p>
                <p className="detalle-item">Intentos hoy: {previewActiva.intentos_restantes} / 3</p>
              </>
            )}

            {resultado && (
              <div className="combate-desenlace">
                <p className={`combate-veredicto ${resultado.gano ? 'exito' : 'fallo'}`}>
                  {resultado.gano ? '¡VICTORIA!' : 'DERROTA'}
                </p>
                <p className="resultado-resumen">
                  {resultado.gano ? `¡Venciste a ${resultado.enemigo}!` : `${resultado.enemigo} fue demasiado. No esta vez.`}
                </p>
                {resultado.gano && <p className="resultado-xp">+{resultado.oro_ganado} 🪙</p>}
                {resultado.gano && resultado.item_ganado_id && (
                  <p className="detalle-item">¡También encontraste un objeto! Revisalo en el Inventario.</p>
                )}
                {!resultado.gano && resultado.oro_perdido > 0 && (
                  <p className="detalle-item fallo">Perdiste 🪙 {resultado.oro_perdido} en la huida.</p>
                )}
                {!resultado.gano && resultado.item_perdido_nombre && (
                  <p className="detalle-item fallo">
                    ¡Perdiste {NOMBRES_SLOT[resultado.item_perdido_slot] ?? 'un ítem'} equipado: {resultado.item_perdido_nombre}!
                  </p>
                )}
              </div>
            )}

            {error && <p className="error">{error}</p>}

            <button disabled={luchando || sinIntentos} onClick={handleCombatir}>
              {luchando ? 'Combatiendo...' : resultado ? (sinIntentos ? 'Sin intentos hoy' : '↻ Repetir') : sinIntentos ? 'Sin intentos hoy' : '⚔️ Combatir'}
            </button>
            <button className="boton-vender" disabled={luchando} onClick={cerrar}>
              Cerrar
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
