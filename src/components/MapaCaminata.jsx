// Mapa visual: dibuja el árbol de zonas como un camino con nodos, partiendo
// del Pueblo. El personaje (AvatarAnimado) recorre el camino nodo por nodo
// hasta la zona tocada y recién al llegar avisa (onLlegar) para abrir la misión.
import { useEffect, useRef, useState } from 'react'
import AvatarAnimado from './AvatarAnimado'

export const MAPA_VIEWBOX = { w: 300, h: 430 }

const PUEBLO_ID = 'pueblo'
const MS_POR_TRAMO = 550 // debe coincidir con la transición de .mapa-personaje

// Posiciones fijas por id de zona. Si se agregan zonas nuevas sin posición
// definida acá, caen en una fila extra abajo para que el mapa no se rompa.
const POSICIONES = {
  [PUEBLO_ID]: { x: 150, y: 32 },
  1: { x: 150, y: 105 }, // Bosque Lindero
  2: { x: 70, y: 180 }, // Camino del Bandido
  3: { x: 230, y: 180 }, // Espesura del Lobo
  4: { x: 230, y: 255 }, // Campamento Orco
  5: { x: 150, y: 325 }, // Guarida Orca
  6: { x: 150, y: 395 }, // Fortaleza del Capitán
}

function posicionDe(id, indiceFallback = 0) {
  return POSICIONES[id] ?? { x: 150, y: MAPA_VIEWBOX.h + indiceFallback * 70 }
}

function direccionEntre(desde, hasta) {
  const dx = hasta.x - desde.x
  const dy = hasta.y - desde.y
  if (Math.abs(dx) > Math.abs(dy)) return dx > 0 ? 'derecha' : 'izquierda'
  return dy > 0 ? 'abajo' : 'arriba'
}

export default function MapaCaminata({ zonas, nivel, apariencia, equipado, completadas, bloqueado, onLlegar }) {
  const [posActualId, setPosActualId] = useState(PUEBLO_ID)
  const [direccion, setDireccion] = useState('abajo')
  const [caminando, setCaminando] = useState(false)
  const timeoutsRef = useRef([])

  useEffect(() => () => timeoutsRef.current.forEach(clearTimeout), [])

  // La zona raíz del árbol cuelga del Pueblo.
  function padreDe(id) {
    if (id === PUEBLO_ID) return null
    return zonas.find((z) => z.id === id)?.zona_padre_id ?? PUEBLO_ID
  }

  function cadenaHaciaLaRaiz(id) {
    const cadena = [id]
    while (padreDe(cadena[cadena.length - 1]) != null) cadena.push(padreDe(cadena[cadena.length - 1]))
    return cadena
  }

  // Nodos a recorrer (sin incluir el de partida): sube hasta el ancestro
  // común y baja hasta el destino, siguiendo siempre los caminos del mapa.
  function rutaEntre(desdeId, hastaId) {
    const subida = cadenaHaciaLaRaiz(desdeId)
    const bajada = cadenaHaciaLaRaiz(hastaId)
    const comun = subida.find((id) => bajada.includes(id))
    return [...subida.slice(1, subida.indexOf(comun) + 1), ...bajada.slice(0, bajada.indexOf(comun)).reverse()]
  }

  function irA(destinoId) {
    if (caminando || bloqueado) return
    if (destinoId === posActualId) {
      if (destinoId !== PUEBLO_ID) onLlegar?.(destinoId)
      return
    }

    const trayecto = [posActualId, ...rutaEntre(posActualId, destinoId)]
    setCaminando(true)
    timeoutsRef.current.forEach(clearTimeout)
    timeoutsRef.current = []

    for (let i = 0; i < trayecto.length - 1; i++) {
      const desde = trayecto[i]
      const hasta = trayecto[i + 1]
      timeoutsRef.current.push(
        setTimeout(() => {
          setDireccion(direccionEntre(posicionDe(desde), posicionDe(hasta)))
          setPosActualId(hasta)
        }, i * MS_POR_TRAMO),
      )
    }
    timeoutsRef.current.push(
      setTimeout(() => {
        setCaminando(false)
        if (destinoId !== PUEBLO_ID) onLlegar?.(destinoId)
      }, (trayecto.length - 1) * MS_POR_TRAMO + 150),
    )
  }

  const posActual = posicionDe(posActualId)
  const pct = (pos) => ({ left: `${(pos.x / MAPA_VIEWBOX.w) * 100}%`, top: `${(pos.y / MAPA_VIEWBOX.h) * 100}%` })

  return (
    <div className="mapa-lienzo">
      <svg viewBox={`0 0 ${MAPA_VIEWBOX.w} ${MAPA_VIEWBOX.h}`} className="mapa-svg">
        {zonas.map((z, i) => {
          const desde = posicionDe(padreDe(z.id), i)
          const hasta = posicionDe(z.id, i)
          return <line key={z.id} x1={desde.x} y1={desde.y} x2={hasta.x} y2={hasta.y} className="mapa-camino" />
        })}
      </svg>

      <button
        className="mapa-nodo mapa-nodo-pueblo"
        style={pct(posicionDe(PUEBLO_ID))}
        disabled={caminando || bloqueado}
        onClick={() => irA(PUEBLO_ID)}
      >
        <span className="mapa-nodo-punto" />
        <span className="mapa-nodo-etiqueta">🏠 Pueblo</span>
      </button>

      {zonas.map((z, i) => {
        const completada = completadas?.has(z.id)
        const disponible = !z.zona_padre_id || completadas?.has(z.zona_padre_id)
        const riesgosa = nivel < z.requisito_nivel

        let estado = 'normal'
        if (completada) estado = 'completada'
        else if (!disponible) estado = 'bloqueada'
        else if (riesgosa) estado = 'riesgosa'

        return (
          <button
            key={z.id}
            className={`mapa-nodo mapa-nodo-${estado} ${z.id === posActualId ? 'mapa-nodo-activo' : ''}`}
            style={pct(posicionDe(z.id, i))}
            disabled={!disponible || caminando || bloqueado}
            onClick={() => irA(z.id)}
          >
            <span className="mapa-nodo-punto" />
            <span className="mapa-nodo-etiqueta">{z.nombre}</span>
          </button>
        )
      })}

      <div className="mapa-personaje" style={pct(posActual)}>
        <AvatarAnimado apariencia={apariencia} direccion={direccion} arrastrable={false} equipado={equipado} />
      </div>

      {caminando && <p className="mapa-caminando">Caminando...</p>}
    </div>
  )
}
