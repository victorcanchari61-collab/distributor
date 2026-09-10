import { api } from '../../lib/apiClient'

export interface PerfilResponse {
  id: number
  nombre: string
  email: string
  dni: string | null
  telefono: string | null
  /** Ruta relativa de la foto de perfil, si tiene. */
  foto: string | null
  rolId: number
  /** Nombre del rol, resuelto por el backend. */
  rol: string
  activo: boolean
  fechaCreacion: string
}

export interface ActualizarPerfilRequest {
  nombre: string
  email: string
  dni?: string | null
  telefono?: string | null
  foto?: string | null
}

export interface CambiarPasswordRequest {
  passwordActual: string
  passwordNueva: string
}

/**
 * El perfil propio.
 *
 * Va contra /api/perfil y no contra /api/usuario: alli todo exige el permiso
 * "config.usuarios", que un vendedor o un almacenero no tiene. Aqui cada uno
 * edita lo suyo sin poder tocarse el rol ni el estado.
 */
export const perfilApi = {
  get: () => api.get<PerfilResponse>('/perfil'),

  update: (body: ActualizarPerfilRequest) => api.put<PerfilResponse>('/perfil', body),

  cambiarPassword: (body: CambiarPasswordRequest) => api.put<void>('/perfil/password', body),
}
