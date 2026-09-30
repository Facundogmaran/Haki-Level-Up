// Miniatura de un ítem de equipamiento: recorta el primer cuadro de la
// dirección "abajo" de su hoja de caminata (mismo asset que ya se usa
// para dibujarlo puesto sobre el personaje), sin animar.
export default function IconoEquipo({ carpeta, variante, tieneBg }) {
  if (!carpeta || !variante) {
    return <div className="icono-equipo icono-equipo-vacio" />
  }
  const sufijo = tieneBg ? '_fg' : ''
  const src = `/avatar-equip/${carpeta}/${variante}${sufijo}.png`
  return (
    <div className="icono-equipo">
      <div className="icono-equipo-hoja" style={{ backgroundImage: `url(${src})` }} />
    </div>
  )
}
