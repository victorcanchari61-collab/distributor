import { api } from '../../lib/apiClient'

// --- Mercados ---
//
// Dónde se entrega: un mercado de abastos, pero también puede ser una zona
// con tiendas o empresas — el nombre quedó "Mercado" porque es como el
// negocio ya lo conoce.

export interface MercadoResponse {
  id: number
  nombre: string
  direccion: string | null
  distrito: string | null
  activo: boolean
  /** Cuántos clientes ya lo usan. Si hay alguno, no se elimina. */
  clientes: number
}

export interface MercadoRequest {
  nombre: string
  direccion?: string | null
  distrito?: string | null
}

export const mercadoApi = {
  getAll: () => api.get<MercadoResponse[]>('/mercado'),
  create: (body: MercadoRequest) => api.post<MercadoResponse>('/mercado', body),
  update: (id: number, body: MercadoRequest & { activo: boolean }) =>
    api.put<MercadoResponse>(`/mercado/${id}`, body),
  remove: (id: number) => api.del<void>(`/mercado/${id}`),
}
