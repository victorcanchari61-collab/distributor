import { api } from '../../lib/apiClient'

export interface UsuarioResponse {
  id: number
  nombre: string
  email: string
  role: number
  activo: boolean
  fechaCreacion: string
}

export interface LoginResponse {
  token: string
  usuario: UsuarioResponse
}

export interface LoginRequest {
  email: string
  password: string
}

/** POST /api/auth/login */
export function login(request: LoginRequest) {
  return api.post<LoginResponse>('/auth/login', request, { auth: false })
}
