import { useEffect, useState } from 'react'
import { Route, Routes } from 'react-router-dom'
import NavBar from './components/NavBar'
import { supabase } from './lib/supabaseClient'
import Login from './pages/Login'
import Mapa from './pages/Mapa'
import Personaje from './pages/Personaje'
import Tienda from './pages/Tienda'

export default function App() {
  const [session, setSession] = useState(undefined)

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session))
    const { data: listener } = supabase.auth.onAuthStateChange((_event, s) => setSession(s))
    return () => listener.subscription.unsubscribe()
  }, [])

  if (session === undefined) return <div className="pantalla-centrada">Cargando...</div>
  if (!session) return <Login />

  return (
    <div className="app">
      <main>
        <Routes>
          <Route path="/" element={<Personaje />} />
          <Route path="/tienda" element={<Tienda />} />
          <Route path="/mapa" element={<Mapa />} />
        </Routes>
      </main>
      <NavBar />
    </div>
  )
}
