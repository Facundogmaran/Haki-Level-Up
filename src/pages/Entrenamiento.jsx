import { useEffect, useState } from 'react'
import Calendario from '../components/Calendario'
import CargaEjercicioFuerza from '../components/CargaEjercicioFuerza'
import ResultadoEntrenamiento from '../components/ResultadoEntrenamiento'
import {
  editarEntrenamiento,
  getDiasConEntrenamientoDelMes,
  getExercises,
  getMuscleGroups,
  getUltimoRegistroEjercicio,
  getWorkoutsPorFecha,
  registrarEntrenamiento,
} from '../lib/game'

const ICONOS_HISTORIAL = { correr: '🏃', bici: '🚴', caminata: '🚶', fuerza: '🏋️', calorias: '🔥' }

// El día "de hoy" tiene que ser el de Argentina, no UTC -- toISOString()
// convierte a UTC, así que antes de la medianoche ART (3 horas menos)
// ya mostraba el día siguiente.
function hoyISO() {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Argentina/Buenos_Aires',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date())
}

function resumenWorkout(w) {
  if (w.tipo === 'cardio' && w.subtipo === 'caminata') return `${w.pasos} pasos`
  if (w.tipo === 'cardio') return `${w.distancia_km} km · ${w.duracion_min} min · ${w.velocidad_media_kmh} km/h`
  if (w.tipo === 'fuerza') {
    const ejercicios = [...new Set(w.ejercicios.map((e) => e.exercise?.nombre))].join(', ')
    return `${w.duracion_min} min · ${ejercicios}`
  }
  if (w.tipo === 'calorias') return `${w.kcal} kcal`
  return ''
}

// Convierte la lista plana de workout_exercises (una fila por serie) en
// una lista agrupada por ejercicio, para la carga/edición con series
// múltiples.
function agruparEjercicios(flatList) {
  const porEjercicio = new Map()
  for (const e of flatList) {
    const key = e.exercise_id
    if (!porEjercicio.has(key)) {
      porEjercicio.set(key, {
        exercise_id: key,
        nombre: e.exercise?.nombre,
        muscle_group_id: e.exercise?.muscle_group_id,
        sets: [],
      })
    }
    porEjercicio.get(key).sets.push({ peso_kg: e.peso_kg, repeticiones: e.repeticiones })
  }
  return [...porEjercicio.values()]
}

// Las series se editan como texto (inputs). Una serie vacía (sin reps ni
// peso) se ignora al guardar; el peso vacío con reps cargadas cuenta como 0
// (ejercicios con el propio peso).
const vacio = (v) => v === '' || v == null
const serieValida = (s) => !vacio(s.repeticiones)
const aNumero = (v) => (vacio(v) ? 0 : Number(v))
const seriesIniciales = () => [
  { peso_kg: '', repeticiones: '' },
  { peso_kg: '', repeticiones: '' },
]

function ejerciciosNormalizados(lista) {
  return lista
    .map((e) => ({
      ...e,
      sets: e.sets.filter(serieValida).map((s) => ({ peso_kg: aNumero(s.peso_kg), repeticiones: aNumero(s.repeticiones) })),
    }))
    .filter((e) => e.sets.length > 0)
}

function errorEnSeries(lista) {
  for (const e of lista) {
    for (let i = 0; i < e.sets.length; i++) {
      const s = e.sets[i]
      if (vacio(s.repeticiones) && !vacio(s.peso_kg)) return `Falta cargar las repeticiones de la serie ${i + 1} de ${e.nombre}.`
      if (serieValida(s) && (!(Number(s.repeticiones) >= 0) || !(aNumero(s.peso_kg) >= 0))) {
        return `Peso y repeticiones deben ser números válidos (0 o más) — serie ${i + 1} de ${e.nombre}.`
      }
    }
  }
  return null
}

function velocidadCalculada(distanciaStr, duracionStr) {
  const distancia = Number(distanciaStr)
  const duracion = Number(duracionStr)
  if (!(distancia > 0) || !(duracion > 0)) return null
  return distancia / (duracion / 60)
}

