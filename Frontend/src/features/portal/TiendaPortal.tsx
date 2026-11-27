import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import type { FormEvent, ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  ChevronDown,
  ClipboardList,
  Heart,
  KeyRound,
  LogOut,
  Minus,
  Phone,
  Plus,
  Send,
  ShoppingCart,
  Store,
  Trash2,
  UserRound,
} from 'lucide-react'
import { Alert, Badge, Button, Input, Logo, Modal, cn, useConfirmacion, useToast } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { Cantidad, CatalogoVista, Foto, nombrePresentacion } from '../maestros/CatalogoVista'
import type { CarritoCatalogo, FavoritosCatalogo } from '../maestros/CatalogoVista'
import type { CatalogoPresentacion, CatalogoProducto, CatalogoResponse } from '../maestros/catalogoApi'
import { ESTADO_COTIZACION, RUTA_PORTAL, portalApi } from './portalApi'
import type { Cotizacion, PortalCliente, PortalSesion, SeccionPortal } from './portalApi'

const soles = (valor: number) =>
  `S/ ${valor.toLocaleString('es-PE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`

const cantidadTexto = (valor: number) => valor.toLocaleString('es-PE', { maximumFractionDigits: 3 })

const fecha = (iso: string) =>
  new Date(iso).toLocaleString('es-PE', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' })

const mensaje = (e: unknown, porDefecto: string) => (e instanceof ApiError ? e.message : porDefecto)

const rutaDe = (s: SeccionPortal) => (s === 'catalogo' ? RUTA_PORTAL : `${RUTA_PORTAL}/${s}`)

// ================================================================ Carrito

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

const lineaDe = (producto: CatalogoProducto, pr: CatalogoPresentacion): Omit<LineaCarrito, 'cantidad'> => ({
  presentacionId: pr.id!,
  producto: producto.nombre,
  presentacion: nombrePresentacion(pr),
  precio: pr.precio,
  escalones: pr.escalones,
})

/** El carrito se recuerda en el celular, por cuenta: si cierra la página, al volver sigue ahí. */
function useCarrito(clave: string) {
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

// ================================================================= Tienda

/**
 * El portal con sesión, armado como una tienda chica: arriba la navegación (Catálogo, Favoritos, Mis cotizaciones),
 * el carrito con su contador y el menú de la cuenta; en el celular, una barra fija abajo con lo mismo. El carrito es
 * una ventana que se abre desde cualquier página.
 */
export function TiendaPortal({
  sesion,
  seccion,
  onSalir,
  onSesion,
}: {
  sesion: PortalSesion
  seccion: SeccionPortal
  onSalir: () => void
  /** El servidor dio una sesión nueva (cambió el usuario o la contraseña): se guarda sin salir. */
  onSesion: (nueva: PortalSesion) => void
}) {
  const toast = useToast()
  const navigate = useNavigate()
  const ir = useCallback((s: SeccionPortal) => navigate(rutaDe(s)), [navigate])

  const [catalogo, setCatalogo] = useState<CatalogoResponse | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [favoritos, setFavoritos] = useState<number[]>([])
  const [cotizaciones, setCotizaciones] = useState<Cotizacion[] | null>(null)
  const [carritoAbierto, setCarritoAbierto] = useState(false)
  // El carrito es de la cuenta y no del usuario: cambiar de usuario no lo vacía.
  const { lineas, fijar, vaciar } = useCarrito(`distribuidora.portal.carrito.${sesion.cliente.documento}`)

  // Una sesión que el servidor ya no acepta (contraseña cambiada en otro celular, acceso apagado) pide entrar de nuevo.
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
    if (seccion === 'cotizaciones') cargarCotizaciones()
  }, [seccion, cargarCotizaciones])

  const carrito: CarritoCatalogo = useMemo(
    () => ({
      cantidadDe: (id) => lineas.find((l) => l.presentacionId === id)?.cantidad ?? 0,
      fijar: (producto, pr, cantidad) => pr.id !== undefined && fijar(lineaDe(producto, pr), cantidad),
    }),
    [lineas, fijar],
  )

  // El corazón responde al toque; si el servidor no lo guarda, vuelve como estaba.
  const favoritosCatalogo: FavoritosCatalogo = useMemo(
    () => ({
      es: (id) => favoritos.includes(id),
      alternar: (_producto, presentacion) => {
        if (presentacion.id === undefined) return
        const id = presentacion.id
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
  const abrirCarrito = () => setCarritoAbierto(true)

  let pagina: ReactNode
  if (seccion === 'favoritos') {
    pagina = (
      <PaginaFavoritos
        catalogo={catalogo}
        cargando={cargando}
        error={error}
        favoritos={favoritos}
        carrito={carrito}
        favoritosCatalogo={favoritosCatalogo}
        onVerCatalogo={() => ir('catalogo')}
      />
    )
  } else if (seccion === 'cotizaciones') {
    pagina = (
      <MisCotizaciones
        cotizaciones={cotizaciones}
        error={error}
        onCambio={cargarCotizaciones}
        alFallar={alFallar}
        onVerCatalogo={() => ir('catalogo')}
      />
    )
  } else if (seccion === 'perfil') {
    pagina = <PaginaPerfil sesion={sesion} onSesion={onSesion} onSalir={onSalir} alFallar={alFallar} />
  } else {
    pagina = (
      <div className="space-y-4">
        <Encabezado
          titulo="Catálogo"
          detalle="Elige lo que necesitas y arma tu cotización. Los precios son los tuyos."
        />
        <CatalogoVista
          datos={catalogo}
          cargando={cargando}
          error={error}
          carrito={carrito}
          favoritos={favoritosCatalogo}
        />
      </div>
    )
  }

  return (
    <div data-sys="fact" className="min-h-screen bg-surface-alt">
      <Cabecera
        cliente={sesion.cliente}
        seccion={seccion}
        enCarrito={lineas.length}
        favoritos={favoritos.length}
        onIr={ir}
        onCarrito={abrirCarrito}
        onSalir={onSalir}
      />

      {/* Abajo deja sitio a la barra del carrito y, en el celular, a la navegación. */}
      <main
        className={cn('mx-auto max-w-6xl px-4 py-5 sm:px-6', lineas.length > 0 ? 'pb-44 md:pb-28' : 'pb-24 md:pb-8')}
      >
        {pagina}
      </main>

      {/* El total, siempre a mano mientras haya algo en el carrito. */}
      {lineas.length > 0 && (
        <div className="fixed inset-x-0 bottom-16 z-30 border-t border-line bg-surface/95 px-4 py-2.5 shadow-[0_-4px_16px_rgba(0,0,0,0.06)] backdrop-blur md:bottom-0 md:py-3">
          <div className="mx-auto flex max-w-6xl items-center justify-between gap-3">
            <div className="min-w-0">
              <p className="text-xs text-ink-muted">
                {lineas.length} {lineas.length === 1 ? 'producto' : 'productos'} en tu cotización
              </p>
              <p className="text-lg font-bold text-ink">{soles(total)}</p>
            </div>
            <Button onClick={abrirCarrito} iconRight={<ShoppingCart className="size-4" />}>
              Ver mi cotización
            </Button>
          </div>
        </div>
      )}

      <BarraInferior seccion={seccion} enCarrito={lineas.length} onIr={ir} onCarrito={abrirCarrito} />

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
          ir('cotizaciones')
          cargarCotizaciones()
        }}
        alFallar={alFallar}
      />

      {/* Los modales se montan aquí: dentro del data-sys, con el color del portal. */}
      <div id="modal-root" />
    </div>
  )
}

// ============================================================ Navegación

const NAVEGACION: { id: Exclude<SeccionPortal, 'perfil'>; etiqueta: string; icono: typeof Store }[] = [
  { id: 'catalogo', etiqueta: 'Catálogo', icono: Store },
  { id: 'favoritos', etiqueta: 'Favoritos', icono: Heart },
  { id: 'cotizaciones', etiqueta: 'Mis cotizaciones', icono: ClipboardList },
]

/** Un número sobre un ícono: lo que hay en el carrito. */
function Contador({ n }: { n: number }) {
  if (n <= 0) return null
  return (
    <span className="absolute -top-1.5 -right-1.5 flex h-5 min-w-5 items-center justify-center rounded-full bg-rose-500 px-1 text-[11px] font-bold leading-none text-white ring-2 ring-white">
      {n > 99 ? '99+' : n}
    </span>
  )
}

function Cabecera({
  cliente,
  seccion,
  enCarrito,
  favoritos,
  onIr,
  onCarrito,
  onSalir,
}: {
  cliente: PortalCliente
  seccion: SeccionPortal
  enCarrito: number
  favoritos: number
  onIr: (s: SeccionPortal) => void
  onCarrito: () => void
  onSalir: () => void
}) {
  const [menu, setMenu] = useState(false)
  const caja = useRef<HTMLDivElement>(null)

  // El menú de la cuenta se cierra al tocar fuera.
  useEffect(() => {
    if (!menu) return
    const fuera = (e: PointerEvent) => {
      if (!caja.current?.contains(e.target as Node)) setMenu(false)
    }
    window.addEventListener('pointerdown', fuera)
    return () => window.removeEventListener('pointerdown', fuera)
  }, [menu])

  return (
    <header className="sticky top-0 z-40 bg-gradient-to-br from-navy to-navy-deep text-white shadow-sm">
      <div className="mx-auto flex max-w-6xl items-center gap-3 px-4 py-3 sm:px-6">
        <button type="button" onClick={() => onIr('catalogo')} className="flex min-w-0 items-center gap-3 text-left">
          <Logo variant="emblem" size={38} className="shrink-0" />
          <div className="min-w-0">
            <p className="truncate text-base font-bold leading-tight">{cliente.empresa}</p>
            <p className="truncate text-xs text-white/75">{cliente.nombre}</p>
          </div>
        </button>

        <nav aria-label="Secciones" className="ml-6 hidden flex-1 items-center gap-1 md:flex">
          {NAVEGACION.map(({ id, etiqueta, icono: Icono }) => (
            <button
              key={id}
              type="button"
              onClick={() => onIr(id)}
              aria-current={seccion === id ? 'page' : undefined}
              className={cn(
                'inline-flex items-center gap-1.5 rounded-full px-3.5 py-2 text-sm font-semibold transition',
                seccion === id ? 'bg-white text-navy' : 'text-white/85 hover:bg-white/10 hover:text-white',
              )}
            >
              <Icono className="size-4" aria-hidden />
              {etiqueta}
              {id === 'favoritos' && favoritos > 0 && (
                <span className={cn('text-xs', seccion === id ? 'text-navy/60' : 'text-white/60')}>{favoritos}</span>
              )}
            </button>
          ))}
        </nav>

        <div className="ml-auto flex items-center gap-2">
          <button
            type="button"
            onClick={onCarrito}
            aria-label={`Ver mi cotización (${enCarrito} productos)`}
            className="relative inline-flex size-10 items-center justify-center rounded-full bg-white/10 ring-1 ring-white/20 transition hover:bg-white/20"
          >
            <ShoppingCart className="size-5" />
            <Contador n={enCarrito} />
          </button>

          <div ref={caja} className="relative hidden md:block">
            <button
              type="button"
              onClick={() => setMenu((m) => !m)}
              aria-expanded={menu}
              className="inline-flex items-center gap-2 rounded-full bg-white/10 py-1 pr-3 pl-1 ring-1 ring-white/20 transition hover:bg-white/20"
            >
              <span className="flex size-8 items-center justify-center rounded-full bg-white text-sm font-bold text-navy">
                {cliente.nombre.trim().charAt(0).toUpperCase()}
              </span>
              <span className="max-w-32 truncate text-sm font-medium">{cliente.usuario}</span>
              <ChevronDown className="size-4 opacity-75" />
            </button>
            {menu && (
              <div className="absolute right-0 mt-2 w-56 overflow-hidden rounded-xl border border-line bg-surface text-ink shadow-lg">
                <div className="border-b border-line px-4 py-3">
                  <p className="truncate text-sm font-semibold">{cliente.nombre}</p>
                  <p className="truncate text-xs text-ink-muted">Usuario: {cliente.usuario}</p>
                </div>
                <button
                  type="button"
                  onClick={() => {
                    setMenu(false)
                    onIr('perfil')
                  }}
                  className="flex w-full items-center gap-2 px-4 py-2.5 text-left text-sm hover:bg-surface-alt"
                >
                  <UserRound className="size-4 text-ink-muted" /> Mi perfil
                </button>
                <button
                  type="button"
                  onClick={onSalir}
                  className="flex w-full items-center gap-2 px-4 py-2.5 text-left text-sm text-rose-600 hover:bg-rose-50"
                >
                  <LogOut className="size-4" /> Salir
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
  )
}

/** En el celular: la navegación abajo, al alcance del pulgar, como en las apps de compras. */
function BarraInferior({
  seccion,
  enCarrito,
  onIr,
  onCarrito,
}: {
  seccion: SeccionPortal
  enCarrito: number
  onIr: (s: SeccionPortal) => void
  onCarrito: () => void
}) {
  const boton = (activo: boolean) =>
    cn(
      'relative flex flex-1 flex-col items-center gap-0.5 py-2 text-[11px] font-medium transition',
      activo ? 'text-[rgb(var(--sys-ink-rgb))]' : 'text-ink-soft',
    )
  return (
    <nav
      aria-label="Secciones"
      className="fixed inset-x-0 bottom-0 z-40 flex h-16 border-t border-line bg-surface pb-[env(safe-area-inset-bottom)] md:hidden"
    >
      <button type="button" className={boton(seccion === 'catalogo')} onClick={() => onIr('catalogo')}>
        <Store className="size-5" /> Catálogo
      </button>
      <button type="button" className={boton(seccion === 'favoritos')} onClick={() => onIr('favoritos')}>
        <Heart className="size-5" /> Favoritos
      </button>
      <button type="button" className={boton(false)} onClick={onCarrito}>
        <span className="relative">
          <ShoppingCart className="size-5" />
          <Contador n={enCarrito} />
        </span>
        Carrito
      </button>
      <button type="button" className={boton(seccion === 'cotizaciones')} onClick={() => onIr('cotizaciones')}>
        <ClipboardList className="size-5" /> Cotizaciones
      </button>
      <button type="button" className={boton(seccion === 'perfil')} onClick={() => onIr('perfil')}>
        <UserRound className="size-5" /> Perfil
      </button>
    </nav>
  )
}

function Encabezado({ titulo, detalle, accion }: { titulo: string; detalle?: string; accion?: ReactNode }) {
  return (
    <div className="flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 className="text-xl font-bold text-ink sm:text-2xl">{titulo}</h1>
        {detalle && <p className="mt-0.5 text-sm text-ink-muted">{detalle}</p>}
      </div>
      {accion}
    </div>
  )
}

// ============================================================= Favoritos

/**
 * Lo que el cliente pide siempre, como una lista de pedido rápido: cada presentación con su cantidad ahí mismo, sin
 * abrir producto por producto. Para la cotización de cada semana.
 */
function PaginaFavoritos({
  catalogo,
  cargando,
  error,
  favoritos,
  carrito,
  favoritosCatalogo,
  onVerCatalogo,
}: {
  catalogo: CatalogoResponse | null
  cargando: boolean
  error: string
  favoritos: number[]
  carrito: CarritoCatalogo
  favoritosCatalogo: FavoritosCatalogo
  onVerCatalogo: () => void
}) {
  // Las presentaciones marcadas, agrupadas bajo su producto, en el orden en que las marcó (el producto va donde está
  // la primera que marcó de él). Una que dejó de venderse ya no está en el catálogo y no se muestra.
  const productos: { producto: CatalogoProducto; presentaciones: CatalogoPresentacion[] }[] = []
  for (const id of favoritos) {
    const producto = catalogo?.productos.find((p) => p.presentaciones.some((pr) => pr.id === id))
    const presentacion = producto?.presentaciones.find((pr) => pr.id === id)
    if (!producto || !presentacion) continue
    const grupo = productos.find((g) => g.producto.clave === producto.clave)
    if (grupo) grupo.presentaciones.push(presentacion)
    else productos.push({ producto, presentaciones: [presentacion] })
  }

  return (
    <div className="space-y-4">
      <Encabezado
        titulo="Mis favoritos"
        detalle="Lo que pides siempre. Pon las cantidades aquí mismo y envía tu cotización."
      />
      {error && <Alert tone="error">{error}</Alert>}

      {cargando ? (
        <p className="text-sm text-ink-muted">Cargando…</p>
      ) : productos.length === 0 ? (
        <div className="flex flex-col items-center gap-3 rounded-2xl border border-dashed border-line-strong bg-surface px-6 py-14 text-center">
          <span className="inline-flex size-14 items-center justify-center rounded-full bg-rose-50 text-rose-500">
            <Heart className="size-6" />
          </span>
          <p className="font-medium text-ink">Todavía no tienes favoritos</p>
          <p className="max-w-sm text-sm text-ink-muted">
            En el catálogo, toca el corazón de lo que pides siempre: aquí te quedan juntos para cotizar rápido.
          </p>
          <Button size="sm" onClick={onVerCatalogo} iconRight={<Store className="size-4" />}>
            Ir al catálogo
          </Button>
        </div>
      ) : (
        <ul className="space-y-3">
          {productos.map(({ producto: p, presentaciones }) => (
            <li key={p.clave} className="overflow-hidden rounded-2xl border border-line bg-surface shadow-sm">
              <div className="flex items-center gap-3 p-3">
                <div className="size-16 shrink-0 overflow-hidden rounded-xl bg-surface-alt">
                  <Foto producto={p} />
                </div>
                <div className="min-w-0 flex-1">
                  <p className="line-clamp-2 font-semibold text-ink">{p.nombre}</p>
                  <p className="truncate text-xs text-ink-muted">
                    {[p.marca, p.categoria].filter(Boolean).join(' · ')}
                  </p>
                </div>
              </div>
              <ul className="divide-y divide-line border-t border-line">
                {presentaciones.map((pr) => (
                  <li key={pr.id} className="flex flex-wrap items-center justify-between gap-x-3 gap-y-2 px-3 py-2.5">
                    <div className="flex min-w-0 items-center gap-2">
                      <button
                        type="button"
                        onClick={() => favoritosCatalogo.alternar(p, pr)}
                        aria-label={`Quitar ${p.nombre} (${nombrePresentacion(pr)}) de mis favoritos`}
                        title="Quitar de mis favoritos"
                        className="inline-flex size-8 shrink-0 items-center justify-center rounded-full hover:bg-rose-50"
                      >
                        <Heart className="size-[18px] fill-rose-500 text-rose-500" />
                      </button>
                      <div className="min-w-0">
                        <p className="text-sm font-medium text-ink">{nombrePresentacion(pr)}</p>
                        <p className="text-xs text-ink-muted">
                          {soles(pr.precio)}
                          {pr.escalones.length > 0 && (
                            <span className="ml-1 text-emerald-700">
                              · desde {cantidadTexto(pr.escalones[0].cantidadMinima)}: {soles(pr.escalones[0].precio)}
                            </span>
                          )}
                        </p>
                      </div>
                    </div>
                    <Cantidad
                      valor={carrito.cantidadDe(pr.id!)}
                      onCambio={(n) => carrito.fijar(p, pr, n)}
                      nombre={nombrePresentacion(pr)}
                    />
                  </li>
                ))}
              </ul>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

// ================================================================ Perfil

function PaginaPerfil({
  sesion,
  onSesion,
  onSalir,
  alFallar,
}: {
  sesion: PortalSesion
  onSesion: (nueva: PortalSesion) => void
  onSalir: () => void
  alFallar: (e: unknown, porDefecto: string) => void
}) {
  const toast = useToast()
  const [datos, setDatos] = useState<PortalCliente>(sesion.cliente)

  // Lo último del servidor (si el vendedor cambió su teléfono o su ruta, aquí se ve).
  useEffect(() => {
    portalApi
      .yo()
      .then(setDatos)
      .catch((e) => alFallar(e, 'No pudimos cargar tus datos.'))
  }, [alFallar])

  const [usuario, setUsuario] = useState(sesion.cliente.usuario)
  const [claveUsuario, setClaveUsuario] = useState('')
  const [guardandoUsuario, setGuardandoUsuario] = useState(false)

  const [actual, setActual] = useState('')
  const [nueva, setNueva] = useState('')
  const [repetir, setRepetir] = useState('')
  const [guardandoClave, setGuardandoClave] = useState(false)

  const cambiarUsuario = async (e: FormEvent) => {
    e.preventDefault()
    setGuardandoUsuario(true)
    try {
      const s = await portalApi.cambiarUsuario({ usuario, passwordActual: claveUsuario })
      onSesion(s)
      setDatos(s.cliente)
      setUsuario(s.cliente.usuario)
      setClaveUsuario('')
      toast.exito(`Listo: ahora entras como ${s.cliente.usuario}`)
    } catch (err) {
      toast.error(mensaje(err, 'No pudimos cambiar tu usuario.'))
    } finally {
      setGuardandoUsuario(false)
    }
  }

  const cambiarClave = async (e: FormEvent) => {
    e.preventDefault()
    if (nueva !== repetir) return toast.error('Las dos contraseñas nuevas no son iguales.')
    setGuardandoClave(true)
    try {
      onSesion(await portalApi.cambiarPassword({ passwordActual: actual, passwordNueva: nueva }))
      setActual('')
      setNueva('')
      setRepetir('')
      toast.exito('Contraseña cambiada. En otros celulares tendrás que entrar de nuevo.')
    } catch (err) {
      toast.error(mensaje(err, 'No pudimos cambiar tu contraseña.'))
    } finally {
      setGuardandoClave(false)
    }
  }

  const fila = (etiqueta: string, valor: ReactNode) => (
    <div className="flex justify-between gap-4 py-2 text-sm">
      <dt className="text-ink-muted">{etiqueta}</dt>
      <dd className="text-right font-medium text-ink">{valor}</dd>
    </div>
  )

  return (
    <div className="space-y-4">
      <Encabezado titulo="Mi perfil" />

      <div className="grid gap-4 lg:grid-cols-2">
        <section className="rounded-2xl border border-line bg-surface p-5 shadow-sm">
          <h2 className="flex items-center gap-2 font-semibold text-ink">
            <Store className="size-4 text-[rgb(var(--sys-rgb))]" /> Tu negocio
          </h2>
          <dl className="mt-2 divide-y divide-line">
            {fila('Nombre', datos.nombre)}
            {fila('DNI / RUC', datos.documento)}
            {fila('Dirección', datos.direccion ?? '—')}
            {fila('Teléfono (WhatsApp)', datos.telefono ?? '—')}
            {fila('Tu vendedor', datos.vendedor ?? 'Sin asignar')}
            {datos.telefonoVendedor &&
              fila(
                'Llamar a tu vendedor',
                <a
                  href={`tel:${datos.telefonoVendedor.replace(/[^\d+]/g, '')}`}
                  className="inline-flex items-center gap-1 text-[rgb(var(--sys-ink-rgb))] hover:underline"
                >
                  <Phone className="size-3.5" /> {datos.telefonoVendedor}
                </a>,
              )}
            {datos.telefonoEmpresa &&
              fila(
                datos.empresa,
                <a
                  href={`tel:${datos.telefonoEmpresa.replace(/[^\d+]/g, '')}`}
                  className="inline-flex items-center gap-1 text-[rgb(var(--sys-ink-rgb))] hover:underline"
                >
                  <Phone className="size-3.5" /> {datos.telefonoEmpresa}
                </a>,
              )}
          </dl>
          <p className="mt-3 text-xs text-ink-soft">
            Para cambiar tu dirección o tu teléfono habla con tu vendedor: a ese número te llega el enlace si olvidas tu
            contraseña.
          </p>
        </section>

        <div className="space-y-4">
          <section className="rounded-2xl border border-line bg-surface p-5 shadow-sm">
            <h2 className="flex items-center gap-2 font-semibold text-ink">
              <UserRound className="size-4 text-[rgb(var(--sys-rgb))]" /> Cambiar usuario
            </h2>
            <form onSubmit={(e) => void cambiarUsuario(e)} className="mt-3 space-y-3">
              <div>
                <Input
                  label="Usuario nuevo"
                  value={usuario}
                  onChange={(e) => setUsuario(e.target.value.toLowerCase().replace(/\s/g, ''))}
                  autoCapitalize="none"
                  autoComplete="username"
                />
                <p className="mt-1 text-xs text-ink-soft">
                  De 4 a 30 letras o números, sin espacios. También puedes entrar con tu DNI/RUC.
                </p>
              </div>
              <Input
                label="Tu contraseña actual"
                type="password"
                revealable
                value={claveUsuario}
                onChange={(e) => setClaveUsuario(e.target.value)}
                autoComplete="current-password"
              />
              <Button
                type="submit"
                size="sm"
                loading={guardandoUsuario}
                disabled={!claveUsuario || !usuario.trim() || usuario === datos.usuario}
              >
                Guardar usuario
              </Button>
            </form>
          </section>

          <section className="rounded-2xl border border-line bg-surface p-5 shadow-sm">
            <h2 className="flex items-center gap-2 font-semibold text-ink">
              <KeyRound className="size-4 text-[rgb(var(--sys-rgb))]" /> Cambiar contraseña
            </h2>
            <form onSubmit={(e) => void cambiarClave(e)} className="mt-3 space-y-3">
              <Input
                label="Contraseña actual"
                type="password"
                revealable
                value={actual}
                onChange={(e) => setActual(e.target.value)}
                autoComplete="current-password"
              />
              <Input
                label="Contraseña nueva"
                hint="Al menos 6 caracteres."
                type="password"
                revealable
                value={nueva}
                onChange={(e) => setNueva(e.target.value)}
                autoComplete="new-password"
              />
              <Input
                label="Repite la contraseña nueva"
                type="password"
                revealable
                value={repetir}
                onChange={(e) => setRepetir(e.target.value)}
                autoComplete="new-password"
              />
              <Button type="submit" size="sm" loading={guardandoClave} disabled={!actual || !nueva || !repetir}>
                Guardar contraseña
              </Button>
            </form>
          </section>
        </div>
      </div>

      <Button variant="secondary" onClick={onSalir} iconRight={<LogOut className="size-4" />}>
        Cerrar sesión
      </Button>
    </div>
  )
}

// ================================================================ Carrito

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
        detalle: lineas.map((l) => ({ presentacionId: l.presentacionId, cantidad: l.cantidad })),
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
      {lineas.length === 0 ? (
        <div className="flex flex-col items-center gap-2 py-8 text-center">
          <ShoppingCart className="size-8 text-ink-soft" aria-hidden />
          <p className="font-medium text-ink">Tu cotización está vacía</p>
          <p className="text-sm text-ink-muted">Agrega productos desde el catálogo o desde tus favoritos.</p>
        </div>
      ) : (
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
      )}
    </Modal>
  )
}

// ======================================================= Mis cotizaciones

function MisCotizaciones({
  cotizaciones,
  error,
  onCambio,
  alFallar,
  onVerCatalogo,
}: {
  cotizaciones: Cotizacion[] | null
  error: string
  onCambio: () => void
  alFallar: (e: unknown, porDefecto: string) => void
  onVerCatalogo: () => void
}) {
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()
  const [abierta, setAbierta] = useState<number | null>(null)

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

  let contenido: ReactNode
  if (error) contenido = <Alert tone="error">{error}</Alert>
  else if (!cotizaciones) contenido = <p className="text-sm text-ink-muted">Cargando tus cotizaciones…</p>
  else if (cotizaciones.length === 0) {
    contenido = (
      <div className="flex flex-col items-center gap-3 rounded-2xl border border-dashed border-line-strong bg-surface px-6 py-14 text-center">
        <ClipboardList className="size-8 text-ink-soft" aria-hidden />
        <p className="font-medium text-ink">Todavía no mandaste ninguna cotización</p>
        <p className="text-sm text-ink-muted">Elige tus productos en el catálogo y envíala a tu vendedor.</p>
        <Button size="sm" onClick={onVerCatalogo} iconRight={<Store className="size-4" />}>
          Ir al catálogo
        </Button>
      </div>
    )
  } else {
    contenido = (
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
                  {c.nota && (
                    <p className="rounded-lg bg-surface-alt px-3 py-2 text-sm text-ink-muted">Nota: {c.nota}</p>
                  )}
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
      </div>
    )
  }

  return (
    <div className="space-y-4">
      <Encabezado titulo="Mis cotizaciones" detalle="Toca una para ver su detalle." />
      {contenido}
      {dialogo}
    </div>
  )
}
