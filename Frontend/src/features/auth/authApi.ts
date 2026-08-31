import { api } from '../../lib/apiClient'

export interface UsuarioResponse {
  id: number
  nombre: string
  email: string
  rolId: number
  /** Nombre del rol, ya resuelto por el backend. */
  rol: string
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

export interface CreateUsuarioRequest {
  nombre: string
  email: string
  password: string
  /** Id de la tabla Roles. */
  rolId: number
}

/** POST /api/auth/register */
export function register(request: CreateUsuarioRequest) {
  return api.post<UsuarioResponse>('/auth/register', request)
}
