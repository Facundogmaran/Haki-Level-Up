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

// zPos LPC de las capas fijas del cuerpo (mismo valor que usa el propio
// generador Universal LPC, para que el equipo agregado dinámicamente se
// intercale bien: un casco (zPos > 120) debe tapar el pelo, un arma
// (zPos > 130) queda delante de todo, etc.
export const Z_POS_CUERPO = {
  cuerpo: 10,
  cara: 101,
  nariz: 105,
  vello: 115,
  pelo: 120,
  orejas: 126,
}

// Un puñado de armas (katana, scimitar) usan la animación "walk_128" de
// LPC: la misma cantidad de cuadros (9) pero dibujados en una hoja de
// 128px por cuadro en vez de 64px (para que la hoja fuente pese menos
// se recortan offline a 9x4 igual que el resto -- ver
// build_equip_sprites*.js). Si en el futuro se suma un arma que
// realmente tenga OTRA cantidad de cuadros, este mapa (carpeta -> total
// de cuadros) es lo que hay que completar; CapaAnimada en
// AvatarAnimado.jsx ya sabe remapear el cuadro compartido del cuerpo.
const CUADROS_ESPECIALES = {}

// Ítem equipado (de getInventory/game.js) -> hasta 2 capas de sprite LPC
// (bg detrás del cuerpo, fg delante) si ese equipamiento ya tiene su
// carpeta generada en public/avatar-equip/. Si no la tiene, no devuelve
// nada -- el equipo simplemente no se dibuja (igual que hasta ahora).
export function capasEquipoWalk(itemsEquipados) {
  const capas = []
  for (const inv of itemsEquipados) {
    const base = inv.item?.base
    const carpeta = base?.lpc_sprite_folder
    if (!carpeta) continue

    const variante = inv.item.material?.nombre ?? inv.color?.nombre ?? 'default'
    const cuadrosTotal = CUADROS_ESPECIALES[carpeta]

    if (base.lpc_zpos_bg != null) {
      capas.push({
        key: `equipo-${inv.id}-bg`,
        zPos: base.lpc_zpos_bg,
        src: `/avatar-equip/${carpeta}/${variante}_bg.png`,
        cuadrosTotal,
      })
    }
    if (base.lpc_zpos_fg != null) {
      const sufijo = base.lpc_zpos_bg != null ? '_fg' : ''
      capas.push({
        key: `equipo-${inv.id}-fg`,
        zPos: base.lpc_zpos_fg,
        src: `/avatar-equip/${carpeta}/${variante}${sufijo}.png`,
        cuadrosTotal,
      })
    }
  }
  return capas
}
