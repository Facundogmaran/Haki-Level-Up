import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import AvatarAnimado from '../components/AvatarAnimado'
import {
  ATRIBUTOS,
  asignarPunto,
  getCharacter,
  getInventory,
  sumarBonusEquipo,
  xpRequeridaParaNivel,
} from '../lib/game'

const NOMBRES = {
  fuerza: 'Fuerza',
  resistencia: 'Resistencia',
  agilidad: 'Agilidad',
  vitalidad: 'Vitalidad',
  mente: 'Mente',
}

const ICONOS_SLOT = {
  head: '🪖',
  neck: '📿',
  ring: '💍',
  shoulder: '🛡️',
  gloves: '🧤',
  torso: '👕',
  legs: '👖',
  feet: '👟',
  weapon: '⚔️',
  shield: '🛡️',
}

export default function Personaje() {
  const navigate = useNavigate()
  const [personaje, setPersonaje] = useState(null)
  const [equipado, setEquipado] = useState([])
  const [error, setError] = useState('')
  const [asignando, setAsignando] = useState(false)

  async function cargar() {
    try {
      const [data, inventario] = await Promise.all([getCharacter(), getInventory()])
      setPersonaje(data)
      setEquipado(inventario.filter((i) => i.equipado))
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

  const bonusEquipo = sumarBonusEquipo(equipado)
  const xpNivelActual = xpRequeridaParaNivel(personaje.nivel)
  const xpNivelSiguiente = xpRequeridaParaNivel(personaje.nivel + 1)
  const progreso = Math.min(
    100,
    ((personaje.xp_total - xpNivelActual) / (xpNivelSiguiente - xpNivelActual)) * 100,
  )

  return (
    <div className="pagina">
      <div className="tarjeta encabezado-personaje">
        <div className="avatar-contenedor">
          <AvatarAnimado apariencia={personaje.apariencia} equipado={equipado} />
        </div>
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
        <button className="boton-editar-personaje" onClick={() => navigate('/personaje/editar')}>
          Editar personaje
        </button>
      </div>

      {personaje.puntos_libres > 0 && (
        <p className="aviso-puntos">Tenés {personaje.puntos_libres} punto(s) de atributo para asignar</p>
      )}

      <div className="tarjeta">
        <h3>Atributos</h3>
        <div className="lista-atributos">
          {ATRIBUTOS.map((atributo) => {
            const bonus = bonusEquipo[atributo]
            return (
              <div key={atributo} className="fila-atributo">
                <span className="nombre-atributo">{NOMBRES[atributo]}</span>
                <span className="valor-atributo">
                  {personaje[atributo] + bonus}
                  {bonus !== 0 && (
                    <span className={`valor-atributo-bonus${bonus < 0 ? ' negativo' : ''}`}>
                      {' '}
                      ({bonus > 0 ? '+' : ''}
                      {bonus})
                    </span>
                  )}
                </span>
                {personaje.puntos_libres > 0 && (
                  <button disabled={asignando} onClick={() => handleAsignar(atributo)}>
                    +
                  </button>
                )}
              </div>
            )
          })}
        </div>
      </div>

      <div className="tarjeta">
        <h3>Equipamiento</h3>
        {equipado.length === 0 && <p className="detalle-item">Nada equipado todavía — visitá la Tienda.</p>}
        <div className="fila-equipamiento">
          {equipado.map((i) => (
            <div key={i.id} className="chip-equipamiento" title={i.item.nombre}>
              <span className="chip-equipamiento-icono">{ICONOS_SLOT[i.item.base.category] ?? '❔'}</span>
              <span className="chip-equipamiento-nombre">{i.item.nombre}</span>
              {i.color && (
                <span className="chip-equipamiento-color" style={{ backgroundColor: i.color.valor_hex }} />
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
