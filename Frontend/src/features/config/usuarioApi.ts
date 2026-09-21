import { api } from '../../lib/apiClient'

export interface UsuarioResponse {
  id: number
  nombre: string
  email: string
  dni: string | null
  /** Nombre de usuario para iniciar sesión, si eligió uno. */
  nombreUsuario: string | null
  telefono: string | null
  foto: string | null
  /** El rol principal. */
  rolId: number
  /** Los roles dichos como se leen: "Vendedor, Almacenero". */
  rol: string
  /** Todos los roles de la persona, el principal primero. */
  rolIds: number[]
  roles: string[]
  /** Su ficha de empleado, si la tiene enlazada. */
  empleadoId: number | null
  empleado: string | null
  /** La ruta que tiene a cargo, si tiene. */
  rutaId: number | null
  ruta: string | null
  activo: boolean
  fechaCreacion: string
}

export interface CreateUsuarioRequest {
  nombre: string
  email: string
  password: string
  dni?: string | null
  /** Nombre de usuario para iniciar sesión. Opcional. */
  nombreUsuario?: string | null
  /** Todos sus roles, el primero como principal. Sus permisos son la unión de los de todos. */
  rolIds: number[]
  /** A quién pertenece la cuenta. Opcional: hay cuentas que no son de nadie del padrón. */
  empleadoId?: number | null
  /** La ruta que tiene a cargo. Opcional y de cualquier usuario, no solo de vendedores. */
  rutaId?: number | null
}

export interface UpdateUsuarioRequest {
  nombre: string
  email: string
  dni?: string | null
  /** Null lo quita. */
  nombreUsuario?: string | null
  /** Todos sus roles, el primero como principal. */
  rolIds: number[]
  /** Null desenlaza la ficha. */
  empleadoId?: number | null
  /** Null la quita. */
  rutaId?: number | null
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
