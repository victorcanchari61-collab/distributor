import { api } from '../../lib/apiClient'

// --- Comun ---

export interface LineaCompraRequest {
  productoId: number
  presentacionId?: number | null
  cantidad: number
  /** Lo que vale UNA presentación completa: el saco entero, no el kilo. */
  costoPresentacion: number
}

export interface LineaCompraResponse {
  id: number
  productoId: number
  codigo: string
  producto: string
  unidadBase: string
  presentacionId: number | null
  presentacion: string | null
  cantidadPresentacion: number
  cantidad: number
  costoUnitario: number
  costoTotal: number
}

// --- Ordenes de compra ---

export type EstadoOrdenCompra = 'PENDIENTE' | 'CONFIRMADA' | 'ANULADA'

export interface OrdenCompraResponse {
  id: number
  numero: string
  proveedorId: number
  proveedor: string
  fecha: string
  fechaEsperada: string | null
  estado: EstadoOrdenCompra
  observacion: string | null
  usuario: string | null
  total: number
  detalle: LineaCompraResponse[]
}

export interface CrearOrdenCompraRequest {
  proveedorId: number
  fecha?: string | null
  fechaEsperada?: string | null
  observacion?: string | null
  detalle: LineaCompraRequest[]
}

export const ordenCompraApi = {
  getAll: (estado?: string) =>
    api.get<OrdenCompraResponse[]>(`/ordencompra${estado ? `?estado=${estado}` : ''}`),
  getById: (id: number) => api.get<OrdenCompraResponse>(`/ordencompra/${id}`),
  create: (body: CrearOrdenCompraRequest) =>
    api.post<OrdenCompraResponse>('/ordencompra', body),
  update: (id: number, body: CrearOrdenCompraRequest) =>
    api.put<OrdenCompraResponse>(`/ordencompra/${id}`, body),
  confirmar: (id: number) => api.patch<OrdenCompraResponse>(`/ordencompra/${id}/confirmar`),
  anular: (id: number) => api.patch<void>(`/ordencompra/${id}/anular`),
}

// --- Compras ---

export type EstadoCompra = 'PENDIENTE' | 'RECIBIDA_PARCIAL' | 'RECIBIDA_TOTAL' | 'ANULADA'

/** El comprobante que trae el proveedor por la compra. */
export type TipoComprobanteCompra = 'FACTURA' | 'BOLETA' | 'NOTA_VENTA'

/** Cómo se paga la compra al proveedor. */
export type FormaPagoCompra = 'CONTADO' | 'CREDITO'

export interface CompraDetalleResponse extends LineaCompraResponse {
  cantidadRecibida: number
  cantidadPendiente: number
}

export interface CompraResponse {
  id: number
  numero: string
  proveedorId: number
  proveedor: string
  ordenCompraId: number | null
  ordenCompraNumero: string | null
  fecha: string
  estado: EstadoCompra
  tipoComprobante: TipoComprobanteCompra
  serieComprobante: string | null
  numeroComprobante: string | null
  formaPago: FormaPagoCompra
  metodoPagoId: number | null
  metodoPago: string | null
  observacion: string | null
  usuario: string | null
  total: number
  detalle: CompraDetalleResponse[]
}

export interface CrearCompraRequest {
  proveedorId: number
  fecha?: string | null
  tipoComprobante?: TipoComprobanteCompra | null
  serieComprobante?: string | null
  numeroComprobante?: string | null
  formaPago?: FormaPagoCompra | null
  metodoPagoId?: number | null
  observacion?: string | null
  detalle: LineaCompraRequest[]
}

export const compraApi = {
  getAll: (estado?: string) =>
    api.get<CompraResponse[]>(`/compra${estado ? `?estado=${estado}` : ''}`),
  getById: (id: number) => api.get<CompraResponse>(`/compra/${id}`),
  create: (body: CrearCompraRequest) => api.post<CompraResponse>('/compra', body),
  anular: (id: number) => api.patch<void>(`/compra/${id}/anular`),
}
