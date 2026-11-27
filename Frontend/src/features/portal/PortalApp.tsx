import { useCallback, useEffect, useState } from 'react'
import type { FormEvent, ReactNode } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { Alert, Button, Input, Logo } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { RUTA_PORTAL, SECCIONES_PORTAL, guardarSesion, leerSesion, portalApi } from './portalApi'
import type { EnlacePortal, PortalSesion, SeccionPortal } from './portalApi'
import { TiendaPortal } from './TiendaPortal'

const mensaje = (e: unknown, porDefecto: string) => (e instanceof ApiError ? e.message : porDefecto)

/**
 * El portal de clientes (/portal): sin el menú ni la sesión del panel. El cliente entra con el usuario y la
 * contraseña que eligió al abrir la invitación que le mandó su vendedor, arma su cotización con el catálogo (con SUS
 * precios) y la manda. El vendedor la jala desde el formulario de pedido.
 */
export function PortalApp() {
  const { pathname } = useLocation()
  const navigate = useNavigate()
  const [sesion, setSesion] = useState<PortalSesion | null>(() => leerSesion())

  const entrar = useCallback(
    (nueva: PortalSesion) => {
      guardarSesion(nueva)
      setSesion(nueva)
      navigate(RUTA_PORTAL, { replace: true })
    },
    [navigate],
  )

  const salir = useCallback(() => {
    guardarSesion(null)
    setSesion(null)
    navigate(RUTA_PORTAL, { replace: true })
  }, [navigate])

  // Cambió el usuario o la contraseña en "Mi perfil": la sesión nueva se guarda sin salir de la página.
  const actualizar = useCallback((nueva: PortalSesion) => {
    guardarSesion(nueva)
    setSesion(nueva)
  }, [])

  useEffect(() => {
    const anterior = document.title
    document.title = sesion ? `Cotizaciones · ${sesion.cliente.empresa}` : 'Portal de clientes'
    return () => {
      document.title = anterior
    }
  }, [sesion])

  const partes = pathname.replace(/\/+$/, '').split('/')
  let contenido: ReactNode
  if (partes[2] === 'activar' && partes[3]) contenido = <Activar token={partes[3]} onListo={entrar} />
  else if (partes[2] === 'restablecer' && partes[3]) contenido = <Restablecer token={partes[3]} onListo={entrar} />
  else if (partes[2] === 'olvide') contenido = <Olvide />
  else if (sesion) {
    // La tienda tiene su propia cabecera y navegación: /portal, /portal/favoritos, /portal/cotizaciones...
    const seccion: SeccionPortal = SECCIONES_PORTAL.includes(partes[2] as SeccionPortal)
      ? (partes[2] as SeccionPortal)
      : 'catalogo'
    return <TiendaPortal sesion={sesion} seccion={seccion} onSalir={salir} onSesion={actualizar} />
  } else contenido = <Entrar onListo={entrar} />

  return (
    <div data-sys="fact" className="min-h-screen bg-surface-alt">
      <header className="bg-gradient-to-br from-navy to-navy-deep text-white">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-4 sm:px-6">
          <div className="flex min-w-0 items-center gap-3">
            <Logo variant="emblem" size={40} className="shrink-0" />
            <div className="min-w-0">
              <p className="truncate text-base font-bold sm:text-lg">
                {sesion?.cliente.empresa || 'Portal de clientes'}
              </p>
              <p className="truncate text-xs text-white/75">
                {sesion ? sesion.cliente.nombre : 'Cotizaciones en línea'}
              </p>
            </div>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-6xl px-4 py-5 pb-16 sm:px-6">{contenido}</main>

      {/* Los modales se montan aquí: dentro del data-sys, con el color del portal. */}
      <div id="modal-root" />
    </div>
  )
}

// ================================================================ Sin sesión

/** Tarjeta centrada para los formularios de entrar, activar y recuperar. */
function Tarjeta({ titulo, subtitulo, children }: { titulo: string; subtitulo?: ReactNode; children: ReactNode }) {
  return (
    <div className="mx-auto mt-4 w-full max-w-md rounded-2xl border border-line bg-surface p-5 shadow-sm sm:mt-10 sm:p-7">
      <h1 className="text-xl font-bold text-ink">{titulo}</h1>
      {subtitulo && <p className="mt-1 text-sm text-ink-muted">{subtitulo}</p>}
      <div className="mt-5">{children}</div>
    </div>
  )
}

