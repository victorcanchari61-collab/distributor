import { useMemo, useState } from 'react'
import { Heart, ImageOff, Minus, Package, Plus, Search, SearchX, ShoppingCart, X } from 'lucide-react'
import { Alert, Desplegable, Input, Modal, cn } from '../../components/ui'
import { urlImagen } from '../tms/flotaApi'
import type { CatalogoPresentacion, CatalogoProducto, CatalogoResponse } from './catalogoApi'

const soles = (valor: number) =>
  `S/ ${valor.toLocaleString('es-PE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`

/** Cantidades sin ceros de más: 12 y no 12.000, 2.5 y no 2.500. */
const cantidad = (valor: number) => valor.toLocaleString('es-PE', { maximumFractionDigits: 3 })

/** Sin tildes ni mayúsculas, para que "azucar" encuentre "Azúcar". */
const normalizar = (texto: string) => texto.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()

/** Iniciales para el placeholder de un producto sin foto: "Aceite Primor" -> "AP". */
const iniciales = (nombre: string) =>
  nombre
    .split(/\s+/)
    .filter((p) => /^[\p{L}\p{N}]/u.test(p))
    .slice(0, 2)
    .map((p) => p[0].toUpperCase())
    .join('')

/**
 * El nombre como se lee en pantalla. Algunas presentaciones se cargaron solo con el número ("12"): sueltas no dicen
 * nada, así que se completan con la unidad ("Caja x 12").
 */
const nombrePresentacion = (pr: CatalogoPresentacion) =>
  /\p{L}/u.test(pr.nombre) ? pr.nombre : `${pr.unidad} x ${pr.nombre}`.trim()

/**
 * El carrito del portal de clientes. Sin él, la vitrina es solo de consulta (la página pública y la vista previa del
 * panel); con él, cada presentación del detalle se puede agregar y la tarjeta dice cuántas lleva.
 */
export interface CarritoCatalogo {
  /** Cuántas de esta presentación lleva ya. */
  cantidadDe: (presentacionId: number) => number
  /** Fija la cantidad de una presentación; 0 la quita. */
  fijar: (producto: CatalogoProducto, presentacion: CatalogoPresentacion, cantidad: number) => void
}

/** Los favoritos del cliente en el portal: un corazón por producto y el filtro "Mis favoritos". */
export interface FavoritosCatalogo {
  es: (productoId: number) => boolean
  alternar: (producto: CatalogoProducto) => void
  /** Si arranca mostrando solo los favoritos (cuando ya tiene alguno). */
  soloAlInicio?: boolean
}

export interface CatalogoVistaProps {
  datos: CatalogoResponse | null
  cargando: boolean
  error?: string
  carrito?: CarritoCatalogo
  favoritos?: FavoritosCatalogo
}

/**
 * La vitrina del catálogo: buscador, filtros, grilla de tarjetas y el detalle de cada producto, a la manera de una
 * tienda pero SOLO de consulta (sin carrito ni compra). La comparten la página pública y la vista previa del panel,
 * así lo que el equipo ve es exactamente lo que ve el cliente.
 */
