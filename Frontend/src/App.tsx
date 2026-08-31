import { useState } from 'react'
import { DashboardLayout, NAV_DEFAULT, resolveNav } from './components/layout'
import { LoginPage } from './features/auth/LoginPage'
import type { UsuarioResponse } from './features/auth/authApi'
import { AccesosPage, EmpresaPage, RolesPage, UsuariosPage } from './features/config'
import { PendingPage } from './features/PendingPage'
import { clearSession, getUsuario } from './lib/authStorage'

/** Vistas ya construidas. El resto cae en PendingPage. */
const VIEWS: Record<string, () => React.ReactElement> = {
  'config.usuarios': UsuariosPage,
  'config.accesos': AccesosPage,
  'config.roles': RolesPage,
  'config.empresa': EmpresaPage,
}

function App() {
  const [usuario, setUsuario] = useState<UsuarioResponse | null>(() =>
    getUsuario<UsuarioResponse>(),
  )
  const [view, setView] = useState(NAV_DEFAULT)

  if (!usuario) return <LoginPage onSuccess={setUsuario} />

  const { group, item } = resolveNav(view)
  const View = VIEWS[view]

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
      {View ? <View /> : <PendingPage title={item?.label ?? 'Vista'} group={group?.label} />}
    </DashboardLayout>
  )
}

export default App
