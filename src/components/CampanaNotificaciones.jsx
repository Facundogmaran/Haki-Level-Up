import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { contarNoLeidas } from '../lib/social'
import IconoCampana from './IconoCampana'

// Campana con el contador de notificaciones sin leer.
export default function CampanaNotificaciones({ className = '' }) {
  const navigate = useNavigate()
  const [noLeidas, setNoLeidas] = useState(0)

  useEffect(() => {
    contarNoLeidas().then(setNoLeidas).catch(() => setNoLeidas(0))
  }, [])

  return (
    <button
      className={`campana ${className}`}
      onClick={() => navigate('/notificaciones')}
      aria-label={noLeidas > 0 ? `Notificaciones (${noLeidas} sin leer)` : 'Notificaciones'}
      title="Notificaciones"
    >
      <IconoCampana />
      {noLeidas > 0 && <span className="campana-contador">{noLeidas > 9 ? '9+' : noLeidas}</span>}
    </button>
  )
}