export function CatalogoVista({ datos, cargando, error, carrito, favoritos }: CatalogoVistaProps) {
  const [busqueda, setBusqueda] = useState('')
  const [categoria, setCategoria] = useState<string | null>(null)
  const [marca, setMarca] = useState('')
  const [abierto, setAbierto] = useState<CatalogoProducto | null>(null)
  // "Mis favoritos": lo que el cliente pide siempre, sin buscarlo producto por producto.
  const [soloFavoritos, setSoloFavoritos] = useState(favoritos?.soloAlInicio ?? false)

  const productos = useMemo(() => {
    const texto = normalizar(busqueda.trim())
    return (datos?.productos ?? []).filter((p) => {
      if (soloFavoritos && favoritos && !(p.id !== undefined && favoritos.es(p.id))) return false
      if (categoria && p.categoria !== categoria) return false
      if (marca && p.marca !== marca) return false
      if (!texto) return true
      return normalizar(`${p.nombre} ${p.marca ?? ''} ${p.categoria ?? ''}`).includes(texto)
    })
  }, [datos, busqueda, categoria, marca, soloFavoritos, favoritos])

  const hayFiltros = busqueda !== '' || categoria !== null || marca !== '' || soloFavoritos
  const limpiar = () => {
    setBusqueda('')
    setCategoria(null)
    setMarca('')
    setSoloFavoritos(false)
  }

  return (
    <div className="space-y-5">
      {error && <Alert tone="error">{error}</Alert>}

      {/* Buscador y filtros: desde sm quedan pegados arriba al desplazarse; en el celular ocuparían media pantalla. */}
      <div className="-mx-1 space-y-3 px-1 py-2 sm:sticky sm:top-0 sm:z-10 sm:bg-[var(--color-surface-alt,#f8fafc)]/90 sm:backdrop-blur">
        <div className="flex flex-col gap-2 sm:flex-row">
          <Input
            buscador
            icon={<Search className="size-4" />}
            value={busqueda}
            onChange={(e) => setBusqueda(e.target.value)}
            placeholder="Buscar por nombre o marca…"
            aria-label="Buscar"
            className="flex-1"
          />
          {(datos?.marcas.length ?? 0) > 0 && (
            <Desplegable
              value={marca}
              onChange={(v) => setMarca(String(v))}
              options={[
                { value: '', label: 'Todas las marcas' },
                ...(datos?.marcas ?? []).map((m) => ({ value: m, label: m })),
              ]}
              className="sm:w-56"
            />
          )}
        </div>

        {/* Categorías: una fila que se desliza en el celular. Con favoritos, "Mis favoritos" va primero. */}
        {((datos?.categorias.length ?? 0) > 0 || favoritos) && (
          <div className="-mx-1 flex gap-2 overflow-x-auto px-1 pb-1 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
            {favoritos && (
              <Chip activo={soloFavoritos} onClick={() => setSoloFavoritos((s) => !s)}>
                <span className="inline-flex items-center gap-1.5">
                  <Heart
                    className={cn('size-4', soloFavoritos ? 'fill-white' : 'fill-rose-500 text-rose-500')}
                    aria-hidden
                  />
                  Mis favoritos
                </span>
              </Chip>
            )}
            <Chip
              activo={categoria === null && !soloFavoritos}
              onClick={() => {
                setCategoria(null)
                setSoloFavoritos(false)
              }}
            >
              Todo
            </Chip>
            {datos?.categorias.map((c) => (
              <Chip key={c} activo={categoria === c} onClick={() => setCategoria(categoria === c ? null : c)}>
                {c}
              </Chip>
            ))}
          </div>
        )}
      </div>

      {!cargando && datos && (
        <p className="flex items-center gap-2 text-sm text-ink-muted">
          <span>
            <strong className="font-semibold text-ink">{productos.length}</strong>{' '}
            {productos.length === 1 ? 'producto' : 'productos'}
          </span>
          {hayFiltros && (
            <button
              type="button"
              onClick={limpiar}
              className="inline-flex items-center gap-1 rounded-full bg-[rgb(var(--sys-rgb)/0.1)] px-2.5 py-0.5 text-xs font-medium text-[rgb(var(--sys-ink-rgb))] hover:bg-[rgb(var(--sys-rgb)/0.18)]"
            >
              <X className="size-3" /> Quitar filtros
            </button>
          )}
        </p>
      )}

      {cargando ? (
        <Esqueleto />
      ) : productos.length === 0 ? (
        soloFavoritos && !busqueda && !categoria && !marca ? (
          <SinFavoritos onVerTodo={() => setSoloFavoritos(false)} />
        ) : (
          <Vacio hayFiltros={hayFiltros} onLimpiar={limpiar} />
        )
      ) : (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-4 lg:grid-cols-4 2xl:grid-cols-5">
          {productos.map((p) => (
            <Tarjeta
              key={p.clave}
              producto={p}
              onAbrir={() => setAbierto(p)}
              enCarrito={
                carrito ? p.presentaciones.reduce((n, pr) => n + (pr.id ? carrito.cantidadDe(pr.id) : 0), 0) : 0
              }
              favoritos={favoritos}
            />
          ))}
        </div>
      )}

      <Modal
        open={abierto !== null}
        onClose={() => setAbierto(null)}
        title={abierto?.nombre ?? ''}
        description={abierto ? [abierto.marca, abierto.categoria].filter(Boolean).join(' · ') : undefined}
        size="lg"
      >
        {abierto && <Detalle producto={abierto} carrito={carrito} favoritos={favoritos} />}
      </Modal>
    </div>
  )
}

function Chip({ activo, onClick, children }: { activo: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        'shrink-0 rounded-full border px-4 py-1.5 text-sm font-medium transition',
        activo
          ? 'border-transparent bg-[rgb(var(--sys-rgb))] text-white shadow-sm'
          : 'border-line bg-surface text-ink-muted hover:border-line-strong hover:text-ink',
      )}
    >
      {children}
    </button>
  )
}

