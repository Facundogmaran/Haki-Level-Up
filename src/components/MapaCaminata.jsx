// Mapa visual: dibuja el árbol de zonas como un camino con nodos, y el
// personaje (AvatarAnimado) se desplaza caminando de nodo a nodo.
import { useEffect, useRef, useState } from 'react'
import AvatarAnimado from './AvatarAnimado'

export const MAPA_VIEWBOX = { w: 300, h: 560 }

// Posiciones fijas para las 6 zonas actuales (por id). Si se agregan
// zonas nuevas sin posición definida acá, caen en una fila extra abajo
// para que el mapa no se rompa.
const POSICIONES = {
  1: { x: 150, y: 40 }, // Bosque Lindero
  2: { x: 70, y: 150 }, // Camino del Bandido
  3: { x: 230, y: 150 }, // Espesura del Lobo
  4: { x: 230, y: 280 }, // Campamento Orco
  5: { x: 150, y: 400 }, // Guarida Orca
  6: { x: 150, y: 520 }, // Fortaleza del Capitán
}

function posicionDe(zonaId, indiceFallback) {
  return POSICIONES[zonaId] ?? { x: 150, y: 560 + indiceFallback * 80 }
}

function direccionEntre(desde, hasta) {
  const dx = hasta.x - desde.x
  const dy = hasta.y - desde.y
  if (Math.abs(dx) > Math.abs(dy)) return dx > 0 ? 'derecha' : 'izquierda'
  return dy > 0 ? 'abajo' : 'arriba'
}

export default function MapaCaminata({ zonas, nivel, apariencia, zonaSeleccionadaId, onSeleccionar, onLlegar }) {
  const [posActualId, setPosActualId] = useState(zonas[0]?.id ?? null)
  const [direccion, setDireccion] = useState('abajo')
  const [caminando, setCaminando] = useState(false)
  const timeoutRef = useRef(null)

  useEffect(() => () => clearTimeout(timeoutRef.current), [])

  useEffect(() => {
    if (!zonaSeleccionadaId || zonaSeleccionadaId === posActualId) return
    const desde = posicionDe(posActualId, 0)
    const hasta = posicionDe(zonaSeleccionadaId, 0)
    setDireccion(direccionEntre(desde, hasta))
    setCaminando(true)
    setPosActualId(zonaSeleccionadaId)
    clearTimeout(timeoutRef.current)
    timeoutRef.current = setTimeout(() => {
      setCaminando(false)
      onLlegar?.(zonaSeleccionadaId)
    }, 900)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [zonaSeleccionadaId])

  const posActual = posicionDe(posActualId, 0)

  return (
    <div className="mapa-lienzo">
      <svg viewBox={`0 0 ${MAPA_VIEWBOX.w} ${MAPA_VIEWBOX.h}`} className="mapa-svg">
        {zonas
          .filter((z) => z.zona_padre_id)
          .map((z, i) => {
            const desde = posicionDe(z.zona_padre_id, i)
            const hasta = posicionDe(z.id, i)
            return (
              <line
                key={z.id}
                x1={desde.x}
                y1={desde.y}
                x2={hasta.x}
                y2={hasta.y}
                className="mapa-camino"
              />
            )
          })}
      </svg>

      {zonas.map((z, i) => {
        const pos = posicionDe(z.id, i)
        const bloqueada = nivel < z.requisito_nivel
        return (
          <button
            key={z.id}
            className={`mapa-nodo ${bloqueada ? 'mapa-nodo-riesgoso' : ''} ${z.id === zonaSeleccionadaId ? 'mapa-nodo-activo' : ''}`}
            style={{ left: `${(pos.x / MAPA_VIEWBOX.w) * 100}%`, top: `${(pos.y / MAPA_VIEWBOX.h) * 100}%` }}
            onClick={() => onSeleccionar?.(z)}
          >
            <span className="mapa-nodo-punto" />
            <span className="mapa-nodo-etiqueta">{z.nombre}</span>
          </button>
        )
      })}

      <div
        className="mapa-personaje"
        style={{ left: `${(posActual.x / MAPA_VIEWBOX.w) * 100}%`, top: `${(posActual.y / MAPA_VIEWBOX.h) * 100}%` }}
      >
        <AvatarAnimado apariencia={apariencia} direccion={direccion} arrastrable={false} />
      </div>

      {caminando && <p className="mapa-caminando">Caminando...</p>}
    </div>
  )
}
