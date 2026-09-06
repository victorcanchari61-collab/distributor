import { api } from '../../lib/apiClient'

export interface RutaResponse {
  id: number
  nombre: string
  activo: boolean
  /** Cuántos clientes ya la usan. Si hay alguno, no se elimina. */
  clientes: number
}

export interface RutaRequest {
  nombre: string
}

export const rutaApi = {
  getAll: () => api.get<RutaResponse[]>('/ruta'),
  create: (body: RutaRequest) => api.post<RutaResponse>('/ruta', body),
  update: (id: number, body: RutaRequest & { activo: boolean }) =>
    api.put<RutaResponse>(`/ruta/${id}`, body),
  remove: (id: number) => api.del<void>(`/ruta/${id}`),
}