/** La foto del producto, o un placeholder con sus iniciales si no tiene o no carga. */
function Foto({ producto, className }: { producto: CatalogoProducto; className?: string }) {
  const [falla, setFalla] = useState(false)

  if (producto.foto && !falla) {
    return (
      <img
        src={urlImagen(producto.foto)}
        alt={producto.nombre}
        loading="lazy"
        onError={() => setFalla(true)}
        className={cn('size-full object-cover', className)}
      />
    )
  }

  return (
    <div
      className={cn(
        'flex size-full flex-col items-center justify-center gap-1 bg-gradient-to-br from-[rgb(var(--sys-rgb)/0.08)] via-[rgb(var(--sys-rgb)/0.14)] to-[rgb(var(--sys-rgb)/0.04)] text-[rgb(var(--sys-ink-rgb))]',
        className,
      )}
      aria-label={`${producto.nombre} (sin foto)`}
    >
      {iniciales(producto.nombre) ? (
        <span className="text-3xl font-bold tracking-tight opacity-60 sm:text-4xl">{iniciales(producto.nombre)}</span>
      ) : (
        <Package className="size-9 opacity-50" />
      )}
      <ImageOff className="size-3.5 opacity-40" />
    </div>
  )
}

/** El corazón de un producto: marcado o no. Va fuera del botón de la tarjeta (un botón no puede ir dentro de otro). */
function Corazon({
  producto,
  favoritos,
  className,
}: {
  producto: CatalogoProducto
  favoritos: FavoritosCatalogo
  className?: string
}) {
  if (producto.id === undefined) return null
  const marcado = favoritos.es(producto.id)
  return (
    <button
      type="button"
      onClick={() => favoritos.alternar(producto)}
      aria-pressed={marcado}
      aria-label={marcado ? `Quitar ${producto.nombre} de mis favoritos` : `Agregar ${producto.nombre} a mis favoritos`}
      title={marcado ? 'Quitar de mis favoritos' : 'Agregar a mis favoritos'}
      className={cn(
        'inline-flex size-9 items-center justify-center rounded-full bg-white/95 shadow-sm ring-1 ring-black/5 backdrop-blur transition hover:scale-105',
        className,
      )}
    >
      <Heart className={cn('size-[18px]', marcado ? 'fill-rose-500 text-rose-500' : 'text-ink-soft')} />
    </button>
  )
}

function Tarjeta({
  producto,
  onAbrir,
  enCarrito,
  favoritos,
}: {
  producto: CatalogoProducto
  onAbrir: () => void
  enCarrito: number
  favoritos?: FavoritosCatalogo
}) {
  const extra = producto.presentaciones.length - 2

  return (
    <div className="relative">
      {favoritos && <Corazon producto={producto} favoritos={favoritos} className="absolute top-2 right-2 z-10" />}
      <button
        type="button"
        onClick={onAbrir}
        className="group flex flex-col overflow-hidden rounded-2xl border border-line bg-surface text-left shadow-sm transition hover:-translate-y-0.5 hover:border-[rgb(var(--sys-rgb)/0.4)] hover:shadow-lg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-ring"
      >
        <div className="relative aspect-square overflow-hidden bg-surface-alt">
          <Foto producto={producto} className="transition duration-300 group-hover:scale-105" />
          {producto.categoria && (
            <span className="absolute left-2 top-2 max-w-[80%] truncate rounded-full bg-white/90 px-2.5 py-0.5 text-[11px] font-medium text-ink-muted shadow-sm backdrop-blur">
              {producto.categoria}
            </span>
          )}
          {/* En el portal: cuánto de este producto ya está en la cotización. */}
          {enCarrito > 0 && (
            <span className="absolute right-2 bottom-2 inline-flex items-center gap-1 rounded-full bg-[rgb(var(--sys-rgb))] px-2.5 py-1 text-xs font-semibold text-white shadow">
              <ShoppingCart className="size-3.5" aria-hidden />
              {cantidad(enCarrito)}
            </span>
          )}
        </div>

        <div className="flex flex-1 flex-col gap-2 p-3 sm:p-4">
          <div>
            {/* Alto fijo de dos líneas: así los precios de una fila quedan alineados aunque un nombre sea corto. */}
            <h3 className="line-clamp-2 min-h-[2.5rem] text-sm font-semibold leading-snug text-ink sm:min-h-[2.65rem] sm:text-[15px]">
              {producto.nombre}
            </h3>
            <p className="mt-0.5 h-4 truncate text-xs text-ink-muted">{producto.marca ?? ''}</p>
          </div>

          <div>
            <p className="text-[11px] uppercase tracking-wide text-ink-soft">
              {producto.presentaciones.length > 1 ? 'Desde' : 'Precio'}
            </p>
            <p className="text-lg font-bold text-ink sm:text-xl">{soles(producto.precioDesde)}</p>
          </div>

          <div className="mt-auto flex flex-wrap gap-1.5">
            {producto.presentaciones.slice(0, 2).map((pr) => (
              <span
                key={`${pr.nombre}-${pr.factor}`}
                className="max-w-full truncate rounded-md bg-[rgb(var(--sys-rgb)/0.08)] px-2 py-0.5 text-[11px] font-medium text-[rgb(var(--sys-ink-rgb))]"
              >
                {nombrePresentacion(pr)}
              </span>
            ))}
            {extra > 0 && (
              <span className="rounded-md bg-surface-alt px-2 py-0.5 text-[11px] font-medium text-ink-muted">
                +{extra}
              </span>
            )}
          </div>
        </div>
      </button>
    </div>
  )
}

