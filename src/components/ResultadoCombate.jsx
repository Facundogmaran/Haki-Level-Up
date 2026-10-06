import { claveVisual } from '../lib/equipoDisplay'
import { NOMBRES_TIER } from '../lib/social'
import IconoEquipo from './IconoEquipo'

function Luchador({ datos }) {
  return (
    <div className="luchador">
      <strong>{datos.nombre}</strong>
      <span>Nivel {datos.nivel}</span>
      <span>Poder {Math.round(datos.poder)}</span>
    </div>
  )
}

// Mismo overlay que el resultado de entrenamiento. Mientras el combate se
// resuelve (`resultado` en null) muestra el cruce; después, el desenlace.
export default function ResultadoCombate({ yo, rival, resultado, onCerrar }) {
  const luchando = !resultado
  const atacante = resultado?.atacante ?? yo
  const defensor = resultado?.defensor ?? rival

  return (
    <div className="overlay">
      <div className="tarjeta resultado-entrenamiento-overlay resultado-combate">
        <p className="resultado-titulo">⚔️ Combate</p>

        <div className="combate-vs">
          <Luchador datos={atacante} />
          <span className={`combate-vs-texto${luchando ? ' combate-vs-luchando' : ''}`}>VS</span>
          <Luchador datos={defensor} />
        </div>

        {luchando && <p className="resultado-resumen">Combatiendo...</p>}

        {resultado && (
          <div className="combate-desenlace">
            <p className={`combate-veredicto ${resultado.gano ? 'exito' : 'fallo'}`}>
              {resultado.gano ? '¡VICTORIA!' : 'DERROTA'}
            </p>
            <p className="resultado-resumen">
              {resultado.gano ? `Has derrotado a ${defensor.nombre}.` : `${defensor.nombre} te ha derrotado.`}
            </p>
            <p className="detalle-item">Probabilidad de victoria: {Math.round(resultado.chance * 100)}%</p>

            {resultado.gano && <p className="resultado-xp">+{resultado.oro_ganado} 🪙 Oro</p>}

            {resultado.item && (
              <div className="combate-loot">
                <p className="detalle-item">Loot obtenido ({NOMBRES_TIER[resultado.item.tier] ?? resultado.item.tier}):</p>
                <div className="item-catalogo-con-icono">
                  <IconoEquipo
                    carpeta={resultado.item.lpc_sprite_folder}
                    variante={claveVisual(resultado.item.material_nombre, resultado.item.color_nombre)}
                    tieneBg={resultado.item.lpc_zpos_bg != null}
                  />
                  <strong>{resultado.item.nombre}</strong>
                </div>
              </div>
            )}

            <p className="detalle-item">
              Combates hoy contra {defensor.nombre}: {resultado.combates_hoy}/{resultado.combates_max}
            </p>
            <button onClick={onCerrar}>Continuar</button>
          </div>
        )}
      </div>
    </div>
  )
}
