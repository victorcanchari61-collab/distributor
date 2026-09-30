import { api } from '../../lib/apiClient'
import type { CuentaFinancieraResponse, MovimientoCuentaResponse, NaturalezaCuenta } from './cuentaFinancieraApi'
import type { TipoMovimientoOperativo, MovimientoOperativoResponse } from './gastoOperativoApi'
import type { CierreCajaResponse } from './cierreCajaApi'

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
  /** Cuántos de cada billete y moneda: queda guardado para revisar el cierre. */
  denominaciones?: { valor: number; cantidad: number }[]
}

/** Una cuenta a la que se puede entregar lo contado, sin su saldo. */
export interface CuentaDestino {
  id: number
  nombre: string
  naturaleza: NaturalezaCuenta
  /** La Bóveda: no es una caja. */
  esBoveda?: boolean
}

/**
 * Un cobro o pago que hizo por Yape, Plin o transferencia: no pasa por su
 * caja —la plata va directo al banco—, pero es suyo.
 */
export interface MovimientoDigital {
  id: number
  fecha: string
  tipo: 'COBRO' | 'PAGO'
  /** La nota de venta o la compra. */
  documento: string
  /** El cliente o el proveedor. */
  contraparte: string | null
  metodoPago: string
  metodoTipo: 'BILLETERA_DIGITAL' | 'TRANSFERENCIA'
  monto: number
  /** A qué cuenta entró (o de cuál salió). */
  cuenta: string | null
  anulado: boolean
  /** Solo en cobros: el número de operación y si ya se buscó en el banco. */
  numeroOperacion: string | null
  estadoVerificacion: 'PENDIENTE' | 'VERIFICADO' | 'RECHAZADO' | null
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

  /** Lo que cobró o pagó por Yape, Plin o transferencia en esas fechas. */
  digitales: (desde: string, hasta: string) =>
    api.get<MovimientoDigital[]>(`/micaja/digitales?desde=${desde}&hasta=${hasta}`),

  cerrar: (body: CerrarMiCajaRequest) => api.post<CierreCajaResponse>('/micaja/cerrar', body),
}
