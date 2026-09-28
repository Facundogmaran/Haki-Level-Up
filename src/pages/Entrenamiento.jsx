import { useEffect, useState } from 'react'
import Calendario from '../components/Calendario'
import ResultadoEntrenamiento from '../components/ResultadoEntrenamiento'
import {
  getDiasConEntrenamientoDelMes,
  getExercises,
  getMuscleGroups,
  getUltimoRegistroEjercicio,
  getWorkoutsPorFecha,
  registrarEntrenamiento,
} from '../lib/game'

const ICONOS_HISTORIAL = { correr: '🏃', bici: '🚴', caminata: '🚶', fuerza: '🏋️', calorias: '🔥' }

function hoyISO() {
  return new Date().toISOString().slice(0, 10)
}

function resumenWorkout(w) {
  if (w.tipo === 'cardio' && w.subtipo === 'caminata') return `${w.pasos} pasos`
  if (w.tipo === 'cardio') return `${w.distancia_km} km · ${w.duracion_min} min · ${w.velocidad_media_kmh} km/h`
  if (w.tipo === 'fuerza') {
    const musculos = [...new Set(w.ejercicios.map((e) => e.exercise?.nombre))].join(', ')
    return `${w.duracion_min} min · ${musculos}`
  }
  if (w.tipo === 'calorias') return `${w.kcal} kcal`
  return ''
}

