import { api } from '../../lib/apiClient'
import type { ConsultaTabla } from '../../components/ui'
import type { PaginaResponse } from '../../lib/paginacion'
import type { ResumenCuentas } from '../facturacion/ventasApi'

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

/** Contadores del listado completo de órdenes de compra. */
export interface ResumenOrdenesCompra {
  total: number
  pendientes: number
  confirmadas: number
}

/** Contadores del listado completo de compras. */
export interface ResumenCompras {
  total: number
  porRecibir: number
  recibidas: number
}

export const ordenCompraApi = {
  /** Una página del listado, ya buscada, filtrada y ordenada en el servidor. */
  listar: (consulta: ConsultaTabla) =>
    api.post<PaginaResponse<OrdenCompraResponse>>('/ordencompra/listar', consulta),

  resumen: () => api.get<ResumenOrdenesCompra>('/ordencompra/resumen'),

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

/** Un pago parcial: un método del catálogo y cuánto se pagó con él. */
export interface PagoCompraResponse {
  id: number
  metodoPagoId: number
  metodoPago: string
  monto: number
  fecha: string
  usuario: string | null
  /** Se registró por error: no cuenta para el total pagado, pero se conserva en el historial. */
  anulado: boolean
}

export interface PagoCompraRequest {
  metodoPagoId: number
  monto: number
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
  observacion: string | null
  usuario: string | null
  total: number
  detalle: CompraDetalleResponse[]
  /** Puede ser más de un método — un pago mixto. */
  pagos: PagoCompraResponse[]
  /** Suma de pagos. Si es menor que total, falta esa diferencia por pagar. */
  totalPagado: number
}

export interface CrearCompraRequest {
  proveedorId: number
  fecha?: string | null
  tipoComprobante?: TipoComprobanteCompra | null
  serieComprobante?: string | null
  numeroComprobante?: string | null
  formaPago?: FormaPagoCompra | null
  /** Pago mixto: una línea por método usado, o ninguna si todavía no se paga nada. */
  pagos?: PagoCompraRequest[]
  observacion?: string | null
  detalle: LineaCompraRequest[]
}

export const compraApi = {
  /** Una página del listado, ya buscada, filtrada y ordenada en el servidor. */
  listar: (consulta: ConsultaTabla) =>
    api.post<PaginaResponse<CompraResponse>>('/compra/listar', consulta),

  resumen: () => api.get<ResumenCompras>('/compra/resumen'),

  /** Una página de las cuentas por pagar, con el saldo resuelto en el servidor. */
  listarCuentasPorPagar: (consulta: ConsultaTabla) =>
    api.post<PaginaResponse<CompraResponse>>('/compra/cuentasporpagar/listar', consulta),

  resumenCuentasPorPagar: () => api.get<ResumenCuentas>('/compra/cuentasporpagar/resumen'),

  /** Las compras que todavía esperan mercadería, sin paginar: son pocas. */
  abiertas: () => api.get<CompraResponse[]>('/compra/abiertas'),

  getAll: (estado?: string) =>
    api.get<CompraResponse[]>(`/compra${estado ? `?estado=${estado}` : ''}`),
  getById: (id: number) => api.get<CompraResponse>(`/compra/${id}`),
  create: (body: CrearCompraRequest) => api.post<CompraResponse>('/compra', body),
  /** Solo si la compra sigue Pendiente: sin nada recibido todavía. */
  update: (id: number, body: CrearCompraRequest) => api.put<CompraResponse>(`/compra/${id}`, body),
  anular: (id: number) => api.patch<void>(`/compra/${id}/anular`),
  /** Compras a crédito con saldo pendiente: la base de "Cuentas por pagar". */
  cuentasPorPagar: () => api.get<CompraResponse[]>('/compra/cuentasporpagar'),
  /** Registra un abono contra el saldo pendiente de la compra. */
  registrarPago: (id: number, body: PagoCompraRequest) =>
    api.post<CompraResponse>(`/compra/${id}/pagos`, body),
  /** Corrige un pago ya registrado: método o monto. */
  actualizarPago: (id: number, pagoId: number, body: PagoCompraRequest) =>
    api.put<CompraResponse>(`/compra/${id}/pagos/${pagoId}`, body),
  /** Quita un pago registrado por error: su monto vuelve al saldo pendiente. */
  anularPago: (id: number, pagoId: number) =>
    api.del<CompraResponse>(`/compra/${id}/pagos/${pagoId}`),
}
