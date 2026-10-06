import { supabase } from './supabaseClient'

// Capa de acceso al sistema social (amigos, combates PvP, notificaciones).
// Toda la lógica de negocio vive en las RPCs de Supabase (migración 025):
// acá solo se llaman y se formatean los resultados.

async function rpc(nombre, args) {
  const { data, error } = await supabase.rpc(nombre, args)
  if (error) throw error
  return data
}

export const buscarPersonajes = (nombre) => rpc('buscar_personajes', { p_nombre: nombre })
export const enviarSolicitudAmistad = (characterId) => rpc('enviar_solicitud_amistad', { p_character_id: characterId })
export const responderSolicitudAmistad = (friendshipId, aceptar) =>
  rpc('responder_solicitud_amistad', { p_friendship_id: friendshipId, p_aceptar: aceptar })
export const eliminarAmistad = (friendshipId) => rpc('eliminar_amistad', { p_friendship_id: friendshipId })
export const getSocial = () => rpc('get_social')
export const verAmigo = (characterId) => rpc('ver_amigo', { p_character_id: characterId })
export const combatirAmigo = (characterId) => rpc('combatir_amigo', { p_character_id: characterId })
export const marcarNotificacionesLeidas = () => rpc('marcar_notificaciones_leidas')

export async function getNotificaciones(limit = 50) {
  const { data, error } = await supabase
    .from('notificaciones')
    .select('id, tipo, datos, leida, created_at')
    .order('created_at', { ascending: false })
    .limit(limit)
  if (error) throw error
  return data
}

export async function contarNoLeidas() {
  const { count, error } = await supabase
    .from('notificaciones')
    .select('id', { count: 'exact', head: true })
    .eq('leida', false)
  if (error) throw error
  return count ?? 0
}

export async function getHistorialPvp(limit = 30) {
  const { data, error } = await supabase
    .from('pvp_combats')
    .select('id, created_at, defensor_nombre, gano_atacante, oro_ganado, detalle, item:equipment_variants(nombre)')
    .order('created_at', { ascending: false })
    .limit(limit)
  if (error) throw error
  return data
}

// "06/10/2026 - 18:42", siempre en hora de Argentina.
export function formatearFechaHora(iso) {
  const partes = Object.fromEntries(
    new Intl.DateTimeFormat('es-AR', {
      timeZone: 'America/Argentina/Buenos_Aires',
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    })
      .formatToParts(new Date(iso))
      .map((p) => [p.type, p.value]),
  )
  return `${partes.day}/${partes.month}/${partes.year} - ${partes.hour}:${partes.minute}`
}

export const NOMBRES_TIER = { comun: 'Común', poco_comun: 'Poco común', raro: 'Raro' }
