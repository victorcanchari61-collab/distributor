import { useCallback, useEffect, useState } from 'react'
import { AlertTriangle, Boxes, Layers, PackageSearch, Warehouse } from 'lucide-react'
import { Alert, Desplegable, ListaDesplegable, ListPage, StatCard, Tabs } from '../../components/ui'
import type { ConsultaTabla, DataTableColumn, TabItem } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { almacenApi, stockApi } from './inventarioApi'
import type { AlmacenResponse, ResumenStock, StockResponse } from './inventarioApi'
import { useRealtime } from '../../lib/realtime'
import { productoApi } from '../maestros'
import type { ProductoResponse } from '../maestros'

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
   * En que unidad se lee el stock de cada producto.
   *
   * "1250 KG" no le dice nada a nadie en el almacen: lo que se cuenta son 25
   * sacos. Cada fila elige su unidad y arranca en la de COMPRA, que es como
   * entra la mercaderia y como se piensa al reponer. Se guarda por producto:
   * { [productoId]: presentacionId }.
   */
  const [productos, setProductos] = useState<ProductoResponse[]>([])
  const [unidades, setUnidades] = useState<Record<number, number>>({})

  useEffect(() => {
    void productoApi.getAll().then(setProductos).catch(() => setProductos([]))
  }, [])

  const presentacionesDe = (productoId: number) =>
    productos.find((p) => p.id === productoId)?.presentaciones.filter((x) => x.activo) ?? []

  /** La de compra: la marcada por defecto, si no la primera que se compra. */
  const unidadPorDefecto = (productoId: number) => {
    const suyas = presentacionesDe(productoId)
    const compra =
      suyas.find((x) => x.predeterminadaCompra && x.esCompra) ?? suyas.find((x) => x.esCompra)
    return compra?.id ?? suyas.find((x) => x.esBase)?.id ?? 0
  }

  const unidadDe = (productoId: number) => unidades[productoId] ?? unidadPorDefecto(productoId)

  const factorDe = (productoId: number) =>
    presentacionesDe(productoId).find((x) => x.id === unidadDe(productoId))?.factor ?? 1

  const nombreUnidad = (row: StockResponse) =>
    presentacionesDe(row.productoId).find((x) => x.id === unidadDe(row.productoId))?.nombre
    ?? row.unidadBase

  /** Una cantidad en unidad base, dicha en la unidad elegida de esa fila. */
  const enUnidad = (row: StockResponse, base: number) =>
    Number((base / factorDe(row.productoId)).toFixed(4))

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
    /*
     * Cantidades e importes no entran al panel: el unico control es un
     * buscador de texto, y "9" contra "S/ 9.00" no encuentra lo esperado.
     */
    {
      /*
       * En que se lee la fila.
       *
       * Columna propia y no pegada al numero: el select ahogaba la cifra, que
       * es lo que se viene a mirar. Manda sobre todas las cantidades de la
       * fila, asi que no hace falta repetir la unidad en cada una.
       */
      key: 'unidad',
      label: 'Unidad',
      filterable: false,
      width: 170,
      value: (row) => nombreUnidad(row),
      render: (row) => {
        const opciones = presentacionesDe(row.productoId)
        return opciones.length > 1 ? (
          <Desplegable
            size="sm"
            value={unidadDe(row.productoId)}
            onChange={(v) => setUnidades((prev) => ({ ...prev, [row.productoId]: Number(v) }))}
            options={opciones.map((x) => ({
              value: x.id,
              label: x.nombre,
              detalle: `${x.factor} ${row.unidadBase}`,
            }))}
          />
        ) : (
          <span className="text-sm text-ink-soft">{row.unidadBase}</span>
        )
      },
    },
    {
      key: 'stock',
      label: 'Stock',
      align: 'right',
      filterable: false,
      width: 110,
      render: (row) => (
        <span className={row.bajoMinimo ? 'font-semibold text-amber-600' : 'font-medium text-ink'}>
          {row.bajoMinimo && <AlertTriangle size={12} className="mr-1 inline" />}
          {enUnidad(row, row.stock)}
        </span>
      ),
    },
    {
      /*
       * Lo que apartan los pedidos pendientes con reserva.
       *
       * Iba escrito chiquito dentro de Disponible, asi que no se podia
       * ordenar por el ni se veia de un vistazo quien tiene mercaderia
       * comprometida.
       */
      key: 'reservado',
      label: 'Reservado',
      align: 'right',
      filterable: false,
      value: (row) => row.reservado,
      render: (row) =>
        row.reservado > 0 ? (
          <span className="font-medium text-ink">
            {enUnidad(row, row.reservado)}
          </span>
        ) : (
          <span className="text-ink-soft">—</span>
        ),
    },
    {
      key: 'disponible',
      label: 'Disponible',
      align: 'right',
      filterable: false,
      value: (row) => row.disponible,
      render: (row) => (
        <span className={row.reservado > 0 ? 'font-medium text-ink' : 'text-ink-soft'}>
          {enUnidad(row, row.disponible)}
        </span>
      ),
    },
    {
      key: 'stockMinimo',
      label: 'Mínimo',
      align: 'right',
      filterable: false,
      value: (row) => row.stockMinimo,
      render: (row) =>
        row.stockMinimo > 0 ? (
          <span className="text-ink-soft">
            {enUnidad(row, row.stockMinimo)}
          </span>
        ) : (
          <span className="text-ink-soft">—</span>
        ),
    },
    {
      /*
       * Cuanto pedir. El triangulo ambar ya avisaba que falta reponer, pero
       * no cuanto, que es lo que se necesita para armar la compra.
       */
      key: 'reponer',
      label: 'Falta reponer',
      align: 'right',
      filterable: false,
      value: (row) => Math.max(0, row.stockMinimo - row.stock),
      render: (row) => {
        const falta = row.stockMinimo - row.stock
        return falta > 0 ? (
          <span className="font-semibold text-amber-600">
            {enUnidad(row, falta)}
          </span>
        ) : (
          <span className="text-ink-soft">—</span>
        )
      },
    },
    {
      /*
       * Lo comprado que no ha llegado.
       *
       * Sin esto se vuelve a comprar lo que ya viene en camino, que es como
       * termina el almacen con el doble de lo que necesita.
       */
      key: 'enTransito',
      label: 'En camino',
      align: 'right',
      filterable: false,
      value: (row) => row.enTransito,
      render: (row) =>
        row.enTransito > 0 ? (
          <span className="font-medium text-sky-600">
            {enUnidad(row, row.enTransito)}
          </span>
        ) : (
          <span className="text-ink-soft">—</span>
        ),
    },
    {
      /* Para cuantos dias alcanza al ritmo al que se vendio el ultimo mes. */
      key: 'diasStock',
      label: 'Días',
      align: 'right',
      filterable: false,
      value: (row) => row.diasStock ?? -1,
      render: (row) =>
        row.diasStock == null ? (
          <span className="text-ink-soft">—</span>
        ) : (
          <span
            className={
              row.diasStock <= 7
                ? 'font-semibold text-red-600'
                : row.diasStock <= 15
                  ? 'font-semibold text-amber-600'
                  : 'text-ink-soft'
            }
          >
            {row.diasStock} d
          </span>
        ),
    },
    {
      key: 'ultimaSalida',
      label: 'Última salida',
      filterable: false,
      value: (row) => row.ultimaSalida ?? '',
      render: (row) =>
        row.ultimaSalida ? (
          <span className="text-ink-soft">
            {new Date(row.ultimaSalida).toLocaleDateString('es-PE')}
          </span>
        ) : (
          <span className="text-ink-soft">Nunca</span>
        ),
    },
    {
      key: 'ultimaEntrada',
      label: 'Última entrada',
      filterable: false,
      value: (row) => row.ultimaEntrada ?? '',
      render: (row) =>
        row.ultimaEntrada ? (
          <span className="text-ink-soft">
            {new Date(row.ultimaEntrada).toLocaleDateString('es-PE')}
          </span>
        ) : (
          <span className="text-ink-soft">Nunca</span>
        ),
    },
    {
      key: 'costoActual',
      label: 'Costo',
      align: 'right',
      filterable: false,
      value: (row) => String(row.costoActual ?? ''),
      // Sigue a la unidad de la fila: leyendo en sacos, el costo del saco. Un
      // costo por kilo al lado de un stock en sacos se compara mal.
      render: (row) => {
        const factor = factorDe(row.productoId)
        return row.costoActual == null ? (
          <span className="text-ink-soft">—</span>
        ) : (
          <span>
            S/ {(row.costoActual * factor).toFixed(2)}
            {row.costoUltimo !== row.costoActual &&
              ` – ${((row.costoUltimo ?? 0) * factor).toFixed(2)}`}
          </span>
        )
      },
    },
    {
      key: 'valorizado',
      label: 'Valorizado',
      align: 'right',
      filterable: false,
      render: (row) => `S/ ${row.valorizado.toFixed(2)}`,
    },
    {
      key: 'categoria',
      label: 'Categoría',
      render: (row) => row.categoria ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'marca',
      label: 'Marca',
      render: (row) => row.marca ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'capas',
      label: 'Capas',
      filterable: false,
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
