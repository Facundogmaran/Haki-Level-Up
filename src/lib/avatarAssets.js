// Catálogo de assets del avatar (Liberated Pixel Cup, CC-BY-SA/GPL3 —
// ver créditos en public/avatar/CREDITS.md). Cada imagen es un recorte
// de 64x64 ya recoloreado, generado offline a partir del proyecto LPC.

export const TONOS_PIEL = [
  { id: 'light', label: 'Clara' },
  { id: 'amber', label: 'Ámbar' },
  { id: 'olive', label: 'Oliva' },
  { id: 'taupe', label: 'Topo' },
  { id: 'bronze', label: 'Bronce' },
  { id: 'brown', label: 'Morena' },
]

export const COLORES_PELO = [
  { id: 'orange', label: 'Naranja' },
  { id: 'ash', label: 'Ceniza' },
  { id: 'gray', label: 'Gris' },
  { id: 'chestnut', label: 'Castaño' },
  { id: 'black', label: 'Negro' },
]

export const PEINADOS = [
  { grupo: 'Afro', id: 'afro', label: 'Afro' },
  { grupo: 'Afro', id: 'dreadlocks_short', label: 'Dreadlock shorts' },
  { grupo: 'Rizado', id: 'curly_short', label: 'Curly short' },
  { grupo: 'Rizado', id: 'curly_short2', label: 'Curly short 2' },
  { grupo: 'Rizado', id: 'jewfro', label: 'Jewfro' },
  { grupo: 'Rapado', id: 'high_and_tight', label: 'High and tight' },
  { grupo: 'Rapado', id: 'shorthawk', label: 'Shorthawk' },
  { grupo: 'Corto', id: 'messy3', label: 'Messy3' },
  { grupo: 'Corto', id: 'page', label: 'Page' },
  { grupo: 'Corto', id: 'parted3', label: 'Parted 3' },
  { grupo: 'Spiky', id: 'spiked_beehive', label: 'Spiked beehive' },
  { grupo: 'Spiky', id: 'spiked_liberty', label: 'Spiked liberty' },
  { grupo: 'Spiky', id: 'spiked2', label: 'Spiked2' },
  { grupo: 'Coletas', id: 'pigtails', label: 'Pigtails' },
  { grupo: 'Coletas', id: 'pigtails_bangs', label: 'Pigtails bangs' },
  { grupo: 'Bob', id: 'bob', label: 'Bob' },
  { grupo: 'Bob', id: 'lob', label: 'Lob' },
  { grupo: 'Trenzas/rodetes', id: 'bangs_bun', label: 'Bangs bun' },
  { grupo: 'Trenzas/rodetes', id: 'braid2', label: 'Braid2' },
  { grupo: 'Trenzas/rodetes', id: 'high_ponytail', label: 'High Ponytail' },
  { grupo: 'Trenzas/rodetes', id: 'long_tied', label: 'Long tied' },
  { grupo: 'Xlong', id: 'long_band', label: 'Long band' },
  { grupo: 'Xlong', id: 'princess', label: 'Princess' },
]

export const VELLO_FACIAL = [
  { grupo: 'Barbas', id: 'basic_beard', label: 'Basic beard' },
  { grupo: 'Barbas', id: 'winter_beard', label: 'Winter Beard' },
  { grupo: 'Bigotes', id: 'big_mustache', label: 'Big mustache' },
  { grupo: 'Bigotes', id: 'mustache', label: 'Mustache' },
]

export const APARIENCIA_POR_DEFECTO = {
  bodyType: 'male',
  skinTone: 'light',
  hairStyle: 'messy3',
  hairColor: 'black',
  facialHairStyle: null,
}

export function rutaPelo(hairStyle, hairColor) {
  return hairStyle ? `/avatar/hair/${hairColor}/${hairStyle}.png` : null
}

export function rutaVelloFacial(facialHairStyle, hairColor) {
  return facialHairStyle ? `/avatar/facial/${hairColor}/${facialHairStyle}.png` : null
}

// Variantes "walk": misma apariencia pero como hoja de animación de
// caminata LPC (9 frames x 4 direcciones — arriba/izquierda/abajo/derecha),
// generadas offline recoloreando los sprites base de Liberated Pixel Cup
// con la misma paleta que las capas estáticas de arriba.
export function rutaCuerpoWalk(skinTone, bodyType) {
  return `/avatar-walk/body/${skinTone}/${bodyType}.png`
}

// Forma de la cabeza (cráneo, frente, sienes) sobre la que se apoyan el
// pelo, las orejas y la cara -- sin esta capa la "cabeza" es solo el
// parche de ojos de rutaCaraWalk flotando sobre el cuello, por eso los
// peinados cortos dejaban un hueco.
export function rutaCabezaWalk(skinTone, bodyType) {
  const genero = bodyType === 'female' ? 'female' : 'male'
  return `/avatar-walk/head/${skinTone}/${genero}.png`
}

export function rutaCaraWalk(skinTone, bodyType) {
  const genero = bodyType === 'female' ? 'female' : 'male'
  return `/avatar-walk/face/${skinTone}/${genero}.png`
}

export function rutaNarizWalk(skinTone) {
  return `/avatar-walk/nose/${skinTone}/button.png`
}

export function rutaOrejasWalk(skinTone) {
  return `/avatar-walk/ears/${skinTone}/big.png`
}

export function rutaPeloWalk(hairStyle, hairColor) {
  return hairStyle ? `/avatar-walk/hair/${hairColor}/${hairStyle}.png` : null
}

export function rutaVelloFacialWalk(facialHairStyle, hairColor) {
  return facialHairStyle ? `/avatar-walk/facial/${hairColor}/${facialHairStyle}.png` : null
}
