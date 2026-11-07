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
  /** La solicitud del almacén de la que nació, si nació de una. */
  solicitudCompraId: number | null
  solicitudNumero: string | null
  total: number
  detalle: LineaCompraResponse[]
}

export interface CrearOrdenCompraRequest {
  proveedorId: number
  /** La solicitud del almacén de la que sale esta orden: la solicitud pasa a Atendida. */
  solicitudCompraId?: number | null
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
    api.post<PaginaResponse<OrdenCompraFila>>('/ordencompra/listar', consulta),

  resumen: () => api.get<ResumenOrdenesCompra>('/ordencompra/resumen'),

  getAll: (estado?: string) =>
    api.get<OrdenCompraResponse[]>(`/ordencompra${estado ? `?estado=${estado}` : ''}`),
  getById: (id: number) => api.get<OrdenCompraResponse>(`/ordencompra/${id}`),
  create: (body: CrearOrdenCompraRequest) =>
    api.post<OrdenCompraResponse>('/ordencompra', body),
  update: (id: number, body: CrearOrdenCompraRequest) =>
    api.put<OrdenCompraResponse>(`/ordencompra/${id}`, body),
  confirmar: (id: number) => api.patch<OrdenCompraResponse>(`/ordencompra/${id}/confirmar`),
  /** Como un pedido a venta: la orden se cierra y nace su compra con lo revisado. */
  convertir: (id: number, body: CrearCompraRequest) =>
    api.post<CompraResponse>(`/ordencompra/${id}/convertir`, body),
  anular: (id: number) => api.patch<void>(`/ordencompra/${id}/anular`),
}

// --- Solicitudes de compra ---

export type EstadoSolicitudCompra = 'PENDIENTE' | 'ATENDIDA' | 'RECHAZADA' | 'ANULADA'
export type UrgenciaSolicitud = 'NORMAL' | 'URGENTE'

export interface OrdenDeSolicitud {
  id: number
  numero: string
  estado: EstadoOrdenCompra
}

export interface SolicitudCompraFila {
  id: number
  numero: string
  fecha: string
  almacenId: number
  almacen: string
  urgencia: UrgenciaSolicitud
  estado: EstadoSolicitudCompra
  observacion: string | null
  motivoRechazo: string | null
  usuarioId: number | null
  solicitante: string | null
  lineas: number
  /** Las órdenes de compra que se hicieron con ella. */
  ordenes: OrdenDeSolicitud[]
}

export interface LineaSolicitudCompraResponse {
  id: number
  productoId: number
  codigo: string
  producto: string
  unidadBase: string
  presentacionId: number | null
  presentacion: string | null
  factor: number
  cantidadPresentacion: number
  cantidad: number
  nota: string | null
  /** Lo que suele costar una presentación, para sugerirlo al armar la orden. */
  costoSugerido: number | null
}

export interface SolicitudCompraResponse extends SolicitudCompraFila {
  detalle: LineaSolicitudCompraResponse[]
}

export interface CrearSolicitudCompraRequest {
  almacenId: number
  urgencia?: UrgenciaSolicitud | null
  observacion?: string | null
  detalle: { productoId: number; presentacionId?: number | null; cantidad: number; nota?: string | null }[]
}

/** Un producto bajo su mínimo en el almacén, con lo que se sugiere pedir (en unidad base). */
export interface SugerenciaSolicitud {
  productoId: number
  codigo: string
  producto: string
  unidadBase: string
  stock: number
  stockMinimo: number
  cantidadSugerida: number
}

