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
  /** Precio por unidad base: derivado, para márgenes y reportes. */
  precioUnitario: number
  /** Lo que se acordó por cada presentación: S/ 212.50 el saco. */
  precioPresentacion: number
  subtotal: number
  /** Si el producto pagaba IGV al momento de esta línea. El precio ya lo incluye. */
  afectoIgv: boolean
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
  /** La ruta del cliente y el día en que se lo visita. */
  ruta: string | null
  diaVisita: string | null
  listaPrecioId: number | null
  listaPrecio: string | null
  fecha: string
  estado: EstadoPedido
  /** En qué quedaron con el cliente: si se cobra al entregar o va fiado. */
  condicionPago: FormaPagoVenta
  observacion: string | null
  usuario: string | null
  reservaStock: boolean
  almacenId: number | null
  almacen: string | null
  /** La venta vigente que salió de este pedido, si ya se convirtió. */
  notaVentaId: number | null
  notaVentaNumero: string | null
  /** Por qué no se entregó, si el repartidor lo marcó así. El pedido sigue Pendiente. */
  noEntregadoMotivo: string | null
  noEntregadoObservacion: string | null
  total: number
  detalle: LineaVentaResponse[]
}

export interface CrearPedidoRequest {
  clienteId: number
  listaPrecioId?: number | null
  fecha?: string | null
  observacion?: string | null
  /** CONTADO o CREDITO: lo acordado con el cliente. Vacío usa CONTADO. */
  condicionPago?: FormaPagoVenta | null
  /** Si aparta stock de almacenId mientras el pedido siga Pendiente. */
  reservaStock: boolean
  /** Requerido cuando reservaStock es true. */
  almacenId?: number | null
  detalle: LineaVentaRequest[]
}

/** Un pedido no lleva pagos: la nota que nace al confirmarlo queda a crédito. */
export interface ConfirmarPedidoRequest {
  /** De dónde sale. Se omite cuando el pedido reservó: sale del almacén de la reserva. */
  almacenId?: number | null
  /**
   * Lo que de verdad se entregó cuando no fue todo. Solo van las líneas que
   * cambian: una que no aparece se entregó completa.
   */
  lineas?: LineaEntregaRequest[]
  /**
   * Lo que el cliente pagó al recibir, en uno o varios métodos. Manda lo que se
   * cobró, no lo acordado: si cubre el total la venta es al contado; si no,
   * queda a crédito con este adelanto (puede ser ninguno).
   */
  pagos?: PagoVentaRequest[]
  /** Mercadería de OTRA venta que se recoge al entregar esta: se descuenta del total. */
  recojos?: RecojoRequest[]
}

/** Cuánto de una línea se entregó, y por qué no fue todo. */
export interface LineaEntregaRequest {
  pedidoDetalleId: number
  /** En unidad base: 9 cajas de 12 y 5 sueltas son 113. Cero quita el producto de la venta. */
  cantidad: number
  /** Obligatorio cuando se entrega menos de lo pedido. */
  motivoId?: number | null
  observacion?: string | null
}

/**
 * Mercadería de OTRA venta que el repartidor recoge al entregar esta: se
 * descuenta del total.
 *
 * No lleva almacén: el repartidor no decide a dónde va — eso lo cuenta el
 * encargado cuando el camión vuelve, en Novedades de entrega
 * (ver {@link recojoApi.verificar}).
 */
export interface RecojoRequest {
  productoId: number
  presentacionId?: number | null
  /** En la presentación elegida. */
  cantidad: number
  /** Valor de UNA presentación completa: con eso se descuenta de la venta. */
  precioUnitario: number
  motivoId: number
  observacion?: string | null
}

/** PENDIENTE (todavía no entra a stock), VERIFICADO (ya entró) o ANULADO. */
export type EstadoRecojo = 'PENDIENTE' | 'VERIFICADO' | 'ANULADO'

/** Un recojo visto desde su venta. */
export interface RecojoDeVenta {
  id: number
  fecha: string
  productoId: number
  producto: string
  presentacion: string | null
  unidadBase: string
  cantidadPresentacion: number
  /** Vacío mientras está pendiente: el almacén lo decide quien lo verifica. */
  almacenId: number | null
  almacen: string | null
  motivo: string
  observacion: string | null
  usuario: string | null
  importe: number
  estado: EstadoRecojo
  verificadoPor: string | null
  verificadoEn: string | null
}

