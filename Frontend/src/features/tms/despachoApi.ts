import { api } from '../../lib/apiClient'

export type EstadoDespacho = 'ARMADO' | 'ANULADO'

/** Un pedido dentro del camión, con lo que hace falta para repartirlo. */
export interface DespachoPedidoResponse {
  pedidoId: number
  numero: string
  clienteId: number
  cliente: string
  direccion: string | null
  mercado: string | null
  telefono: string | null
  total: number
  lineas: number
  /** La venta, si el repartidor ya lo convirtió. */
  notaVentaId: number | null
  notaVentaNumero: string | null
}

export interface DespachoResponse {
  id: number
  numero: string
  fecha: string
  rutaId: number
  ruta: string
  vehiculoId: number
  /** La placa: es como se nombra a un camión de verdad. */
  vehiculo: string
  conductorId: number
  conductor: string
  estado: EstadoDespacho
  observacion: string | null
  usuario: string | null
  pedidos: number
  total: number
  /** Cuántos de esos pedidos ya se convirtieron en venta. */
  entregados: number
  detalle: DespachoPedidoResponse[]
}

export interface ResumenDespachos {
  total: number
  armados: number
  /** Pedidos que están en un camión y todavía no se entregaron. */
  pedidosEnRuta: number
}

export interface DespachoRequest {
  fecha?: string | null
  rutaId: number
  vehiculoId: number
  conductorId: number
  observacion?: string | null
  pedidoIds: number[]
}

export const despachoApi = {
  getAll: (estado?: string) =>
    api.get<DespachoResponse[]>(`/despacho${estado ? `?estado=${estado}` : ''}`),
  getById: (id: number) => api.get<DespachoResponse>(`/despacho/${id}`),
  resumen: () => api.get<ResumenDespachos>('/despacho/resumen'),

  /**
   * Los pedidos que se pueden cargar en esa ruta.
   *
   * `despachoId` se manda al editar: sin él, los pedidos que ya son de ese
   * despacho se verían como tomados y desaparecerían de la pantalla.
   */
  disponibles: (rutaId: number, despachoId?: number) =>
    api.get<DespachoPedidoResponse[]>(
      `/despacho/disponibles?rutaId=${rutaId}${despachoId ? `&despachoId=${despachoId}` : ''}`,
    ),

  create: (body: DespachoRequest) => api.post<DespachoResponse>('/despacho', body),
  update: (id: number, body: DespachoRequest) => api.put<DespachoResponse>(`/despacho/${id}`, body),
  anular: (id: number) => api.patch<DespachoResponse>(`/despacho/${id}/anular`),
}
