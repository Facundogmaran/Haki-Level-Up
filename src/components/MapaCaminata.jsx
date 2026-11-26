// Mapa visual: dibuja el árbol de zonas de UNA página del mapa como un camino
// con nodos, partiendo del punto de inicio (el Pueblo en el primer mapa). El personaje (AvatarAnimado) recorre el camino nodo por nodo
// hasta la zona tocada y recién al llegar avisa (onLlegar) para abrir la misión.
import { useEffect, useRef, useState } from 'react'
import AvatarAnimado from './AvatarAnimado'

export const MAPA_VIEWBOX = { w: 300, h: 430 }

const PUEBLO_ID = 'pueblo'
const MS_POR_TRAMO = 550 // debe coincidir con la transición de .mapa-personaje

const INICIO = { x: 150, y: 32 }

// Posiciones fijas por lugar dentro de la página (la zona de menor id es el
// lugar 0, etc.), así todas las páginas comparten el mismo trazado de camino:
//   0 raíz · 1 y 2 salen de la raíz (izq / der) · 3 sigue a la 2 · 4 · 5
// Si una página tiene más zonas que lugares, caen en filas extra abajo.
const LUGARES = [
  { x: 150, y: 105 },
  { x: 70, y: 180 },
  { x: 230, y: 180 },
  { x: 230, y: 255 },
  { x: 150, y: 325 },
  { x: 150, y: 395 },
]

function direccionEntre(desde, hasta) {
  const dx = hasta.x - desde.x
  const dy = hasta.y - desde.y
  if (Math.abs(dx) > Math.abs(dy)) return dx > 0 ? 'derecha' : 'izquierda'
  return dy > 0 ? 'abajo' : 'arriba'
}

export default function MapaCaminata({ zonas, inicio, nivel, apariencia, equipado, completadas, bloqueado, onLlegar }) {
  const [posActualId, setPosActualId] = useState(PUEBLO_ID)
  const [direccion, setDireccion] = useState('abajo')
  const [caminando, setCaminando] = useState(false)
  const timeoutsRef = useRef([])

  useEffect(() => () => timeoutsRef.current.forEach(clearTimeout), [])

  const ordenadas = [...zonas].sort((a, b) => a.id - b.id)
  function posicionDe(id) {
    if (id === PUEBLO_ID) return INICIO
    const i = ordenadas.findIndex((z) => z.id === id)
    return LUGARES[i] ?? { x: 150, y: MAPA_VIEWBOX.h + (i - LUGARES.length + 1) * 70 }
  }

  // La zona raíz de la página (su padre está en otra página o no existe)
  // cuelga del punto de inicio.
  function padreDe(id) {
    if (id === PUEBLO_ID) return null
    const padre = zonas.find((z) => z.id === id)?.zona_padre_id
    return padre != null && zonas.some((z) => z.id === padre) ? padre : PUEBLO_ID
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
        {zonas.map((z) => {
          const desde = posicionDe(padreDe(z.id))
          const hasta = posicionDe(z.id)
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
        <span className="mapa-nodo-etiqueta">{inicio?.icono ?? '🏠'} {inicio?.nombre ?? 'Pueblo'}</span>
      </button>

      {zonas.map((z) => {
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
            style={pct(posicionDe(z.id))}
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
