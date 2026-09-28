// Avatar animado: mismas capas que Avatar.jsx pero usando las hojas de
// caminata LPC (9 frames x 4 direcciones). Reproduce el ciclo de caminata
// todo el tiempo; arrastrar horizontalmente rota el personaje entre las 4
// direcciones disponibles (no hay 360 real, LPC solo tiene 4 orientaciones).
import { useRef, useState } from 'react'
import {
  APARIENCIA_POR_DEFECTO,
  rutaCaraWalk,
  rutaCuerpoWalk,
  rutaOrejasWalk,
  rutaNarizWalk,
  rutaPeloWalk,
  rutaVelloFacialWalk,
} from '../lib/avatarAssets'

// Orden de filas dentro de cada hoja LPC (fila 0..3).
const FILA_DIRECCION = { arriba: 0, izquierda: 1, abajo: 2, derecha: 3 }
// Orden de "giro" al arrastrar: abajo -> derecha -> arriba -> izquierda -> abajo...
const ORDEN_GIRO = ['abajo', 'derecha', 'arriba', 'izquierda']
const PX_POR_PASO = 48

function CapaAnimada({ src, direccion }) {
  if (!src) return null
  const fila = FILA_DIRECCION[direccion]
  return (
    <div className="avatar-capa-viewport">
      <div
        className="avatar-capa-hoja"
        style={{
          backgroundImage: `url(${src})`,
          translate: `0% ${fila * -25}%`,
        }}
      />
    </div>
  )
}

export default function AvatarAnimado({ apariencia }) {
  const a = { ...APARIENCIA_POR_DEFECTO, ...apariencia }
  const [turno, setTurno] = useState(0) // índice dentro de ORDEN_GIRO
  const arrastre = useRef(null)

  const direccion = ORDEN_GIRO[turno]

  function onPointerDown(e) {
    arrastre.current = { ultimoX: e.clientX }
    e.currentTarget.setPointerCapture(e.pointerId)
  }

  function onPointerMove(e) {
    if (!arrastre.current) return
    const dx = e.clientX - arrastre.current.ultimoX
    if (Math.abs(dx) < PX_POR_PASO) return
    const pasos = Math.trunc(dx / PX_POR_PASO)
    arrastre.current.ultimoX += pasos * PX_POR_PASO
    setTurno((t) => ((t + pasos) % 4 + 4) % 4)
  }

  function onPointerUp() {
    arrastre.current = null
  }

  const capas = [
    { src: rutaCuerpoWalk(a.skinTone, a.bodyType), key: 'cuerpo' },
    { src: rutaCaraWalk(a.skinTone, a.bodyType), key: 'cara' },
    { src: rutaNarizWalk(a.skinTone), key: 'nariz' },
    { src: rutaVelloFacialWalk(a.facialHairStyle, a.hairColor), key: 'vello' },
    { src: rutaPeloWalk(a.hairStyle, a.hairColor), key: 'pelo' },
    { src: rutaOrejasWalk(a.skinTone), key: 'orejas' },
  ]

  return (
    <div
      className="avatar-lienzo avatar-lienzo-animado"
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerCancel={onPointerUp}
    >
      {capas.map(({ src, key }) => (
        <CapaAnimada key={key} src={src} direccion={direccion} />
      ))}
    </div>
  )
}
