import { useCallback, useEffect, useMemo, useState } from 'react'
import type { FormEvent, ReactNode } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { ClipboardList, LogOut, Minus, Plus, Send, ShoppingCart, Store, Trash2, UserRound } from 'lucide-react'
import { Alert, Badge, Button, Input, Logo, Modal, cn, useConfirmacion, useToast } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { CatalogoVista } from '../maestros/CatalogoVista'
import type { CarritoCatalogo, FavoritosCatalogo } from '../maestros/CatalogoVista'
import type { CatalogoPresentacion, CatalogoProducto, CatalogoResponse } from '../maestros/catalogoApi'
import { ESTADO_COTIZACION, RUTA_PORTAL, guardarSesion, leerSesion, portalApi } from './portalApi'
import type { Cotizacion, EnlacePortal, PortalSesion } from './portalApi'

const soles = (valor: number) =>
  `S/ ${valor.toLocaleString('es-PE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`

const cantidadTexto = (valor: number) => valor.toLocaleString('es-PE', { maximumFractionDigits: 3 })

const fecha = (iso: string) =>
  new Date(iso).toLocaleString('es-PE', {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  })

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
  else if (sesion) contenido = <Inicio sesion={sesion} onSalir={salir} />
  else contenido = <Entrar onListo={entrar} />

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
          {sesion && partes.length <= 2 && (
            <button
              type="button"
              onClick={salir}
              className="inline-flex shrink-0 items-center gap-1.5 rounded-full bg-white/10 px-3 py-1.5 text-sm ring-1 ring-white/20 hover:bg-white/20"
            >
              <LogOut className="size-4" aria-hidden /> Salir
            </button>
          )}
        </div>
      </header>

      <main className="mx-auto max-w-6xl px-4 py-5 pb-28 sm:px-6">{contenido}</main>

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
        <Input
          label="Elige tu usuario"
          hint="De 4 a 30 letras o números, sin espacios. Puedes dejar tu número de documento."
          value={usuarioActual}
          onChange={(e) => setUsuario(e.target.value.toLowerCase().replace(/\s/g, ''))}
          autoCapitalize="none"
          autoComplete="username"
        />
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

// ================================================================ Con sesión

/** Una línea del carrito. Guarda lo necesario para mostrarla; el precio de verdad lo pone el servidor al enviar. */
interface LineaCarrito {
  presentacionId: number
  cantidad: number
  producto: string
  presentacion: string
  precio: number
  escalones: { cantidadMinima: number; precio: number }[]
}

/** El precio por esa cantidad, como lo calcula el servidor: el escalón más alto que alcanza, o el normal. */
const precioPorCantidad = (l: Pick<LineaCarrito, 'precio' | 'escalones' | 'cantidad'>) =>
  [...l.escalones].sort((a, b) => b.cantidadMinima - a.cantidadMinima).find((e) => e.cantidadMinima <= l.cantidad)
    ?.precio ?? l.precio

/** El carrito se recuerda en el celular, por usuario: si cierra la página, al volver sigue ahí. */
function useCarrito(usuario: string) {
  const clave = `distribuidora.portal.carrito.${usuario}`
  const [lineas, setLineas] = useState<LineaCarrito[]>(() => {
    try {
      return JSON.parse(localStorage.getItem(clave) ?? '[]') as LineaCarrito[]
    } catch {
      return []
    }
  })

  useEffect(() => {
    try {
      localStorage.setItem(clave, JSON.stringify(lineas))
    } catch {
      // Sin almacenamiento: el carrito dura lo que la página.
    }
  }, [clave, lineas])

  const fijar = useCallback((nueva: Omit<LineaCarrito, 'cantidad'>, cantidad: number) => {
    setLineas((actual) => {
      const resto = actual.filter((l) => l.presentacionId !== nueva.presentacionId)
      if (cantidad <= 0) return resto
      const existente = actual.find((l) => l.presentacionId === nueva.presentacionId)
      const linea = { ...(existente ?? nueva), cantidad }
      return existente ? actual.map((l) => (l.presentacionId === nueva.presentacionId ? linea : l)) : [...resto, linea]
    })
  }, [])

  const vaciar = useCallback(() => setLineas([]), [])
  return { lineas, fijar, vaciar }
}

