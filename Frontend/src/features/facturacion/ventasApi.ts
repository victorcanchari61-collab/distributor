import { api } from '../../lib/apiClient'
import type { AuditoriaResponse } from '../config'
import type { ConsultaTabla } from '../../components/ui'
import type { PaginaResponse } from '../../lib/paginacion'

// --- Comun ---

export interface LineaVentaRequest {
  /** Solo al editar un pedido: el id de la línea existente. Vacío es una línea nueva. */
  id?: number | null
  productoId: number
  presentacionId?: number | null
  cantidad: number
  /** Precio de venta de UNA presentación completa: la caja entera, no la unidad. */
  precioUnitario: number
  /** Solo al editar un pedido: si esta línea existente se quitó (nunca se borra, se anula). */
  anulado?: boolean
}

export interface LineaVentaResponse {
  id: number
  productoId: number
  codigo: string
  producto: string
  unidadBase: string
  presentacionId: number | null
  presentacion: string | null
  cantidadPresentacion: number
  cantidad: number
  precioUnitario: number
  subtotal: number
  /** Solo aplica a líneas de pedido: se quitó al editarlo, sin borrarse. */
  anulado: boolean
}

/** Cómo se paga una venta al cliente. */
export type FormaPagoVenta = 'CONTADO' | 'CREDITO'

/** Un pago parcial: un método del catálogo y cuánto se pagó con él. */
export interface PagoVentaRequest {
  metodoPagoId: number
  monto: number
}

export interface PagoVentaResponse {
  id: number
  metodoPagoId: number
  metodoPago: string
  monto: number
  fecha: string
  usuario: string | null
  /** Se registró por error: no cuenta para el total cobrado, pero se conserva en el historial. */
  anulado: boolean
}

/** Un cobro: un pago de una nota de venta, visto desde quién lo cobró. */
export interface CobroResponse {
  id: number
  fecha: string
  notaVentaId: number
  notaVentaNumero: string
  clienteId: number
  cliente: string
  metodoPagoId: number
  metodoPago: string
  monto: number
  /** Se anuló después de registrarse: no cuenta para el total cobrado. */
  anulado: boolean
}

// --- Pedidos ---

export type EstadoPedido = 'PENDIENTE' | 'CONFIRMADO' | 'ANULADO'

export interface PedidoResponse {
  id: number
  numero: string
  clienteId: number
  cliente: string
  listaPrecioId: number | null
  listaPrecio: string | null
  fecha: string
  estado: EstadoPedido
  observacion: string | null
  usuario: string | null
  reservaStock: boolean
  almacenId: number | null
  almacen: string | null
  total: number
  detalle: LineaVentaResponse[]
}

export interface CrearPedidoRequest {
  clienteId: number
  listaPrecioId?: number | null
  fecha?: string | null
  observacion?: string | null
  /** Si aparta stock de almacenId mientras el pedido siga Pendiente. */
  reservaStock: boolean
  /** Requerido cuando reservaStock es true. */
  almacenId?: number | null
  detalle: LineaVentaRequest[]
}

/** Un pedido no lleva pagos: la nota que nace al confirmarlo queda a crédito. */
export interface ConfirmarPedidoRequest {
  almacenId: number
}

/** Contadores del listado completo de pedidos, no de la página visible. */
export interface ResumenPedidos {
  total: number
  pendientes: number
  confirmados: number
}

/** Totales de las cuentas pendientes, calculados sobre todas y no una página. */
export interface ResumenCuentas {
  cuentas: number
  totalPendiente: number
  totalFacturado: number
  totalCubierto: number
}

/** Totales de los cobros de un usuario, sobre todo el rango y no una página. */
export interface ResumenCobros {
  validos: number
  anulados: number
  totalCobrado: number
}

/** Contadores del listado completo de notas de venta. */
export interface ResumenNotasVenta {
  total: number
  confirmadas: number
  totalVendido: number
}

export const pedidoApi = {
  /** Una página del listado, ya buscada, filtrada y ordenada en el servidor. */
  listar: (consulta: ConsultaTabla) =>
    api.post<PaginaResponse<PedidoResponse>>('/pedido/listar', consulta),

  resumen: () => api.get<ResumenPedidos>('/pedido/resumen'),

  getAll: (estado?: string) =>
    api.get<PedidoResponse[]>(`/pedido${estado ? `?estado=${estado}` : ''}`),
  getById: (id: number) => api.get<PedidoResponse>(`/pedido/${id}`),
  create: (body: CrearPedidoRequest) => api.post<PedidoResponse>('/pedido', body),
  update: (id: number, body: CrearPedidoRequest) => api.put<PedidoResponse>(`/pedido/${id}`, body),
  confirmar: (id: number, body: ConfirmarPedidoRequest) =>
    api.patch<PedidoResponse>(`/pedido/${id}/confirmar`, body),
  anular: (id: number) => api.patch<void>(`/pedido/${id}/anular`),
  /** Qué cambió en este pedido y sus líneas. */
  historial: (id: number) => api.get<AuditoriaResponse[]>(`/pedido/${id}/historial`),
}

