// Avatar del personaje: un único SVG armado por capas simples.
// Pensado para ser fácil de ampliar: cada capa es una función que devuelve
// shapes de un viewBox fijo (0 0 200 320), según la variante elegida.

export const OPCIONES_FISICO = ['a', 'b', 'c']
export const OPCIONES_PELO = ['1', '2', '3']
export const OPCIONES_OJOS = ['1', '2', '3']
export const OPCIONES_BOCA = ['1', '2', '3']

const PIEL = '#e8b98a'
const PELO_COLOR = '#3a2a1a'
const TRAZO = '#1a1625'

const HEAD_CX = 100
const HEAD_CY = 68
const HEAD_R = 32

const MEDIDAS_FISICO = {
  a: { torsoX: 65, torsoW: 70, torsoY: 100, torsoH: 90, legW: 22, legGap: 12 },
  b: { torsoX: 72, torsoW: 56, torsoY: 100, torsoH: 90, legW: 16, legGap: 12 },
  c: { torsoX: 58, torsoW: 84, torsoY: 100, torsoH: 78, legW: 26, legGap: 12 },
}

function medidas(fisico) {
  const m = MEDIDAS_FISICO[fisico] ?? MEDIDAS_FISICO.a
  const legY = m.torsoY + m.torsoH
  const legH = 100
  const legsTotalW = m.legW * 2 + m.legGap
  const legsX = HEAD_CX - legsTotalW / 2
  return { ...m, legY, legH, legsX }
}

function Cuerpo({ fisico }) {
  const m = medidas(fisico)
  return (
    <g>
      <circle cx={HEAD_CX} cy={HEAD_CY} r={HEAD_R} fill={PIEL} stroke={TRAZO} strokeWidth="2" />
      <rect x={m.torsoX} y={m.torsoY} width={m.torsoW} height={m.torsoH} rx="16" fill={PIEL} stroke={TRAZO} strokeWidth="2" />
      <rect x={m.legsX} y={m.legY} width={m.legW} height={m.legH} rx="8" fill={PIEL} stroke={TRAZO} strokeWidth="2" />
      <rect x={m.legsX + m.legW + m.legGap} y={m.legY} width={m.legW} height={m.legH} rx="8" fill={PIEL} stroke={TRAZO} strokeWidth="2" />
    </g>
  )
}

function Pelo({ variante }) {
  if (variante === '2') {
    return (
      <g fill={PELO_COLOR} stroke={TRAZO} strokeWidth="1.5">
        <path d={`M ${HEAD_CX - HEAD_R - 2} ${HEAD_CY - 4} A ${HEAD_R + 4} ${HEAD_R + 4} 0 0 1 ${HEAD_CX + HEAD_R + 2} ${HEAD_CY - 4} L ${HEAD_CX + HEAD_R + 2} ${HEAD_CY - 12} A ${HEAD_R + 4} ${HEAD_R + 4} 0 0 0 ${HEAD_CX - HEAD_R - 2} ${HEAD_CY - 12} Z`} />
        <rect x={HEAD_CX - HEAD_R - 4} y={HEAD_CY - 6} width="10" height="34" rx="5" />
        <rect x={HEAD_CX + HEAD_R - 6} y={HEAD_CY - 6} width="10" height="34" rx="5" />
      </g>
    )
  }
  if (variante === '3') {
    return (
      <g fill={PELO_COLOR} stroke={TRAZO} strokeWidth="1.5">
        <path d={`M ${HEAD_CX - 4} ${HEAD_CY - HEAD_R - 22} L ${HEAD_CX + 6} ${HEAD_CY - HEAD_R + 2} L ${HEAD_CX - 14} ${HEAD_CY - HEAD_R + 4} Z`} />
        <path d={`M ${HEAD_CX + 10} ${HEAD_CY - HEAD_R - 16} L ${HEAD_CX + 18} ${HEAD_CY - HEAD_R + 4} L ${HEAD_CX} ${HEAD_CY - HEAD_R + 2} Z`} />
        <path d={`M ${HEAD_CX - 18} ${HEAD_CY - HEAD_R - 10} L ${HEAD_CX - 8} ${HEAD_CY - HEAD_R + 4} L ${HEAD_CX - 24} ${HEAD_CY - HEAD_R + 6} Z`} />
      </g>
    )
  }
  // '1' por defecto: gorro corto
  return (
    <path
      d={`M ${HEAD_CX - HEAD_R - 2} ${HEAD_CY - 2} A ${HEAD_R + 3} ${HEAD_R + 3} 0 0 1 ${HEAD_CX + HEAD_R + 2} ${HEAD_CY - 2} A ${HEAD_R + 10} ${HEAD_R + 10} 0 0 0 ${HEAD_CX - HEAD_R - 2} ${HEAD_CY - 2} Z`}
      fill={PELO_COLOR}
      stroke={TRAZO}
      strokeWidth="1.5"
    />
  )
}

