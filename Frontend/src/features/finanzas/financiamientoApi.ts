import { api } from '../../lib/apiClient'

export type EstadoFinanciamiento = 'VIGENTE' | 'CANCELADO' | 'ANULADO'

export interface PagoFinanciamientoResponse {
  id: number
  fecha: string
  monto: number
  cuentaFinancieraId: number
  cuentaFinanciera: string
  anulado: boolean
  usuario: string | null
  observacion: string | null
}

/** Un préstamo que recibió el negocio: la plata que entró y lo que falta devolver. */
export interface FinanciamientoResponse {
  id: number
  acreedor: string
  descripcion: string | null
  fecha: string
  montoRecibido: number
  totalADevolver: number
  pagado: number
  saldo: number
  estado: EstadoFinanciamiento
  cuentaFinancieraId: number
  cuentaFinanciera: string
  usuario: string | null
  pagos: PagoFinanciamientoResponse[]
}

export interface CrearFinanciamientoRequest {
  acreedor: string
  descripcion?: string | null
  fecha?: string | null
  montoRecibido: number
  /** Con intereses. Vacío: lo mismo que se recibió. */
  totalADevolver?: number | null
  cuentaFinancieraId: number
}

export interface PagoFinanciamientoRequest {
  monto: number
  fecha?: string | null
  cuentaFinancieraId: number
  observacion?: string | null
}

export interface CuentaOpcion {
  id: number
  nombre: string
  naturaleza: string
}

export const financiamientoApi = {
  listar: () => api.get<FinanciamientoResponse[]>('/financiamiento'),
  cuentas: () => api.get<CuentaOpcion[]>('/financiamiento/cuentas'),
  crear: (body: CrearFinanciamientoRequest) => api.post<FinanciamientoResponse>('/financiamiento', body),
  pagar: (id: number, body: PagoFinanciamientoRequest) =>
    api.post<FinanciamientoResponse>(`/financiamiento/${id}/pagos`, body),
  anularPago: (id: number, pagoId: number) =>
    api.patch<FinanciamientoResponse>(`/financiamiento/${id}/pagos/${pagoId}/anular`),
  anular: (id: number) => api.patch<FinanciamientoResponse>(`/financiamiento/${id}/anular`),
}
