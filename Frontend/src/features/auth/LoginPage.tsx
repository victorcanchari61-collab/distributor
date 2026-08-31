import { useState } from 'react'
import type { FormEvent } from 'react'
import { Alert, Button, Card, Checkbox, Input, Logo } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { saveSession } from '../../lib/authStorage'
import { login } from './authApi'
import type { UsuarioResponse } from './authApi'
import { ModuleCarousel } from './ModuleCarousel'

const DEMO = { email: 'admin@distributor.com', password: '123456' }

export interface LoginPageProps {
  /** Se dispara cuando la autenticacion fue correcta. */
  onSuccess?: (usuario: UsuarioResponse) => void
}

export function LoginPage({ onSuccess }: LoginPageProps) {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [remember, setRemember] = useState(true)
  const [errors, setErrors] = useState<{ email?: string; password?: string }>({})
  const [formError, setFormError] = useState('')
  const [loading, setLoading] = useState(false)

  function validate() {
    const next: { email?: string; password?: string } = {}
    if (!email.trim()) next.email = 'Ingresa tu correo electrónico.'
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) next.email = 'El correo no tiene un formato válido.'
    if (!password) next.password = 'Ingresa tu contraseña.'
    else if (password.length < 6) next.password = 'La contraseña debe tener al menos 6 caracteres.'
    setErrors(next)
    return Object.keys(next).length === 0
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setFormError('')
    if (!validate()) return

    setLoading(true)
    try {
      const data = await login({ email: email.trim(), password })
      saveSession(data.token, data.usuario, remember)
      onSuccess?.(data.usuario)
    } catch (error) {
      if (error instanceof ApiError) {
        setFormError(error.errors.length ? error.errors.join(' ') : error.message)
      } else {
        setFormError('No pudimos validar tus credenciales. Inténtalo nuevamente.')
      }
    } finally {
      setLoading(false)
    }
  }

  function useDemoCredentials() {
    setEmail(DEMO.email)
    setPassword(DEMO.password)
    setErrors({})
  }

  return (
    <main className="grid min-h-screen grid-cols-1 lg:grid-cols-2">
      {/* Columna izquierda: formulario */}
      <div className="relative flex flex-col bg-surface px-5 py-8 sm:px-10 lg:px-14">
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-0 opacity-[0.35] [background-image:radial-gradient(circle_at_1px_1px,var(--color-line)_1px,transparent_0)] [background-size:26px_26px]"
        />

        <header className="relative flex items-center gap-3">
          <Logo showText={false} />
          <span className="text-xs font-semibold tracking-[0.22em] text-ink-soft uppercase">
            Suite operativa
          </span>
        </header>

        <div className="relative flex flex-1 items-center justify-center py-10">
          <Card className="w-full max-w-md">
            <div className="mb-6 text-center">
              <p className="text-xs font-semibold tracking-[0.22em] text-ink-soft uppercase">
                Bienvenido a
              </p>
              <Logo className="mt-2 justify-center" />
              <p className="mt-3 text-sm text-ink-muted">
                Inicia sesión para gestionar ventas, almacén, despacho y RR. HH. desde un solo lugar.
              </p>
            </div>

            <form onSubmit={handleSubmit} noValidate className="flex flex-col gap-5">
              {formError && <Alert>{formError}</Alert>}

              <Input
                label="Correo electrónico"
                type="email"
                autoComplete="email"
                placeholder="admin@distributor.com"
                value={email}
                error={errors.email}
                onChange={(e) => setEmail(e.target.value)}
                icon={<MailIcon />}
              />

              <Input
                label="Contraseña"
                type="password"
                autoComplete="current-password"
                placeholder="********"
                revealable
                value={password}
                error={errors.password}
                onChange={(e) => setPassword(e.target.value)}
                icon={<LockIcon />}
                hint={
                  <a
                    href="#recuperar"
                    className="text-xs font-medium text-brand hover:underline"
                  >
                    ¿Olvidaste tu contraseña?
                  </a>
                }
              />

              <Checkbox
                label="Mantener sesión iniciada en este equipo"
                checked={remember}
                onChange={(e) => setRemember(e.target.checked)}
              />

              <Button type="submit" block loading={loading} iconRight={<ArrowIcon />}>
                Ingresar al panel
              </Button>
            </form>

            <p className="mt-6 text-center text-xs text-ink-muted">
              ¿Solo quieres echar un vistazo?{' '}
              <Button variant="ghost" onClick={useDemoCredentials}>
                Usar credenciales de prueba
              </Button>
            </p>
          </Card>
        </div>

        <footer className="relative text-center text-xs text-ink-soft lg:text-left">
          &copy; {new Date().getFullYear()} Distribuidora. Todos los derechos reservados.
        </footer>
      </div>

      {/* Columna derecha: carrusel de módulos */}
      <aside className="relative hidden items-center justify-center overflow-hidden border-l border-line bg-gradient-to-br from-surface-alt via-surface to-surface-alt px-10 py-12 lg:flex xl:px-16">
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-0 opacity-60 [background-image:linear-gradient(to_right,var(--color-line)_1px,transparent_1px),linear-gradient(to_bottom,var(--color-line)_1px,transparent_1px)] [background-size:64px_64px] [mask-image:radial-gradient(ellipse_at_center,black,transparent_75%)]"
        />
        <div className="relative w-full max-w-2xl">
          <ModuleCarousel />
        </div>
      </aside>
    </main>
  )
}

function MailIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
      <rect x="3" y="5" width="18" height="14" rx="2.5" />
      <path d="m3.5 7 8.5 6 8.5-6" />
    </svg>
  )
}

function LockIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
      <rect x="4.5" y="10" width="15" height="10" rx="2.5" />
      <path d="M8 10V7.5a4 4 0 1 1 8 0V10" />
    </svg>
  )
}

function ArrowIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.9">
      <path d="M5 12h13M13 6.5 18.5 12 13 17.5" />
    </svg>
  )
}
