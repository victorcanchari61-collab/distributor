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

export const permisoApi = {
  /** GET /api/permiso/usuario/{id} — excepciones de una persona. */
  deUsuario: (usuarioId: number) =>
    api.get<UsuarioPermisoResponse[]>(`/permiso/usuario/${usuarioId}`),

  /** POST /api/permiso/conceder */
  conceder: (body: ConcederPermisoRequest) =>
    api.post<UsuarioPermisoResponse>('/permiso/conceder', body),

  /** PATCH /api/permiso/{id}/revocar */
  revocar: (id: number) => api.patch<void>(`/permiso/${id}/revocar`, {}),
}