export default function Entrenamiento() {
  const [fecha, setFecha] = useState(hoyISO())
  const [dias, setDias] = useState([])
  const [workouts, setWorkouts] = useState([])
  const [error, setError] = useState('')
  const [cargando, setCargando] = useState(false)

  const [paso, setPaso] = useState('lista') // lista | categoria | cardio_subtipo | cardio_form | caminata_form | fuerza_duracion | fuerza_musculo | fuerza_ejercicio | fuerza_carga | fuerza_resumen | calorias_form
  const [subtipo, setSubtipo] = useState(null)
  const [form, setForm] = useState({})
  const [musculos, setMusculos] = useState([])
  const [musculoActivo, setMusculoActivo] = useState(null)
  const [ejerciciosMusculo, setEjerciciosMusculo] = useState([])
  const [ejercicioActivo, setEjercicioActivo] = useState(null)
  const [ultimoRegistro, setUltimoRegistro] = useState(null)
  const [ejerciciosAgregados, setEjerciciosAgregados] = useState([])
  const [duracionFuerza, setDuracionFuerza] = useState('')

  const [resultado, setResultado] = useState(null)
  const [workoutGuardado, setWorkoutGuardado] = useState(null)

  async function cargarDia(f) {
    try {
      const data = await getWorkoutsPorFecha(f)
      setWorkouts(data)
    } catch (e) {
      setError(e.message)
    }
  }

  useEffect(() => {
    cargarDia(fecha)
  }, [fecha])

  async function handleCambiarMes(year, month) {
    const desde = `${year}-${String(month).padStart(2, '0')}-01`
    const ultimoDia = new Date(year, month, 0).getDate()
    const hasta = `${year}-${String(month).padStart(2, '0')}-${String(ultimoDia).padStart(2, '0')}`
    try {
      setDias(await getDiasConEntrenamientoDelMes(desde, hasta))
    } catch (e) {
      setError(e.message)
    }
  }

  function reiniciarFlujo() {
    setPaso('lista')
    setSubtipo(null)
    setForm({})
    setMusculoActivo(null)
    setEjercicioActivo(null)
    setUltimoRegistro(null)
    setEjerciciosAgregados([])
    setDuracionFuerza('')
    setError('')
  }

  async function abrirMusculo(musculo) {
    setMusculoActivo(musculo)
    setError('')
    try {
      setEjerciciosMusculo(await getExercises(musculo.id))
      setPaso('fuerza_ejercicio')
    } catch (e) {
      setError(e.message)
    }
  }

  async function abrirEjercicio(ejercicio) {
    setEjercicioActivo(ejercicio)
    setError('')
    try {
      setUltimoRegistro(await getUltimoRegistroEjercicio(ejercicio.id))
    } catch {
      setUltimoRegistro(null)
    }
    setForm({ peso_kg: '', repeticiones: '' })
    setPaso('fuerza_carga')
  }

  function agregarEjercicioALista() {
    const peso = Number(form.peso_kg)
    const reps = Number(form.repeticiones)
    if (!(peso >= 0) || !(reps >= 0)) {
      setError('Peso y repeticiones deben ser números válidos (0 o más).')
      return
    }
    setEjerciciosAgregados((prev) => [
      ...prev,
      { exercise_id: ejercicioActivo.id, nombre: ejercicioActivo.nombre, peso_kg: peso, repeticiones: reps },
    ])
    setError('')
    setPaso('fuerza_resumen')
  }

  async function guardarCardio() {
    setError('')
    setCargando(true)
    try {
      const payload =
        subtipo === 'caminata'
          ? { tipo: 'cardio', subtipo, fecha, pasos: Number(form.pasos) }
          : {
              tipo: 'cardio',
              subtipo,
              fecha,
              distancia_km: Number(form.distancia_km),
              velocidad_media_kmh: Number(form.velocidad_media_kmh),
              duracion_min: Number(form.duracion_min),
            }
      const r = await registrarEntrenamiento(payload)
      setResultado(r)
      setWorkoutGuardado(payload)
    } catch (e) {
      setError(e.message)
    }
    setCargando(false)
  }

  async function guardarFuerza() {
    setError('')
    setCargando(true)
    try {
      const payload = {
        tipo: 'fuerza',
        fecha,
        duracion_min: Number(duracionFuerza),
        ejercicios: ejerciciosAgregados.map(({ exercise_id, peso_kg, repeticiones }) => ({
          exercise_id,
          peso_kg,
          repeticiones,
        })),
      }
      const r = await registrarEntrenamiento(payload)
      setResultado(r)
      setWorkoutGuardado({ ...payload, ejercicios: ejerciciosAgregados })
    } catch (e) {
      setError(e.message)
    }
    setCargando(false)
  }

  async function guardarCalorias() {
    setError('')
    setCargando(true)
    try {
      const payload = { tipo: 'calorias', fecha, kcal: Number(form.kcal) }
      const r = await registrarEntrenamiento(payload)
      setResultado(r)
      setWorkoutGuardado(payload)
    } catch (e) {
      setError(e.message)
    }
    setCargando(false)
  }

  function cerrarResultado() {
    setResultado(null)
    setWorkoutGuardado(null)
    reiniciarFlujo()
    cargarDia(fecha)
    handleCambiarMes(Number(fecha.slice(0, 4)), Number(fecha.slice(5, 7)))
  }

  return (
    <div className="pagina">
      {paso === 'lista' && (
        <>
          <Calendario
            fechaSeleccionada={fecha}
            diasConEntrenamiento={dias}
            onSeleccionar={setFecha}
            onCambiarMes={handleCambiarMes}
          />

          {error && <p className="error">{error}</p>}

          <button className="boton-primario" onClick={() => setPaso('categoria')}>
            Registrar entrenamiento
          </button>

          <div className="lista-items">
            {workouts.length === 0 && <p className="detalle-item">Sin entrenamientos este día.</p>}
            {workouts.map((w) => (
              <div key={w.id} className="tarjeta item-catalogo">
                <div>
                  <strong>{ICONOS_HISTORIAL[w.subtipo] ?? ICONOS_HISTORIAL[w.tipo]} {w.tipo === 'cardio' ? w.subtipo : w.tipo}</strong>
                  <p className="detalle-item">{resumenWorkout(w)}</p>
                </div>
                <span className="resultado-xp-chico">+{Math.round(w.xp_otorgada)} XP</span>
              </div>
            ))}
          </div>
        </>
      )}

      {paso === 'categoria' && (
        <div className="lista-items">
          <button onClick={reiniciarFlujo} className="boton-volver">‹ Cancelar</button>
          <button className="tarjeta categoria-card" onClick={() => setPaso('cardio_subtipo')}>🏃 Cardio</button>
          <button className="tarjeta categoria-card" onClick={() => setPaso('fuerza_duracion')}>🏋️ Fuerza</button>
          <button className="tarjeta categoria-card" onClick={() => setPaso('calorias_form')}>🔥 Calorías</button>
        </div>
      )}

      {paso === 'cardio_subtipo' && (
        <div className="lista-items">
          <button onClick={() => setPaso('categoria')} className="boton-volver">‹ Volver</button>
          {[
            { id: 'correr', label: '🏃 Correr' },
            { id: 'bici', label: '🚴 Bici' },
            { id: 'caminata', label: '🚶 Caminata' },
          ].map((s) => (
            <button
              key={s.id}
              className="tarjeta categoria-card"
              onClick={() => {
                setSubtipo(s.id)
                setForm({})
                setPaso(s.id === 'caminata' ? 'caminata_form' : 'cardio_form')
              }}
            >
              {s.label}
            </button>
          ))}
        </div>
      )}

      {paso === 'cardio_form' && (
        <div className="tarjeta form-entreno">
          <button onClick={() => setPaso('cardio_subtipo')} className="boton-volver">‹ Volver</button>
          <label>Velocidad media (km/h)</label>
          <input type="number" min="0" step="0.1" value={form.velocidad_media_kmh ?? ''}
            onChange={(e) => setForm({ ...form, velocidad_media_kmh: e.target.value })} />
          <label>Distancia (km)</label>
          <input type="number" min="0" step="0.1" value={form.distancia_km ?? ''}
            onChange={(e) => setForm({ ...form, distancia_km: e.target.value })} />
          <label>Tiempo total (min)</label>
          <input type="number" min="0" step="1" value={form.duracion_min ?? ''}
            onChange={(e) => setForm({ ...form, duracion_min: e.target.value })} />
          {error && <p className="error">{error}</p>}
          <button disabled={cargando} onClick={guardarCardio}>Guardar</button>
        </div>
      )}

      {paso === 'caminata_form' && (
        <div className="tarjeta form-entreno">
          <button onClick={() => setPaso('cardio_subtipo')} className="boton-volver">‹ Volver</button>
          <label>Pasos del día</label>
          <input type="number" min="0" step="1" value={form.pasos ?? ''}
            onChange={(e) => setForm({ ...form, pasos: e.target.value })} />
          {error && <p className="error">{error}</p>}
          <button disabled={cargando} onClick={guardarCardio}>Guardar</button>
        </div>
      )}

      {paso === 'fuerza_duracion' && (
        <div className="tarjeta form-entreno">
          <button onClick={() => setPaso('categoria')} className="boton-volver">‹ Volver</button>
          <label>Tiempo total del entrenamiento (min)</label>
          <input type="number" min="0" step="1" value={duracionFuerza}
            onChange={(e) => setDuracionFuerza(e.target.value)} />
          {error && <p className="error">{error}</p>}
          <button
            disabled={!(Number(duracionFuerza) >= 0) || duracionFuerza === ''}
            onClick={async () => {
              setError('')
              try {
                setMusculos(await getMuscleGroups())
                setPaso('fuerza_musculo')
              } catch (e) {
                setError(e.message)
              }
            }}
          >
            Siguiente
          </button>
        </div>
      )}

      {paso === 'fuerza_musculo' && (
        <div className="lista-items">
          <button onClick={() => setPaso('fuerza_duracion')} className="boton-volver">‹ Volver</button>
          {musculos.map((m) => (
            <button key={m.id} className="tarjeta categoria-card" onClick={() => abrirMusculo(m)}>
              {m.nombre}
            </button>
          ))}
        </div>
      )}

      {paso === 'fuerza_ejercicio' && (
        <div className="lista-items">
          <button onClick={() => setPaso('fuerza_musculo')} className="boton-volver">‹ Volver</button>
          <p className="detalle-item">{musculoActivo?.nombre}</p>
          {ejerciciosMusculo.map((ej) => (
            <button key={ej.id} className="tarjeta categoria-card" onClick={() => abrirEjercicio(ej)}>
              {ej.nombre}
            </button>
          ))}
        </div>
      )}

      {paso === 'fuerza_carga' && (
        <div className="tarjeta form-entreno">
          <button onClick={() => setPaso('fuerza_ejercicio')} className="boton-volver">‹ Volver</button>
          <strong>{ejercicioActivo?.nombre}</strong>
          {ultimoRegistro && (
            <p className="detalle-item">
              Última vez: {ultimoRegistro.peso_kg} kg × {ultimoRegistro.repeticiones} reps
            </p>
          )}
          <label>Peso (kg)</label>
          <input type="number" min="0" step="0.5" value={form.peso_kg ?? ''}
            onChange={(e) => setForm({ ...form, peso_kg: e.target.value })} />
          <label>Repeticiones</label>
          <input type="number" min="0" step="1" value={form.repeticiones ?? ''}
            onChange={(e) => setForm({ ...form, repeticiones: e.target.value })} />
          {error && <p className="error">{error}</p>}
          <button onClick={agregarEjercicioALista}>Agregar ejercicio</button>
        </div>
      )}

      {paso === 'fuerza_resumen' && (
        <div className="lista-items">
          <strong>Entrenamiento de fuerza — {duracionFuerza} min</strong>
          {ejerciciosAgregados.map((e, i) => (
            <div key={i} className="tarjeta item-catalogo">
              <div>
                <strong>{e.nombre}</strong>
                <p className="detalle-item">{e.peso_kg} kg × {e.repeticiones} reps</p>
              </div>
            </div>
          ))}
          {error && <p className="error">{error}</p>}
          <button onClick={async () => {
            setError('')
            try {
              setMusculos((m) => (m.length ? m : []))
              setPaso('fuerza_musculo')
              if (musculos.length === 0) setMusculos(await getMuscleGroups())
            } catch (e) {
              setError(e.message)
            }
          }}>
            + Agregar otro ejercicio
          </button>
          <button disabled={cargando || ejerciciosAgregados.length === 0} onClick={guardarFuerza}>
            Guardar entrenamiento
          </button>
        </div>
      )}

      {paso === 'calorias_form' && (
        <div className="tarjeta form-entreno">
          <button onClick={() => setPaso('categoria')} className="boton-volver">‹ Volver</button>
          <label>Calorías quemadas (kcal)</label>
          <input type="number" min="0" step="1" value={form.kcal ?? ''}
            onChange={(e) => setForm({ ...form, kcal: e.target.value })} />
          {error && <p className="error">{error}</p>}
          <button disabled={cargando} onClick={guardarCalorias}>Guardar</button>
        </div>
      )}

      {resultado && workoutGuardado && (
        <ResultadoEntrenamiento workout={workoutGuardado} resultado={resultado} onCerrar={cerrarResultado} />
      )}
    </div>
  )
}
