import { useState } from 'react'
import { LoginPage } from './features/auth/LoginPage'
import type { UsuarioResponse } from './features/auth/authApi'
import { HomePage } from './features/home/HomePage'
import { clearSession, getUsuario } from './lib/authStorage'

function App() {
  const [usuario, setUsuario] = useState<UsuarioResponse | null>(() =>
    getUsuario<UsuarioResponse>(),
  )

  if (!usuario) return <LoginPage onSuccess={setUsuario} />

  return (
    <HomePage
      usuario={usuario}
      onLogout={() => {
        clearSession()
        setUsuario(null)
      }}
    />
  )
}

export default App
