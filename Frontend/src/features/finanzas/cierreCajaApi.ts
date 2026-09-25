import { api } from '../../lib/apiClient'

export type EstadoDescuentoFaltante = 'PENDIENTE' | 'DESCONTADO' | 'ANULADO'

export interface DescuentoFaltanteResponse {
  id: number
  monto: number
  montoAplicado: number
  saldo: number
  estado: EstadoDescuentoFaltante
}

export interface CierreCajaResponse {
  id: number
  fecha: string
  usuarioId: number
  usuario: string
  caja: string
  saldoSistema: number
  billetes: number
  monedas: number
  contado: number
  /** Negativa: faltó plata. Positiva: sobró. */
  diferencia: number
  cuentaDestinoId: number
  cuentaDestino: string
  observacion: string | null
  anulado: boolean
  /** Solo si hubo faltante. */
  descuento: DescuentoFaltanteResponse | null
  /** El usuario no tiene empleado vinculado: su faltante no entra en ninguna planilla. */
  sinEmpleado: boolean
}

export const cierreCajaApi = {
  listar: (desde: string, hasta: string) =>
    api.get<CierreCajaResponse[]>(`/cierrecaja?desde=${desde}&hasta=${hasta}`),
  anular: (id: number) => api.patch<CierreCajaResponse>(`/cierrecaja/${id}/anular`),
}
