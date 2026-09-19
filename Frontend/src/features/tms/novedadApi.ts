import { api } from '../../lib/apiClient'
import type { ConsultaTabla } from '../../components/ui'
import type { PaginaResponse } from '../../lib/paginacion'

// --- Novedades de entrega ---
//
// Lo que no se entregó completo: un producto que quedó corto al convertir el
// pedido en venta, o un pedido entero que no se pudo entregar. Cada una lleva
// el motivo que eligió quien entregó y, si la mercadería volvía en el camión,
// lo que el encargado encontró al contarla.

/** LINEA: un producto se entregó en menos. PEDIDO: no se entregó el pedido entero. */
export type TipoNovedad = 'LINEA' | 'PEDIDO'

/**
 * PENDIENTE: volvió en el camión y nadie la contó. RECIBIDA: se contó y está.
 * FALTANTE: no volvió completa. SIN_RETORNO: nunca salió del almacén.
 * ANULADA: la venta o el pedido cambió y ya no aplica.
 */
export type EstadoNovedad = 'PENDIENTE' | 'RECIBIDA' | 'FALTANTE' | 'SIN_RETORNO' | 'ANULADA'

export interface NovedadResponse {
  id: number
  tipo: TipoNovedad
  fecha: string
  estado: EstadoNovedad
  pedidoId: number
  pedido: string
  cliente: string
  despachoId: number | null
  despacho: string | null
  notaVentaId: number | null
  notaVenta: string | null
  productoId: number
  codigo: string
  producto: string
  /** En qué presentación se pidió: "Caja 12UND". */
  presentacion: string | null
  /** Unidades base que trae esa presentación. */
  factor: number
  unidadBase: string
  // Todo en unidad base: se muestra partido en cajas y sueltas.
  cantidadPedida: number
  cantidadEntregada: number
  cantidadNoEntregada: number
  /** Cuánto valen S/ las unidades que no se entregaron. */
  importe: number
  motivoId: number
  motivo: string
  /** Si la mercadería salió en el camión y hay que esperarla de vuelta. */
  regresaAlAlmacen: boolean
  observacion: string | null
  usuario: string | null
  cantidadRegresada: number | null
  verificadoPor: string | null
  verificadoEn: string | null
  observacionVerificacion: string | null
}

export interface ResumenNovedades {
  total: number
  /** Esperando que el encargado cuente lo que volvió. */
  porRevisar: number
  recibidas: number
  faltantes: number
  /** Cuánto valen S/ todas las unidades no entregadas. */
  importe: number
}

export interface VerificarNovedadRequest {
  estado: 'RECIBIDA' | 'FALTANTE'
  /** Cuánto volvió, en unidad base. Solo cuenta en FALTANTE. */
  cantidadRegresada?: number | null
  observacion?: string | null
}

export const novedadApi = {
  /** Una página del listado, ya buscada, filtrada y ordenada en el servidor. */
  listar: (consulta: ConsultaTabla) =>
    api.post<PaginaResponse<NovedadResponse>>('/novedad/listar', consulta),
  resumen: () => api.get<ResumenNovedades>('/novedad/resumen'),
  /** El encargado cuenta lo que volvió en el camión: llegó completo o faltó. */
  verificar: (id: number, body: VerificarNovedadRequest) =>
    api.patch<NovedadResponse>(`/novedad/${id}/verificar`, body),
  /** Deshace una revisión: se contó mal y vuelve a quedar pendiente. */
  reabrir: (id: number) => api.patch<NovedadResponse>(`/novedad/${id}/reabrir`),
}

const redondear = (n: number) => Math.round(n * 10000) / 10000

/**
 * Una cantidad en unidad base, dicha como se cuenta en el almacén: 113
 * unidades de una caja de 12 son "9 Caja 12UND + 5 UND".
 */
export function textoCantidad(
  base: number,
  factor: number,
  presentacion: string | null,
  unidadBase: string,
): string {
  if (factor <= 1 || !presentacion) return `${redondear(base)} ${unidadBase}`

  const cajas = Math.floor(base / factor + 1e-6)
  const sueltas = redondear(base - cajas * factor)
  const partes: string[] = []
  if (cajas > 0) partes.push(`${cajas} ${presentacion}`)
  if (sueltas > 0) partes.push(`${sueltas} ${unidadBase}`)
  return partes.length ? partes.join(' + ') : `0 ${unidadBase}`
}
