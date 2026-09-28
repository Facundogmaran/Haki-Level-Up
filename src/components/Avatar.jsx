// Avatar del personaje: capas de imagen (arte de Liberated Pixel Cup,
// recortado y recoloreado offline — ver public/avatar/CREDITS.md).
// El equipamiento todavía no se dibuja sobre el cuerpo (queda para
// cuando se sumen los assets de equipamiento).
import {
  APARIENCIA_POR_DEFECTO,
  rutaCara,
  rutaCuerpo,
  rutaOrejas,
  rutaNariz,
  rutaPelo,
  rutaVelloFacial,
} from '../lib/avatarAssets'

export default function Avatar({ apariencia }) {
  const a = { ...APARIENCIA_POR_DEFECTO, ...apariencia }
  const capas = [
    rutaCuerpo(a.skinTone, a.bodyType),
    rutaCara(a.skinTone, a.bodyType),
    rutaNariz(a.skinTone),
    rutaVelloFacial(a.facialHairStyle, a.hairColor),
    rutaPelo(a.hairStyle, a.hairColor),
    rutaOrejas(a.skinTone),
  ].filter(Boolean)

  return (
    <div className="avatar-lienzo">
      {capas.map((src) => (
        <img key={src} src={src} alt="" className="avatar-capa" />
      ))}
    </div>
  )
}