function Ojos({ variante }) {
  const y = HEAD_CY - 2
  if (variante === '2') {
    return (
      <g stroke={TRAZO} strokeWidth="2.5" fill="none" strokeLinecap="round">
        <path d={`M ${HEAD_CX - 14} ${y} Q ${HEAD_CX - 9} ${y - 6} ${HEAD_CX - 4} ${y}`} />
        <path d={`M ${HEAD_CX + 4} ${y} Q ${HEAD_CX + 9} ${y - 6} ${HEAD_CX + 14} ${y}`} />
      </g>
    )
  }
  if (variante === '3') {
    return (
      <g stroke={TRAZO} strokeWidth="2.5" strokeLinecap="round">
        <line x1={HEAD_CX - 15} y1={y} x2={HEAD_CX - 5} y2={y} />
        <line x1={HEAD_CX + 5} y1={y} x2={HEAD_CX + 15} y2={y} />
      </g>
    )
  }
  return (
    <g fill={TRAZO}>
      <circle cx={HEAD_CX - 10} cy={y} r="3" />
      <circle cx={HEAD_CX + 10} cy={y} r="3" />
    </g>
  )
}

function Boca({ variante }) {
  const y = HEAD_CY + 14
  if (variante === '2') {
    return <path d={`M ${HEAD_CX - 9} ${y} Q ${HEAD_CX} ${y + 7} ${HEAD_CX + 9} ${y}`} stroke={TRAZO} strokeWidth="2.5" fill="none" strokeLinecap="round" />
  }
  if (variante === '3') {
    return <ellipse cx={HEAD_CX} cy={y + 2} rx="6" ry="5" fill={TRAZO} />
  }
  return <line x1={HEAD_CX - 8} y1={y} x2={HEAD_CX + 8} y2={y} stroke={TRAZO} strokeWidth="2.5" strokeLinecap="round" />
}

function colorDe(equipado, slot) {
  return equipado.find((e) => e.slot === slot)?.color
}

function EquipoCabeza({ color }) {
  if (!color) return null
  return (
    <path
      d={`M ${HEAD_CX - HEAD_R - 6} ${HEAD_CY - 4} A ${HEAD_R + 6} ${HEAD_R + 6} 0 0 1 ${HEAD_CX + HEAD_R + 6} ${HEAD_CY - 4} Z`}
      fill={color}
      stroke={TRAZO}
      strokeWidth="1.5"
    />
  )
}

function EquipoTorso({ color, fisico }) {
  if (!color) return null
  const m = medidas(fisico)
  return <rect x={m.torsoX - 3} y={m.torsoY - 2} width={m.torsoW + 6} height={m.torsoH * 0.75} rx="14" fill={color} stroke={TRAZO} strokeWidth="1.5" />
}

function EquipoPiernas({ color, fisico }) {
  if (!color) return null
  const m = medidas(fisico)
  return (
    <g fill={color} stroke={TRAZO} strokeWidth="1.5">
      <rect x={m.legsX - 2} y={m.legY - 2} width={m.legW + 4} height={m.legH * 0.55} rx="8" />
      <rect x={m.legsX + m.legW + m.legGap - 2} y={m.legY - 2} width={m.legW + 4} height={m.legH * 0.55} rx="8" />
    </g>
  )
}

function EquipoPies({ color, fisico }) {
  if (!color) return null
  const m = medidas(fisico)
  const y = m.legY + m.legH - 16
  return (
    <g fill={color} stroke={TRAZO} strokeWidth="1.5">
      <rect x={m.legsX - 3} y={y} width={m.legW + 6} height="16" rx="6" />
      <rect x={m.legsX + m.legW + m.legGap - 3} y={y} width={m.legW + 6} height="16" rx="6" />
    </g>
  )
}

function EquipoAccesorio({ color, fisico }) {
  if (!color) return null
  const m = medidas(fisico)
  return <circle cx={HEAD_CX} cy={m.torsoY + 14} r="7" fill={color} stroke={TRAZO} strokeWidth="1.5" />
}

function EquipoArma({ color, fisico }) {
  if (!color) return null
  const m = medidas(fisico)
  const x = m.torsoX + m.torsoW + 6
  return <rect x={x} y={m.torsoY - 6} width="8" height={m.torsoH + 30} rx="4" fill={color} stroke={TRAZO} strokeWidth="1.5" transform={`rotate(18 ${x} ${m.torsoY})`} />
}

export default function Avatar({ apariencia, equipado = [] }) {
  const fisico = apariencia?.fisico ?? 'a'
  const pelo = apariencia?.pelo ?? '1'
  const ojos = apariencia?.ojos ?? '1'
  const boca = apariencia?.boca ?? '1'

  return (
    <svg viewBox="0 0 200 320" className="avatar-svg" role="img" aria-label="Tu personaje">
      <Cuerpo fisico={fisico} />
      <EquipoPiernas color={colorDe(equipado, 'piernas')} fisico={fisico} />
      <EquipoPies color={colorDe(equipado, 'pies')} fisico={fisico} />
      <EquipoTorso color={colorDe(equipado, 'torso')} fisico={fisico} />
      <Boca variante={boca} />
      <Ojos variante={ojos} />
      <Pelo variante={pelo} />
      <EquipoCabeza color={colorDe(equipado, 'cabeza')} />
      <EquipoAccesorio color={colorDe(equipado, 'accesorio')} fisico={fisico} />
      <EquipoArma color={colorDe(equipado, 'arma')} fisico={fisico} />
    </svg>
  )
}
