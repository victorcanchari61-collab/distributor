import { api } from '../../lib/apiClient'
import type { EstadoClave, PeriodoCaida, Rango } from '../crm/crmApi'

// --- Productos sin ventas ---

export interface ProductoSinVentaCrm {
  productoId: number
  codigo: string
  producto: string
  categoriaId: number | null
  categoria: string | null
  marca: string | null
  unidadBase: string
  /** Lo que hay en todos los almacenes, en unidad base. */
  stock: number
  /** Ese stock a su costo: la plata parada. */
  valorStock: number
  /** El día de la última venta (de la zona si se filtró por una). Null: nunca se vendió. */
  ultimaVenta: string | null
  diasSinVender: number | null
  /** Con mercado o ruta: lo que sí se vendió en el mismo periodo en el resto de las zonas. */
  vendidoEnOtrasZonas: number
}

export interface ResumenProductosCrm {
  productosActivos: number
  sinVentas: number
  conStock: number
  sinStock: number
  nuncaVendidos: number
  capitalParado: number
}

export interface ProductosSinVentasCrm {
  dias: number
  rango: Rango
  mercado: string | null
  ruta: string | null
  resumen: ResumenProductosCrm
  items: ProductoSinVentaCrm[]
}

export interface ConsultaProductosCrm {
  dias: number
  mercadoId?: number
  rutaId?: number
  categoriaId?: number
  stock?: 'con' | 'sin'
}

// --- Productos con caída (el análisis de la pantalla Productos sin ventas) ---

export type CompararProductos = 'mes' | 'anio'
export type MedidaProductos = 'soles' | 'unidades'
export type CriterioProductos = 'variacion' | 'dias'

export interface PeriodoProductos {
  desde: string
  hasta: string
  anteriorDesde: string
  anteriorHasta: string
}

export interface FilaProductoCaida {
  productoId: number
  codigo: string
  producto: string
  foto: string | null
  marca: string | null
  categoriaId: number | null
  categoria: string
  unidadBase: string
  ultimaVenta: string | null
  nuncaVendido: boolean
  diasSinVenta: number
  stock: number
  costoStock: number
  ultimaCompra: string | null
  anterior: number
  actual: number
  variacion: number
  /** Positiva si vendió menos. Null: el tramo anterior no vendió, no hay con qué comparar. */
  caidaPct: number | null
  perdida: number
  estado: EstadoClave
}

export interface EstadoProductos {
  estado: EstadoClave
  productos: number
  costoStock: number
  perdida: number
}

export interface CategoriaCaida {
  categoria: string
  anterior: number
  actual: number
  variacion: number
  caidaPct: number | null
}

export interface PuntoEvolucion {
  /** AAAA-MM-DD (un día) o AAAA-MM (un mes) del tramo actual. */
  etiqueta: string
  anterior: number
  actual: number
}

export interface SerieEvolucion {
  /** "TODOS" (los que cayeron) o un estado. */
  clave: string
  anterior: number
  actual: number
  puntos: PuntoEvolucion[]
}

export interface ResumenProductosCaida {
  totalProductos: number
  enCaida: number
  conStock: number
  unidadesInmovilizadas: number
  stockInmovilizado: number
  ventaPerdida: number
}

export interface ProductosCaida {
  periodo: PeriodoProductos
  comparar: CompararProductos
  medida: MedidaProductos
  criterio: CriterioProductos
  granularidad: 'dia' | 'mes'
  corte: string
  resumen: ResumenProductosCaida
  estados: EstadoProductos[]
  porCategoria: CategoriaCaida[]
  evolucion: SerieEvolucion[]
  items: FilaProductoCaida[]
}

export interface ConsultaProductosCaida {
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

const queryAnalisis = (c: ConsultaProductosCaida) => {
  const partes = new URLSearchParams({
    desde: c.desde,
    hasta: c.hasta,
    comparar: c.comparar,
    medida: c.medida,
    criterio: c.criterio,
    incluirSinStock: String(c.incluirSinStock),
  })
  if (c.almacenId) partes.set('almacenId', String(c.almacenId))
  if (c.categoriaId) partes.set('categoriaId', String(c.categoriaId))
  if (c.marcaId) partes.set('marcaId', String(c.marcaId))
  return `?${partes.toString()}`
}

// --- Mercados y rutas ---

export type AgruparZonas = 'mercado' | 'ruta'

export interface ZonaCrm {
  /** Null: los clientes sin mercado (o sin ruta) asignado. */
  zonaId: number | null
  nombre: string
  clientes: number
  conVentas: number
  criticos: number
  enRiesgo: number
  enSeguimiento: number
  sinComparacion: number
  ventaAnterior: number
  ventaActual: number
  variacion: number
  /** Positiva si la zona cayó. Nula si el año anterior no vendió. */
  caidaPct: number | null
  /** Lo que dejaron de comprar los clientes que bajaron. */
  ventaPerdida: number
  saldoPorCobrar: number
}

export interface ZonasCrm {
  periodo: PeriodoCaida
  agrupar: AgruparZonas
  soloPropios: boolean
  items: ZonaCrm[]
}

const queryProductos = (c: ConsultaProductosCrm) => {
  const partes = new URLSearchParams({ dias: String(c.dias) })
  if (c.mercadoId) partes.set('mercadoId', String(c.mercadoId))
  if (c.rutaId) partes.set('rutaId', String(c.rutaId))
  if (c.categoriaId) partes.set('categoriaId', String(c.categoriaId))
  if (c.stock) partes.set('stock', c.stock)
  return `?${partes.toString()}`
}

export const sinVentasApi = {
  productosSinVentas: (c: ConsultaProductosCrm) => api.get<ProductosSinVentasCrm>(`/dashboard/sin-ventas${queryProductos(c)}`),
  analisis: (c: ConsultaProductosCaida) => api.get<ProductosCaida>(`/dashboard/sin-ventas/analisis${queryAnalisis(c)}`),
  zonas: (desde: string, hasta: string, agrupar: AgruparZonas, comparar: CompararProductos = 'mes') =>
    api.get<ZonasCrm>(`/dashboard/zonas?desde=${desde}&hasta=${hasta}&agrupar=${agrupar}&comparar=${comparar}`),
}
