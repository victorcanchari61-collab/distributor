import { api } from '../../lib/apiClient'
import type { PeriodoCrm, RangoCrm, VentanasCrm } from './crmApi'

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
  rango: RangoCrm
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

// --- Mercados y rutas ---

export type AgruparZonas = 'mercado' | 'ruta'

export interface ZonaCrm {
  /** Null: los clientes sin mercado (o sin ruta) asignado. */
  zonaId: number | null
  nombre: string
  clientes: number
  conVentas: number
  criticos: number
  altos: number
  inactivos: number
  nuevos: number
  actual: number
  anterior: number
  diferencia: number
  variacion: number | null
  /** Lo que dejaron de comprar los clientes que bajaron. */
  ventaPerdida: number
  saldoPorCobrar: number
}

export interface ZonasCrm {
  ventanas: VentanasCrm
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

export const crmReportesApi = {
  productosSinVentas: (c: ConsultaProductosCrm) =>
    api.get<ProductosSinVentasCrm>(`/crm/productos${queryProductos(c)}`),
  zonas: (periodo: PeriodoCrm, agrupar: AgruparZonas) =>
    api.get<ZonasCrm>(`/crm/zonas?periodo=${periodo}&agrupar=${agrupar}`),
}
