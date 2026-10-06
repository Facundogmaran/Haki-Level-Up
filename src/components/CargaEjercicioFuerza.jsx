import { useEffect, useRef, useState } from 'react'

function rutaImagen(ej) {
  return ej.imagen ? `/ejercicios/${ej.imagen}.webp` : null
}

function Ilustracion({ ej, className }) {
  const [fallo, setFallo] = useState(false)
  const ruta = rutaImagen(ej)
  if (!ruta || fallo) return <span className={`${className} ilustracion-vacia`}>🏋️</span>
  return <img className={className} src={ruta} alt={ej.nombre} loading="lazy" draggable="false" onError={() => setFallo(true)} />
}

// Carrusel horizontal de ejercicios + imagen grande + tabla de series del
// ejercicio activo. Los datos viven en el padre (Entrenamiento.jsx): acá
// solo se editan las series del ejercicio activo.
export default function CargaEjercicioFuerza({
  ejercicios,
  activoId,
  onSeleccionar,
  conDatos,
  nombreGrupo,
  ultimoRegistro,
  sets,
  onCambiarSets,
}) {
  const carruselRef = useRef(null)
  const activo = ejercicios.find((e) => e.id === activoId)

  useEffect(() => {
    const el = carruselRef.current?.querySelector('[aria-current="true"]')
    el?.scrollIntoView({ inline: 'center', block: 'nearest', behavior: 'smooth' })
  }, [activoId])

  function cambiar(i, campo, valor) {
    onCambiarSets(sets.map((s, idx) => (idx === i ? { ...s, [campo]: valor } : s)))
  }

  function agregar() {
    onCambiarSets([...sets, { peso_kg: '', repeticiones: '' }])
  }

  function duplicar(i) {
    onCambiarSets([...sets.slice(0, i + 1), { ...sets[i] }, ...sets.slice(i + 1)])
  }

  function eliminar(i) {
    onCambiarSets(sets.filter((_, idx) => idx !== i))
  }

  if (!activo) return null

  return (
    <div className="carga-ejercicio">
      <div className="carrusel-ejercicios" ref={carruselRef}>
        {ejercicios.map((ej) => (
          <button
            key={ej.id}
            className={`carrusel-item${ej.id === activoId ? ' carrusel-item-activo' : ''}`}
            onClick={() => onSeleccionar(ej)}
            aria-current={ej.id === activoId}
            title={ej.nombre}
          >
            <Ilustracion ej={ej} className="carrusel-miniatura" />
            <span className="carrusel-nombre">{ej.nombre}</span>
            {conDatos.has(ej.id) && <span className="carrusel-check">✓</span>}
          </button>
        ))}
      </div>

      <div className="ejercicio-imagen-grande">
        <Ilustracion ej={activo} className="ejercicio-imagen" />
      </div>

      <div className="ejercicio-titulo">
        <h3>{activo.nombre}</h3>
        <p className="detalle-item">{nombreGrupo}</p>
        {ultimoRegistro && (
          <p className="detalle-item">
            Última vez: {ultimoRegistro.peso_kg} kg × {ultimoRegistro.repeticiones} reps
          </p>
        )}
      </div>

      <div className="tabla-series">
        <div className="tabla-series-fila tabla-series-cabecera">
          <span>#</span>
          <span>Reps</span>
          <span>Peso (kg)</span>
          <span />
        </div>
        {sets.map((s, i) => (
          <div key={i} className="tabla-series-fila">
            <span className="tabla-series-numero">{i + 1}</span>
            <input
              type="number"
              inputMode="numeric"
              min="0"
              step="1"
              value={s.repeticiones}
              onChange={(e) => cambiar(i, 'repeticiones', e.target.value)}
              aria-label={`Repeticiones de la serie ${i + 1}`}
            />
            <input
              type="number"
              inputMode="decimal"
              min="0"
              step="0.5"
              value={s.peso_kg}
              onChange={(e) => cambiar(i, 'peso_kg', e.target.value)}
              aria-label={`Peso de la serie ${i + 1}`}
            />
            <span className="tabla-series-acciones">
              <button onClick={() => duplicar(i)} title="Duplicar serie" aria-label="Duplicar serie">⧉</button>
              <button onClick={() => eliminar(i)} disabled={sets.length <= 1} title="Quitar serie" aria-label="Quitar serie">✕</button>
            </span>
          </div>
        ))}
      </div>

      <button className="boton-agregar-serie" onClick={agregar}>+ Agregar serie</button>
    </div>
  )
}
