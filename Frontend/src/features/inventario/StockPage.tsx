import { useCallback, useEffect, useState } from 'react'
import { AlertTriangle, Boxes, Layers, PackageSearch, Warehouse } from 'lucide-react'
import { Alert, ListaDesplegable, ListPage, StatCard, Tabs } from '../../components/ui'
import type { ConsultaTabla, DataTableColumn, TabItem } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { almacenApi, stockApi } from './inventarioApi'
import type { AlmacenResponse, ResumenStock, StockResponse } from './inventarioApi'
import { useRealtime } from '../../lib/realtime'

/**
 * Cuánto hay y a qué costo, por almacén.
 *
 * Una pestaña por almacén, igual que las listas de precios: cambiar de
 * almacén es cambiar de contexto completo (otro stock, otro valorizado), no
 * un filtro más entre varios. "Todos" queda como la primera pestaña para ver
 * el conjunto.
 *
 * Es una consulta: aquí no se mueve stock. Para eso está Ajustes de
 * inventario, el único documento que crea movimientos manuales.
 */
export function StockPage() {
  const [almacenes, setAlmacenes] = useState<AlmacenResponse[]>([])
  const [almacenId, setAlmacenId] = useState(0)
  const [stock, setStock] = useState<StockResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    void almacenApi.getAll().then(setAlmacenes)
  }, [])

  /*
   * El stock es una fila por producto y almacen: con miles de productos son
   * miles de filas. La tabla pide su pagina y el servidor calcula los
   * agregados solo de esos productos.
   */
  const [consulta, setConsulta] = useState<ConsultaTabla | null>(null)
  const [totalRegistros, setTotalRegistros] = useState(0)
  const [resumen, setResumen] = useState<ResumenStock | null>(null)

  const cargarPagina = useCallback(
    async (q: ConsultaTabla) => {
      setCargando(true)
      try {
        const pagina = await stockApi.listar(q, almacenId || undefined)
        setStock(pagina.items)
        setTotalRegistros(pagina.total)
        setError('')
      } catch (e) {
        setError(e instanceof ApiError ? e.message : 'No pudimos cargar el stock.')
      } finally {
        setCargando(false)
      }
    },
    [almacenId],
  )

  const cargarResumen = useCallback(async () => {
    try {
      setResumen(await stockApi.resumenTotales(almacenId || undefined))
    } catch {
      // Los totales de arriba son secundarios: la tabla igual sirve.
    }
  }, [almacenId])

  const cargar = useCallback(async () => {
    await Promise.all([consulta ? cargarPagina(consulta) : Promise.resolve(), cargarResumen()])
  }, [consulta, cargarPagina, cargarResumen])

  // Cambiar de almacen es cambiar el listado entero: se vuelve a pedir.
  useEffect(() => {
    void cargarResumen()
    if (consulta) void cargarPagina({ ...consulta, pagina: 1 })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [almacenId])

  useRealtime('stock', cargar)

  const conStock = resumen?.conStock ?? 0
  const bajoMinimo = resumen?.bajoMinimo ?? 0
  const valorTotal = resumen?.valorizado ?? 0
  const almacenActivo = almacenes.find((a) => a.id === almacenId)

  const tabs: TabItem[] = [
    { id: '0', label: 'Todos', icon: <Boxes size={15} /> },
    ...almacenes.map((a) => ({
      id: String(a.id),
      label: a.nombre,
      icon: <Warehouse size={15} />,
    })),
  ]

  const columns: DataTableColumn<StockResponse>[] = [
    { key: 'codigo', label: 'Código' },
    { key: 'producto', label: 'Producto' },
    {
      key: 'categoria',
      label: 'Categoría',
      render: (row) => row.categoria ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'stock',
      label: 'Stock',
      align: 'right',
      render: (row) => (
        <span className={row.bajoMinimo ? 'font-semibold text-amber-600' : ''}>
          {row.bajoMinimo && <AlertTriangle size={12} className="mr-1 inline" />}
          {row.stock} {row.unidadBase}
        </span>
      ),
    },
    {
      key: 'disponible',
      label: 'Disponible',
      align: 'right',
      render: (row) =>
        row.reservado > 0 ? (
          <span>
            {row.disponible} {row.unidadBase}
            <span className="ml-1.5 text-xs text-ink-soft">
              ({row.reservado} reservado)
            </span>
          </span>
        ) : (
          <span className="text-ink-soft">{row.disponible} {row.unidadBase}</span>
        ),
    },
    {
      key: 'costoActual',
      label: 'Costo',
      align: 'right',
      value: (row) => String(row.costoActual ?? ''),
      render: (row) =>
        row.costoActual == null ? (
          <span className="text-ink-soft">—</span>
        ) : (
          <span>
            S/ {row.costoActual}
            {row.costoUltimo !== row.costoActual && ` – ${row.costoUltimo}`}
          </span>
        ),
    },
    {
      key: 'valorizado',
      label: 'Valorizado',
      align: 'right',
      render: (row) => `S/ ${row.valorizado.toFixed(2)}`,
    },
    {
      key: 'capas',
      label: 'Capas',
      value: (row) => String(row.capas.length),
      render: (row) =>
        row.capas.length === 0 ? (
          <span className="text-ink-soft">—</span>
        ) : (
          <ListaDesplegable
            icono={<Layers size={13} />}
            titulo="Capas de costo"
            resumen={`${row.capas.length} ${row.capas.length === 1 ? 'capa' : 'capas'}`}
            items={row.capas.map((c, i) => ({
              id: c.id,
              label: `${i === 0 ? 'Sale primero · ' : ''}${c.cantidadDisponible} ${row.unidadBase}`,
              nota: new Date(c.fecha).toLocaleDateString('es-PE'),
              detalle: `S/ ${c.costoUnitario} · S/ ${c.valor.toFixed(2)}`,
            }))}
          />
        ),
    },
  ]

  return (
    <>
      {almacenes.length > 0 && (
        <Tabs className="mb-5" active={String(almacenId)} onChange={(id) => setAlmacenId(Number(id))} items={tabs} />
      )}

      <ListPage
        icon={<PackageSearch size={20} />}
        title="Stock por almacén"
        description={
          almacenActivo
            ? `Lo que hay en ${almacenActivo.nombre}.`
            : 'Cuánto hay y a qué costo, en todos los almacenes.'
        }
        alert={error ? <Alert>{error}</Alert> : undefined}
        stats={
          <>
            <StatCard
              label="Productos con stock"
              value={String(conStock)}
              icon={<Boxes size={18} />}
            />
            <StatCard
              label="Bajo el mínimo"
              value={String(bajoMinimo)}
              icon={<AlertTriangle size={18} />}
              tono={bajoMinimo > 0 ? 'warning' : 'neutral'}
              hint={bajoMinimo > 0 ? 'reponer pronto' : 'todo en orden'}
            />
            <StatCard
              label="Valor del inventario"
              value={`S/ ${valorTotal.toFixed(2)}`}
              icon={<Layers size={18} />}
              tono="success"
              hint="al costo de compra"
            />
          </>
        }
        columns={columns}
        rows={stock}
        servidor={{
          total: totalRegistros,
          cargando,
          onConsulta: (q) => {
            setConsulta(q)
            void cargarPagina(q)
          },
        }}
        cardIcon={PackageSearch}
        searchPlaceholder="Buscar por código, producto, categoría..."
        empty={
          cargando
            ? 'Cargando stock...'
            : almacenActivo
              ? `${almacenActivo.nombre} todavía no tiene stock.`
              : 'No hay productos que controlen stock.'
        }
        note={
          <>
            El costo real lo fija cada entrada; para moverlo, usa{' '}
            <span className="font-semibold">Ajustes de inventario</span>.
          </>
        }
      />
    </>
  )
}