function Detalle({
  producto,
  carrito,
  favoritos,
}: {
  producto: CatalogoProducto
  carrito?: CarritoCatalogo
  favoritos?: FavoritosCatalogo
}) {
  return (
    <div className="grid gap-5 sm:grid-cols-[14rem_1fr]">
      <div className="relative mx-auto aspect-square w-full max-w-[16rem] overflow-hidden rounded-2xl border border-line bg-surface-alt sm:mx-0">
        <Foto producto={producto} />
        {favoritos && <Corazon producto={producto} favoritos={favoritos} className="absolute top-2 right-2" />}
      </div>

      <div className="min-w-0 space-y-4">
        <div className="flex flex-wrap gap-1.5 text-xs">
          {producto.contenido && (
            <span className="rounded-full bg-surface-alt px-2.5 py-1 text-ink-muted">
              Contenido {producto.contenido}
            </span>
          )}
          {producto.unidadBase && (
            <span className="rounded-full bg-surface-alt px-2.5 py-1 text-ink-muted">
              Unidad base: {producto.unidadBase}
            </span>
          )}
        </div>

        {producto.descripcion && <p className="text-sm leading-relaxed text-ink-muted">{producto.descripcion}</p>}

        <div>
          <h4 className="mb-2 text-xs font-semibold uppercase tracking-wide text-ink-soft">Presentaciones y precios</h4>
          <ul className="divide-y divide-line overflow-hidden rounded-xl border border-line">
            {producto.presentaciones.map((pr) => (
              <li
                key={`${pr.nombre}-${pr.factor}`}
                className="flex items-start justify-between gap-3 bg-surface px-3.5 py-3"
              >
                <div className="min-w-0">
                  <p className="font-medium text-ink">{nombrePresentacion(pr)}</p>
                  <p className="text-xs text-ink-muted">
                    {pr.factor !== 1
                      ? `Trae ${cantidad(pr.factor)} · ${soles(pr.precioUnidadBase)} por ${producto.unidadBase.toLowerCase() || 'unidad'}`
                      : pr.unidad}
                  </p>
                  {pr.escalones.length > 0 && (
                    <ul className="mt-1.5 space-y-0.5">
                      {pr.escalones.map((e) => (
                        <li key={e.cantidadMinima} className="text-xs font-medium text-emerald-700">
                          Desde {cantidad(e.cantidadMinima)}: {soles(e.precio)} c/u
                        </li>
                      ))}
                    </ul>
                  )}
                </div>
                <div className="flex shrink-0 flex-col items-end gap-2">
                  <p className="text-lg font-bold text-ink">{soles(pr.precio)}</p>
                  {carrito && pr.id !== undefined && (
                    <Cantidad
                      valor={carrito.cantidadDe(pr.id)}
                      onCambio={(n) => carrito.fijar(producto, pr, n)}
                      nombre={nombrePresentacion(pr)}
                    />
                  )}
                </div>
              </li>
            ))}
          </ul>
        </div>
      </div>
    </div>
  )
}

/**
 * Cuánto lleva de una presentación: "Agregar" si nada, y si ya lleva, − cantidad +. Se puede escribir la cantidad
 * (diez sacos no son diez toques); vaciarla o poner 0 la quita.
 */
