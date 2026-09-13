import { useEffect, useMemo, useState } from 'react'
import { Package, RotateCcw, Search, SlidersHorizontal } from 'lucide-react'
import { cn } from './cn'
import { Button } from './Button'
import { Desplegable } from './Desplegable'
import { Input } from './Input'
import { Modal } from './Modal'

/** Lo mínimo de un producto que este buscador necesita para funcionar. */
export interface ProductoBuscable {
  id: number
  codigo: string
  nombre: string
  descripcion: string | null
  categoria?: string | null
  marca?: string | null
  unidadBase: string
  costoReferencia: number | null
  stockMinimo?: number
  presentaciones: {
    id: number
    nombre: string
    factor: number
    esBase: boolean
    activo: boolean
  }[]
}

/** Una elección del buscador: el producto, la presentación y la cantidad marcada. */
export interface SeleccionProducto {
  producto: ProductoBuscable
  presentacionId: number
  cantidad: number
}

export interface BuscadorProductoModalProps {
  open: boolean
  onClose: () => void
  productos: ProductoBuscable[]
  /** Stock actual por producto, en unidad base — se pinta como badge de color y habilita los filtros de stock. */
  stock?: Record<number, number>
  /** Se llama una sola vez con todo lo marcado al pulsar "Agregar". */
  onAgregar: (selecciones: SeleccionProducto[]) => void
}

const FILTROS_VACIOS = { texto: '', categoria: '', marca: '', stockEstado: '', stockHasta: '' }

const ESTADO_STOCK_OPTIONS = [
  { value: 'con', label: 'Con stock' },
  { value: 'sin', label: 'Sin stock' },
]

/** Sin acentos y en minúsculas, para que "nunez" encuentre "Nuñez". */
const normalizar = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()

/** Opciones únicas de un campo del producto, para llenar un filtro. */
function opcionesDe(productos: ProductoBuscable[], campo: 'categoria' | 'marca') {
  const valores = new Set(productos.map((p) => p[campo]).filter((v): v is string => Boolean(v)))
  return [...valores].sort((a, b) => a.localeCompare(b, 'es'))
}

/**
 * Buscar productos en una lista de tarjetas marcables — se eligen varios a la
 * vez (cada uno con su unidad y cantidad) y se agregan todos juntos, en vez de
 * abrir el buscador una vez por producto.
 */
