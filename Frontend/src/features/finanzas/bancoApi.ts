import { api } from '../../lib/apiClient'

/** Un banco como entidad propia (BBVA, BCP, Interbank...): de aquí cuelgan las cuentas bancarias. */
export interface BancoResponse {
  id: number
  nombre: string
  activo: boolean
  fechaCreacion: string
  /** Cuántas cuentas bancarias tiene. */
  cantidadCuentas: number
}

export interface BancoRequest {
  nombre: string
  activo: boolean
}

export const bancoApi = {
  getAll: () => api.get<BancoResponse[]>('/banco'),
  create: (body: BancoRequest) => api.post<BancoResponse>('/banco', body),
  update: (id: number, body: BancoRequest) => api.put<BancoResponse>(`/banco/${id}`, body),
}
