import { api } from '../../lib/apiClient'
import type { ConsultaTabla } from '../../components/ui'
import type { PaginaResponse } from '../../lib/paginacion'

// --- Métodos de pago ---
//
// Catálogo compartido: compras, cuentas por cobrar, cuentas por pagar, mis
// cobros y el arqueo diario lo reusan en vez de declarar cada uno el suyo.

/** Efectivo no pide cuenta; billetera y transferencia sí identifican una. */
export type TipoMetodoPago = 'EFECTIVO' | 'BILLETERA_DIGITAL' | 'TRANSFERENCIA'

export interface MetodoPagoResponse {
  id: number
  nombre: string
  tipo: TipoMetodoPago
  banco: string | null
  numeroCuenta: string | null
  cci: string | null
  titular: string | null
  activo: boolean
  /** Cuántos documentos ya lo usan. Si hay alguno, no se elimina. */
  usos: number
}

export interface MetodoPagoRequest {
  nombre: string
  tipo: TipoMetodoPago
  banco?: string | null
  numeroCuenta?: string | null
  cci?: string | null
  titular?: string | null
}

export const metodoPagoApi = {
  getAll: () => api.get<MetodoPagoResponse[]>('/metodopago'),
  create: (body: MetodoPagoRequest) => api.post<MetodoPagoResponse>('/metodopago', body),
  update: (id: number, body: MetodoPagoRequest & { activo: boolean }) =>
    api.put<MetodoPagoResponse>(`/metodopago/${id}`, body),
  remove: (id: number) => api.del<void>(`/metodopago/${id}`),
}

// --- Arqueo de caja ---
//
// El cierre de caja de un día: solo importa el efectivo, porque una
// transferencia o una billetera digital no se cuenta a mano.

export interface ArqueoCajaResponse {
  id: number
  fecha: string
  montoEsperado: number
  montoContado: number
  /** montoContado - montoEsperado. Negativo es faltante, positivo es sobrante. */
  diferencia: number
  observacion: string | null
  usuario: string | null
  fechaCreacion: string
}

export interface ArqueoResumenResponse {
  fecha: string
  cobradoEfectivo: number
  pagadoEfectivo: number
  montoEsperado: number
  /** El cierre ya registrado para este día, si existe. */
  arqueo: ArqueoCajaResponse | null
}

export interface RegistrarArqueoRequest {
  fecha: string
  montoContado: number
  observacion?: string | null
}

export const arqueoApi = {
  resumen: (fecha: string) => api.get<ArqueoResumenResponse>(`/arqueo/resumen?fecha=${fecha}`),
  historial: () => api.get<ArqueoCajaResponse[]>('/arqueo/historial'),

  /** Una página del historial de cierres, resuelta en el servidor. */
  listar: (consulta: ConsultaTabla) =>
    api.post<PaginaResponse<ArqueoCajaResponse>>('/arqueo/listar', consulta),
  registrar: (body: RegistrarArqueoRequest) => api.post<ArqueoCajaResponse>('/arqueo', body),
}
