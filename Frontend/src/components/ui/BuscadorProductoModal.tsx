import { useEffect, useMemo, useState } from 'react'
import { Package, Search } from 'lucide-react'
import { Badge } from './Badge'
import { Button } from './Button'
import { Desplegable } from './Desplegable'
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

export interface BuscadorProductoModalProps {
  open: boolean
  onClose: () => void
  productos: ProductoBuscable[]
  /** Stock actual por producto, en unidad base — se pinta como badge de color. */
  stock?: Record<number, number>
  onSeleccionar: (producto: ProductoBuscable) => void
}

/** Sin acentos y en minúsculas, para que "nunez" encuentre "Nuñez". */
const normalizar = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()

/** Opciones únicas de un campo del producto, para llenar un filtro. */
function opcionesDe(productos: ProductoBuscable[], campo: 'categoria' | 'marca') {
  const valores = new Set(productos.map((p) => p[campo]).filter((v): v is string => Boolean(v)))
  return [...valores].sort((a, b) => a.localeCompare(b, 'es'))
}

/**
 * Buscar un producto en una lista de tarjetas, filtrable por categoría y
 * marca — no una grilla genérica: acá no hace falta ordenar columnas ni
 * ocultarlas, solo encontrar el producto rápido.
 */
export function BuscadorProductoModal({
  open,
  onClose,
  productos,
  stock,
  onSeleccionar,
}: BuscadorProductoModalProps) {
  const [texto, setTexto] = useState('')
  const [categoria, setCategoria] = useState('')
  const [marca, setMarca] = useState('')

  useEffect(() => {
    if (open) {
      setTexto('')
      setCategoria('')
      setMarca('')
    }
  }, [open])

  const categorias = useMemo(() => opcionesDe(productos, 'categoria'), [productos])
  const marcas = useMemo(() => opcionesDe(productos, 'marca'), [productos])

  const resultados = useMemo(() => {
    const term = normalizar(texto.trim())
    return productos.filter((p) => {
      if (categoria && p.categoria !== categoria) return false
      if (marca && p.marca !== marca) return false
      if (!term) return true
      return normalizar(`${p.nombre} ${p.codigo} ${p.categoria ?? ''} ${p.marca ?? ''}`).includes(term)
    })
  }, [productos, texto, categoria, marca])

  const elegir = (p: ProductoBuscable) => {
    onSeleccionar(p)
    onClose()
  }

  return (
    <Modal
      open={open}
      onClose={onClose}
      title="Elegir producto"
      description="Busca por nombre o código; filtra por categoría o marca."
      size="lg"
      footer={
        <>
          <span className="mr-auto text-xs text-ink-soft">
            {resultados.length} producto{resultados.length === 1 ? '' : 's'}
          </span>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cerrar
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <div className="relative">
            <Search size={15} className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-ink-soft" />
            <input
              autoFocus
              type="text"
              value={texto}
              onChange={(e) => setTexto(e.target.value)}
              placeholder="Nombre o código..."
              className="h-[var(--height-field-md)] w-full rounded-field border border-line bg-surface pr-3 pl-9 text-sm text-ink outline-none placeholder:text-ink-soft focus:border-ink-soft"
            />
          </div>
          <Desplegable
            value={categoria}
            onChange={(v) => setCategoria(String(v))}
            placeholder="Todas las categorías"
            options={[
              { value: '', label: 'Todas las categorías' },
              ...categorias.map((c) => ({ value: c, label: c })),
            ]}
          />
          <Desplegable
            value={marca}
            onChange={(v) => setMarca(String(v))}
            placeholder="Todas las marcas"
            options={[{ value: '', label: 'Todas las marcas' }, ...marcas.map((m) => ({ value: m, label: m }))]}
          />
        </div>

        {resultados.length === 0 ? (
          <div className="flex flex-col items-center gap-2 py-14 text-center">
            <Package size={28} className="text-ink-soft" />
            <p className="text-sm text-ink-soft">Ningún producto coincide con la búsqueda.</p>
          </div>
        ) : (
          <div className="max-h-[24rem] divide-y divide-line overflow-y-auto overflow-x-hidden rounded-field border border-line">
            {resultados.map((p) => {
              const cantidad = stock?.[p.id]
              const bajoMinimo = (p.stockMinimo ?? 0) > 0 && (cantidad ?? 0) < (p.stockMinimo ?? 0)
              const tono =
                cantidad == null
                  ? 'neutral'
                  : cantidad <= 0
                    ? 'danger'
                    : bajoMinimo
                      ? 'warning'
                      : 'success'

              return (
                <button
                  key={p.id}
                  type="button"
                  onClick={() => elegir(p)}
                  className="flex w-full items-center gap-3 px-3 py-2.5 text-left transition-colors hover:bg-[rgb(var(--sys-rgb)/0.05)]"
                >
                  <span className="grid size-9 shrink-0 place-items-center rounded-field bg-[rgb(var(--sys-rgb)/0.1)] text-[rgb(var(--sys-ink-rgb))]">
                    <Package size={16} />
                  </span>

                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-semibold text-ink">{p.nombre}</span>
                    <span className="block truncate text-xs text-ink-soft">
                      Código: {p.codigo}
                      {p.marca && ` · ${p.marca}`}
                      {p.categoria && ` · ${p.categoria}`}
                    </span>
                    <span className="mt-1 flex flex-wrap items-center gap-2">
                      {cantidad != null && (
                        <Badge tone={tono}>
                          Stock: {cantidad} {p.unidadBase}
                        </Badge>
                      )}
                      {p.costoReferencia != null && (
                        <span className="text-sm font-semibold text-[rgb(var(--sys-rgb))]">
                          S/ {p.costoReferencia.toFixed(2)}
                        </span>
                      )}
                    </span>
                  </span>
                </button>
              )
            })}
          </div>
        )}
      </div>
    </Modal>
  )
}
