import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import AvatarAnimado from '../components/AvatarAnimado'
import {
  APARIENCIA_POR_DEFECTO,
  COLORES_PELO,
  PEINADOS,
  TONOS_PIEL,
  VELLO_FACIAL,
  rutaPelo,
  rutaVelloFacial,
} from '../lib/avatarAssets'
import { actualizarApariencia, getCharacter } from '../lib/game'

function agrupar(lista) {
  const grupos = {}
  for (const item of lista) {
    grupos[item.grupo] = grupos[item.grupo] || []
    grupos[item.grupo].push(item)
  }
  return grupos
}

const PEINADOS_AGRUPADOS = agrupar(PEINADOS)
const VELLO_AGRUPADO = agrupar(VELLO_FACIAL)

export default function EditarPersonaje() {
  const navigate = useNavigate()
  const [personaje, setPersonaje] = useState(null)
  const [apariencia, setApariencia] = useState(null)
  const [error, setError] = useState('')
  const [guardando, setGuardando] = useState(false)

  useEffect(() => {
    async function cargar() {
      try {
        const data = await getCharacter()
        setPersonaje(data)
        setApariencia({ ...APARIENCIA_POR_DEFECTO, ...(data.apariencia || {}) })
      } catch (e) {
        setError(e.message)
      }
    }
    cargar()
  }, [])

  function set(campo, valor) {
    setApariencia({ ...apariencia, [campo]: valor })
  }

  async function handleGuardar() {
    setGuardando(true)
    setError('')
    try {
      await actualizarApariencia(personaje.id, apariencia)
      navigate('/')
    } catch (e) {
      setError(e.message)
    }
    setGuardando(false)
  }

  if (error) return <p className="error">{error}</p>
  if (!apariencia) return <p>Cargando...</p>

  return (
    <div className="pagina">
      <button onClick={() => navigate('/')} className="boton-volver">‹ Volver</button>

      <div className="avatar-contenedor avatar-contenedor-fijo">
        <AvatarAnimado apariencia={apariencia} />
      </div>

      <div className="tarjeta">
        <h3>Cuerpo</h3>
        <div className="fila-opciones-rasgo">
          {[{ id: 'male', label: 'Hombre' }, { id: 'female', label: 'Mujer' }].map((op) => (
            <button key={op.id} className={apariencia.bodyType === op.id ? 'activo' : ''} onClick={() => set('bodyType', op.id)}>
              {op.label}
            </button>
          ))}
        </div>
      </div>

      <div className="tarjeta">
        <h3>Tono de piel</h3>
        <div className="fila-opciones-rasgo">
          {TONOS_PIEL.map((op) => (
            <button key={op.id} className={apariencia.skinTone === op.id ? 'activo' : ''} onClick={() => set('skinTone', op.id)}>
              {op.label}
            </button>
          ))}
        </div>
      </div>

      <div className="tarjeta">
        <h3>Color de pelo</h3>
        <div className="fila-opciones-rasgo">
          {COLORES_PELO.map((op) => (
            <button key={op.id} className={apariencia.hairColor === op.id ? 'activo' : ''} onClick={() => set('hairColor', op.id)}>
              {op.label}
            </button>
          ))}
        </div>
      </div>

      <div className="tarjeta">
        <h3>Peinado</h3>
        <div className="grilla-miniaturas">
          <button
            className={`miniatura-opcion ${!apariencia.hairStyle ? 'activo' : ''}`}
            onClick={() => set('hairStyle', null)}
          >
            Ninguno
          </button>
          {Object.entries(PEINADOS_AGRUPADOS).map(([grupo, opciones]) => (
            <div key={grupo} className="grupo-miniaturas">
              <p className="detalle-item">{grupo}</p>
              <div className="grilla-miniaturas">
                {opciones.map((op) => (
                  <button
                    key={op.id}
                    className={`miniatura-opcion ${apariencia.hairStyle === op.id ? 'activo' : ''}`}
                    onClick={() => set('hairStyle', op.id)}
                    title={op.label}
                  >
                    <img src={rutaPelo(op.id, apariencia.hairColor)} alt={op.label} />
                  </button>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="tarjeta">
        <h3>Vello facial</h3>
        <div className="grilla-miniaturas">
          <button
            className={`miniatura-opcion ${!apariencia.facialHairStyle ? 'activo' : ''}`}
            onClick={() => set('facialHairStyle', null)}
          >
            Ninguno
          </button>
          {Object.entries(VELLO_AGRUPADO).map(([grupo, opciones]) => (
            <div key={grupo} className="grupo-miniaturas">
              <p className="detalle-item">{grupo}</p>
              <div className="grilla-miniaturas">
                {opciones.map((op) => (
                  <button
                    key={op.id}
                    className={`miniatura-opcion ${apariencia.facialHairStyle === op.id ? 'activo' : ''}`}
                    onClick={() => set('facialHairStyle', op.id)}
                    title={op.label}
                  >
                    <img src={rutaVelloFacial(op.id, apariencia.hairColor)} alt={op.label} />
                  </button>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>

      <button className="boton-primario" disabled={guardando} onClick={handleGuardar}>
        Guardar
      </button>
    </div>
  )
}