function Inicio({ sesion, onSalir }: { sesion: PortalSesion; onSalir: () => void }) {
  const toast = useToast()
  const [pestana, setPestana] = useState<'catalogo' | 'cotizaciones'>('catalogo')
  const [catalogo, setCatalogo] = useState<CatalogoResponse | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [cotizaciones, setCotizaciones] = useState<Cotizacion[] | null>(null)
  const [carritoAbierto, setCarritoAbierto] = useState(false)
  const { lineas, fijar, vaciar } = useCarrito(sesion.cliente.usuario)
  const [favoritos, setFavoritos] = useState<number[]>([])

  // Una sesión que el servidor ya no acepta (contraseña cambiada, acceso apagado) vuelve a pedir entrar.
  const alFallar = useCallback(
    (e: unknown, porDefecto: string) => {
      if (e instanceof ApiError && e.statusCode === 401) {
        toast.error(e.message)
        onSalir()
        return
      }
      setError(mensaje(e, porDefecto))
    },
    [onSalir, toast],
  )

  // El catálogo y los favoritos juntos: con favoritos, el catálogo arranca mostrando solo esos.
  useEffect(() => {
    Promise.all([portalApi.catalogo(), portalApi.favoritos().catch(() => [] as number[])])
      .then(([c, f]) => {
        setFavoritos(f)
        setCatalogo(c)
      })
      .catch((e) => alFallar(e, 'No pudimos cargar el catálogo.'))
      .finally(() => setCargando(false))
  }, [alFallar])

  const cargarCotizaciones = useCallback(() => {
    portalApi
      .cotizaciones()
      .then(setCotizaciones)
      .catch((e) => alFallar(e, 'No pudimos cargar tus cotizaciones.'))
  }, [alFallar])

  useEffect(() => {
    if (pestana === 'cotizaciones') cargarCotizaciones()
  }, [pestana, cargarCotizaciones])

  const carrito: CarritoCatalogo = useMemo(
    () => ({
      cantidadDe: (id) => lineas.find((l) => l.presentacionId === id)?.cantidad ?? 0,
      fijar: (producto: CatalogoProducto, pr: CatalogoPresentacion, cantidad: number) =>
        pr.id !== undefined &&
        fijar(
          {
            presentacionId: pr.id,
            producto: producto.nombre,
            presentacion: /\p{L}/u.test(pr.nombre) ? pr.nombre : `${pr.unidad} x ${pr.nombre}`.trim(),
            precio: pr.precio,
            escalones: pr.escalones,
          },
          cantidad,
        ),
    }),
    [lineas, fijar],
  )

  // El corazón responde al toque; si el servidor no lo guarda, vuelve como estaba.
  const favoritosCatalogo: FavoritosCatalogo = useMemo(
    () => ({
      es: (id) => favoritos.includes(id),
      soloAlInicio: favoritos.length > 0,
      alternar: (producto) => {
        if (producto.id === undefined) return
        const id = producto.id
        const marcar = !favoritos.includes(id)
        const antes = favoritos
        setFavoritos(marcar ? [...favoritos, id] : favoritos.filter((f) => f !== id))
        portalApi
          .marcarFavorito(id, marcar)
          .then(setFavoritos)
          .catch((e) => {
            setFavoritos(antes)
            if (e instanceof ApiError && e.statusCode === 401) alFallar(e, '')
            else toast.error(mensaje(e, 'No pudimos guardar tu favorito.'))
          })
      },
    }),
    [favoritos, alFallar, toast],
  )

  const total = lineas.reduce((n, l) => n + l.cantidad * precioPorCantidad(l), 0)

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="inline-flex rounded-full border border-line bg-surface p-1">
          {(
            [
              ['catalogo', 'Catálogo', Store],
              ['cotizaciones', 'Mis cotizaciones', ClipboardList],
            ] as const
          ).map(([id, etiqueta, Icono]) => (
            <button
              key={id}
              type="button"
              onClick={() => setPestana(id)}
              className={cn(
                'inline-flex items-center gap-1.5 rounded-full px-4 py-1.5 text-sm font-semibold transition',
                pestana === id ? 'bg-[rgb(var(--sys-rgb))] text-white shadow-sm' : 'text-ink-muted hover:text-ink',
              )}
            >
              <Icono className="size-4" aria-hidden /> {etiqueta}
            </button>
          ))}
        </div>
        {sesion.cliente.vendedor && (
          <p className="flex items-center gap-1.5 text-sm text-ink-muted">
            <UserRound className="size-4" aria-hidden /> Tu vendedor:{' '}
            <span className="font-medium text-ink">{sesion.cliente.vendedor}</span>
          </p>
        )}
      </div>

      {pestana === 'catalogo' ? (
        <CatalogoVista
          datos={catalogo}
          cargando={cargando}
          error={error}
          carrito={carrito}
          favoritos={favoritosCatalogo}
        />
      ) : (
        <MisCotizaciones cotizaciones={cotizaciones} error={error} onCambio={cargarCotizaciones} alFallar={alFallar} />
      )}

      {/* La barra del carrito: siempre a mano en el celular, abajo. */}
      {lineas.length > 0 && (
        <div className="fixed inset-x-0 bottom-0 z-30 border-t border-line bg-surface/95 px-4 py-3 shadow-[0_-4px_16px_rgba(0,0,0,0.06)] backdrop-blur">
          <div className="mx-auto flex max-w-6xl items-center justify-between gap-3">
            <div className="min-w-0">
              <p className="text-xs text-ink-muted">
                {lineas.length} {lineas.length === 1 ? 'producto' : 'productos'} en tu cotización
              </p>
              <p className="text-lg font-bold text-ink">{soles(total)}</p>
            </div>
            <Button onClick={() => setCarritoAbierto(true)} iconRight={<ShoppingCart className="size-4" />}>
              Ver mi cotización
            </Button>
          </div>
        </div>
      )}

      <CarritoModal
        abierto={carritoAbierto}
        onCerrar={() => setCarritoAbierto(false)}
        lineas={lineas}
        total={total}
        vendedor={sesion.cliente.vendedor}
        onCantidad={(l, n) => fijar(l, n)}
        onEnviada={(c) => {
          vaciar()
          setCarritoAbierto(false)
          toast.exito(`Listo: tu cotización ${c.numero} le llegó a tu vendedor.`)
          setPestana('cotizaciones')
          cargarCotizaciones()
        }}
        alFallar={alFallar}
      />
    </div>
  )
}

