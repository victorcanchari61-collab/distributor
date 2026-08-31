import { useState } from 'react'
import { DashboardLayout, NAV_DEFAULT } from './components/layout'
import { LoginPage } from './features/auth/LoginPage'
import type { UsuarioResponse } from './features/auth/authApi'
import { DashboardPage } from './features/dashboard/DashboardPage'
import { clearSession, getUsuario } from './lib/authStorage'

function App() {
  const [usuario, setUsuario] = useState<UsuarioResponse | null>(() =>
    getUsuario<UsuarioResponse>(),
  )
  const [view, setView] = useState(NAV_DEFAULT)

  if (!usuario) return <LoginPage onSuccess={setUsuario} />

  return (
    <DashboardLayout
      active={view}
      onSelect={setView}
      userName={usuario.nombre}
      userEmail={usuario.email}
      onLogout={() => {
        clearSession()
        setUsuario(null)
      }}
    >
      {/* TODO: cada entrada del menu tendra su propia vista cuando exista el router. */}
      <DashboardPage />
    </DashboardLayout>
  )
}

export default App
