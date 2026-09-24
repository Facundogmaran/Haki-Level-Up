import { useEffect, useState } from 'react'
import { getCharacter, getZones, intentarEncuentro } from '../lib/game'

export default function Mapa() {
  const [zonas, setZonas] = useState([])
  const [nivel, setNivel] = useState(1)
  const [error, setError] = useState('')
  const [resultado, setResultado] = useState(null)
  const [zonaActiva, setZonaActiva] = useState(null)
  const [luchando, setLuchando] = useState(false)

  async function cargar() {
    try {
      const [z, personaje] = await Promise.all([getZones(), getCharacter()])
      setZonas(z)
      setNivel(personaje.nivel)
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
      if (r.gano) await cargar()
    } catch (e) {
      setError(e.message)
    }
    setLuchando(false)
  }

  const raices = zonas.filter((z) => !z.zona_padre_id)
  const hijasDe = (id) => zonas.filter((z) => z.zona_padre_id === id)

  function renderZona(zona, profundidad = 0) {
    const desbloqueada = nivel >= zona.requisito_nivel
    return (
      <div key={zona.id} style={{ marginLeft: profundidad * 16 }}>
        <div className={`tarjeta zona ${desbloqueada ? '' : 'zona-bloqueada'}`}>
          <div>
            <strong>{zona.nombre}</strong>
            <p className="detalle-item">
              {zona.enemigo?.nombre} · Poder {zona.enemigo?.poder} · Nivel mínimo {zona.requisito_nivel}
            </p>
          </div>
          <button disabled={!desbloqueada || luchando} onClick={() => handleIntentar(zona)}>
            {desbloqueada ? 'Explorar' : `Nivel ${zona.requisito_nivel}`}
          </button>
        </div>
        {hijasDe(zona.id).map((h) => renderZona(h, profundidad + 1))}
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
              <p className="detalle-item">Probabilidad de éxito: {Math.round(resultado.chance * 100)}%</p>
              {resultado.gano && <p className="detalle-item">Ganaste 🪙 {resultado.oro_ganado}</p>}
              {resultado.item_ganado_id && <p className="detalle-item">¡También encontraste un objeto! Revisalo en la Tienda &gt; Inventario.</p>}
            </>
          )}
        </div>
      )}

      <div className="lista-items">{raices.map((z) => renderZona(z))}</div>
    </div>
  )
}
