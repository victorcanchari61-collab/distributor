import { api } from '../../lib/apiClient'

/** OPERATIVO, NO_OPERATIVO, o INTERNO: plata que solo cambia de cuenta propia, o un saldo inicial. */
export type OrigenDinero = 'OPERATIVO' | 'NO_OPERATIVO' | 'INTERNO'

/** Una fila del kardex del dinero: un movimiento de cualquier caja o banco. */
export interface MovimientoDineroResponse {
  id: number
  fecha: string
  cuentaFinancieraId: number
  cuenta: string
  naturaleza: string
  tipo: 'INGRESO' | 'EGRESO'
  monto: number
  /** El saldo de esa cuenta justo después de este movimiento. */
  saldoResultante: number
  documentoOrigen: string
  /** Qué fue, en palabras: "Cobro NV-0004 — cliente", "Préstamo de BCP". */
  concepto: string
  categoria: string | null
  origen: OrigenDinero
  observacion: string | null
  usuario: string | null
  /** Se anuló después: tiene una reversa. */
  anulado: boolean
  /** Esta fila ES la reversa de otra: resta de la categoría de aquella. */
  esReversa: boolean
  movimientoOperativoId: number | null
  /** Registrado a mano, vigente y no del sistema: se puede anular desde aquí. */
  anulable: boolean
}

export interface CuentaMovimiento {
  id: number
  nombre: string
  naturaleza: string
}

export const movimientoDineroApi = {
  listar: (desde: string, hasta: string) =>
    api.get<MovimientoDineroResponse[]>(`/movimientodinero?desde=${desde}&hasta=${hasta}`),
  cuentas: () => api.get<CuentaMovimiento[]>('/movimientodinero/cuentas'),
}
