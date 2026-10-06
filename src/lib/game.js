import { supabase } from './supabaseClient'

export const ATRIBUTOS = ['fuerza', 'resistencia', 'agilidad', 'vitalidad', 'mente']

export async function getCharacter() {
  const { data, error } = await supabase.from('character').select('*').single()
  if (error) throw error
  return data
}

export function xpRequeridaParaNivel(nivel, xpBase = 100, xpExponente = 1.5) {
  return xpBase * Math.pow(Math.max(0, nivel - 1), xpExponente)
}

// Suma los bonus de atributo (jsonb en equipment_variants, ej. {"fuerza": 2})
// de una lista de ítems de inventario equipados. El resultado se suma al
// atributo base del personaje para mostrar el valor efectivo — la misma
// cuenta que ya usa calcular_chance_encuentro() del lado del servidor.
export function sumarBonusEquipo(itemsEquipados) {
  const total = Object.fromEntries(ATRIBUTOS.map((a) => [a, 0]))
  for (const inv of itemsEquipados) {
    for (const [atributo, valor] of Object.entries(inv.item?.bonus ?? {})) {
      if (atributo in total) total[atributo] += valor
    }
  }
  return total
}

export async function asignarPunto(atributo) {
  const { error } = await supabase.rpc('asignar_punto', { p_atributo: atributo })
  if (error) throw error
}

export async function quitarPunto(atributo) {
  const { error } = await supabase.rpc('quitar_punto', { p_atributo: atributo })
  if (error) throw error
}

export async function actualizarApariencia(characterId, apariencia) {
  const { error } = await supabase.from('character').update({ apariencia }).eq('id', characterId)
  if (error) throw error
}

const CATEGORIAS = [
  { id: 'head', nombre: 'Cabeza', icono: '🪖' },
  { id: 'neck', nombre: 'Collar', icono: '📿' },
  { id: 'ring', nombre: 'Anillo', icono: '💍' },
  { id: 'shoulder', nombre: 'Hombrera', icono: '🛡️' },
  { id: 'gloves', nombre: 'Guantes', icono: '🧤' },
  { id: 'torso', nombre: 'Torso', icono: '👕' },
  { id: 'legs', nombre: 'Piernas', icono: '👖' },
  { id: 'feet', nombre: 'Calzado', icono: '👟' },
  { id: 'weapon', nombre: 'Arma', icono: '⚔️' },
  { id: 'shield', nombre: 'Escudo', icono: '🛡️' },
]

export function getCategoriasEquipo() {
  return CATEGORIAS
}

// Cuántas bases de esa categoría tienen al menos una variante comprable
// en la tienda (para el contador "N disponibles" del menú inicial).
export async function getConteoPorCategoria() {
  const { data, error } = await supabase
    .from('equipment_base')
    .select('category, equipment_variants(shop_disponible)')
  if (error) throw error
  const conteo = {}
  for (const base of data) {
    if (base.equipment_variants.some((v) => v.shop_disponible)) {
      conteo[base.category] = (conteo[base.category] ?? 0) + 1
    }
  }
  return conteo
}

export async function getEquipmentPorCategoria(category) {
  const { data, error } = await supabase
    .from('equipment_base')
    .select(
      'id, base_key, nombre, descripcion, category, admite_colores, lpc_sprite_folder, lpc_zpos_bg, lpc_zpos_fg, colores:equipment_base_colores(color:colors(*)), variantes:equipment_variants(*, material:materials(*))',
    )
    .eq('category', category)
    .order('nombre')
  if (error) throw error
  return data
    .map((base) => ({
      ...base,
      colores: base.colores.map((c) => c.color),
      variantes: base.variantes
        .filter((v) => v.shop_disponible)
        .sort((a, b) => a.precio_oro - b.precio_oro),
    }))
    .filter((base) => base.variantes.length > 0)
}

export async function getInventory() {
  const { data, error } = await supabase
    .from('inventory')
    .select(
      'id, equipado, adquirido_at, color:colors(*), item:equipment_variants(*, base:equipment_base(*), material:materials(*))',
    )
    .order('adquirido_at', { ascending: false })
  if (error) throw error
  return data
}

