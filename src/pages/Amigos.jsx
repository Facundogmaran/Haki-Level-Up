import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import CampanaNotificaciones from '../components/CampanaNotificaciones'
import {
  buscarPersonajes,
  eliminarAmistad,
  enviarSolicitudAmistad,
  formatearFechaHora,
  getHistorialPvp,
  getSocial,
  responderSolicitudAmistad,
} from '../lib/social'

export default function Amigos() {
  const navigate = useNavigate()
  const [social, setSocial] = useState(null)
  const [historial, setHistorial] = useState([])
  const [error, setError] = useState('')
  const [ocupado, setOcupado] = useState(false)

  const [agregando, setAgregando] = useState(false)
  const [busqueda, setBusqueda] = useState('')
  const [resultados, setResultados] = useState(null)
  const [verHistorial, setVerHistorial] = useState(false)

  async function cargar() {
    try {
      const [s, h] = await Promise.all([getSocial(), getHistorialPvp(30)])
      setSocial(s)
      setHistorial(h)
    } catch (e) {
      setError(e.message)
    }
  }

  useEffect(() => {
    cargar()
  }, [])

  async function accion(fn) {
    setOcupado(true)
    setError('')
    try {
      await fn()
      await cargar()
    } catch (e) {
      setError(e.message)
    }
    setOcupado(false)
  }

  async function handleBuscar(e) {
    e.preventDefault()
    setError('')
    try {
      setResultados(await buscarPersonajes(busqueda))
    } catch (err) {
      setError(err.message)
    }
  }

  async function refrescarBusqueda() {
    if (resultados) setResultados(await buscarPersonajes(busqueda))
  }

  if (!social) return error ? <p className="error">{error}</p> : <p>Cargando...</p>

  return (
    <div className="pagina">
      <div className="fila-titulo">
        <h2>Amigos</h2>
        <CampanaNotificaciones />
      </div>

      {error && <p className="error">{error}</p>}

      <button className="boton-primario" onClick={() => setAgregando(!agregando)}>
        {agregando ? 'Cerrar búsqueda' : '+ Agregar amigo'}
      </button>

      {agregando && (
        <div className="tarjeta form-entreno">
          <form className="form-buscar" onSubmit={handleBuscar}>
            <input
              type="text"
              placeholder="Nombre del personaje"
              value={busqueda}
              onChange={(e) => setBusqueda(e.target.value)}
              autoFocus
            />
            <button type="submit" disabled={busqueda.trim().length < 2}>Buscar</button>
          </form>
          {resultados && resultados.length === 0 && <p className="detalle-item">No se encontraron personajes.</p>}
          {resultados?.map((r) => (
            <div key={r.character_id} className="item-catalogo">
              <div>
                <strong>{r.nombre}</strong>
                <p className="detalle-item">Nivel {r.nivel}</p>
              </div>
              {r.relacion === 'ninguna' && (
                <button
                  disabled={ocupado}
                  onClick={() =>
                    accion(async () => {
                      await enviarSolicitudAmistad(r.character_id)
                      await refrescarBusqueda()
                    })
                  }
                >
                  Enviar solicitud
                </button>
              )}
              {r.relacion === 'solicitud_enviada' && <span className="detalle-item">Solicitud enviada</span>}
              {r.relacion === 'amigos' && <span className="detalle-item">Ya son amigos</span>}
              {r.relacion === 'solicitud_recibida' && (
                <button
                  disabled={ocupado}
                  onClick={() =>
                    accion(async () => {
                      await responderSolicitudAmistad(r.friendship_id, true)
                      await refrescarBusqueda()
                    })
                  }
                >
                  Aceptar
                </button>
              )}
            </div>
          ))}
        </div>
      )}

      {social.recibidas.length > 0 && (
        <div className="tarjeta">
          <h3>Solicitudes recibidas</h3>
          <div className="lista-items">
            {social.recibidas.map((s) => (
              <div key={s.friendship_id} className="item-catalogo">
                <div>
                  <strong>{s.nombre}</strong>
                  <p className="detalle-item">Nivel {s.nivel}</p>
                </div>
                <div className="acciones-item-inventario">
                  <button disabled={ocupado} onClick={() => accion(() => responderSolicitudAmistad(s.friendship_id, true))}>
                    Aceptar
                  </button>
                  <button
                    className="boton-vender"
                    disabled={ocupado}
                    onClick={() => accion(() => responderSolicitudAmistad(s.friendship_id, false))}
                  >
                    Rechazar
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {social.enviadas.length > 0 && (
        <div className="tarjeta">
          <h3>Solicitudes enviadas</h3>
          <div className="lista-items">
            {social.enviadas.map((s) => (
              <div key={s.friendship_id} className="item-catalogo">
                <div>
                  <strong>{s.nombre}</strong>
                  <p className="detalle-item">Nivel {s.nivel} · pendiente</p>
                </div>
                <button className="boton-vender" disabled={ocupado} onClick={() => accion(() => eliminarAmistad(s.friendship_id))}>
                  Cancelar
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="lista-items">
        {social.amigos.length === 0 && <p className="detalle-item">Todavía no tenés amigos agregados.</p>}
        {social.amigos.map((a) => (
          <button
            key={a.character_id}
            className="tarjeta item-catalogo item-catalogo-boton"
            onClick={() => navigate(`/amigos/${a.character_id}`)}
          >
            <div>
              <strong>{a.nombre}</strong>
              <p className="detalle-item">
                Nivel {a.nivel} · ⚡ Poder {Math.round(a.poder)}
              </p>
            </div>
            <span className={`detalle-item${a.combates_hoy >= social.combates_max ? ' fallo' : ''}`}>
              ⚔️ {social.combates_max - a.combates_hoy}/{social.combates_max}
            </span>
          </button>
        ))}
      </div>

      <div className="tarjeta workout-registrado">
        <button className="item-catalogo workout-registrado-header" onClick={() => setVerHistorial(!verHistorial)}>
          <strong>Historial de combates</strong>
          <span className="detalle-item">{verHistorial ? '▾' : '▸'}</span>
        </button>
        {verHistorial && (
          <div className="workout-registrado-detalle">
            {historial.length === 0 && <p className="detalle-item">Todavía no combatiste a nadie.</p>}
            {historial.map((h) => (
              <div key={h.id} className="fila-historial">
                <div>
                  <strong>{h.defensor_nombre}</strong>
                  <p className="detalle-item">
                    {formatearFechaHora(h.created_at)} · combate {h.detalle?.combate_n_hoy}/{h.detalle?.combates_max} del día
                  </p>
                </div>
                <div className="fila-historial-resultado">
                  <span className={h.gano_atacante ? 'exito' : 'fallo'}>{h.gano_atacante ? 'Victoria' : 'Derrota'}</span>
                  {h.gano_atacante && <span className="detalle-item">+{h.oro_ganado} 🪙</span>}
                  {h.item && <span className="detalle-item">🎁 {h.item.nombre}</span>}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
