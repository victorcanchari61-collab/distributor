import { api } from '../../lib/apiClient'

/**
 * Un permiso concedido: una accion sobre un submodulo.
 *
 * Antes era un modulo entero con cuatro banderas, y por eso no se podia dejar
 * a alguien ver Inventario sin dejarle tambien tocar los ajustes de stock.
 */
export interface RolPermisoResponse {
  /** Clave del submodulo, la misma del menu: inv.ajustes, fact.notaventa... */
  submodulo: string
  /** ver, crear, editar, anular, eliminar, exportar, importar, confirmar, cobrar. */
  accion: string
}

export interface RolResponse {
  id: number
  nombre: string
  descripcion: string | null
  activo: boolean
  /** Roles base (Administrador, Vendedor, Almacenero): no se eliminan. */
  delSistema: boolean
  /** Administrador: tampoco se desactiva. */
  protegido: boolean
  fechaCreacion: string
  usuarios: number
  permisos: RolPermisoResponse[]
}

export interface CreateRolRequest {
  nombre: string
  descripcion?: string | null
}

export interface UpdateRolRequest extends CreateRolRequest {
  activo: boolean
}

export const rolApi = {
  /** GET /api/rol */
  getAll: () => api.get<RolResponse[]>('/rol'),

  /** GET /api/rol/{id} */
  getById: (id: number) => api.get<RolResponse>(`/rol/${id}`),

  /** POST /api/rol */
  create: (body: CreateRolRequest) => api.post<RolResponse>('/rol', body),

  /** PUT /api/rol/{id} */
  update: (id: number, body: UpdateRolRequest) => api.put<RolResponse>(`/rol/${id}`, body),

  /** PUT /api/rol/{id}/permisos — reemplaza la matriz completa. */
  updatePermisos: (id: number, permisos: RolPermisoResponse[]) =>
    api.put<RolResponse>(`/rol/${id}/permisos`, { permisos }),

  /** DELETE /api/rol/{id} */
  remove: (id: number) => api.del<void>(`/rol/${id}`),
}