function Entrar({ onListo }: { onListo: (s: PortalSesion) => void }) {
  const navigate = useNavigate()
  const [usuario, setUsuario] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [enviando, setEnviando] = useState(false)

  const enviar = async (e: FormEvent) => {
    e.preventDefault()
    setEnviando(true)
    setError('')
    try {
      onListo(await portalApi.login({ usuario, password }))
    } catch (err) {
      setError(mensaje(err, 'No pudimos entrar. Revisa tu conexión.'))
    } finally {
      setEnviando(false)
    }
  }

  return (
    <Tarjeta
      titulo="Entra para hacer tu cotización"
      subtitulo="Con el usuario y la contraseña que creaste. También puedes poner tu DNI o RUC."
    >
      <form onSubmit={(e) => void enviar(e)} className="space-y-4">
        {error && <Alert tone="error">{error}</Alert>}
        <Input
          label="Usuario o DNI/RUC"
          value={usuario}
          onChange={(e) => setUsuario(e.target.value)}
          autoComplete="username"
          autoCapitalize="none"
        />
        <Input
          label="Contraseña"
          type="password"
          revealable
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          autoComplete="current-password"
        />
        <Button type="submit" className="w-full" loading={enviando}>
          Entrar
        </Button>
        <button
          type="button"
          onClick={() => navigate(`${RUTA_PORTAL}/olvide`)}
          className="block w-full text-center text-sm font-medium text-[rgb(var(--sys-ink-rgb))] hover:underline"
        >
          Olvidé mi contraseña
        </button>
      </form>
      <p className="mt-5 text-center text-xs text-ink-soft">
        ¿Todavía no tienes acceso? Pídele a tu vendedor que te invite.
      </p>
    </Tarjeta>
  )
}

function Olvide() {
  const navigate = useNavigate()
  const [usuario, setUsuario] = useState('')
  const [listo, setListo] = useState('')
  const [error, setError] = useState('')
  const [enviando, setEnviando] = useState(false)

  const enviar = async (e: FormEvent) => {
    e.preventDefault()
    setEnviando(true)
    setError('')
    try {
      setListo((await portalApi.olvide(usuario)).message)
    } catch (err) {
      setError(mensaje(err, 'No pudimos enviar el enlace. Inténtalo de nuevo.'))
    } finally {
      setEnviando(false)
    }
  }

  return (
    <Tarjeta
      titulo="Crea una contraseña nueva"
      subtitulo="Te mandamos por WhatsApp, al número que tiene tu vendedor, un enlace para elegirla."
    >
      {listo ? (
        <div className="space-y-4">
          <Alert tone="info">{listo}</Alert>
          <Button variant="secondary" className="w-full" onClick={() => navigate(RUTA_PORTAL)}>
            Volver a entrar
          </Button>
        </div>
      ) : (
        <form onSubmit={(e) => void enviar(e)} className="space-y-4">
          {error && <Alert tone="error">{error}</Alert>}
          <Input
            label="Tu usuario o tu DNI/RUC"
            value={usuario}
            onChange={(e) => setUsuario(e.target.value)}
            autoCapitalize="none"
          />
          <Button type="submit" className="w-full" loading={enviando} disabled={!usuario.trim()}>
            Enviarme el enlace
          </Button>
          <button
            type="button"
            onClick={() => navigate(RUTA_PORTAL)}
            className="block w-full text-center text-sm font-medium text-ink-muted hover:underline"
          >
            Volver
          </button>
        </form>
      )}
    </Tarjeta>
  )
}

/** Abre el enlace y avisa si ya no sirve. */
function useEnlace(token: string) {
  const [enlace, setEnlace] = useState<EnlacePortal | null>(null)
  const [error, setError] = useState('')
  useEffect(() => {
    let vigente = true
    portalApi
      .enlace(token)
      .then((r) => vigente && setEnlace(r))
      .catch((e) => vigente && setError(mensaje(e, 'No pudimos abrir el enlace.')))
    return () => {
      vigente = false
    }
  }, [token])
  return { enlace, error }
}

function EnlaceNoSirve({ error }: { error: string }) {
  const navigate = useNavigate()
  return (
    <Tarjeta titulo="Este enlace no sirve">
      <div className="space-y-4">
        <Alert tone="error">{error}</Alert>
        <Button variant="secondary" className="w-full" onClick={() => navigate(RUTA_PORTAL, { replace: true })}>
          Ir a entrar
        </Button>
      </div>
    </Tarjeta>
  )
}

