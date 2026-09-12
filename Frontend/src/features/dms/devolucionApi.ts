import { api } from '../../lib/apiClient'

export type EstadoDevolucion = 'SOLICITADA' | 'APROBADA' | 'RECHAZADA'

export interface LineaDevolucionResponse {
  id: number
  notaVentaDetalleId: number
  productoId: number
  codigo: string
  producto: string
  unidadBase: string
  presentacion: string | null
  cantidadPresentacion: number
  cantidad: number
  precioUnitario: number
  importe: number
  /** Si volvió al stock vendible. En falso entró y salió como merma. */
  reingresaStock: boolean
}

export interface DevolucionResponse {
  id: number
  numero: string
  fecha: string
  notaVentaId: number
  notaVenta: string
  clienteId: number
  cliente: string
  almacenId: number
  almacen: string
  estado: EstadoDevolucion
  motivo: string | null
  observacion: string | null
  motivoRechazo: string | null
  usuario: string | null
  aprobadoPor: string | null
  resueltaEn: string | null
  total: number
  detalle: LineaDevolucionResponse[]
}

/** Una línea de la venta, con lo que ya se devolvió de ella. */
export interface LineaDevolvible {
  notaVentaDetalleId: number
  productoId: number
  codigo: string
  producto: string
  unidadBase: string
  presentacion: string | null
  vendida: number
  /** Lo ya devuelto: aprobado, más lo que espera aprobación. */
  devuelta: number
  /** Vendida − devuelta: el tope de esta devolución. */
  disponible: number
  precioUnitario: number
}

export interface ResumenDevoluciones {
  total: number
  solicitadas: number
  aprobadas: number
  importe: number
}

export interface LineaDevolucionRequest {
  notaVentaDetalleId: number
  cantidad: number
  reingresaStock: boolean
}

export interface DevolucionRequest {
  notaVentaId: number
  motivo?: string | null
  observacion?: string | null
  detalle: LineaDevolucionRequest[]
}

export const devolucionApi = {
  getAll: (estado?: string) =>
    api.get<DevolucionResponse[]>(`/devolucion${estado ? `?estado=${estado}` : ''}`),
  getById: (id: number) => api.get<DevolucionResponse>(`/devolucion/${id}`),
  resumen: () => api.get<ResumenDevoluciones>('/devolucion/resumen'),

  /** Lo que todavía se puede devolver de una venta. */
  devolvible: (notaVentaId: number) =>
    api.get<LineaDevolvible[]>(`/devolucion/devolvible/${notaVentaId}`),

  create: (body: DevolucionRequest) => api.post<DevolucionResponse>('/devolucion', body),

  aprobar: (id: number) => api.patch<DevolucionResponse>(`/devolucion/${id}/aprobar`),
  rechazar: (id: number, motivo: string) =>
    api.patch<DevolucionResponse>(`/devolucion/${id}/rechazar`, { motivo }),
}
