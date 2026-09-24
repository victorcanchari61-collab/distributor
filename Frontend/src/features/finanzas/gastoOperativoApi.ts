import { api } from '../../lib/apiClient'

export type TipoMovimientoOperativo = 'INGRESO' | 'EGRESO'

export interface GastoRecurrenteResponse {
  id: number
  nombre: string
  motivoGastoId: number
  motivoGasto: string
  montoEstimado: number
  diaVencimiento: number
  cuentaFinancieraSugeridaId: number | null
  cuentaFinancieraSugerida: string | null
  activo: boolean
}

export interface GastoRecurrenteRequest {
  nombre: string
  motivoGastoId: number
  montoEstimado: number
  diaVencimiento: number
  cuentaFinancieraSugeridaId?: number | null
  activo: boolean
}

/** Una plantilla recurrente que este mes todavía no tiene su pago registrado. */
export interface GastoPendienteResponse {
  gastoRecurrenteId: number
  nombre: string
  motivoGastoId: number
  motivoGasto: string
  montoEstimado: number
  cuentaFinancieraSugeridaId: number | null
  proximoVencimiento: string
  vencido: boolean
}

export interface MovimientoOperativoResponse {
  id: number
  cuentaFinancieraId: number
  cuentaFinanciera: string
  tipo: TipoMovimientoOperativo
  motivoGastoId: number
  motivoGasto: string
  monto: number
  fecha: string
  descripcion: string | null
  gastoRecurrenteId: number | null
  usuario: string | null
  anulado: boolean
}

export interface MovimientoOperativoRequest {
  cuentaFinancieraId: number
  tipo: TipoMovimientoOperativo
  motivoGastoId: number
  monto: number
  fecha?: string | null
  descripcion?: string | null
  gastoRecurrenteId?: number | null
}

export const gastoOperativoApi = {
  getRecurrentes: () => api.get<GastoRecurrenteResponse[]>('/gastooperativo/recurrentes'),
  crearRecurrente: (body: GastoRecurrenteRequest) =>
    api.post<GastoRecurrenteResponse>('/gastooperativo/recurrentes', body),
  actualizarRecurrente: (id: number, body: GastoRecurrenteRequest) =>
    api.put<GastoRecurrenteResponse>(`/gastooperativo/recurrentes/${id}`, body),
  eliminarRecurrente: (id: number) => api.del<void>(`/gastooperativo/recurrentes/${id}`),

  getPendientes: () => api.get<GastoPendienteResponse[]>('/gastooperativo/pendientes'),

  listar: (desde: string, hasta: string) =>
    api.get<MovimientoOperativoResponse[]>(`/gastooperativo?desde=${desde}&hasta=${hasta}`),
  crear: (body: MovimientoOperativoRequest) =>
    api.post<MovimientoOperativoResponse>('/gastooperativo', body),
  anular: (id: number) => api.patch<MovimientoOperativoResponse>(`/gastooperativo/${id}/anular`),
}
