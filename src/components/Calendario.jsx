import { useEffect, useState } from 'react'

const MESES = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
]
const DIAS = ['L', 'M', 'X', 'J', 'V', 'S', 'D']

function toFecha(d) {
  return d.toISOString().slice(0, 10)
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
  const hoy = toFecha(new Date())

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
