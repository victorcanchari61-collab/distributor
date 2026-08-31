import { api } from '../../lib/apiClient'

export interface EmpresaResponse {
  id: number
  razonSocial: string
  nombreComercial: string
  ruc: string
  direccion: string | null
  telefono: string | null
  email: string | null
  activa: boolean
  fechaCreacion: string
}

export interface EmpresaRequest {
  razonSocial: string
  nombreComercial: string
  ruc: string
  direccion?: string | null
  telefono?: string | null
  email?: string | null
  activa: boolean
}

export const empresaApi = {
  /** GET /api/empresa */
  getAll: () => api.get<EmpresaResponse[]>('/empresa'),

  /** GET /api/empresa/activa — la empresa con la que opera el sistema. */
  getActiva: () => api.get<EmpresaResponse>('/empresa/activa'),

  /** POST /api/empresa */
  create: (body: EmpresaRequest) => api.post<EmpresaResponse>('/empresa', body),

  /** PUT /api/empresa/{id} */
  update: (id: number, body: EmpresaRequest) => api.put<EmpresaResponse>(`/empresa/${id}`, body),

  /** PATCH /api/empresa/{id}/activar — activa una y desactiva la anterior. */
  activar: (id: number) => api.patch<EmpresaResponse>(`/empresa/${id}/activar`),

  /** DELETE /api/empresa/{id} */
  remove: (id: number) => api.del<void>(`/empresa/${id}`),
}
