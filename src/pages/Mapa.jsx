import { useEffect, useState } from 'react'
import { getCharacter, getZones, intentarEncuentro, previsualizarEncuentro } from '../lib/game'

function formatearChance(chance) {
  const pct = chance * 100
  if (pct < 1) return `${pct.toFixed(2)}%`
  if (pct < 10) return `${pct.toFixed(1)}%`
  return `${Math.round(pct)}%`
}

export default function Mapa() {
  const [zonas, setZonas] = useState([])
  const [nivel, setNivel] = useState(1)
  const [previews, setPreviews] = useState({})
  const [error, setError] = useState('')
  const [resultado, setResultado] = useState(null)
  const [zonaActiva, setZonaActiva] = useState(null)
  const [luchando, setLuchando] = useState(false)

  async function cargar() {
    try {
      const [z, personaje] = await Promise.all([getZones(), getCharacter()])
      setZonas(z)
      setNivel(personaje.nivel)

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

  async function handleIntentar(zona) {
    setLuchando(true)
    setError('')
    setResultado(null)
    setZonaActiva(zona)
    try {
      const r = await intentarEncuentro(zona.id)
      setResultado(r)
      await cargar()
    } catch (e) {
      setError(e.message)
    }
    setLuchando(false)
  }

  function aplanarZonas() {
    const hijasDe = (id) => zonas.filter((z) => z.zona_padre_id === id)
    const resultado = []
    function recorrer(zona, profundidad) {
      resultado.push({ zona, profundidad })
      hijasDe(zona.id).forEach((h) => recorrer(h, profundidad + 1))
    }
    zonas.filter((z) => !z.zona_padre_id).forEach((z) => recorrer(z, 0))
    return resultado
  }

  function renderZona({ zona, profundidad }) {
    const preview = previews[zona.id]
    const porDebajoDeLoRecomendado = nivel < zona.requisito_nivel
    return (
      <div key={zona.id} style={{ marginLeft: profundidad * 16 }} className={`tarjeta zona ${porDebajoDeLoRecomendado ? 'zona-riesgosa' : ''}`}>
        <div>
          <strong>{zona.nombre}</strong>
          <p className="detalle-item">
            {zona.enemigo?.nombre} · Poder {zona.enemigo?.poder} · Nivel recomendado {zona.requisito_nivel}
          </p>
          {preview && (
            <p className={`chance-exito ${porDebajoDeLoRecomendado ? 'chance-baja' : ''}`}>
              Probabilidad de éxito: {formatearChance(preview.chance)}
            </p>
          )}
        </div>
        <button disabled={luchando} onClick={() => handleIntentar(zona)}>
          Explorar
        </button>
      </div>
    )
  }

  return (
    <div className="pagina">
      {error && <p className="error">{error}</p>}

      {zonaActiva && (
        <div className="tarjeta resultado-encuentro">
          <strong>{zonaActiva.nombre}</strong>
          {luchando && <p>Resolviendo el encuentro...</p>}
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
            </>
          )}
        </div>
      )}

      <div className="lista-items">{aplanarZonas().map((entrada) => renderZona(entrada))}</div>
    </div>
  )
}
