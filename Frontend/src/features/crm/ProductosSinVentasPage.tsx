import { useCallback, useEffect, useMemo, useState } from 'react'
import { Boxes, PackageX, PiggyBank, SearchX } from 'lucide-react'
import { Alert, ListPage, StatCard, Tabs } from '../../components/ui'
import type { ConsultaTabla, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta } from '../../lib/fechas'
import { useRealtime } from '../../lib/realtime'
import { categoriaApi } from '../maestros'
import type { CategoriaResponse } from '../maestros/productoApi'
import { mercadoApi, rutaApi } from '../tms'
import type { MercadoResponse, RutaResponse } from '../tms'
import { crmReportesApi } from './crmReportesApi'
import type { ConsultaProductosCrm, ProductoSinVentaCrm, ProductosSinVentasCrm } from './crmReportesApi'
import { rango, soles } from './formato'

const DIAS = [7, 15, 30, 60, 90]

type Filtros = Omit<ConsultaProductosCrm, 'dias'>

const mismos = (a: Filtros, b: Filtros) =>
  a.mercadoId === b.mercadoId && a.rutaId === b.rutaId && a.categoriaId === b.categoriaId && a.stock === b.stock

/**
 * Productos sin ventas: lo que está en el catálogo y no se vendió en los últimos días.
 *
 * Los que tienen stock son plata parada; los que no, un producto que ni se compra ni se vende. Con
 * un mercado o una ruta se ve qué producto se mueve en otras partes y ahí no.
 */
