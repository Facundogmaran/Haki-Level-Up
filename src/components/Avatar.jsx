// Avatar del personaje: capas de imagen (arte de Liberated Pixel Cup,
// recortado y recoloreado offline — ver public/avatar/CREDITS.md).
// El equipamiento todavía no se dibuja sobre el cuerpo (queda para
// cuando se sumen los assets de equipamiento).
import { APARIENCIA_POR_DEFECTO, rutaCuerpo, rutaPelo, rutaVelloFacial } from '../lib/avatarAssets'

export default function Avatar({ apariencia }) {
  const a = { ...APARIENCIA_POR_DEFECTO, ...apariencia }
  const capas = [
    rutaCuerpo(a.skinTone, a.bodyType),
    rutaVelloFacial(a.facialHairStyle, a.hairColor),
    rutaPelo(a.hairStyle, a.hairColor),
  ].filter(Boolean)

  return (
    <div className="avatar-lienzo">
      {capas.map((src) => (
        <img key={src} src={src} alt="" className="avatar-capa" />
      ))}
    </div>
  )
}
