import { useEffect, useState } from 'react'

const MESES = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
]
const DIAS = ['L', 'M', 'X', 'J', 'V', 'S', 'D']

function toFecha(d) {
  return d.toISOString().slice(0, 10)
}

// "Hoy" tiene que ser el día en Argentina, no en UTC -- toISOString()
// convierte a UTC, así que antes de la medianoche ART (que son 3
// horas menos) ya mostraba el día siguiente.
function hoyEnArgentina() {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Argentina/Buenos_Aires',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date())
}

function primerDiaSemana(date) {
  // Lunes = 0 ... Domingo = 6
  return (date.getDay() + 6) % 7
}

export default function Calendario({ fechaSeleccionada, diasConEntrenamiento = [], onSeleccionar, onCambiarMes }) {
  const [mesActual, setMesActual] = useState(() => {
    const [y, m] = fechaSeleccionada.split('-').map(Number)
    return new Date(y, m - 1, 1)
  })

  useEffect(() => {
    onCambiarMes?.(mesActual.getFullYear(), mesActual.getMonth() + 1)
  }, [mesActual])

  const diasDelMes = new Date(mesActual.getFullYear(), mesActual.getMonth() + 1, 0).getDate()
  const offset = primerDiaSemana(mesActual)
  const set = new Set(diasConEntrenamiento)
  const hoy = hoyEnArgentina()

  const celdas = []
  for (let i = 0; i < offset; i++) celdas.push(null)
  for (let dia = 1; dia <= diasDelMes; dia++) celdas.push(dia)

  function irAMes(delta) {
    setMesActual(new Date(mesActual.getFullYear(), mesActual.getMonth() + delta, 1))
  }

  return (
    <div className="calendario">
      <div className="calendario-header">
        <button onClick={() => irAMes(-1)}>‹</button>
        <span>{MESES[mesActual.getMonth()]} {mesActual.getFullYear()}</span>
        <button onClick={() => irAMes(1)}>›</button>
      </div>
      <div className="calendario-grid calendario-dias-semana">
        {DIAS.map((d) => (
          <span key={d}>{d}</span>
        ))}
      </div>
      <div className="calendario-grid">
        {celdas.map((dia, i) => {
          if (dia === null) return <span key={`vacio-${i}`} />
          const fecha = toFecha(new Date(mesActual.getFullYear(), mesActual.getMonth(), dia))
          const seleccionado = fecha === fechaSeleccionada
          const esHoy = fecha === hoy
          const tieneRegistro = set.has(fecha)
          return (
            <button
              key={fecha}
              className={`calendario-dia ${seleccionado ? 'seleccionado' : ''} ${esHoy ? 'hoy' : ''}`}
              onClick={() => onSeleccionar(fecha)}
            >
              {dia}
              {tieneRegistro && <span className="calendario-punto" />}
            </button>
          )
        })}
      </div>
    </div>
  )
}
