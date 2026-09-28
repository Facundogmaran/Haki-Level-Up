const ICONOS = { correr: '🏃', bici: '🚴', caminata: '🚶', fuerza: '🏋️', calorias: '🔥' }

function resumenTexto(workout) {
  if (workout.tipo === 'cardio' && workout.subtipo === 'caminata') {
    return `${workout.pasos.toLocaleString('es-AR')} pasos`
  }
  if (workout.tipo === 'cardio') {
    return `${workout.distancia_km} km · ${workout.duracion_min} min · ${workout.velocidad_media_kmh} km/h`
  }
  if (workout.tipo === 'fuerza') {
    const minutos = Math.round(workout.duracion_min)
    return `${Math.floor(minutos / 60)}h ${minutos % 60}m · ${workout.ejercicios.length} ejercicio(s)`
  }
  if (workout.tipo === 'calorias') {
    return `${workout.kcal} kcal`
  }
  return ''
}

export default function ResultadoEntrenamiento({ workout, resultado, onCerrar }) {
  const icono = ICONOS[workout.subtipo] ?? ICONOS[workout.tipo]
  const subioDeNivel = resultado.nivel_nuevo > resultado.nivel_anterior

  return (
    <div className="overlay">
      <div className="tarjeta resultado-entrenamiento-overlay">
        <p className="resultado-titulo">Entrenamiento completado</p>
        <div className="resultado-icono">{icono}</div>
        <p className="resultado-resumen">{resumenTexto(workout)}</p>
        <p className="resultado-xp">+{Math.round(resultado.xp_otorgada)} XP</p>

        {subioDeNivel && (
          <div className="resultado-nivel-up">
            <p>¡Subiste de nivel!</p>
            <p className="resultado-nivel-cambio">
              Nivel {resultado.nivel_anterior} → {resultado.nivel_nuevo}
            </p>
          </div>
        )}

        <button onClick={onCerrar}>Continuar</button>
      </div>
    </div>
  )
}
