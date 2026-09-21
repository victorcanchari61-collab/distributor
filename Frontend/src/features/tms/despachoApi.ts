import { api } from '../../lib/apiClient'

export type EstadoDespacho = 'ARMADO' | 'ANULADO'

/** Un pedido dentro del camión, con lo que hace falta para repartirlo. */
export interface DespachoPedidoResponse {
  pedidoId: number
  numero: string
  clienteId: number
  cliente: string
  clienteDocumento: string | null
  /** Cuándo se tomó el pedido. */
  fecha: string
  direccion: string | null
  mercado: string | null
  telefono: string | null
  /** La ruta del cliente y el día en que se lo visita: con varias rutas en el camión, dice de cuál es cada pedido. */
  rutaCliente: string | null
  diaVisita: string | null
  total: number
  lineas: number
  /** La venta, si el repartidor ya lo convirtió. */
  notaVentaId: number | null
  notaVentaNumero: string | null
  /** Por qué no se entregó, si se marcó entero como no entregado en este camión. */
  noEntregadoMotivo: string | null
  noEntregadoObservacion: string | null
  /** En cuántos productos se entregó menos de lo pedido. */
  lineasConNovedad: number
}

export interface DespachoResponse {
  id: number
  numero: string
  fecha: string
  /** De qué días son los pedidos que carga el camión. */
  pedidosDesde: string | null
  pedidosHasta: string | null
  /** La ruta principal (la primera). */
  rutaId: number
  /** Todas las rutas, dichas como se leen: "1 · 7". */
  ruta: string
  rutaIds: number[]
  rutas: string[]
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
  /** Cuántos pedidos se marcaron como no entregados. */
  noEntregados: number
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
  pedidosDesde?: string | null
  pedidosHasta?: string | null
  /** Las rutas que carga el camión ese día. Al menos una. */
  rutaIds: number[]
  vehiculoId: number
  conductorId: number
  observacion?: string | null
  pedidoIds: number[]
}

/** Lo que lleva el camión, para recortar el reporte de carga. */
export interface OpcionesCarga {
  mercados: { id: number; nombre: string; pedidos: number }[]
  unidades: { codigo: string; nombre: string; productos: number }[]
  /** Todos (0), primer, segundo y tercer corte, con el texto con que se muestran. */
  cortes: { codigo: number; nombre: string }[]
}

export const despachoApi = {
  opcionesCarga: (id: number) => api.get<OpcionesCarga>(`/despacho/${id}/carga/opciones`),

  getAll: (estado?: string) =>
    api.get<DespachoResponse[]>(`/despacho${estado ? `?estado=${estado}` : ''}`),
  getById: (id: number) => api.get<DespachoResponse>(`/despacho/${id}`),
  resumen: () => api.get<ResumenDespachos>('/despacho/resumen'),

  /**
   * Los pedidos que se pueden cargar en esas rutas.
   *
   * `despachoId` se manda al editar: sin él, los pedidos que ya son de ese
   * despacho se verían como tomados y desaparecerían de la pantalla.
   */
  disponibles: (rutaIds: number[], despachoId?: number, diaDeVisita?: string) =>
    api.get<DespachoPedidoResponse[]>(
      `/despacho/disponibles?${rutaIds.map((id) => `rutaIds=${id}`).join('&')}` +
        (despachoId ? `&despachoId=${despachoId}` : '') +
        // Solo los clientes que se visitan el día de esa fecha; sin ella salen de todos los días.
        (diaDeVisita ? `&diaDeVisita=${diaDeVisita}` : ''),
    ),

  create: (body: DespachoRequest) => api.post<DespachoResponse>('/despacho', body),
  update: (id: number, body: DespachoRequest) => api.put<DespachoResponse>(`/despacho/${id}`, body),
  anular: (id: number) => api.patch<DespachoResponse>(`/despacho/${id}/anular`),
}