// --- Notas de venta ---

export type EstadoNotaVenta = 'CONFIRMADA' | 'ANULADA'

export interface NotaVentaResponse {
  id: number
  numero: string
  clienteId: number
  cliente: string
  pedidoId: number | null
  pedidoNumero: string | null
  almacenId: number
  almacen: string
  fecha: string
  estado: EstadoNotaVenta
  formaPago: FormaPagoVenta
  observacion: string | null
  usuario: string | null
  total: number
  detalle: LineaVentaResponse[]
  /** Puede ser más de un método — un pago mixto. */
  pagos: PagoVentaResponse[]
  /** Suma de pagos. Si es menor que total, falta esa diferencia por cobrar. */
  totalPagado: number
}

export interface CrearNotaVentaRequest {
  clienteId: number
  almacenId: number
  listaPrecioId?: number | null
  fecha?: string | null
  formaPago?: FormaPagoVenta | null
  /** Pago mixto: una línea por método usado, o ninguna si es a crédito. */
  pagos?: PagoVentaRequest[]
  observacion?: string | null
  detalle: LineaVentaRequest[]
}

export const notaVentaApi = {
  /** Una página del listado, ya buscada, filtrada y ordenada en el servidor. */
  listar: (consulta: ConsultaTabla) =>
    api.post<PaginaResponse<NotaVentaResponse>>('/notaventa/listar', consulta),

  resumen: () => api.get<ResumenNotasVenta>('/notaventa/resumen'),

  getAll: (estado?: string) =>
    api.get<NotaVentaResponse[]>(`/notaventa${estado ? `?estado=${estado}` : ''}`),
  getById: (id: number) => api.get<NotaVentaResponse>(`/notaventa/${id}`),
  create: (body: CrearNotaVentaRequest) => api.post<NotaVentaResponse>('/notaventa', body),
  /** Corrige una venta ya confirmada: el stock se ajusta solo, según la diferencia. */
  update: (id: number, body: CrearNotaVentaRequest) => api.put<NotaVentaResponse>(`/notaventa/${id}`, body),
  anular: (id: number) => api.patch<void>(`/notaventa/${id}/anular`),
  /** Una página de las cuentas por cobrar, con el saldo resuelto en el servidor. */
  listarCuentasPorCobrar: (consulta: ConsultaTabla) =>
    api.post<PaginaResponse<NotaVentaResponse>>('/notaventa/cuentasporcobrar/listar', consulta),

  resumenCuentasPorCobrar: () =>
    api.get<ResumenCuentas>('/notaventa/cuentasporcobrar/resumen'),

  /** Notas a crédito con saldo pendiente: la base de "Cuentas por cobrar". */
  cuentasPorCobrar: () => api.get<NotaVentaResponse[]>('/notaventa/cuentasporcobrar'),
  /** Registra un abono contra el saldo pendiente de la nota. */
  registrarPago: (id: number, body: PagoVentaRequest) =>
    api.post<NotaVentaResponse>(`/notaventa/${id}/pagos`, body),
  /** Corrige un pago ya registrado: método o monto. */
  actualizarPago: (id: number, pagoId: number, body: PagoVentaRequest) =>
    api.put<NotaVentaResponse>(`/notaventa/${id}/pagos/${pagoId}`, body),
  /** Quita un pago registrado por error: su monto vuelve al saldo pendiente. */
  anularPago: (id: number, pagoId: number) =>
    api.del<NotaVentaResponse>(`/notaventa/${id}/pagos/${pagoId}`),
  /** Una página de los cobros del usuario, resuelta en el servidor. */
  listarCobros: (consulta: ConsultaTabla, desde?: string, hasta?: string) => {
    const params = new URLSearchParams()
    if (desde) params.set('desde', desde)
    if (hasta) params.set('hasta', hasta)
    const query = params.toString()
    return api.post<PaginaResponse<CobroResponse>>(
      `/notaventa/miscobros/listar${query ? `?${query}` : ''}`,
      consulta,
    )
  },

  /** Totales de esos cobros, sobre todo el rango. */
  resumenCobros: (desde?: string, hasta?: string) => {
    const params = new URLSearchParams()
    if (desde) params.set('desde', desde)
    if (hasta) params.set('hasta', hasta)
    const query = params.toString()
    return api.get<ResumenCobros>(`/notaventa/miscobros/resumen${query ? `?${query}` : ''}`)
  },

  /** Los cobros del usuario que hizo login, opcionalmente por rango de fechas (ISO). */
  misCobros: (desde?: string, hasta?: string) => {
    const params = new URLSearchParams()
    if (desde) params.set('desde', desde)
    if (hasta) params.set('hasta', hasta)
    const query = params.toString()
    return api.get<CobroResponse[]>(`/notaventa/miscobros${query ? `?${query}` : ''}`)
  },
  /** Qué cambió en esta nota de venta: sobre todo anulaciones y movimientos de pago. */
  historial: (id: number) => api.get<AuditoriaResponse[]>(`/notaventa/${id}/historial`),
}
