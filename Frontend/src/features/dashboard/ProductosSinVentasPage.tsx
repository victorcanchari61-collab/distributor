import { useCallback, useEffect, useMemo, useState } from 'react'
import { FileSpreadsheet, ImageOff, PackageX } from 'lucide-react'
import { DonutChart, HBarChart, LineChart, Marco, moneda } from '../../components/charts'
import { Alert, Button, ListPage } from '../../components/ui'
import type { ConsultaTabla, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { exportarExcel } from '../../lib/excel'
import { hoyLocal } from '../../lib/fechas'
import { useRealtime } from '../../lib/realtime'
import type { EstadoClave } from '../crm/crmApi'
import { ESTADOS_UI, ORDEN_ESTADOS, colorCambio, colorDeDias, fechaDia, mesCorto, porcentaje, soles } from '../crm/formato'
import { ICONO_ESTADO } from '../crm/iconosEstado'
import { EtiquetaEstado, TarjetaReporte } from '../crm/piezas'
import { almacenApi } from '../inventario/inventarioApi'
import type { AlmacenOpcion } from '../inventario/inventarioApi'
import { categoriaApi, marcaApi } from '../maestros/productoApi'
import type { CategoriaResponse, MarcaResponse } from '../maestros/productoApi'
import { urlImagen } from '../tms/flotaApi'
import { sinVentasApi } from './sinVentasApi'
import type { CompararProductos, CriterioProductos, FilaProductoCaida, MedidaProductos, ProductosCaida } from './sinVentasApi'

import { opcional } from '../../lib/apoyo'
/** Lo que el panel de filtros decide que se pida al servidor. */
interface FiltrosServidor {
  desde: string
  hasta: string
  comparar: CompararProductos
  medida: MedidaProductos
  criterio: CriterioProductos
  almacenId?: number
  categoriaId?: number
  marcaId?: number
  incluirSinStock: boolean
}

/** Lo que el panel acota sobre lo que ya llegó: cada fila trae sus días y su stock. */
interface FiltrosLocales {
  /** "15", "30", "60", "90" (días sin venta, o más) o "sin_ventas" (nunca se vendió). */
  movimiento?: string
  stock?: 'con' | 'sin'
  stockDesde?: number
  stockHasta?: number
}

/** "En caída" es crítico + en riesgo + en seguimiento, como la tarjeta de Productos sin ventas. */
type EstadoElegido = EstadoClave | 'CAIDA'
const EN_CAIDA: EstadoClave[] = ['CRITICO', 'RIESGO', 'SEGUIMIENTO']

const iguales = (a: object, b: object) => JSON.stringify(a) === JSON.stringify(b)

/** El 1 del mes en curso: de ahí a hoy se mide si nadie elige fechas. */
const inicioDeMes = () => `${hoyLocal().slice(0, 7)}-01`

const numero = (texto?: string) => {
  const t = texto?.trim().replace(',', '.')
  if (!t) return undefined
  const n = Number(t)
  return Number.isFinite(n) ? n : undefined
}

const cantidad = (n: number) => n.toLocaleString('es-PE', { maximumFractionDigits: 2 })

const OPCIONES_COMPARAR = [
  { value: 'mes', label: 'Mes anterior' },
  { value: 'anio', label: 'Año anterior' },
]
const OPCIONES_MEDIDA = [
  { value: 'soles', label: 'Soles' },
  { value: 'unidades', label: 'Unidades' },
]
const OPCIONES_CRITERIO = [
  { value: 'variacion', label: 'Variación de ventas' },
  { value: 'dias', label: 'Días sin venta' },
]
const OPCIONES_MOVIMIENTO = [
  { value: '15', label: '15 días o más' },
  { value: '30', label: '30 días o más' },
  { value: '60', label: '60 días o más' },
  { value: '90', label: '90 días o más' },
  { value: 'sin_ventas', label: 'Sin ventas (nunca vendidos)' },
]

/** Lo que cubre cada estado, según con qué se decide. */
function rangoDe(estado: EstadoClave, criterio: CriterioProductos, comparar: CompararProductos) {
  if (criterio === 'dias') {
    return {
      CRITICO: '61 días o más',
      RIESGO: '31 - 60 días',
      SEGUIMIENTO: '16 - 30 días',
      NORMAL: '0 - 15 días',
      SIN_BASE: 'Nunca vendidos',
    }[estado]
  }
  return estado === 'SIN_BASE' ? `Sin ventas el ${comparar === 'anio' ? 'año' : 'mes'} anterior` : ESTADOS_UI[estado].rango
}

/**
 * Productos sin ventas: lo que vendió cada producto en el tramo elegido contra el mes anterior (o el año anterior) y en
 * qué estado queda, por cuánto cayó o por los días que lleva sin venderse. Las tarjetas son filtros: tocar una deja solo
 * esos productos. Todo lo demás se elige en el ícono de filtros de la tabla.
 */
export function ProductosSinVentasPage() {
  const [desdeInicial] = useState(inicioDeMes())
  const [hastaInicial] = useState(hoyLocal())
  const [filtros, setFiltros] = useState<FiltrosServidor>({
    desde: desdeInicial,
    hasta: hastaInicial,
    comparar: 'mes',
    medida: 'soles',
    criterio: 'variacion',
    incluirSinStock: false,
  })
  const [locales, setLocales] = useState<FiltrosLocales>({})
  const [estado, setEstado] = useState<EstadoElegido>()

  const [datos, setDatos] = useState<ProductosCaida | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [almacenes, setAlmacenes] = useState<AlmacenOpcion[]>([])
  const [categorias, setCategorias] = useState<CategoriaResponse[]>([])
  const [marcas, setMarcas] = useState<MarcaResponse[]>([])

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setDatos(await sinVentasApi.analisis(filtros))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar el análisis de productos.')
    } finally {
      setCargando(false)
    }
  }, [filtros])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useEffect(() => {
    void Promise.all([opcional(almacenApi.opciones(), []), opcional(categoriaApi.getAll(), []), opcional(marcaApi.getAll(), [])])
      .then(([alm, cat, mar]) => {
        setAlmacenes(alm.filter((a) => a.activo))
        setCategorias(cat.filter((c) => c.activo))
        setMarcas(mar.filter((m) => m.activo))
      })
      .catch(() => {
        /* Sin catálogos el reporte sigue sirviendo: solo se pierde filtrar. */
      })
  }, [])

  // Una venta, una compra o un ajuste de stock cambian el análisis.
  useRealtime(['notasventa', 'productos', 'stock', 'compras', 'recepciones'], cargar)

  /** Traduce el panel de filtros a lo que se pide al servidor y a lo que se acota aquí. */
  const aplicar = useCallback(
    (q: ConsultaTabla) => {
      const filtro = (columna: string) => q.filtros.find((f) => f.columna === columna)
      const valor = (columna: string) => filtro(columna)?.valor || undefined
      const fecha = filtro('fecha')
      const comparar = valor('comparar')
      const medida = valor('medida')
      const criterio = valor('criterio')
      const stock = valor('stock')

      const servidor: FiltrosServidor = {
        desde: fecha?.valor || desdeInicial,
        hasta: fecha?.valorHasta || fecha?.valor || hastaInicial,
        comparar: comparar === 'anio' ? 'anio' : 'mes',
        medida: medida === 'unidades' ? 'unidades' : 'soles',
        criterio: criterio === 'dias' ? 'dias' : 'variacion',
        almacenId: Number(valor('almacen')) || undefined,
        categoriaId: Number(valor('categoriaFiltro')) || undefined,
        marcaId: Number(valor('marcaFiltro')) || undefined,
        incluirSinStock: valor('sinStock') === 'si',
      }
      const local: FiltrosLocales = {
        movimiento: valor('movimiento'),
        stock: stock === 'con' || stock === 'sin' ? stock : undefined,
        stockDesde: numero(valor('stockDesde')),
        stockHasta: numero(valor('stockHasta')),
      }
      // Cada tecla del buscador también llega aquí: sin esta comparación se volvería a pedir todo.
      setFiltros((previo) => (iguales(previo, servidor) ? previo : servidor))
      setLocales((previo) => (iguales(previo, local) ? previo : local))
    },
    [desdeInicial, hastaInicial],
  )

  const { medida, criterio, comparar } = filtros
  const enSoles = medida === 'soles'
  const valorDe = useCallback((n: number) => (enSoles ? soles(n) : `${cantidad(n)} u.`), [enSoles])
  const referencia = comparar === 'anio' ? 'el año anterior' : 'el mes anterior'

  const columnas: DataTableColumn<FilaProductoCaida>[] = useMemo(
    () => [
      // Estas solo existen en el panel de Filtros: deciden qué se pide o qué se acota (ver SysDataTable).
      { key: 'fecha', label: 'Fechas', soloFiltro: true, filterType: 'date' },
      { key: 'comparar', label: 'Comparar con', soloFiltro: true, filterType: 'select', filterOptions: OPCIONES_COMPARAR },
      { key: 'medida', label: 'Comparar por', soloFiltro: true, filterType: 'select', filterOptions: OPCIONES_MEDIDA },
      { key: 'criterio', label: 'Criterio de análisis', soloFiltro: true, filterType: 'select', filterOptions: OPCIONES_CRITERIO },
      {
        key: 'almacen',
        label: 'Sucursal (almacén)',
        soloFiltro: true,
        filterType: 'select',
        filterOptions: almacenes.map((a) => ({ value: String(a.id), label: a.nombre })),
      },
      {
        key: 'categoriaFiltro',
        label: 'Categoría',
        soloFiltro: true,
        filterType: 'select',
        filterOptions: categorias.map((c) => ({ value: String(c.id), label: c.nombre })),
      },
      {
        key: 'marcaFiltro',
        label: 'Marca',
        soloFiltro: true,
        filterType: 'select',
        filterOptions: marcas.map((m) => ({ value: String(m.id), label: m.nombre })),
      },
      { key: 'movimiento', label: 'Días sin movimiento', soloFiltro: true, filterType: 'select', filterOptions: OPCIONES_MOVIMIENTO },
      {
        key: 'sinStock',
        label: 'Incluir sin stock',
        soloFiltro: true,
        filterType: 'select',
        filterOptions: [
          { value: 'si', label: 'Sí' },
          { value: 'no', label: 'No' },
        ],
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
      { key: 'stockDesde', label: 'Stock desde', soloFiltro: true },
      { key: 'stockHasta', label: 'Stock hasta', soloFiltro: true },

      {
        key: 'foto',
        label: 'Foto',
        width: 64,
        filterable: false,
        sortable: false,
        render: (r) =>
          r.foto ? (
            <img src={urlImagen(r.foto)} alt={r.producto} loading="lazy" className="size-10 rounded-field border border-line object-cover" />
          ) : (
            <span className="grid size-10 place-items-center rounded-field border border-dashed border-line text-ink-soft">
              <ImageOff size={16} />
            </span>
          ),
      },
      { key: 'codigo', label: 'Código', width: 90, filterable: false, value: (r) => r.codigo, render: (r) => r.codigo },
      {
        key: 'producto',
        label: 'Producto',
        width: 250,
        filterable: false,
        // Lo que busca el buscador de la tabla.
        value: (r) => `${r.producto} ${r.codigo} ${r.marca ?? ''} ${r.categoria}`,
        render: (r) => <span className="font-medium text-ink">{r.producto}</span>,
      },
      { key: 'marca', label: 'Marca', width: 130, filterable: false, value: (r) => r.marca ?? '', render: (r) => r.marca ?? '—' },
      { key: 'categoria', label: 'Categoría', width: 140, filterable: false, value: (r) => r.categoria, render: (r) => r.categoria },
      {
        key: 'ultimaVenta',
        label: 'Última venta',
        width: 110,
        filterable: false,
        // Los que nunca se vendieron, como los más viejos.
        value: (r) => r.diasSinVenta + (r.nuncaVendido ? 100000 : 0),
        render: (r) => (r.ultimaVenta ? fechaDia(r.ultimaVenta) : <span className="text-ink-soft">Nunca</span>),
      },
      {
        key: 'diasSinVenta',
        label: 'Días sin venta',
        width: 110,
        align: 'right',
        filterable: false,
        value: (r) => r.diasSinVenta,
        render: (r) => (
          <span className="font-medium" style={{ color: colorDeDias(r.diasSinVenta) }}>
            {r.diasSinVenta}
          </span>
        ),
      },
      {
        key: 'existencia',
        label: 'Stock',
        width: 110,
        align: 'right',
        filterable: false,
        value: (r) => r.stock,
        render: (r) =>
          r.stock > 0 ? `${cantidad(r.stock)} ${r.unidadBase}` : <span className="text-ink-soft">Sin stock</span>,
      },
      {
        key: 'costoStock',
        label: 'Costo stock',
        width: 120,
        align: 'right',
        filterable: false,
        value: (r) => r.costoStock,
        render: (r) => (r.costoStock > 0 ? soles(r.costoStock) : <span className="text-ink-soft">—</span>),
      },
      {
        key: 'ultimaCompra',
        label: 'Última compra',
        width: 115,
        filterable: false,
        value: (r) => r.ultimaCompra ?? '',
        render: (r) => (r.ultimaCompra ? fechaDia(r.ultimaCompra) : <span className="text-ink-soft">—</span>),
      },
      {
        key: 'anterior',
        label: 'Anterior',
        width: 110,
        align: 'right',
        filterable: false,
        value: (r) => r.anterior,
        render: (r) => valorDe(r.anterior),
      },
      {
        key: 'actual',
        label: 'Actual',
        width: 110,
        align: 'right',
        filterable: false,
        value: (r) => r.actual,
        render: (r) => <span className="font-medium">{valorDe(r.actual)}</span>,
      },
      {
        key: 'variacion',
        label: 'Variación',
        width: 120,
        align: 'right',
        filterable: false,
        value: (r) => r.variacion,
        render: (r) => (
          <span className={`font-semibold ${colorCambio(r.variacion)}`}>
            {r.variacion < 0 ? '−' : r.variacion > 0 ? '+' : ''}
            {valorDe(Math.abs(r.variacion))}
          </span>
        ),
      },
      {
        key: 'caidaPct',
        label: '% caída',
        width: 90,
        align: 'right',
        filterable: false,
        value: (r) => r.caidaPct ?? -999,
        render: (r) =>
          r.caidaPct === null ? (
            <span className="text-ink-soft">—</span>
          ) : (
            <span className={colorCambio(-r.caidaPct)}>{porcentaje(-r.caidaPct)}</span>
          ),
      },
      {
        key: 'perdida',
        label: 'Pérdida',
        width: 110,
        align: 'right',
        filterable: false,
        value: (r) => r.perdida,
        render: (r) => (r.perdida > 0 ? <span className="font-semibold text-red-600">{valorDe(r.perdida)}</span> : '—'),
      },
      {
        key: 'estado',
        label: 'Estado',
        width: 130,
        filterable: false,
        value: (r) => ORDEN_ESTADOS.indexOf(r.estado),
        render: (r) => <EtiquetaEstado estado={r.estado} />,
      },
    ],
    [almacenes, categorias, marcas, valorDe],
  )

  // Las tarjetas, la dona y los gráficos miden todos los productos; la tabla, además, lo que se acota aquí.
  const items = useMemo(
    () =>
      (datos?.items ?? []).filter((f) => {
        if (estado === 'CAIDA' ? !EN_CAIDA.includes(f.estado) : estado && f.estado !== estado) return false
        if (locales.stock === 'con' && f.stock <= 0) return false
        if (locales.stock === 'sin' && f.stock > 0) return false
        if (locales.stockDesde !== undefined && f.stock < locales.stockDesde) return false
        if (locales.stockHasta !== undefined && f.stock > locales.stockHasta) return false
        if (locales.movimiento === 'sin_ventas') return f.nuncaVendido
        if (locales.movimiento && f.diasSinVenta < Number(locales.movimiento)) return false
        return true
      }),
    [datos, estado, locales],
  )

  const resumen = datos?.resumen
  const estados = datos?.estados ?? []
  const totalProductos = estados.reduce((s, e) => s + e.productos, 0)

  // La evolución es la de lo que se ve: la del estado elegido, o la de todos los que cayeron.
  const claveSerie = estado && estado !== 'CAIDA' ? estado : 'TODOS'
  const serie = datos?.evolucion.find((s) => s.clave === claveSerie)
  const perdidaSerie =
    claveSerie === 'TODOS'
      ? estados.filter((e) => e.estado !== 'SIN_BASE').reduce((s, e) => s + e.perdida, 0)
      : (estados.find((e) => e.estado === claveSerie)?.perdida ?? 0)

  const etiquetas = useMemo(
    () => (serie?.puntos ?? []).map((p) => (datos?.granularidad === 'dia' ? `${Number(p.etiqueta.slice(8, 10))}/${Number(p.etiqueta.slice(5, 7))}` : mesCorto(p.etiqueta))),
    [serie, datos?.granularidad],
  )
  const etiquetasLargas = useMemo(
    () =>
      (serie?.puntos ?? []).map((p) =>
        datos?.granularidad === 'dia' ? fechaDia(p.etiqueta) : `${mesCorto(p.etiqueta)} ${p.etiqueta.slice(0, 4)}`,
      ),
    [serie, datos?.granularidad],
  )

  const categoriasCaida = (datos?.porCategoria ?? []).map((c) => ({
    nombre: c.categoria,
    valor: -c.variacion,
    detalle: c.caidaPct === null ? 'sin comparación' : `${c.caidaPct.toFixed(1)} % de caída`,
  }))

  /** Lo que se ve en la tabla (con sus filtros y la tarjeta elegida), en un Excel. */
  const exportar = () =>
    exportarExcel(
      `productos-sin-ventas-${filtros.desde}_${filtros.hasta}`,
      items.map((f) => ({
        Código: f.codigo,
        Producto: f.producto,
        Marca: f.marca,
        Categoría: f.categoria,
        'Última venta': f.ultimaVenta ? f.ultimaVenta.slice(0, 10) : null,
        'Días sin venta': f.diasSinVenta,
        Stock: f.stock,
        Unidad: f.unidadBase,
        'Costo stock': f.costoStock,
        'Última compra': f.ultimaCompra ? f.ultimaCompra.slice(0, 10) : null,
        Anterior: f.anterior,
        Actual: f.actual,
        Variación: f.variacion,
        '% Caída': f.caidaPct === null ? null : Math.round(f.caidaPct * 10) / 10,
        Pérdida: f.perdida,
        Estado: ESTADOS_UI[f.estado].etiqueta,
      })),
    )

  return (
    <ListPage
      icon={<PackageX size={20} />}
      title="Productos sin ventas"
      description={`Ventas de cada producto frente a ${referencia}.`}
      actions={
        <Button variant="secondary" size="sm" disabled={items.length === 0} onClick={exportar} iconRight={<FileSpreadsheet size={15} />}>
          Exportar Excel
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      banner={
        <div className="space-y-4">
          {/* Una tarjeta por estado, más la de los que ya cayeron: son filtros. */}
          <section className="grid gap-3 sm:grid-cols-2 xl:grid-cols-6">
            <TarjetaReporte
              titulo="Productos sin ventas"
              valor={resumen?.enCaida ?? 0}
              detalle={`Venta perdida ${valorDe(resumen?.ventaPerdida ?? 0)}`}
              icono={PackageX}
              color="#dc2626"
              activa={estado === 'CAIDA'}
              onClick={() => setEstado(estado === 'CAIDA' ? undefined : 'CAIDA')}
            />
            {ORDEN_ESTADOS.map((e) => {
              const ui = ESTADOS_UI[e]
              const fila = estados.find((r) => r.estado === e)
              return (
                <TarjetaReporte
                  key={e}
                  titulo={ui.etiqueta}
                  nota={rangoDe(e, criterio, comparar)}
                  valor={fila?.productos ?? 0}
                  detalle={
                    e === 'SIN_BASE'
                      ? criterio === 'dias'
                        ? 'sin ninguna venta'
                        : `no vendieron ${referencia}`
                      : `${soles(fila?.costoStock ?? 0)} en stock`
                  }
                  icono={ICONO_ESTADO[e]}
                  color={ui.color}
                  activa={estado === e}
                  onClick={() => setEstado(estado === e ? undefined : e)}
                />
              )
            })}
          </section>

          <section className="grid gap-4 lg:grid-cols-3">
            <Marco
              titulo="Categorías con mayor caída"
              subtitulo="Venta perdida y % de caída"
              cargando={cargando && !datos}
              vacio={categoriasCaida.length === 0}
              mensajeVacio="Ninguna categoría vendió menos en este tramo"
              alto={220}
            >
              <HBarChart items={categoriasCaida} formato={(n) => (enSoles ? moneda(n) : `${cantidad(n)} u.`)} unColor="#dc2626" />
            </Marco>

            <Marco
              titulo="Evolución de ventas"
              subtitulo={
                datos && serie ? (
                  <>
                    Anterior <b>{valorDe(serie.anterior)}</b> · actual <b>{valorDe(serie.actual)}</b> · perdida{' '}
                    <b className="text-red-600">{valorDe(perdidaSerie)}</b>
                  </>
                ) : undefined
              }
              cargando={cargando && !datos}
              vacio={!serie || serie.puntos.every((p) => p.anterior === 0 && p.actual === 0)}
              mensajeVacio="Sin ventas para comparar en este tramo"
              alto={220}
            >
              {serie && (
                <LineChart
                  alto={220}
                  etiquetas={etiquetas}
                  etiquetasLargas={etiquetasLargas}
                  formato={valorDe}
                  series={[
                    {
                      id: 'anterior',
                      nombre: comparar === 'anio' ? 'Año anterior' : 'Período anterior',
                      color: '#94a3b8',
                      punteada: true,
                      valores: serie.puntos.map((p) => p.anterior),
                    },
                    { id: 'actual', nombre: 'Período actual', color: '#2563eb', area: true, valores: serie.puntos.map((p) => p.actual) },
                  ]}
                />
              )}
            </Marco>

            <Marco
              titulo="Distribución por estado"
              subtitulo={datos ? `${totalProductos} ${totalProductos === 1 ? 'producto' : 'productos'} analizados` : undefined}
              cargando={cargando && !datos}
              vacio={!!datos && totalProductos === 0}
              mensajeVacio="No hay productos para analizar"
              alto={168}
            >
              <DonutChart
                porciones={ORDEN_ESTADOS.filter((e) => (estados.find((r) => r.estado === e)?.productos ?? 0) > 0).map((e) => ({
                  nombre: ESTADOS_UI[e].etiqueta,
                  valor: estados.find((r) => r.estado === e)?.productos ?? 0,
                  color: ESTADOS_UI[e].color,
                }))}
                formato={(n) => String(n)}
                decimalesPct={1}
                centro={{ titulo: 'productos', valor: String(totalProductos) }}
              />
            </Marco>
          </section>
        </div>
      }
      columns={columnas}
      rows={items}
      rowKey="productoId"
      onConsulta={aplicar}
      filtrosIniciales={[
        { column: 'fecha', operator: 'between', value: desdeInicial, valueTo: hastaInicial },
        { column: 'comparar', operator: 'equals', value: 'mes' },
        { column: 'medida', operator: 'equals', value: 'soles' },
        { column: 'criterio', operator: 'equals', value: 'variacion' },
      ]}
      pageSize={15}
      cardIcon={PackageX}
      searchPlaceholder="Buscar producto, código, marca o categoría..."
      empty={cargando ? 'Cargando productos...' : 'No hay productos con estos filtros.'}
    />
  )
}