export function BuscadorProductoModal({ open, onClose, productos, stock, onAgregar }: BuscadorProductoModalProps) {
  const [filtros, setFiltros] = useState(FILTROS_VACIOS)
  /*
   * Los filtros salen plegados.
   *
   * Son cuatro controles y la lista es a lo que se viene: desplegados le
   * comian media pantalla al buscador. El boton lleva cuantos hay puestos,
   * para no tener que abrirlo solo para comprobarlo.
   */
  const [filtrosAbiertos, setFiltrosAbiertos] = useState(false)
  /** Marcados: { [productoId]: true } */
  const [marcados, setMarcados] = useState<Record<number, true>>({})
  /** Unidad elegida por fila: { [productoId]: presentacionId } — 0 = unidad base. */
  const [unidades, setUnidades] = useState<Record<number, number>>({})
  /** Cantidad escrita por fila: { [productoId]: '3' } */
  const [cantidades, setCantidades] = useState<Record<number, string>>({})

  useEffect(() => {
    if (open) {
      setFiltros(FILTROS_VACIOS)
      setMarcados({})
      setUnidades({})
      setCantidades({})
    }
  }, [open])

  const setFiltro = (patch: Partial<typeof FILTROS_VACIOS>) => setFiltros((prev) => ({ ...prev, ...patch }))

  const categorias = useMemo(() => opcionesDe(productos, 'categoria'), [productos])
  const marcas = useMemo(() => opcionesDe(productos, 'marca'), [productos])

  const resultados = useMemo(() => {
    const term = normalizar(filtros.texto.trim())
    return productos.filter((p) => {
      if (filtros.categoria && p.categoria !== filtros.categoria) return false
      if (filtros.marca && p.marca !== filtros.marca) return false

      if (filtros.stockEstado || filtros.stockHasta !== '') {
        const cantidad = stock?.[p.id] ?? 0
        if (filtros.stockEstado === 'con' && cantidad <= 0) return false
        if (filtros.stockEstado === 'sin' && cantidad > 0) return false
        // "Stock hasta 10" = de 10 hacia abajo, incluyendo 0.
        if (filtros.stockHasta !== '' && cantidad > Number(filtros.stockHasta)) return false
      }

      if (!term) return true
      return normalizar(`${p.nombre} ${p.codigo} ${p.categoria ?? ''} ${p.marca ?? ''}`).includes(term)
    })
  }, [productos, filtros, stock])

  const filtrosActivos = Object.values(filtros).filter(Boolean).length
  /** Los del panel: el texto no cuenta, que ya se ve escrito en el buscador. */
  const filtrosSinTexto = filtrosActivos - (filtros.texto ? 1 : 0)

  const presentacionesDe = (producto: ProductoBuscable) => producto.presentaciones.filter((p) => p.activo)

  /** Selección resuelta contra `productos` (no `resultados`), para que no se pierda al cambiar los filtros. */
  const seleccionados: SeleccionProducto[] = useMemo(
    () =>
      Object.keys(marcados)
        .map((id) => productos.find((p) => p.id === Number(id)))
        .filter((p): p is ProductoBuscable => Boolean(p))
        .map((producto) => ({
          producto,
          presentacionId: unidades[producto.id] ?? 0,
          cantidad: Number(cantidades[producto.id] ?? '1') || 1,
        })),
    [marcados, productos, unidades, cantidades],
  )

  const alternar = (producto: ProductoBuscable) =>
    setMarcados((prev) => {
      const next = { ...prev }
      if (next[producto.id]) delete next[producto.id]
      else next[producto.id] = true
      return next
    })

  /** Escribir una cantidad marca la fila automáticamente. */
  const setCantidad = (producto: ProductoBuscable, valor: string) => {
    setCantidades((prev) => ({ ...prev, [producto.id]: valor }))
    if (!marcados[producto.id]) setMarcados((prev) => ({ ...prev, [producto.id]: true }))
  }

  const confirmar = () => {
    const utiles = seleccionados.filter((s) => s.cantidad > 0)
    if (utiles.length === 0) return
    onAgregar(utiles)
    onClose()
  }

  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Buscar producto"
      description="Filtra por categoría, marca o stock; marca los productos y ajusta unidad y cantidad."
      size="lg"
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cerrar
          </Button>
          <Button size="sm" onClick={confirmar} disabled={seleccionados.length === 0}>
            Agregar{seleccionados.length > 0 ? ` (${seleccionados.length})` : ''}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        <div className="flex flex-col gap-3">
          <div className="flex items-center gap-2">
            <div className="relative flex-1">
              <Search size={15} className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-ink-soft" />
              <input
                autoFocus
                type="text"
                value={filtros.texto}
                onChange={(e) => setFiltro({ texto: e.target.value })}
                placeholder="Nombre, código, marca..."
                className="h-[var(--height-field-md)] w-full rounded-field border border-line bg-surface pr-3 pl-9 text-sm text-ink outline-none placeholder:text-ink-soft focus:border-ink-soft"
              />
            </div>

            <button
              type="button"
              onClick={() => setFiltrosAbiertos((v) => !v)}
              aria-label="Filtros"
              className={cn(
                'relative flex h-[var(--height-field-md)] w-[var(--height-field-md)] shrink-0 items-center justify-center rounded-field border transition-colors',
                filtrosAbiertos || filtrosSinTexto > 0
                  ? 'border-[rgb(var(--sys-rgb))] bg-[rgb(var(--sys-rgb)/0.08)] text-[rgb(var(--sys-rgb))]'
                  : 'border-line bg-surface text-ink-soft hover:text-ink',
              )}
            >
              <SlidersHorizontal size={16} />
              {filtrosSinTexto > 0 && (
                <span className="absolute -top-1.5 -right-1.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-[rgb(var(--sys-rgb))] px-1 text-[10px] font-bold text-white">
                  {filtrosSinTexto}
                </span>
              )}
            </button>
          </div>

          {filtrosAbiertos && (
            <div className="flex flex-col gap-3 rounded-field border border-line bg-surface-alt p-3">
              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                <Desplegable
                  label="Categoría"
                  value={filtros.categoria}
                  onChange={(v) => setFiltro({ categoria: String(v) })}
                  placeholder="Todas las categorías"
                  options={[
                    { value: '', label: 'Todas las categorías' },
                    ...categorias.map((c) => ({ value: c, label: c })),
                  ]}
                />
                <Desplegable
                  label="Marca"
                  value={filtros.marca}
                  onChange={(v) => setFiltro({ marca: String(v) })}
                  placeholder="Todas las marcas"
                  options={[{ value: '', label: 'Todas las marcas' }, ...marcas.map((m) => ({ value: m, label: m }))]}
                />
              </div>

              <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                <Desplegable
                  label="Stock"
                  value={filtros.stockEstado}
                  onChange={(v) => setFiltro({ stockEstado: String(v) })}
                  placeholder="Todo el stock"
                  options={[{ value: '', label: 'Todo el stock' }, ...ESTADO_STOCK_OPTIONS]}
                />
                <Input
                  label="Stock hasta"
                  type="number"
                  min="0"
                  placeholder="N"
                  value={filtros.stockHasta}
                  onChange={(e) => setFiltro({ stockHasta: e.target.value })}
                />
              </div>

              {filtrosSinTexto > 0 && (
                <button
                  type="button"
                  onClick={() => setFiltros({ ...FILTROS_VACIOS, texto: filtros.texto })}
                  className="inline-flex items-center gap-1.5 self-end text-xs font-semibold text-[rgb(var(--sys-rgb))] transition-colors hover:text-[rgb(var(--sys-dark-rgb))]"
                >
                  <RotateCcw size={13} /> Limpiar filtros
                </button>
              )}
            </div>
          )}

          {/* Cuantos hay y cuantos llevas marcados, justo sobre la lista. */}
          <div className="flex items-center justify-between">
            <span className="text-xs text-ink-soft">
              {resultados.length} producto{resultados.length === 1 ? '' : 's'}
            </span>
            {seleccionados.length > 0 && (
              <span className="text-xs font-semibold text-[rgb(var(--sys-rgb))]">
                {seleccionados.length} seleccionado{seleccionados.length === 1 ? '' : 's'}
              </span>
            )}
          </div>

        </div>

        {resultados.length === 0 ? (
          <div className="flex flex-col items-center gap-2 py-14 text-center">
            <Package size={28} className="text-ink-soft" />
            <p className="text-sm text-ink-soft">Ningún producto coincide con la búsqueda.</p>
          </div>
        ) : (
          <div className="max-h-[22rem] divide-y divide-line overflow-y-auto overflow-x-hidden rounded-field border border-line">
            {resultados.map((p) => {
              const cantidadStock = stock?.[p.id]
              const marcado = Boolean(marcados[p.id])
              const presentaciones = presentacionesDe(p)

              return (
                <div
                  key={p.id}
                  onClick={() => alternar(p)}
                  className={cn(
                    'cursor-pointer px-3 py-2.5 transition-colors',
                    marcado
                      ? 'bg-[rgb(var(--sys-rgb)/0.08)]'
                      : 'hover:bg-[rgb(var(--sys-rgb)/0.05)]',
                  )}
                >
                  <div className="flex items-center gap-3">
                    <input
                      type="checkbox"
                      checked={marcado}
                      onChange={() => alternar(p)}
                      onClick={(e) => e.stopPropagation()}
                      aria-label={`Seleccionar ${p.nombre}`}
                      className="size-4 shrink-0 cursor-pointer accent-[rgb(var(--sys-rgb))]"
                    />

                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-sm font-semibold text-ink">{p.nombre}</span>
                      <span className="block truncate text-xs text-ink-soft">
                        {p.codigo}
                        {p.marca && ` · ${p.marca}`}
                        {p.categoria && ` · ${p.categoria}`}
                      </span>
                    </span>

                    {cantidadStock != null && (
                      <span
                        className={cn(
                          'shrink-0 rounded-full px-2 py-0.5 text-xs font-semibold',
                          cantidadStock <= 0
                            ? 'bg-red-50 text-red-700'
                            : 'bg-surface-alt text-ink-muted',
                        )}
                      >
                        {cantidadStock} {p.unidadBase}
                      </span>
                    )}
                  </div>

                  {/*
                    Unidad y cantidad solo en la fila marcada: con 280 productos
                    en pantalla, repetirlas en todas alarga la lista sin que
                    sirvan de nada — son de lo que ya elegiste.
                  */}
                  {marcado && (
                    <div
                      className="mt-2.5 flex items-end gap-2 pl-7"
                      onClick={(e) => e.stopPropagation()}
                    >
                      <div className="min-w-0 flex-1">
                        <Desplegable
                          label="Unidad"
                          value={unidades[p.id] ?? 0}
                          onChange={(v) => setUnidades((prev) => ({ ...prev, [p.id]: Number(v) }))}
                          options={[
                            { value: 0, label: p.unidadBase },
                            ...presentaciones
                              .filter((pr) => !pr.esBase)
                              .map((pr) => ({ value: pr.id, label: pr.nombre })),
                          ]}
                        />
                      </div>

                      <div className="w-24 shrink-0">
                        <Input
                          label="Cant."
                          size="sm"
                          type="number"
                          min="0"
                          step="0.0001"
                          value={cantidades[p.id] ?? '1'}
                          onChange={(e) => setCantidad(p, e.target.value)}
                          aria-label={`Cantidad de ${p.nombre}`}
                        />
                      </div>
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        )}
      </div>
    </Modal>
  )
}