function CarritoModal({
  abierto,
  onCerrar,
  lineas,
  total,
  vendedor,
  onCantidad,
  onEnviada,
  alFallar,
}: {
  abierto: boolean
  onCerrar: () => void
  lineas: LineaCarrito[]
  total: number
  vendedor: string | null
  onCantidad: (linea: LineaCarrito, cantidad: number) => void
  onEnviada: (c: Cotizacion) => void
  alFallar: (e: unknown, porDefecto: string) => void
}) {
  const toast = useToast()
  const [nota, setNota] = useState('')
  const [enviando, setEnviando] = useState(false)

  const enviar = async () => {
    setEnviando(true)
    try {
      const creada = await portalApi.enviar({
        nota: nota.trim() || null,
        detalle: lineas.map((l) => ({
          presentacionId: l.presentacionId,
          cantidad: l.cantidad,
        })),
      })
      setNota('')
      onEnviada(creada)
    } catch (e) {
      if (e instanceof ApiError && e.statusCode !== 401) toast.error(e.message)
      else alFallar(e, 'No pudimos enviar tu cotización.')
    } finally {
      setEnviando(false)
    }
  }

  const paso =
    'inline-flex size-8 items-center justify-center rounded-full text-[rgb(var(--sys-ink-rgb))] hover:bg-[rgb(var(--sys-rgb)/0.12)]'

  return (
    <Modal
      open={abierto}
      onClose={onCerrar}
      title="Tu cotización"
      description={
        vendedor
          ? `Le llega a ${vendedor}, que la convierte en tu pedido.`
          : 'Le llega a tu vendedor, que la convierte en tu pedido.'
      }
      size="lg"
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onCerrar}>
            Seguir eligiendo
          </Button>
          <Button
            size="sm"
            loading={enviando}
            disabled={lineas.length === 0}
            onClick={() => void enviar()}
            iconRight={<Send className="size-4" />}
          >
            Enviar a mi vendedor
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        <ul className="divide-y divide-line overflow-hidden rounded-xl border border-line">
          {lineas.map((l) => {
            const precio = precioPorCantidad(l)
            return (
              <li
                key={l.presentacionId}
                className="flex flex-wrap items-center justify-between gap-x-3 gap-y-2 bg-surface px-3.5 py-3"
              >
                {/* En el celular el nombre va en su propia fila: si no, quedaba en "A…" junto a los botones. */}
                <div className="min-w-0 basis-full sm:flex-1 sm:basis-0">
                  <p className="line-clamp-2 font-medium text-ink">{l.producto}</p>
                  <p className="text-xs text-ink-muted">
                    {l.presentacion} · {soles(precio)} c/u
                    {precio < l.precio && (
                      <span className="ml-1 font-medium text-emerald-700">(precio por cantidad)</span>
                    )}
                  </p>
                </div>
                <div className="ml-auto flex items-center gap-2">
                  <div className="inline-flex items-center gap-1 rounded-full border border-line p-0.5">
                    <button
                      type="button"
                      className={paso}
                      onClick={() => onCantidad(l, l.cantidad - 1)}
                      aria-label={`Una ${l.presentacion} menos`}
                    >
                      <Minus className="size-4" />
                    </button>
                    <input
                      type="number"
                      inputMode="decimal"
                      min={0}
                      value={l.cantidad}
                      onChange={(e) => onCantidad(l, Math.max(0, Number(e.target.value) || 0))}
                      aria-label={`Cantidad de ${l.producto}`}
                      className="w-12 [appearance:textfield] bg-transparent text-center text-sm font-semibold outline-none [&::-webkit-inner-spin-button]:appearance-none"
                    />
                    <button
                      type="button"
                      className={paso}
                      onClick={() => onCantidad(l, l.cantidad + 1)}
                      aria-label={`Una ${l.presentacion} más`}
                    >
                      <Plus className="size-4" />
                    </button>
                  </div>
                  <p className="w-24 text-right font-semibold text-ink">{soles(l.cantidad * precio)}</p>
                  <button
                    type="button"
                    onClick={() => onCantidad(l, 0)}
                    aria-label={`Quitar ${l.producto}`}
                    className="inline-flex size-8 items-center justify-center rounded-full text-ink-soft hover:bg-rose-50 hover:text-rose-600"
                  >
                    <Trash2 className="size-4" />
                  </button>
                </div>
              </li>
            )
          })}
        </ul>

        <div className="flex items-baseline justify-between rounded-xl bg-[rgb(var(--sys-rgb)/0.06)] px-4 py-3">
          <span className="text-sm font-medium text-ink-muted">Total referencial</span>
          <span className="text-xl font-bold text-ink">{soles(total)}</span>
        </div>

        <label className="block">
          <span className="ui-label">
            Nota para tu vendedor <span className="font-normal text-ink-soft">(opcional)</span>
          </span>
          <textarea
            value={nota}
            onChange={(e) => setNota(e.target.value.slice(0, 300))}
            rows={2}
            placeholder="Para el jueves. Si no hay Primor, Cocinero."
            className="mt-1.5 w-full rounded-lg border border-line bg-surface px-3 py-2 text-sm outline-none focus:border-[rgb(var(--sys-rgb))] focus:ring-2 focus:ring-[rgb(var(--sys-rgb)/0.2)]"
          />
        </label>

        <p className="text-xs text-ink-soft">
          Los precios son referenciales: tu vendedor confirma el pedido con los precios y el stock del día.
        </p>
      </div>
    </Modal>
  )
}

