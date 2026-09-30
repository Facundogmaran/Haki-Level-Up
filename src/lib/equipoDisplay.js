// Helpers de presentación de equipamiento compartidos entre Tienda e
// Inventario, para no duplicar la misma lógica en los dos lugares.

export const NOMBRES_CATEGORIA = {
  head: 'Cabeza',
  neck: 'Collar',
  ring: 'Anillo',
  shoulder: 'Hombrera',
  gloves: 'Guantes',
  torso: 'Torso',
  legs: 'Piernas',
  feet: 'Calzado',
  weapon: 'Arma',
  shield: 'Escudo',
}

export const NOMBRES_ATRIBUTO = {
  fuerza: 'Fuerza',
  resistencia: 'Resistencia',
  agilidad: 'Agilidad',
  vitalidad: 'Vitalidad',
  mente: 'Mente',
}

export function bonusTexto(bonus) {
  return Object.entries(bonus || {})
    .map(([atributo, valor]) => `${valor > 0 ? '+' : ''}${valor} ${NOMBRES_ATRIBUTO[atributo] ?? atributo}`)
    .join(', ')
}

export function requisitosFaltantes(variante, personaje) {
  if (!personaje) return []
  const faltan = []
  if (personaje.nivel < variante.requisito_nivel) faltan.push(`Nivel +${variante.requisito_nivel - personaje.nivel}`)
  for (const atributo of ['fuerza', 'resistencia', 'agilidad', 'vitalidad', 'mente']) {
    const requerido = variante[`requisito_${atributo}`] ?? 0
    if (requerido > 0 && personaje[atributo] < requerido) {
      faltan.push(`${NOMBRES_ATRIBUTO[atributo]} +${requerido - personaje[atributo]}`)
    }
  }
  return faltan
}

export function requisitosTexto(variante) {
  const partes = []
  if (variante.requisito_nivel > 1) partes.push(`Nivel ${variante.requisito_nivel}`)
  for (const atributo of ['fuerza', 'resistencia', 'agilidad', 'vitalidad', 'mente']) {
    const requerido = variante[`requisito_${atributo}`] ?? 0
    if (requerido > 0) partes.push(`${NOMBRES_ATRIBUTO[atributo]} ${requerido}`)
  }
  return partes.join(' · ')
}

// Clave de variante visual (nombre de material o de color) para armar
// la ruta del sprite -- mismo criterio que capasEquipoWalk en
// avatarAssets.js, para que el ícono coincida con lo que se ve puesto.
export function claveVisual(materialNombre, colorNombre) {
  return materialNombre ?? colorNombre ?? 'default'
}
