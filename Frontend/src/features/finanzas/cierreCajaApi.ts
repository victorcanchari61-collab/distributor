import { api } from '../../lib/apiClient'

export type EstadoDescuentoFaltante = 'PENDIENTE' | 'DESCONTADO' | 'ANULADO'

export interface DescuentoFaltanteResponse {
  id: number
  monto: number
  montoAplicado: number
  saldo: number
  estado: EstadoDescuentoFaltante
}

export interface CierreCajaResponse {
  id: number
  fecha: string
  usuarioId: number
  usuario: string
  caja: string
  saldoSistema: number
  billetes: number
  monedas: number
  contado: number
  /** Negativa: faltó plata. Positiva: sobró. */
  diferencia: number
  cuentaDestinoId: number
  cuentaDestino: string
  observacion: string | null
  anulado: boolean
  /** Solo si hubo faltante. */
  descuento: DescuentoFaltanteResponse | null
  /** El usuario no tiene empleado vinculado: su faltante no entra en ninguna planilla. */
  sinEmpleado: boolean
  /** Lo cobrado por Yape o transferencia desde el cierre anterior hasta este, sin lo rechazado. */
  digital: number
  digitalPorVerificar: number
  digitalRechazados: number
}

export interface DenominacionResponse {
  valor: number
  cantidad: number
  total: number
  esBillete: boolean
}

/** Un movimiento de la caja dentro del periodo de un cierre. */
export interface MovimientoCierreResponse {
  id: number
  fecha: string
  tipo: 'INGRESO' | 'EGRESO'
  monto: number
  documentoOrigen: string
  /** La venta y el cliente, la categoría del gasto o lo escrito a mano. */
  detalle: string | null
  anulado: boolean
  esReversa: boolean
}

/** Todo lo de un cierre para revisar si cuadra. */
export interface CierreDetalleResponse {
  cierre: CierreCajaResponse
  /** El cierre anterior de esa caja. Nulo si es el primero. */
  desde: string | null
  /** Lo que la caja ya tenía al empezar el periodo. */
  saldoAnterior: number
  /** Vacío en los cierres de antes de guardar el desglose. */
  denominaciones: DenominacionResponse[]
  efectivo: MovimientoCierreResponse[]
  digitales: CobroDigitalResponse[]
}

export type EstadoVerificacionCobro = 'PENDIENTE' | 'VERIFICADO' | 'RECHAZADO'

/** Un cobro por Yape, Plin o transferencia, para buscarlo en el banco por su número de operación. */
export interface CobroDigitalResponse {
  /** El id del pago de la venta. */
  id: number
  fecha: string
  notaVentaId: number
  documento: string
  cliente: string | null
  /** Quién lo cobró: a quien se le descuenta si no aparece. */
  usuarioId: number | null
  usuario: string | null
  metodoPago: string
  metodoTipo: 'BILLETERA_DIGITAL' | 'TRANSFERENCIA'
  /** La cuenta donde tiene que aparecer. */
  cuenta: string | null
  numeroOperacion: string | null
  monto: number
  estado: EstadoVerificacionCobro
  verificadoPor: string | null
  verificadoEn: string | null
  observacion: string | null
  /** Solo si se rechazó: cómo va su descuento en planilla. */
  descuento: DescuentoFaltanteResponse | null
  sinEmpleado: boolean
}

export const cierreCajaApi = {
  listar: (desde: string, hasta: string) =>
    api.get<CierreCajaResponse[]>(`/cierrecaja?desde=${desde}&hasta=${hasta}`),
  anular: (id: number) => api.patch<CierreCajaResponse>(`/cierrecaja/${id}/anular`),
  detalle: (id: number) => api.get<CierreDetalleResponse>(`/cierrecaja/${id}/detalle`),

  /** Los del rango, más los pendientes de cualquier fecha. */
  cobrosDigitales: (desde: string, hasta: string) =>
    api.get<CobroDigitalResponse[]>(`/cierrecaja/cobrosdigitales?desde=${desde}&hasta=${hasta}`),
  verificar: (pagoId: number) => api.patch<CobroDigitalResponse>(`/cierrecaja/cobrosdigitales/${pagoId}/verificar`),
  quitarVerificacion: (pagoId: number) =>
    api.patch<CobroDigitalResponse>(`/cierrecaja/cobrosdigitales/${pagoId}/pendiente`),
  rechazar: (pagoId: number, observacion: string) =>
    api.patch<CobroDigitalResponse>(`/cierrecaja/cobrosdigitales/${pagoId}/rechazar`, { observacion }),
}