function Cantidad({ valor, onCambio, nombre }: { valor: number; onCambio: (n: number) => void; nombre: string }) {
  if (valor <= 0) {
    return (
      <button
        type="button"
        onClick={() => onCambio(1)}
        className="inline-flex items-center gap-1.5 rounded-full bg-[rgb(var(--sys-rgb))] px-3.5 py-1.5 text-sm font-semibold text-white shadow-sm transition hover:bg-[rgb(var(--sys-dark-rgb))]"
      >
        <Plus className="size-4" aria-hidden /> Agregar
      </button>
    )
  }

  const boton =
    'inline-flex size-8 items-center justify-center rounded-full text-[rgb(var(--sys-ink-rgb))] transition hover:bg-[rgb(var(--sys-rgb)/0.12)]'
  return (
    <div className="inline-flex items-center gap-1 rounded-full border border-[rgb(var(--sys-rgb)/0.4)] bg-[rgb(var(--sys-rgb)/0.06)] p-0.5">
      <button type="button" className={boton} onClick={() => onCambio(valor - 1)} aria-label={`Una ${nombre} menos`}>
        <Minus className="size-4" />
      </button>
      <input
        type="number"
        inputMode="decimal"
        min={0}
        value={valor}
        onChange={(e) => onCambio(Math.max(0, Number(e.target.value) || 0))}
        aria-label={`Cantidad de ${nombre}`}
        className="w-12 [appearance:textfield] bg-transparent text-center text-sm font-semibold text-ink outline-none [&::-webkit-inner-spin-button]:appearance-none"
      />
      <button type="button" className={boton} onClick={() => onCambio(valor + 1)} aria-label={`Una ${nombre} más`}>
        <Plus className="size-4" />
      </button>
    </div>
  )
}

function SinFavoritos({ onVerTodo }: { onVerTodo: () => void }) {
  return (
    <div className="flex flex-col items-center gap-3 rounded-2xl border border-dashed border-line-strong bg-surface px-6 py-16 text-center">
      <span className="inline-flex size-14 items-center justify-center rounded-full bg-rose-50 text-rose-500">
        <Heart className="size-6" />
      </span>
      <p className="font-medium text-ink">Todavía no tienes favoritos</p>
      <p className="max-w-sm text-sm text-ink-muted">
        Toca el corazón de lo que pides siempre: aquí te quedan juntos para armar tu cotización rápido.
      </p>
      <button
        type="button"
        onClick={onVerTodo}
        className="rounded-full bg-[rgb(var(--sys-rgb))] px-4 py-1.5 text-sm font-medium text-white"
      >
        Ver todo el catálogo
      </button>
    </div>
  )
}

function Esqueleto() {
  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-4 lg:grid-cols-4 2xl:grid-cols-5" aria-busy="true">
      {Array.from({ length: 10 }, (_, i) => (
        <div key={i} className="animate-pulse overflow-hidden rounded-2xl border border-line bg-surface">
          <div className="aspect-square bg-surface-alt" />
          <div className="space-y-2.5 p-4">
            <div className="h-3.5 w-4/5 rounded bg-surface-alt" />
            <div className="h-3 w-1/3 rounded bg-surface-alt" />
            <div className="h-5 w-1/2 rounded bg-surface-alt" />
          </div>
        </div>
      ))}
    </div>
  )
}

function Vacio({ hayFiltros, onLimpiar }: { hayFiltros: boolean; onLimpiar: () => void }) {
  return (
    <div className="flex flex-col items-center gap-3 rounded-2xl border border-dashed border-line-strong bg-surface px-6 py-16 text-center">
      <span className="inline-flex size-14 items-center justify-center rounded-full bg-surface-alt text-ink-soft">
        {hayFiltros ? <SearchX className="size-6" /> : <Package className="size-6" />}
      </span>
      <p className="font-medium text-ink">
        {hayFiltros ? 'No hay productos con esos filtros' : 'Todavía no hay productos en el catálogo'}
      </p>
      <p className="max-w-sm text-sm text-ink-muted">
        {hayFiltros
          ? 'Prueba con otra palabra o quita algún filtro.'
          : 'Aparecen aquí los productos activos que se venden y tienen precio.'}
      </p>
      {hayFiltros && (
        <button
          type="button"
          onClick={onLimpiar}
          className="rounded-full bg-[rgb(var(--sys-rgb))] px-4 py-1.5 text-sm font-medium text-white"
        >
          Quitar filtros
        </button>
      )}
    </div>
  )
}