export const solicitudCompraApi = {
  getAll: (estado?: string) =>
    api.get<SolicitudCompraFila[]>(`/solicitudcompra${estado ? `?estado=${estado}` : ''}`),
  getById: (id: number) => api.get<SolicitudCompraResponse>(`/solicitudcompra/${id}`),
  sugerencias: (almacenId: number) =>
    api.get<SugerenciaSolicitud[]>(`/solicitudcompra/sugerencias?almacenId=${almacenId}`),
  create: (body: CrearSolicitudCompraRequest) =>
    api.post<SolicitudCompraResponse>('/solicitudcompra', body),
  update: (id: number, body: CrearSolicitudCompraRequest) =>
    api.put<SolicitudCompraResponse>(`/solicitudcompra/${id}`, body),
  /** Quien la pidió la retira (solo Pendiente). */
  anular: (id: number) => api.del<void>(`/solicitudcompra/${id}`),
  /** Compras no la atiende y dice por qué. */
  rechazar: (id: number, motivo: string) =>
    api.post<SolicitudCompraResponse>(`/solicitudcompra/${id}/rechazar`, { motivo }),
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
  /** En efectivo, salió de la Bóveda y no de la caja de quien pagó. */
  desdeBoveda: boolean
}

export interface PagoCompraRequest {
  metodoPagoId: number
  monto: number
  /** Solo en efectivo: sale de la Bóveda en vez de la caja de quien paga. */
  desdeBoveda?: boolean
}

/**
 * La Bóveda como opción del método en efectivo. No es un método del catálogo: es de dónde sale
 * la plata. En el selector vale este número, y al guardar se manda como Efectivo + desdeBoveda.
 */
export const PAGO_BOVEDA = -1

/** El pago listo para el API: la opción Bóveda pasa a ser Efectivo desde la Bóveda. */
export const aPagoCompra = (metodoPagoId: number, monto: number, efectivoId: number | undefined): PagoCompraRequest =>
  metodoPagoId === PAGO_BOVEDA ? { metodoPagoId: efectivoId ?? 0, monto, desdeBoveda: true } : { metodoPagoId, monto }

/** El valor del selector para un pago guardado: la Bóveda vuelve a ser su opción. */
export const metodoDePago = (pago: { metodoPagoId: number; desdeBoveda?: boolean }) =>
  pago.desdeBoveda ? PAGO_BOVEDA : pago.metodoPagoId

/** La opción Bóveda, para sumarla a los métodos en efectivo. */
export const OPCION_BOVEDA = { value: PAGO_BOVEDA, label: 'Bóveda', detalle: 'El efectivo de la empresa' }

/**
 * Una compra como fila de un listado (Compras, Cuentas por pagar): solo lo que
 * muestra la tabla. El detalle y los pagos vienen con getById al abrirla.
 */
/** Una orden como fila del listado: sin sus líneas (vienen con getById). */
export interface OrdenCompraFila {
  id: number
  numero: string
  proveedorId: number
  proveedor: string
  fecha: string
  fechaEsperada: string | null
  estado: OrdenCompraResponse['estado']
  usuario: string | null
  total: number
}

export interface CompraFila {
  id: number
  numero: string
  proveedorId: number
  proveedor: string
  ordenCompraNumero: string | null
  fecha: string
  estado: CompraResponse['estado']
  tipoComprobante: CompraResponse['tipoComprobante']
  serieComprobante: string | null
  numeroComprobante: string | null
  formaPago: CompraResponse['formaPago']
  total: number
  totalPagado: number
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
    api.post<PaginaResponse<CompraFila>>('/compra/listar', consulta),

  resumen: () => api.get<ResumenCompras>('/compra/resumen'),

  /** Una página de las cuentas por pagar, con el saldo resuelto en el servidor. */
  listarCuentasPorPagar: (consulta: ConsultaTabla) =>
    api.post<PaginaResponse<CompraFila>>('/compra/cuentasporpagar/listar', consulta),

  resumenCuentasPorPagar: () => api.get<ResumenCuentas>('/compra/cuentasporpagar/resumen'),

  /** Las compras que todavía esperan mercadería, sin paginar: son pocas. */
  abiertas: () => api.get<CompraResponse[]>('/compra/abiertas'),

  /** Solo los números de las compras que ya tienen recepción: el filtro de Recepciones. */
  conRecepcion: () => api.get<string[]>('/compra/con-recepcion'),

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