/** Un recojo pendiente de verificar, con el contexto de la venta que lo descontó. */
export interface RecojoPendiente {
  id: number
  fecha: string
  notaVentaId: number
  notaVenta: string
  cliente: string
  productoId: number
  producto: string
  presentacion: string | null
  unidadBase: string
  cantidadPresentacion: number
  motivo: string
  observacion: string | null
  usuario: string | null
  importe: number
}

export interface VerificarRecojoRequest {
  almacenId: number
}

/** El pedido entero no se entregó. */
export interface NoEntregadoRequest {
  motivoId: number
  observacion?: string | null
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
  /** Quiénes registraron alguna, para el filtro de Vendedor. */
  vendedores: string[]
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
  /** El pedido entero no se entregó: no crea venta, deja la novedad con su motivo. */
  noEntregado: (id: number, body: NoEntregadoRequest) =>
    api.post<PedidoResponse>(`/pedido/${id}/noentregado`, body),
  quitarNoEntregado: (id: number) => api.del<PedidoResponse>(`/pedido/${id}/noentregado`),
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
  /** La suma del detalle MENOS los recojos: es lo que de verdad se cobra. */
  total: number
  /** Op. Gravada: lo cobrado SIN el IGV, de las líneas afectas. */
  opGravada: number
  /** El IGV de las líneas afectas: opGravada × 18%. */
  igv: number
  /** Lo cobrado por líneas de productos no afectos (exonerados). opGravada + igv + opExonerada = total. */
  opExonerada: number
  detalle: LineaVentaResponse[]
  /** Puede ser más de un método — un pago mixto. */
  pagos: PagoVentaResponse[]
  /** Suma de pagos. Si es menor que total, falta esa diferencia por cobrar. */
  totalPagado: number
  /** Lo devuelto y aprobado. No se resta de total: el detalle ya viene descontado. */
  totalDevuelto: number
  /** Lo que el cliente devolvió, con su estado. Nacen de editar esta venta. */
  devoluciones: DevolucionDeVenta[]
  /** Suma de los recojos vigentes. Ya está restada de total; esto es informativo. */
  totalRecogido: number
  /** Mercadería de otra venta que se recogió al entregar esta. */
  recojos: RecojoDeVenta[]
}

export type EstadoDevolucion = 'SOLICITADA' | 'APROBADA' | 'RECHAZADA'

/** Una línea devuelta: qué producto y cuánto. */
export interface LineaDevuelta {
  notaVentaDetalleId: number
  producto: string
  cantidad: number
  unidad: string
  importe: number
}

/**
 * Lo que se quitó de la venta al editarla.
 *
 * No se registra a mano en ninguna pantalla: sale de bajarle cantidad a una
 * línea, y hasta que alguien la aprueba no mueve stock ni baja la deuda.
 */
export interface DevolucionDeVenta {
  id: number
  numero: string
  fecha: string
  estado: EstadoDevolucion
  motivo: string | null
  motivoRechazo: string | null
  usuario: string | null
  aprobadoPor: string | null
  total: number
  detalle: LineaDevuelta[]
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
  /** Mercadería de OTRA venta que se recoge al entregar esta: se descuenta del total. */
  recojos?: RecojoRequest[]
}

/** Las devoluciones que nacieron de editar una venta: solo se resuelven. */
export const devolucionVentaApi = {
  aprobar: (id: number) => api.patch<unknown>(`/devolucion/${id}/aprobar`),
  rechazar: (id: number, motivo: string) =>
    api.patch<unknown>(`/devolucion/${id}/rechazar`, { motivo }),
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

/** Los recojos que todavía no entraron a ningún almacén, para revisarlos desde Novedades de entrega. */
export const recojoApi = {
  pendientes: () => api.get<RecojoPendiente[]>('/notaventa/recojo/pendientes'),
  /** El encargado dice a qué almacén entra: recién ahí suma stock. */
  verificar: (id: number, body: VerificarRecojoRequest) =>
    api.patch<NotaVentaResponse>(`/notaventa/recojo/${id}/verificar`, body),
}

