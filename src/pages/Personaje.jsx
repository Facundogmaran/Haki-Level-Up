import { useEffect, useState } from 'react'
import { ATRIBUTOS, asignarPunto, getCharacter, xpRequeridaParaNivel } from '../lib/game'

const NOMBRES = {
  fuerza: 'Fuerza',
  resistencia: 'Resistencia',
  agilidad: 'Agilidad',
  vitalidad: 'Vitalidad',
  mente: 'Mente',
}

export default function Personaje() {
  const [personaje, setPersonaje] = useState(null)
  const [error, setError] = useState('')
  const [asignando, setAsignando] = useState(false)

  async function cargar() {
    try {
      const data = await getCharacter()
      setPersonaje(data)
    } catch (e) {
      setError(e.message)
    }
  }

  useEffect(() => {
    cargar()
  }, [])

  async function handleAsignar(atributo) {
    setAsignando(true)
    setError('')
    try {
      await asignarPunto(atributo)
      await cargar()
    } catch (e) {
      setError(e.message)
    }
    setAsignando(false)
  }

  if (error) return <p className="error">{error}</p>
  if (!personaje) return <p>Cargando personaje...</p>

  const xpNivelActual = xpRequeridaParaNivel(personaje.nivel)
  const xpNivelSiguiente = xpRequeridaParaNivel(personaje.nivel + 1)
  const progreso = Math.min(
    100,
    ((personaje.xp_total - xpNivelActual) / (xpNivelSiguiente - xpNivelActual)) * 100,
  )

  return (
    <div className="pagina">
      <div className="tarjeta encabezado-personaje">
        <h2>{personaje.nombre}</h2>
        <div className="fila-stats-top">
          <span>Nivel {personaje.nivel}</span>
          <span>🪙 {personaje.oro}</span>
        </div>
        <div className="barra-xp">
          <div className="barra-xp-relleno" style={{ width: `${Math.max(0, progreso)}%` }} />
        </div>
        <p className="detalle-xp">
          {Math.round(personaje.xp_total)} XP · próximo nivel en {Math.max(0, Math.round(xpNivelSiguiente - personaje.xp_total))} XP
        </p>
      </div>

      {personaje.puntos_libres > 0 && (
        <p className="aviso-puntos">Tenés {personaje.puntos_libres} punto(s) de atributo para asignar</p>
      )}

      <div className="tarjeta">
        <h3>Atributos</h3>
        <div className="lista-atributos">
          {ATRIBUTOS.map((atributo) => (
            <div key={atributo} className="fila-atributo">
              <span className="nombre-atributo">{NOMBRES[atributo]}</span>
              <span className="valor-atributo">{personaje[atributo]}</span>
              {personaje.puntos_libres > 0 && (
                <button disabled={asignando} onClick={() => handleAsignar(atributo)}>
                  +
                </button>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
