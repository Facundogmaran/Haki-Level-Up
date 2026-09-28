import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import Avatar, { OPCIONES_BOCA, OPCIONES_FISICO, OPCIONES_OJOS, OPCIONES_PELO } from '../components/Avatar'
import { actualizarApariencia, getCharacter, getInventory } from '../lib/game'

const RASGOS = [
  { clave: 'fisico', label: 'Físico', opciones: OPCIONES_FISICO },
  { clave: 'pelo', label: 'Pelo', opciones: OPCIONES_PELO },
  { clave: 'ojos', label: 'Ojos', opciones: OPCIONES_OJOS },
  { clave: 'boca', label: 'Boca', opciones: OPCIONES_BOCA },
]

export default function EditarPersonaje() {
  const navigate = useNavigate()
  const [personaje, setPersonaje] = useState(null)
  const [equipado, setEquipado] = useState([])
  const [apariencia, setApariencia] = useState(null)
  const [error, setError] = useState('')
  const [guardando, setGuardando] = useState(false)

  useEffect(() => {
    async function cargar() {
      try {
        const [data, inventario] = await Promise.all([getCharacter(), getInventory()])
        setPersonaje(data)
        setApariencia(data.apariencia)
        setEquipado(inventario.filter((i) => i.equipado).map((i) => ({ slot: i.item.slot, color: i.item.color })))
      } catch (e) {
        setError(e.message)
      }
    }
    cargar()
  }, [])

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

      <div className="tarjeta avatar-contenedor">
        <Avatar apariencia={apariencia} equipado={equipado} />
      </div>

      {RASGOS.map((rasgo) => (
        <div key={rasgo.clave} className="tarjeta">
          <h3>{rasgo.label}</h3>
          <div className="fila-opciones-rasgo">
            {rasgo.opciones.map((op) => (
              <button
                key={op}
                className={apariencia[rasgo.clave] === op ? 'activo' : ''}
                onClick={() => setApariencia({ ...apariencia, [rasgo.clave]: op })}
              >
                {op}
              </button>
            ))}
          </div>
        </div>
      ))}

      <button className="boton-primario" disabled={guardando} onClick={handleGuardar}>
        Guardar
      </button>
    </div>
  )
}
