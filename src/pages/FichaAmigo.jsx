import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import AvatarAnimado from '../components/AvatarAnimado'
import IconoEquipo from '../components/IconoEquipo'
import ResultadoCombate from '../components/ResultadoCombate'
import { ATRIBUTOS, calcularPoder, getCharacter, getInventory, sumarBonusEquipo } from '../lib/game'
import { NOMBRES_ATRIBUTO, NOMBRES_CATEGORIA, bonusTexto, claveVisual } from '../lib/equipoDisplay'
import { combatirAmigo, eliminarAmistad, getSocial, verAmigo } from '../lib/social'

const PAUSA_MIN_MS = 1100

export default function FichaAmigo() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [amigo, setAmigo] = useState(null)
  const [yo, setYo] = useState(null)
  const [miPoder, setMiPoder] = useState(0)
  const [friendshipId, setFriendshipId] = useState(null)
  const [error, setError] = useState('')
  const [combate, setCombate] = useState(null) // { resultado } mientras haya overlay

  async function cargar() {
    try {
      const [a, p, social, inv] = await Promise.all([verAmigo(id), getCharacter(), getSocial(), getInventory()])
      const miBonus = sumarBonusEquipo(inv.filter((i) => i.equipado))
      setMiPoder(calcularPoder(p, miBonus))
      setAmigo(a)
      setYo(p)
      setFriendshipId(social.amigos.find((x) => x.character_id === id)?.friendship_id ?? null)
    } catch (e) {
      setError(e.message)
    }
  }

  useEffect(() => {
    cargar()
  }, [id])

  async function handleCombatir() {
    setError('')
    setCombate({ resultado: null })
    try {
      const [resultado] = await Promise.all([
        combatirAmigo(id),
        new Promise((r) => setTimeout(r, PAUSA_MIN_MS)),
      ])
      setCombate({ resultado })
    } catch (e) {
      setCombate(null)
      setError(e.message)
    }
  }

  async function cerrarCombate() {
    setCombate(null)
    await cargar()
  }

  async function handleQuitar() {
    if (!window.confirm(`¿Quitar a ${amigo.nombre} de tus amigos?`)) return
    try {
      await eliminarAmistad(friendshipId)
      navigate('/amigos')
    } catch (e) {
      setError(e.message)
    }
  }

  if (error && !amigo) return (
    <div className="pagina">
      <button className="boton-volver" onClick={() => navigate('/amigos')}>‹ Amigos</button>
      <p className="error">{error}</p>
    </div>
  )
  if (!amigo || !yo) return <p>Cargando...</p>

  const bonus = sumarBonusEquipo(amigo.equipado)
  const restantes = amigo.combates_max - amigo.combates_hoy

  return (
    <div className="pagina">
      <button className="boton-volver" onClick={() => navigate('/amigos')}>‹ Amigos</button>

      <div className="tarjeta encabezado-personaje">
        <div className="avatar-contenedor">
          <AvatarAnimado apariencia={amigo.apariencia} equipado={amigo.equipado} />
        </div>
        <h2>{amigo.nombre}</h2>
        <div className="fila-stats-top">
          <span>Nivel {amigo.nivel}</span>
          <span>⚡ Poder {Math.round(amigo.poder)}</span>
        </div>
      </div>

      <div className="tarjeta zona-combate">
        <button className="boton-combatir" disabled={restantes <= 0 || !!combate} onClick={handleCombatir}>
          ⚔️ COMBATIR
        </button>
        <p className="detalle-item">
          Combates disponibles hoy: {restantes}/{amigo.combates_max}
        </p>
        {error && <p className="error">{error}</p>}
      </div>

      <div className="tarjeta">
        <h3>Atributos</h3>
        <div className="lista-atributos">
          {ATRIBUTOS.map((atributo) => (
            <div key={atributo} className="fila-atributo">
              <span className="nombre-atributo">{NOMBRES_ATRIBUTO[atributo]}</span>
              <span />
              <span className="valor-atributo">
                {amigo[atributo] + bonus[atributo]}
                {bonus[atributo] !== 0 && (
                  <span className={`valor-atributo-bonus${bonus[atributo] < 0 ? ' negativo' : ''}`}>
                    {' '}
                    ({bonus[atributo] > 0 ? '+' : ''}
                    {bonus[atributo]})
                  </span>
                )}
              </span>
            </div>
          ))}
        </div>
      </div>

      <div className="tarjeta">
        <h3>Equipamiento</h3>
        {amigo.equipado.length === 0 && <p className="detalle-item">Sin equipamiento.</p>}
        <div className="lista-items">
          {amigo.equipado.map((inv) => (
            <div key={inv.id} className="item-catalogo-con-icono">
              <IconoEquipo
                carpeta={inv.item.base.lpc_sprite_folder}
                variante={claveVisual(inv.item.material?.nombre, inv.color?.nombre)}
                tieneBg={inv.item.base.lpc_zpos_bg != null}
              />
              <div>
                <strong>{inv.item.nombre}</strong>
                <p className="detalle-item">
                  {NOMBRES_CATEGORIA[inv.item.base.category]} · {bonusTexto(inv.item.bonus)}
                  {inv.color && <> · Color: {inv.color.nombre}</>}
                </p>
              </div>
            </div>
          ))}
        </div>
      </div>

      {friendshipId && (
        <button className="boton-vender" onClick={handleQuitar}>
          Quitar de amigos
        </button>
      )}

      {combate && (
        <ResultadoCombate
          yo={{ nombre: yo.nombre, nivel: yo.nivel, poder: miPoder }}
          rival={{ nombre: amigo.nombre, nivel: amigo.nivel, poder: amigo.poder }}
          resultado={combate.resultado}
          onCerrar={cerrarCombate}
        />
      )}
    </div>
  )
}