function MisCotizaciones({
  cotizaciones,
  error,
  onCambio,
  alFallar,
}: {
  cotizaciones: Cotizacion[] | null
  error: string
  onCambio: () => void
  alFallar: (e: unknown, porDefecto: string) => void
}) {
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()
  const [abierta, setAbierta] = useState<number | null>(null)

  if (error) return <Alert tone="error">{error}</Alert>
  if (!cotizaciones) return <p className="text-sm text-ink-muted">Cargando tus cotizaciones…</p>
  if (cotizaciones.length === 0) {
    return (
      <div className="rounded-2xl border border-dashed border-line-strong bg-surface px-6 py-14 text-center">
        <ClipboardList className="mx-auto size-8 text-ink-soft" aria-hidden />
        <p className="mt-3 font-medium text-ink">Todavía no mandaste ninguna cotización</p>
        <p className="mt-1 text-sm text-ink-muted">Elige tus productos en el catálogo y envíala a tu vendedor.</p>
      </div>
    )
  }

  const cancelar = (c: Cotizacion) =>
    confirmar({
      titulo: `Cancelar ${c.numero}`,
      mensaje: 'Tu vendedor ya no la verá para atenderla. Puedes mandar otra cuando quieras.',
      confirmar: 'Cancelar cotización',
      cancelar: 'No, dejarla',
      tono: 'danger',
      accion: async () => {
        try {
          await portalApi.cancelar(c.id)
          toast.exito(`Cancelaste ${c.numero}`)
          onCambio()
        } catch (e) {
          alFallar(e, 'No pudimos cancelarla.')
        }
      },
    })

  return (
    <div className="space-y-3">
      {cotizaciones.map((c) => {
        const estado = ESTADO_COTIZACION[c.estado]
        const verDetalle = abierta === c.id
        return (
          <article key={c.id} className="overflow-hidden rounded-2xl border border-line bg-surface shadow-sm">
            <button
              type="button"
              onClick={() => setAbierta(verDetalle ? null : c.id)}
              className="flex w-full flex-wrap items-center justify-between gap-3 px-4 py-3.5 text-left"
            >
              <div className="min-w-0">
                <p className="flex items-center gap-2 font-semibold text-ink">
                  {c.numero} <Badge tone={estado.tono}>{estado.etiqueta}</Badge>
                </p>
                <p className="text-xs text-ink-muted">
                  {fecha(c.fecha)} · {c.detalle.length} {c.detalle.length === 1 ? 'producto' : 'productos'}
                </p>
              </div>
              <p className="text-lg font-bold text-ink">{soles(c.total)}</p>
            </button>

            {c.estado === 'ATENDIDA' && c.pedidoNumero && (
              <p className="border-t border-line bg-emerald-50 px-4 py-2 text-sm text-emerald-800">
                Tu vendedor ya la convirtió en el pedido <strong>{c.pedidoNumero}</strong>.
              </p>
            )}
            {c.estado === 'DESCARTADA' && c.motivoDescarte && (
              <p className="border-t border-line bg-rose-50 px-4 py-2 text-sm text-rose-800">
                No se atendió: {c.motivoDescarte}
              </p>
            )}

            {verDetalle && (
              <div className="space-y-3 border-t border-line px-4 py-3">
                <ul className="space-y-1.5 text-sm">
                  {c.detalle.map((l) => (
                    <li key={l.id} className="flex justify-between gap-3">
                      <span className="min-w-0 truncate text-ink">
                        {cantidadTexto(l.cantidad)} × {l.producto}{' '}
                        <span className="text-ink-muted">({l.presentacion})</span>
                      </span>
                      <span className="shrink-0 font-medium text-ink">{soles(l.subtotal)}</span>
                    </li>
                  ))}
                </ul>
                {c.nota && <p className="rounded-lg bg-surface-alt px-3 py-2 text-sm text-ink-muted">Nota: {c.nota}</p>}
                {c.estado === 'EN_ESPERA' && (
                  <Button variant="secondary" size="sm" onClick={() => cancelar(c)}>
                    Cancelar cotización
                  </Button>
                )}
              </div>
            )}
          </article>
        )
      })}
      {dialogo}
    </div>
  )
}
