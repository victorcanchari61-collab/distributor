import { api } from '../../lib/apiClient'

export interface EmpresaResponse {
  id: number
  razonSocial: string
  nombreComercial: string
  ruc: string
  direccion: string | null
  departamento: string | null
  provincia: string | null
  distrito: string | null
  telefono: string | null
  email: string | null
  sitioWeb: string | null
  representanteLegal: string | null
  /** La empresa con la que opera el sistema. Solo una a la vez. */
  activa: boolean
  /** Disponible para usarse. Una deshabilitada no se puede activar. */
  habilitada: boolean
  fechaCreacion: string
}

export interface EmpresaRequest {
  razonSocial: string
  nombreComercial: string
  ruc: string
  direccion?: string | null
  departamento?: string | null
  provincia?: string | null
  distrito?: string | null
  telefono?: string | null
  email?: string | null
  /** Se puede escribir sin http: el backend le pone https al guardar. */
  sitioWeb?: string | null
  representanteLegal?: string | null
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

  /** PATCH /api/empresa/{id}/deshabilitar — la retira sin eliminarla. */
  deshabilitar: (id: number) => api.patch<EmpresaResponse>(`/empresa/${id}/deshabilitar`),

  /** PATCH /api/empresa/{id}/habilitar */
  habilitar: (id: number) => api.patch<EmpresaResponse>(`/empresa/${id}/habilitar`),

  /** DELETE /api/empresa/{id} */
  remove: (id: number) => api.del<void>(`/empresa/${id}`),
}
