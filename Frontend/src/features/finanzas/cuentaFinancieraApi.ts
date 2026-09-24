import { api } from '../../lib/apiClient'

/** Caja: efectivo físico (hoy solo existe la Caja General). Banco: cuenta real. Pasarela: retiene fondos antes de liquidar. */
export type NaturalezaCuenta = 'CAJA' | 'BANCO' | 'PASARELA'

/**
 * La entidad que sí tiene saldo real: la Caja General, una cuenta BCP, una
 * cuenta Interbank. Un método de pago (Efectivo, Yape, Transferencia) es solo
 * un canal que apunta a una de estas — nunca tiene saldo propio.
 */
export interface CuentaFinancieraResponse {
  id: number
  nombre: string
  naturaleza: NaturalezaCuenta
  banco: string | null
  numeroCuenta: string | null
  cci: string | null
  titular: string | null
  saldoActual: number
  activo: boolean
  fechaCreacion: string
}

export interface CuentaFinancieraRequest {
  nombre: string
  naturaleza: NaturalezaCuenta
  banco?: string | null
  numeroCuenta?: string | null
  cci?: string | null
  titular?: string | null
  activo: boolean
}

export type TipoMovimientoCuenta = 'INGRESO' | 'EGRESO'

export interface MovimientoCuentaResponse {
  id: number
  cuentaFinancieraId: number
  tipo: TipoMovimientoCuenta
  monto: number
  saldoResultante: number
  fecha: string
  documentoOrigen: string
  origenId: number | null
  movimientoOrigenId: number | null
  usuario: string | null
  observacion: string | null
}

export type EstadoConciliacion = 'PENDIENTE' | 'CONCILIADO'

export interface ConciliacionBancariaResponse {
  id: number
  cuentaFinancieraId: number
  cuentaFinanciera: string
  fecha: string
  saldoExtracto: number
  saldoContable: number
  diferencia: number
  observacion: string | null
  estado: EstadoConciliacion
  usuario: string | null
  fechaCreacion: string
}

export interface ConciliacionBancariaRequest {
  cuentaFinancieraId: number
  fecha: string
  saldoExtracto: number
  observacion?: string | null
}

export const cuentaFinancieraApi = {
  getAll: () => api.get<CuentaFinancieraResponse[]>('/cuentafinanciera'),
  getById: (id: number) => api.get<CuentaFinancieraResponse>(`/cuentafinanciera/${id}`),
  create: (body: CuentaFinancieraRequest) => api.post<CuentaFinancieraResponse>('/cuentafinanciera', body),
  update: (id: number, body: CuentaFinancieraRequest) =>
    api.put<CuentaFinancieraResponse>(`/cuentafinanciera/${id}`, body),
  movimientos: (id: number, desde?: string, hasta?: string) =>
    api.get<MovimientoCuentaResponse[]>(
      `/cuentafinanciera/${id}/movimientos${desde ? `?desde=${desde}&hasta=${hasta ?? desde}` : ''}`,
    ),
}

export const conciliacionBancariaApi = {
  listar: (cuentaFinancieraId: number) =>
    api.get<ConciliacionBancariaResponse[]>(`/conciliacionbancaria/cuenta/${cuentaFinancieraId}`),
  crear: (body: ConciliacionBancariaRequest) =>
    api.post<ConciliacionBancariaResponse>('/conciliacionbancaria', body),
  marcarConciliada: (id: number) =>
    api.patch<ConciliacionBancariaResponse>(`/conciliacionbancaria/${id}/conciliar`),
}
