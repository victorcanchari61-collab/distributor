import { api } from '../../lib/apiClient'

export type EstadoPlanilla = 'BORRADOR' | 'PAGADA' | 'ANULADA'

export interface PlanillaDetalleResponse {
  id: number
  empleadoId: number
  empleado: string
  cargo: string | null
  sueldoSemanal: number
  diasNoPagados: number
  /** Días que se le pagan sin tener marca de asistencia. */
  diasSinMarcar: number
  descuentoInasistencias: number
  extraFeriados: number
  bonos: number
  otrosDescuentos: number
  notaAjuste: string | null
  descuentoFaltantes: number
  /** Lo que se le descuenta esta semana de sus adelantos. */
  descuentoAdelantos: number
  /** Lo que le toca según cómo se pactaron sus adelantos. */
  adelantosSugerido: number
  /** Lo que se decidió a mano para esta semana; null si va lo sugerido. */
  adelantosManual: number | null
  /** Todo lo que debe de adelantos. */
  adelantosSaldo: number
  /** El gasto de planilla de ese empleado. */
  costoLaboral: number
  neto: number
}

export interface PlanillaResponse {
  id: number
  desde: string
  hasta: string
  estado: EstadoPlanilla
  cuentaFinancieraId: number | null
  cuentaFinanciera: string | null
  fechaPago: string | null
  totalCostoLaboral: number
  totalFaltantes: number
  totalAdelantos: number
  totalNeto: number
  /** En borrador: los días (lunes a sábado) en que a alguien le falta su marca. Se pagarían como trabajados. */
  fechasSinMarcar: string[]
  detalle: PlanillaDetalleResponse[]
}

export interface PlanillaResumenResponse {
  id: number
  desde: string
  hasta: string
  estado: EstadoPlanilla
  empleados: number
  totalNeto: number
  fechaPago: string | null
}

export interface CuentaPagoOpcion {
  id: number
  nombre: string
  naturaleza: string
  /** La Bóveda: no es una caja. */
  esBoveda?: boolean
}

export interface AjustePlanillaRequest {
  bonos: number
  otrosDescuentos: number
  nota?: string | null
  /** Cuánto descontarle de adelantos esta semana; null es lo que le toca. */
  adelantos?: number | null
}

export const planillaApi = {
  /** La planilla de la semana que contiene esa fecha; null si todavía no se armó. */
  semana: (fecha: string) => api.get<PlanillaResponse | null>(`/planilla/semana?fecha=${fecha}`),
  historial: () => api.get<PlanillaResumenResponse[]>('/planilla'),
  cuentas: () => api.get<CuentaPagoOpcion[]>('/planilla/cuentas'),
  generar: (semana: string) => api.post<PlanillaResponse>('/planilla/generar', { semana }),
  ajustar: (detalleId: number, body: AjustePlanillaRequest) =>
    api.put<PlanillaResponse>(`/planilla/detalle/${detalleId}`, body),
  /** Con días sin marcar, el servidor no paga salvo que se confirme con `conDiasSinMarcar`. */
  pagar: (id: number, cuentaFinancieraId: number, conDiasSinMarcar = false) =>
    api.post<PlanillaResponse>(`/planilla/${id}/pagar`, { cuentaFinancieraId, conDiasSinMarcar }),
  anular: (id: number) => api.patch<PlanillaResponse>(`/planilla/${id}/anular`),
}
