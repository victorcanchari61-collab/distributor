import { api } from '../../lib/apiClient'

export type EstadoPlanilla = 'BORRADOR' | 'PAGADA' | 'ANULADA'

export interface PlanillaDetalleResponse {
  id: number
  empleadoId: number
  empleado: string
  cargo: string | null
  sueldoSemanal: number
  diasNoPagados: number
  descuentoInasistencias: number
  extraFeriados: number
  bonos: number
  otrosDescuentos: number
  notaAjuste: string | null
  descuentoFaltantes: number
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
  totalNeto: number
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
}

export interface AjustePlanillaRequest {
  bonos: number
  otrosDescuentos: number
  nota?: string | null
}

export const planillaApi = {
  /** La planilla de la semana que contiene esa fecha; null si todavía no se armó. */
  semana: (fecha: string) => api.get<PlanillaResponse | null>(`/planilla/semana?fecha=${fecha}`),
  historial: () => api.get<PlanillaResumenResponse[]>('/planilla'),
  cuentas: () => api.get<CuentaPagoOpcion[]>('/planilla/cuentas'),
  generar: (semana: string) => api.post<PlanillaResponse>('/planilla/generar', { semana }),
  ajustar: (detalleId: number, body: AjustePlanillaRequest) =>
    api.put<PlanillaResponse>(`/planilla/detalle/${detalleId}`, body),
  pagar: (id: number, cuentaFinancieraId: number) =>
    api.post<PlanillaResponse>(`/planilla/${id}/pagar`, { cuentaFinancieraId }),
  anular: (id: number) => api.patch<PlanillaResponse>(`/planilla/${id}/anular`),
}
