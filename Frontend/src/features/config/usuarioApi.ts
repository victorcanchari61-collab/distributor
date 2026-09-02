import { api } from '../../lib/apiClient'

export interface UsuarioResponse {
  id: number
  nombre: string
  email: string
  dni: string | null
  rolId: number
  /** Nombre del rol, resuelto por el backend. */
  rol: string
  activo: boolean
  fechaCreacion: string
}

export interface CreateUsuarioRequest {
  nombre: string
  email: string
  password: string
  dni?: string | null
  rolId: number
}

export interface UpdateUsuarioRequest {
  nombre: string
  email: string
  dni?: string | null
  rolId: number
  activo: boolean
  /** Vacio deja la contraseña actual. */
  password?: string | null
}

export const usuarioApi = {
  /** GET /api/usuario */
  getAll: () => api.get<UsuarioResponse[]>('/usuario'),

  /** GET /api/usuario/{id} */
  getById: (id: number) => api.get<UsuarioResponse>(`/usuario/${id}`),

  /** POST /api/usuario */
  create: (body: CreateUsuarioRequest) => api.post<UsuarioResponse>('/usuario', body),

  /** PUT /api/usuario/{id} */
  update: (id: number, body: UpdateUsuarioRequest) =>
    api.put<UsuarioResponse>(`/usuario/${id}`, body),
}