export default function Entrenamiento() {
  const [fecha, setFecha] = useState(hoyISO())
  const [dias, setDias] = useState([])
  const [workouts, setWorkouts] = useState([])
  const [error, setError] = useState('')
  const [cargando, setCargando] = useState(false)

  // lista | categoria | cardio_subtipo | cardio_form | caminata_form |
  // fuerza_duracion | fuerza_musculo | fuerza_ejercicio |
  // fuerza_ejercicio_detalle | fuerza_resumen | calorias_form
  const [paso, setPaso] = useState('lista')
  const [subtipo, setSubtipo] = useState(null)
  const [form, setForm] = useState({})
  const [musculos, setMusculos] = useState([])
  const [musculoActivo, setMusculoActivo] = useState(null)
  const [ejerciciosMusculo, setEjerciciosMusculo] = useState([])
  const [ejercicioActivo, setEjercicioActivo] = useState(null)
  const [ultimoRegistro, setUltimoRegistro] = useState(null)
  const [ejerciciosAgregados, setEjerciciosAgregados] = useState([])
  const [duracionFuerza, setDuracionFuerza] = useState('')
  const [origenDetalle, setOrigenDetalle] = useState('musculo') // 'musculo' | 'resumen'

  const [workoutEditandoId, setWorkoutEditandoId] = useState(null)
  const [workoutAbierto, setWorkoutAbierto] = useState(null)

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
    setWorkoutAbierto(null)
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
    setWorkoutEditandoId(null)
    setError('')
  }

  // Ejercicios activos del grupo + los ya cargados en este entrenamiento que
  // hoy están inactivos (entrenamientos viejos), para poder verlos/editarlos.
  function ejerciciosVisibles(lista) {
    return lista.filter((e) => e.activo || ejerciciosAgregados.some((a) => a.exercise_id === e.id))
  }

  async function seleccionarEjercicio(ej) {
    setEjercicioActivo(ej)
    setError('')
    try {
      setUltimoRegistro(await getUltimoRegistroEjercicio(ej.id))
    } catch {
      setUltimoRegistro(null)
    }
  }

  async function abrirMusculo(musculo) {
    setError('')
    try {
      const lista = ejerciciosVisibles(await getExercises(musculo.id))
      if (lista.length === 0) {
        setError('Este músculo todavía no tiene ejercicios.')
        return
      }
      setMusculoActivo(musculo)
      setEjerciciosMusculo(lista)
      setOrigenDetalle('musculo')
      await seleccionarEjercicio(lista[0])
      setPaso('fuerza_ejercicio')
    } catch (e) {
      setError(e.message)
    }
  }

  async function abrirEjercicioDesdeResumen(entrada) {
    setError('')
    try {
      const grupos = musculos.length > 0 ? musculos : await getMuscleGroups()
      if (musculos.length === 0) setMusculos(grupos)
      let lista = entrada.muscle_group_id ? ejerciciosVisibles(await getExercises(entrada.muscle_group_id)) : []
      let activo = lista.find((e) => e.id === entrada.exercise_id)
      if (!activo) {
        activo = { id: entrada.exercise_id, nombre: entrada.nombre, imagen: null, activo: true, muscle_group_id: entrada.muscle_group_id }
        lista = [activo]
      }
      setMusculoActivo(grupos.find((m) => m.id === entrada.muscle_group_id) ?? { id: entrada.muscle_group_id, nombre: '' })
      setEjerciciosMusculo(lista)
      setOrigenDetalle('resumen')
      await seleccionarEjercicio(activo)
      setPaso('fuerza_ejercicio')
    } catch (e) {
      setError(e.message)
    }
  }

  function setsActivos() {
    if (!ejercicioActivo) return []
    return ejerciciosAgregados.find((e) => e.exercise_id === ejercicioActivo.id)?.sets ?? seriesIniciales()
  }

  function cambiarSets(sets) {
    const ej = ejercicioActivo
    setEjerciciosAgregados((prev) =>
      prev.some((e) => e.exercise_id === ej.id)
        ? prev.map((e) => (e.exercise_id === ej.id ? { ...e, sets } : e))
        : [...prev, { exercise_id: ej.id, nombre: ej.nombre, muscle_group_id: ej.muscle_group_id ?? musculoActivo?.id, sets }],
    )
  }

  function irAResumen() {
    const err = errorEnSeries(ejerciciosAgregados)
    if (err) {
      setError(err)
      return
    }
    setError('')
    setPaso('fuerza_resumen')
  }

  function eliminarEjercicio(exerciseId) {
    setEjerciciosAgregados((prev) => prev.filter((e) => e.exercise_id !== exerciseId))
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
              duracion_min: Number(form.duracion_min),
            }
      const r = workoutEditandoId
        ? await editarEntrenamiento(workoutEditandoId, payload)
        : await registrarEntrenamiento(payload)
      setResultado(r)
      setWorkoutGuardado({ ...payload, velocidad_media_kmh: velocidadCalculada(form.distancia_km, form.duracion_min) })
    } catch (e) {
      setError(e.message)
    }
    setCargando(false)
  }

  async function guardarFuerza() {
    setError('')
    const errorSeries = errorEnSeries(ejerciciosAgregados)
    const lista = ejerciciosNormalizados(ejerciciosAgregados)
    if (errorSeries || lista.length === 0) {
      setError(errorSeries ?? 'Cargá al menos una serie con repeticiones.')
      return
    }
    setCargando(true)
    try {
      const payload = {
        tipo: 'fuerza',
        fecha,
        duracion_min: Number(duracionFuerza),
        ejercicios: lista.flatMap((e) =>
          e.sets.map((s) => ({ exercise_id: e.exercise_id, peso_kg: s.peso_kg, repeticiones: s.repeticiones })),
        ),
      }
      const r = workoutEditandoId
        ? await editarEntrenamiento(workoutEditandoId, payload)
        : await registrarEntrenamiento(payload)
      setResultado(r)
      setWorkoutGuardado({ ...payload, ejercicios: lista })
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
      const r = workoutEditandoId
        ? await editarEntrenamiento(workoutEditandoId, payload)
        : await registrarEntrenamiento(payload)
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

  function iniciarEdicion(w) {
    setError('')
    setWorkoutEditandoId(w.id)
    if (w.tipo === 'cardio') {
      setSubtipo(w.subtipo)
      setForm(
        w.subtipo === 'caminata'
          ? { pasos: String(w.pasos ?? '') }
          : { distancia_km: String(w.distancia_km ?? ''), duracion_min: String(w.duracion_min ?? '') },
      )
      setPaso(w.subtipo === 'caminata' ? 'caminata_form' : 'cardio_form')
    } else if (w.tipo === 'calorias') {
      setForm({ kcal: String(w.kcal ?? '') })
      setPaso('calorias_form')
    } else if (w.tipo === 'fuerza') {
      setDuracionFuerza(String(w.duracion_min ?? ''))
      setEjerciciosAgregados(agruparEjercicios(w.ejercicios))
      setPaso('fuerza_resumen')
    }
  }

  function repetirEntrenamiento(w) {
    setError('')
    setWorkoutEditandoId(null)
    setFecha(hoyISO())
    setEjerciciosAgregados(agruparEjercicios(w.ejercicios))
    setDuracionFuerza('')
    setPaso('fuerza_duracion')
  }

  const velocidadCardio = subtipo !== 'caminata' ? velocidadCalculada(form.distancia_km, form.duracion_min) : null
  const ejerciciosValidos = ejerciciosNormalizados(ejerciciosAgregados)

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
            {workouts.map((w) => {
              const abierto = workoutAbierto === w.id
              return (
                <div key={w.id} className="tarjeta workout-registrado">
                  <button
                    className="item-catalogo workout-registrado-header"
                    onClick={() => setWorkoutAbierto(abierto ? null : w.id)}
                  >
                    <div>
                      <strong>{ICONOS_HISTORIAL[w.subtipo] ?? ICONOS_HISTORIAL[w.tipo]} {w.tipo === 'cardio' ? w.subtipo : w.tipo}</strong>
                      <p className="detalle-item">{resumenWorkout(w)}</p>
                    </div>
                    <span className="resultado-xp-chico">+{Math.round(w.xp_otorgada)} XP {abierto ? '▾' : '▸'}</span>
                  </button>

                  {abierto && (
                    <div className="workout-registrado-detalle">
                      {w.tipo === 'fuerza' ? (
                        w.ejercicios.map((e, i) => (
                          <div key={i} className="fila-atributo">
                            <span className="nombre-atributo">{e.exercise?.nombre}</span>
                            <span className="valor-atributo">{e.peso_kg} kg × {e.repeticiones}</span>
                          </div>
                        ))
                      ) : w.tipo === 'cardio' && w.subtipo === 'caminata' ? (
                        <div className="fila-atributo">
                          <span className="nombre-atributo">Pasos</span>
                          <span className="valor-atributo">{w.pasos}</span>
                        </div>
                      ) : w.tipo === 'cardio' ? (
                        <>
                          <div className="fila-atributo">
                            <span className="nombre-atributo">Distancia</span>
                            <span className="valor-atributo">{w.distancia_km} km</span>
                          </div>
                          <div className="fila-atributo">
                            <span className="nombre-atributo">Tiempo</span>
                            <span className="valor-atributo">{w.duracion_min} min</span>
                          </div>
                          <div className="fila-atributo">
                            <span className="nombre-atributo">Velocidad media</span>
                            <span className="valor-atributo">{w.velocidad_media_kmh} km/h</span>
                          </div>
                        </>
                      ) : (
                        <div className="fila-atributo">
                          <span className="nombre-atributo">Calorías</span>
                          <span className="valor-atributo">{w.kcal} kcal</span>
                        </div>
                      )}
                      <div className="acciones-item-inventario">
                        <button onClick={() => iniciarEdicion(w)}>Editar</button>
                        {w.tipo === 'fuerza' && <button onClick={() => repetirEntrenamiento(w)}>Repetir</button>}
                      </div>
                    </div>
                  )}
                </div>
              )
            })}
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
          <label>Distancia (km)</label>
          <input type="number" min="0" step="0.1" value={form.distancia_km ?? ''}
            onChange={(e) => setForm({ ...form, distancia_km: e.target.value })} />
          <label>Tiempo total (min)</label>
          <input type="number" min="0" step="1" value={form.duracion_min ?? ''}
            onChange={(e) => setForm({ ...form, duracion_min: e.target.value })} />
          <p className="detalle-item">
            Velocidad media: {velocidadCardio != null ? `${velocidadCardio.toFixed(2)} km/h` : '—'}
          </p>
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
          <button
            onClick={() => setPaso(ejerciciosValidos.length > 0 ? 'fuerza_resumen' : workoutEditandoId ? 'lista' : 'categoria')}
            className="boton-volver"
          >
            ‹ Volver
          </button>
          <label>Tiempo total del entrenamiento (min)</label>
          <input type="number" min="0" step="1" value={duracionFuerza}
            onChange={(e) => setDuracionFuerza(e.target.value)} />
          {error && <p className="error">{error}</p>}
          <button
            disabled={!(Number(duracionFuerza) >= 0) || duracionFuerza === ''}
            onClick={async () => {
              setError('')
              if (ejerciciosValidos.length > 0) {
                setPaso('fuerza_resumen')
                return
              }
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

      {paso === 'fuerza_ejercicio' && ejercicioActivo && (
        <div className="lista-items">
          <button
            onClick={() => (origenDetalle === 'resumen' ? irAResumen() : setPaso('fuerza_musculo'))}
            className="boton-volver"
          >
            {origenDetalle === 'resumen' ? '‹ Volver al resumen' : '‹ Cambiar músculo'}
          </button>
          <CargaEjercicioFuerza
            ejercicios={ejerciciosMusculo}
            activoId={ejercicioActivo.id}
            onSeleccionar={seleccionarEjercicio}
            conDatos={new Set(ejerciciosValidos.map((e) => e.exercise_id))}
            nombreGrupo={musculoActivo?.nombre}
            ultimoRegistro={ultimoRegistro}
            sets={setsActivos()}
            onCambiarSets={cambiarSets}
          />
          {error && <p className="error">{error}</p>}
          {ejerciciosValidos.length > 0 && (
            <button className="boton-primario" onClick={irAResumen}>
              Finalizar entrenamiento →
            </button>
          )}
        </div>
      )}

      {paso === 'fuerza_resumen' && (
        <div className="lista-items">
          <button className="boton-volver" onClick={() => setPaso('fuerza_duracion')}>
            Entrenamiento de fuerza — {duracionFuerza} min (✎ cambiar)
          </button>
          {ejerciciosValidos.map((e) => (
            <div
              key={e.exercise_id}
              className="tarjeta item-catalogo item-catalogo-clicable"
              onClick={() => abrirEjercicioDesdeResumen(e)}
            >
              <div>
                <strong>{e.nombre}</strong>
                <p className="detalle-item">
                  {e.sets.map((s, i) => `${s.peso_kg}×${s.repeticiones}`).join(' · ')}
                </p>
              </div>
              <button
                className="boton-vender"
                onClick={(ev) => {
                  ev.stopPropagation()
                  eliminarEjercicio(e.exercise_id)
                }}
              >
                🗑
              </button>
            </div>
          ))}
          {error && <p className="error">{error}</p>}
          <button
            onClick={async () => {
              setError('')
              try {
                if (musculos.length === 0) setMusculos(await getMuscleGroups())
                setPaso('fuerza_musculo')
              } catch (e) {
                setError(e.message)
              }
            }}
          >
            + Agregar más ejercicios
          </button>
          <button disabled={cargando || ejerciciosValidos.length === 0} onClick={guardarFuerza}>
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
