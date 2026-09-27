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
  /** Solo si naturaleza es Caja: de quién es. */
  usuarioResponsableId: number | null
  usuarioResponsable: string | null
  /** Solo si naturaleza es Banco: a qué banco pertenece. */
  bancoId: number | null
  banco: string | null
  numeroCuenta: string | null
  cci: string | null
  titular: string | null
  saldoActual: number
  activo: boolean
  fechaCreacion: string
  /** La caja de la empresa, sin responsable: adonde va el efectivo de los cierres. */
  esBoveda: boolean
}

/** Mover plata entre cuentas propias: un depósito, el sencillo de un repartidor, un retiro. */
export interface TransferenciaRequest {
  cuentaOrigenId: number
  cuentaDestinoId: number
  monto: number
  observacion?: string | null
}

export interface CuentaFinancieraRequest {
  nombre: string
  naturaleza: NaturalezaCuenta
  usuarioResponsableId?: number | null
  bancoId?: number | null
  numeroCuenta?: string | null
  cci?: string | null
  titular?: string | null
  /** Solo se usa al crear: con cuánto ya venía la cuenta antes de registrarla. */
  montoInicial?: number
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
  /** Crea la Bóveda: una sola por empresa, con el efectivo que ya hay guardado. */
  crearBoveda: (montoInicial: number) =>
    api.post<CuentaFinancieraResponse>('/cuentafinanciera/boveda', { montoInicial }),
  /** No es ingreso ni gasto: la plata solo cambia de cuenta. */
  transferir: (body: TransferenciaRequest) => api.post<{ salidaId: number }>('/cuentafinanciera/transferir', body),
  /** Con cualquiera de sus dos mitades se anula la transferencia entera. */
  anularTransferencia: (movimientoId: number) =>
    api.patch<void>(`/cuentafinanciera/transferencias/${movimientoId}/anular`),
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