export async function comprarItem(variantId, colorId = null) {
  const { error } = await supabase.rpc('comprar_item', { p_variant_id: variantId, p_color_id: colorId })
  if (error) throw error
}

export async function venderItem(inventoryId) {
  const { data, error } = await supabase.rpc('vender_item', { p_inventory_id: inventoryId })
  if (error) throw error
  return data
}

export async function equiparItem(inventoryId) {
  const { error } = await supabase.rpc('equipar_item', { p_inventory_id: inventoryId })
  if (error) throw error
}

export async function desequiparItem(inventoryId) {
  const { error } = await supabase.from('inventory').update({ equipado: false }).eq('id', inventoryId)
  if (error) throw error
}

export async function getZones() {
  const { data, error } = await supabase
    .from('zones')
    .select('id, nombre, zona_padre_id, orden, requisito_nivel, enemigo:enemies(*)')
    .order('orden')
  if (error) throw error
  return data
}

export async function intentarEncuentro(zoneId) {
  const { data, error } = await supabase.rpc('intentar_encuentro', { p_zone_id: zoneId })
  if (error) throw error
  return data
}

export async function previsualizarEncuentro(zoneId) {
  const { data, error } = await supabase.rpc('previsualizar_encuentro', { p_zone_id: zoneId })
  if (error) throw error
  return data
}

// Ids de zona que el personaje ya completó (ganó) alguna vez, para
// saber qué zona siguiente del árbol queda desbloqueada.
export async function getZonasCompletadas() {
  const { data, error } = await supabase.from('encounter_log').select('zone_id').eq('resultado', true)
  if (error) throw error
  return new Set(data.map((r) => r.zone_id))
}

export async function getHistorial(limit = 20) {
  const { data, error } = await supabase
    .from('encounter_log')
    .select('id, created_at, chance, resultado, oro_ganado, zone:zones(nombre), item:equipment_variants(nombre)')
    .order('created_at', { ascending: false })
    .limit(limit)
  if (error) throw error
  return data
}

export async function getMuscleGroups() {
  // Solo los grupos que tienen al menos un ejercicio activo.
  const { data, error } = await supabase
    .from('muscle_groups')
    .select('id, nombre, exercises!inner(id)')
    .eq('exercises.activo', true)
    .order('nombre')
  if (error) throw error
  return data.map(({ id, nombre }) => ({ id, nombre }))
}

export async function getExercises(muscleGroupId) {
  const { data, error } = await supabase
    .from('exercises')
    .select('*')
    .eq('muscle_group_id', muscleGroupId)
    .order('orden')
    .order('nombre')
  if (error) throw error
  return data
}

export async function getUltimoRegistroEjercicio(exerciseId) {
  const { data, error } = await supabase
    .from('workout_exercises')
    .select('peso_kg, repeticiones, workout:workouts(fecha)')
    .eq('exercise_id', exerciseId)
    .order('id', { ascending: false })
    .limit(1)
  if (error) throw error
  return data?.[0] ?? null
}

export async function registrarEntrenamiento(workout) {
  const { data, error } = await supabase.rpc('registrar_entrenamiento', { p_workout: workout })
  if (error) throw error
  return data
}

export async function editarEntrenamiento(workoutId, workout) {
  const { data, error } = await supabase.rpc('editar_entrenamiento', { p_workout_id: workoutId, p_workout: workout })
  if (error) throw error
  return data
}

export async function getWorkoutsPorFecha(fecha) {
  const { data, error } = await supabase
    .from('workouts')
    .select(
      '*, ejercicios:workout_exercises(exercise_id, peso_kg, repeticiones, exercise:exercises(nombre, muscle_group_id))',
    )
    .eq('fecha', fecha)
    .order('created_at', { ascending: false })
  if (error) throw error
  return data
}

export async function getDiasConEntrenamientoDelMes(desde, hasta) {
  const { data, error } = await supabase
    .from('workouts')
    .select('fecha')
    .gte('fecha', desde)
    .lte('fecha', hasta)
  if (error) throw error
  return [...new Set(data.map((w) => w.fecha))]
}
