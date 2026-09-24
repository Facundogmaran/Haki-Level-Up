import { NavLink } from 'react-router-dom'
import { supabase } from '../lib/supabaseClient'

const LINKS = [
  { to: '/', label: 'Personaje', end: true },
  { to: '/tienda', label: 'Tienda' },
  { to: '/mapa', label: 'Mapa' },
]

export default function NavBar() {
  return (
    <nav className="navbar">
      {LINKS.map((l) => (
        <NavLink key={l.to} to={l.to} end={l.end} className={({ isActive }) => (isActive ? 'activo' : '')}>
          {l.label}
        </NavLink>
      ))}
      <button className="link-salir" onClick={() => supabase.auth.signOut()}>
        Salir
      </button>
    </nav>
  )
}