function Activar({ token, onListo }: { token: string; onListo: (s: PortalSesion) => void }) {
  const { enlace, error: errorEnlace } = useEnlace(token)
  const [documento, setDocumento] = useState('')
  const [usuario, setUsuario] = useState<string | null>(null)
  const [password, setPassword] = useState('')
  const [repetir, setRepetir] = useState('')
  const [error, setError] = useState('')
  const [enviando, setEnviando] = useState(false)

  if (errorEnlace) return <EnlaceNoSirve error={errorEnlace} />
  if (!enlace) return <Tarjeta titulo="Abriendo tu invitación…">{null}</Tarjeta>

  const usuarioActual = usuario ?? enlace.usuarioSugerido ?? ''

  const enviar = async (e: FormEvent) => {
    e.preventDefault()
    if (password !== repetir) return setError('Las dos contraseñas no son iguales.')
    setEnviando(true)
    setError('')
    try {
      onListo(
        await portalApi.activar({
          token,
          documento,
          usuario: usuarioActual,
          password,
        }),
      )
    } catch (err) {
      setError(mensaje(err, 'No pudimos crear tu acceso. Inténtalo de nuevo.'))
    } finally {
      setEnviando(false)
    }
  }

  return (
    <Tarjeta
      titulo={`Hola, ${enlace.cliente}`}
      subtitulo={`${enlace.empresa} te invita a mandar tus cotizaciones desde aquí. Crea tu acceso: lo harás una sola vez.`}
    >
      <form onSubmit={(e) => void enviar(e)} className="space-y-4">
        {error && <Alert tone="error">{error}</Alert>}
        <Input
          label="Confirma tu DNI o RUC"
          hint="Para saber que eres tú."
          inputMode="numeric"
          value={documento}
          onChange={(e) => setDocumento(e.target.value.replace(/\D/g, ''))}
          maxLength={11}
        />
        <div>
          <Input
            label="Elige tu usuario"
            value={usuarioActual}
            onChange={(e) => setUsuario(e.target.value.toLowerCase().replace(/\s/g, ''))}
            autoCapitalize="none"
            autoComplete="username"
          />
          <p className="mt-1 text-xs text-ink-soft">
            De 4 a 30 letras o números, sin espacios. Puedes dejar tu número de documento.
          </p>
        </div>
        <Input
          label="Elige tu contraseña"
          hint="Al menos 6 caracteres."
          type="password"
          revealable
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          autoComplete="new-password"
        />
        <Input
          label="Repite la contraseña"
          type="password"
          revealable
          value={repetir}
          onChange={(e) => setRepetir(e.target.value)}
          autoComplete="new-password"
        />
        <Button type="submit" className="w-full" loading={enviando}>
          Crear mi acceso
        </Button>
      </form>
    </Tarjeta>
  )
}

function Restablecer({ token, onListo }: { token: string; onListo: (s: PortalSesion) => void }) {
  const { enlace, error: errorEnlace } = useEnlace(token)
  const [password, setPassword] = useState('')
  const [repetir, setRepetir] = useState('')
  const [error, setError] = useState('')
  const [enviando, setEnviando] = useState(false)

  if (errorEnlace) return <EnlaceNoSirve error={errorEnlace} />
  if (!enlace) return <Tarjeta titulo="Abriendo el enlace…">{null}</Tarjeta>

  const enviar = async (e: FormEvent) => {
    e.preventDefault()
    if (password !== repetir) return setError('Las dos contraseñas no son iguales.')
    setEnviando(true)
    setError('')
    try {
      onListo(await portalApi.restablecer({ token, password }))
    } catch (err) {
      setError(mensaje(err, 'No pudimos cambiar tu contraseña. Inténtalo de nuevo.'))
    } finally {
      setEnviando(false)
    }
  }

  return (
    <Tarjeta
      titulo="Elige tu contraseña nueva"
      subtitulo={enlace.usuario ? `Tu usuario es ${enlace.usuario}.` : undefined}
    >
      <form onSubmit={(e) => void enviar(e)} className="space-y-4">
        {error && <Alert tone="error">{error}</Alert>}
        <Input
          label="Contraseña nueva"
          hint="Al menos 6 caracteres."
          type="password"
          revealable
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          autoComplete="new-password"
        />
        <Input
          label="Repite la contraseña"
          type="password"
          revealable
          value={repetir}
          onChange={(e) => setRepetir(e.target.value)}
          autoComplete="new-password"
        />
        <Button type="submit" className="w-full" loading={enviando}>
          Guardar y entrar
        </Button>
      </form>
    </Tarjeta>
  )
}
