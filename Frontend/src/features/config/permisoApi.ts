import { api } from '../../lib/apiClient'

/** Hasta cuando vale un permiso concedido a una persona suelta. */
export const ALCANCE = {
  /** Se gasta al usarlo. */
  unaVez: 0,
  /** Vale hasta una fecha y hora. */
  temporal: 1,
  /** No vence. */
  permanente: 2,
} as const

export type Alcance = (typeof ALCANCE)[keyof typeof ALCANCE]

export const ALCANCE_LABEL: Record<Alcance, string> = {
  [ALCANCE.unaVez]: 'Una sola vez',
  [ALCANCE.temporal]: 'Por un tiempo',
  [ALCANCE.permanente]: 'Para siempre',
}

export interface UsuarioPermisoResponse {
  id: number
  usuarioId: number
  submodulo: string
  accion: string
  alcance: Alcance
  expiraEn: string | null
  /** Veces que se uso. Solo cuenta para las de una sola vez. */
  usos: number
  revocado: boolean
  motivo: string | null
  fechaOtorgado: string
  /** Si ahora mismo sirve. Lo calcula el servidor. */
  vigente: boolean
}

export interface ConcederPermisoRequest {
  usuarioId: number
  submodulo: string
  accion: string
  alcance: Alcance
  /** Obligatoria solo si el alcance es temporal. */
  expiraEn?: string | null
  motivo?: string | null
}

/** Qué filas ve alguien en cada pantalla: submódulo → todos | misclientes | propios. */
export type AlcancesDatos = Record<string, string>

export interface CatalogoAlcances {
  /** Las pantallas donde el alcance tiene sentido: las que tienen filas que son de alguien. */
  submodulos: string[]
  niveles: string[]
}

export const permisoApi = {
  /** GET /api/permiso/alcances/catalogo */
  catalogoAlcances: () => api.get<CatalogoAlcances>('/permiso/alcances/catalogo'),

  /** GET /api/permiso/alcances/rol/{id}. Lo que falta es "todos": el backend no guarda lo que no limita. */
  alcancesDeRol: (rolId: number) => api.get<AlcancesDatos>(`/permiso/alcances/rol/${rolId}`),

  /** PUT /api/permiso/alcances/rol/{id} — reemplaza los alcances del rol. */
  guardarAlcancesRol: (rolId: number, alcances: AlcancesDatos) =>
    api.put<void>(`/permiso/alcances/rol/${rolId}`, alcances),

  /** GET /api/permiso/alcances/usuario/{id}. Lo que falta es "igual que su rol". */
  alcancesDeUsuario: (usuarioId: number) => api.get<AlcancesDatos>(`/permiso/alcances/usuario/${usuarioId}`),

  /** PUT /api/permiso/alcances/usuario/{id} — reemplaza los de la persona; los que no viajan siguen a su rol. */
  guardarAlcancesUsuario: (usuarioId: number, alcances: AlcancesDatos) =>
    api.put<void>(`/permiso/alcances/usuario/${usuarioId}`, alcances),

  /** GET /api/permiso/usuario/{id} — excepciones de una persona. */
  deUsuario: (usuarioId: number) =>
    api.get<UsuarioPermisoResponse[]>(`/permiso/usuario/${usuarioId}`),

  /** POST /api/permiso/conceder */
  conceder: (body: ConcederPermisoRequest) =>
    api.post<UsuarioPermisoResponse>('/permiso/conceder', body),

  /** PATCH /api/permiso/{id}/revocar */
  revocar: (id: number) => api.patch<void>(`/permiso/${id}/revocar`, {}),
}
