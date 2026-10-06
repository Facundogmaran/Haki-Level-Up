import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { formatearFechaHora, getNotificaciones, marcarNotificacionesLeidas } from '../lib/social'

function contenido(n) {
  const d = n.datos
  switch (n.tipo) {
    case 'combate_recibido':
      return {
        titulo: `⚔️ ${d.rival_nombre} te combatió`,
        detalle: `${d.rival_nombre} ${d.gano_atacante ? 'ganó' : 'perdió'} el combate.`,
      }
    case 'combate_realizado':
      return {
        titulo: d.gano ? `⚔️ Combate ganado contra ${d.rival_nombre}` : `⚔️ Combate perdido contra ${d.rival_nombre}`,
        detalle: d.gano ? `+${d.oro} 🪙 Oro${d.item_nombre ? ` · 🎁 ${d.item_nombre}` : ''}` : null,
      }
    case 'solicitud_amistad':
      return { titulo: `🤝 ${d.nombre} quiere ser tu amigo`, detalle: 'Respondé la solicitud desde Amigos.', destino: '/amigos' }
    case 'amistad_aceptada':
      return { titulo: `🤝 ${d.nombre} aceptó tu solicitud de amistad`, detalle: null, destino: '/amigos' }
    default:
      return { titulo: 'Notificación', detalle: null }
  }
}

export default function Notificaciones() {
  const navigate = useNavigate()
  const [lista, setLista] = useState(null)
  const [error, setError] = useState('')

  useEffect(() => {
    async function cargar() {
      try {
        // Se muestra el estado "nuevo" de cada una y recién después se
        // marcan como leídas (el historial queda guardado).
        setLista(await getNotificaciones())
        await marcarNotificacionesLeidas()
      } catch (e) {
        setError(e.message)
      }
    }
    cargar()
  }, [])

  if (error) return <p className="error">{error}</p>
  if (!lista) return <p>Cargando...</p>

  return (
    <div className="pagina">
      <button className="boton-volver" onClick={() => navigate(-1)}>‹ Volver</button>
      <h2>Notificaciones</h2>

      {lista.length === 0 && <p className="detalle-item">No tenés notificaciones.</p>}

      <div className="lista-items">
        {lista.map((n) => {
          const c = contenido(n)
          return (
            <div
              key={n.id}
              className={`tarjeta notificacion${n.leida ? '' : ' notificacion-nueva'}${c.destino ? ' item-catalogo-clicable' : ''}`}
              onClick={c.destino ? () => navigate(c.destino) : undefined}
            >
              <strong>
                {!n.leida && <span className="punto-nuevo" aria-label="Nueva" />}
                {c.titulo}
              </strong>
              {c.detalle && <p className="detalle-item">{c.detalle}</p>}
              <p className="detalle-item">{formatearFechaHora(n.created_at)}</p>
            </div>
          )
        })}
      </div>
    </div>
  )
}
