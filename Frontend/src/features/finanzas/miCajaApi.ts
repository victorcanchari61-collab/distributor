import { api } from '../../lib/apiClient'
import type { CuentaFinancieraResponse, MovimientoCuentaResponse, NaturalezaCuenta } from './cuentaFinancieraApi'
import type { TipoMovimientoOperativo, MovimientoOperativoResponse } from './gastoOperativoApi'

/** Un ingreso o egreso libre en Mi Caja: la cuenta la decide el servidor, siempre la propia. */
export interface MovimientoLibreRequest {
  tipo: TipoMovimientoOperativo
  motivoGastoId: number
  monto: number
  descripcion?: string | null
}

/** Cierra la caja propia: cuánto se contó y a qué cuenta se entrega. */
export interface CerrarMiCajaRequest {
  billetes: number
  monedas: number
  cuentaDestinoId: number
  observacion?: string | null
}

export interface CierreCajaResponse {
  id: number
  fecha: string
  saldoSistema: number
  billetes: number
  monedas: number
  contado: number
  /** Negativa: faltó plata. Positiva: sobró. */
  diferencia: number
  cuentaDestinoId: number
  cuentaDestino: string
  observacion: string | null
}

/** Una cuenta a la que se puede entregar lo contado, sin su saldo. */
export interface CuentaDestino {
  id: number
  nombre: string
  naturaleza: NaturalezaCuenta
}

export const miCajaApi = {
  /** La Caja de quien está logueado. Si no tiene una asignada, el servidor responde con error. */
  mia: () => api.get<CuentaFinancieraResponse>('/micaja'),

  movimientos: (desde?: string, hasta?: string) =>
    api.get<MovimientoCuentaResponse[]>(
      `/micaja/movimientos${desde ? `?desde=${desde}&hasta=${hasta ?? desde}` : ''}`,
    ),

  registrarMovimiento: (body: MovimientoLibreRequest) =>
    api.post<MovimientoOperativoResponse>('/micaja/movimiento', { ...body, cuentaFinancieraId: 0 }),

  destinos: () => api.get<CuentaDestino[]>('/micaja/destinos'),

  cerrar: (body: CerrarMiCajaRequest) => api.post<CierreCajaResponse>('/micaja/cerrar', body),
}
