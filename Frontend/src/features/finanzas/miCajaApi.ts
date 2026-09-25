import { api } from '../../lib/apiClient'
import type { CuentaFinancieraResponse, MovimientoCuentaResponse } from './cuentaFinancieraApi'
import type { ArqueoCajaResponse } from './arqueoApi'
import type { TipoMovimientoOperativo, MovimientoOperativoResponse } from './gastoOperativoApi'

/** Un ingreso o egreso libre en Mi Caja: la cuenta la decide el servidor, siempre la propia. */
export interface MovimientoLibreRequest {
  tipo: TipoMovimientoOperativo
  motivoGastoId: number
  monto: number
  descripcion?: string | null
}

/** Cierra el día: cuenta lo físico y liquida a la Caja General. El usuario también lo decide el servidor. */
export interface CerrarMiCajaRequest {
  fecha: string
  billetes: number
  monedas: number
  observacion?: string | null
}

export const miCajaApi = {
  /** La Caja de quien está logueado: se crea sola la primera vez que hace falta. */
  mia: () => api.get<CuentaFinancieraResponse>('/micaja'),

  movimientos: (desde?: string, hasta?: string) =>
    api.get<MovimientoCuentaResponse[]>(
      `/micaja/movimientos${desde ? `?desde=${desde}&hasta=${hasta ?? desde}` : ''}`,
    ),

  registrarMovimiento: (body: MovimientoLibreRequest) =>
    api.post<MovimientoOperativoResponse>('/micaja/movimiento', { ...body, cuentaFinancieraId: 0 }),

  cerrar: (body: CerrarMiCajaRequest) =>
    api.post<ArqueoCajaResponse>('/micaja/cerrar', { ...body, usuarioId: 0, gastos: [], pagosDigitales: [] }),
}
