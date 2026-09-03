import { api } from '../../lib/apiClient'

// --- Métodos de pago ---
//
// Catálogo compartido: compras, cuentas por cobrar, cuentas por pagar, mis
// cobros y el arqueo diario lo reusan en vez de declarar cada uno el suyo.

export interface MetodoPagoResponse {
  id: number
  nombre: string
  activo: boolean
  /** Cuántos documentos ya lo usan. Si hay alguno, no se elimina. */
  usos: number
}

export interface MetodoPagoRequest {
  nombre: string
}

export const metodoPagoApi = {
  getAll: () => api.get<MetodoPagoResponse[]>('/metodopago'),
  create: (body: MetodoPagoRequest) => api.post<MetodoPagoResponse>('/metodopago', body),
  update: (id: number, body: MetodoPagoRequest & { activo: boolean }) =>
    api.put<MetodoPagoResponse>(`/metodopago/${id}`, body),
  remove: (id: number) => api.del<void>(`/metodopago/${id}`),
}