export function ProductosSinVentasPage() {
  const [dias, setDias] = useState(30)
  const [filtros, setFiltros] = useState<Filtros>({})
  const [datos, setDatos] = useState<ProductosSinVentasCrm | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [mercados, setMercados] = useState<MercadoResponse[]>([])
  const [rutas, setRutas] = useState<RutaResponse[]>([])
  const [categorias, setCategorias] = useState<CategoriaResponse[]>([])

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setDatos(await crmReportesApi.productosSinVentas({ dias, ...filtros }))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los productos.')
    } finally {
      setCargando(false)
    }
  }, [dias, filtros])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useEffect(() => {
    void Promise.all([mercadoApi.getAll(), rutaApi.getAll(), categoriaApi.getAll()])
      .then(([mer, rut, cat]) => {
        setMercados(mer.filter((m) => m.activo))
        setRutas(rut.filter((r) => r.activo))
        setCategorias(cat.filter((c) => c.activo))
      })
      .catch(() => {
        /* Sin catálogos la lista sigue sirviendo: solo se pierde filtrar. */
      })
  }, [])

  // Una venta, una compra o un ajuste de stock cambian la lista.
  useRealtime(['notasventa', 'productos', 'stock', 'compras', 'recepciones'], cargar)

  /** Traduce los filtros del panel a lo que el servidor necesita para acotar. */
  const aplicar = useCallback((q: ConsultaTabla) => {
    const valor = (columna: string) => q.filtros.find((f) => f.columna === columna)?.valor
    const stock = valor('stock')
    const siguiente: Filtros = {
      mercadoId: Number(valor('mercado')) || undefined,
      rutaId: Number(valor('ruta')) || undefined,
      categoriaId: Number(valor('categoria')) || undefined,
      stock: stock === 'con' || stock === 'sin' ? stock : undefined,
    }
    // Cada tecla del buscador también llega aquí: sin esta comparación se volvería a pedir todo.
    setFiltros((previo) => (mismos(previo, siguiente) ? previo : siguiente))
  }, [])

  const columns: DataTableColumn<ProductoSinVentaCrm>[] = useMemo(
    () => [
      {
        key: 'producto',
        label: 'Producto',
        filterable: false,
        render: (row) => (
          <span className="flex flex-col">
            <span className="font-medium text-ink">{row.producto}</span>
            <span className="text-xs text-ink-soft">
              {row.codigo}
              {row.marca ? ` · ${row.marca}` : ''}
            </span>
          </span>
        ),
      },
      {
        key: 'categoria',
        label: 'Categoría',
        filterType: 'select',
        filterOptions: categorias.map((c) => ({ value: String(c.id), label: c.nombre })),
        value: (row) => String(row.categoriaId ?? ''),
        render: (row) => row.categoria ?? '—',
      },
      // Estos dos solo existen en el panel de filtros: deciden qué se pide al servidor.
      {
        key: 'mercado',
        label: 'Sin ventas en el mercado',
        soloFiltro: true,
        filterType: 'select',
        filterOptions: mercados.map((m) => ({ value: String(m.id), label: m.nombre })),
      },
      {
        key: 'ruta',
        label: 'Sin ventas en la ruta',
        soloFiltro: true,
        filterType: 'select',
        filterOptions: rutas.map((r) => ({ value: String(r.id), label: r.nombre })),
      },
      {
        key: 'stock',
        label: 'Stock',
        soloFiltro: true,
        filterType: 'select',
        filterOptions: [
          { value: 'con', label: 'Con stock' },
          { value: 'sin', label: 'Sin stock' },
        ],
      },
      {
        key: 'existencia',
        label: 'En stock',
        align: 'right',
        filterable: false,
        value: (row) => row.stock,
        render: (row) =>
          row.stock > 0 ? (
            `${row.stock.toLocaleString('es-PE', { maximumFractionDigits: 2 })} ${row.unidadBase}`
          ) : (
            <span className="text-ink-soft">Sin stock</span>
          ),
      },
      {
        key: 'valorStock',
        label: 'Plata parada',
        align: 'right',
        filterable: false,
        value: (row) => row.valorStock,
        render: (row) => (row.valorStock > 0 ? soles(row.valorStock) : <span className="text-ink-soft">—</span>),
      },
      {
        key: 'ultimaVenta',
        label: 'Última venta',
        filterable: false,
        // Los que nunca se vendieron, como los más viejos.
        value: (row) => row.diasSinVender ?? Number.MAX_SAFE_INTEGER,
        render: (row) =>
          row.ultimaVenta ? (
            <span className="flex flex-col">
              <span>{fechaCorta(row.ultimaVenta)}</span>
              <span className="text-xs text-ink-soft">hace {row.diasSinVender} días</span>
            </span>
          ) : (
            <span className="text-ink-soft">Nunca</span>
          ),
      },
      {
        key: 'otras',
        label: 'Vendido en otras zonas',
        align: 'right',
        filterable: false,
        value: (row) => row.vendidoEnOtrasZonas,
        render: (row) =>
          row.vendidoEnOtrasZonas > 0 ? (
            <span className="font-medium text-emerald-600">{soles(row.vendidoEnOtrasZonas)}</span>
          ) : (
            <span className="text-ink-soft">—</span>
          ),
      },
    ],
    [categorias, mercados, rutas],
  )

  const resumen = datos?.resumen
  const zona = datos?.mercado ?? datos?.ruta

  return (
    <ListPage
      icon={<PackageX size={20} />}
      title="Productos sin ventas"
      description="Productos activos que no se vendieron en los últimos días."
      alert={error ? <Alert>{error}</Alert> : undefined}
      banner={
        <div className="space-y-2">
          <Tabs
            items={DIAS.map((d) => ({ id: String(d), label: `${d} días` }))}
            active={String(dias)}
            onChange={(id) => setDias(Number(id))}
          />
          {datos && (
            <p className="text-xs text-ink-soft">
              {zona ? `Sin ventas a clientes de ${zona}` : 'Sin ventas'} del {rango(datos.rango)}. Venta neta de
              recojos; el stock suma todos los almacenes y se valoriza a su costo.
            </p>
          )}
        </div>
      }
      stats={
        <>
          <StatCard
            label="Sin ventas"
            value={String(resumen?.sinVentas ?? 0)}
            hint={`de ${resumen?.productosActivos ?? 0} productos activos`}
            icon={<PackageX size={18} />}
            tono="warning"
          />
          <StatCard
            label="Con stock"
            value={String(resumen?.conStock ?? 0)}
            hint={`${resumen?.sinStock ?? 0} sin stock`}
            icon={<Boxes size={18} />}
          />
          <StatCard
            label="Plata parada"
            value={soles(resumen?.capitalParado ?? 0)}
            hint="stock de los que no se vendieron, a costo"
            icon={<PiggyBank size={18} />}
            tono="danger"
          />
          <StatCard
            label="Nunca vendidos"
            value={String(resumen?.nuncaVendidos ?? 0)}
            icon={<SearchX size={18} />}
            tono="neutral"
          />
        </>
      }
      columns={columns}
      rows={datos?.items ?? []}
      rowKey="productoId"
      onConsulta={aplicar}
      cardIcon={PackageX}
      searchPlaceholder="Buscar producto, código..."
      empty={cargando ? 'Cargando productos...' : 'Todos los productos se vendieron en este periodo.'}
      note="Con un mercado o una ruta elegidos, 'Vendido en otras zonas' muestra lo que sí se movió en el resto."
    />
  )
}
