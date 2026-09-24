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

export async function asignarPunto(atributo) {
  const { error } = await supabase.rpc('asignar_punto', { p_atributo: atributo })
  if (error) throw error
}

export async function getEquipmentCatalog() {
  const { data, error } = await supabase.from('equipment_catalog').select('*').order('slot')
  if (error) throw error
  return data
}

export async function getInventory() {
  const { data, error } = await supabase
    .from('inventory')
    .select('id, equipado, adquirido_at, item:equipment_catalog(*)')
    .order('adquirido_at', { ascending: false })
  if (error) throw error
  return data
}

export async function comprarItem(itemId) {
  const { error } = await supabase.rpc('comprar_item', { p_item_id: itemId })
  if (error) throw error
}

export async function equiparItem(inventoryId) {
  const { error } = await supabase.from('inventory').update({ equipado: true }).eq('id', inventoryId)
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

export async function getHistorial(limit = 20) {
  const { data, error } = await supabase
    .from('encounter_log')
    .select('id, created_at, chance, resultado, oro_ganado, zone:zones(nombre), item:equipment_catalog(nombre)')
    .order('created_at', { ascending: false })
    .limit(limit)
  if (error) throw error
  return data
}
