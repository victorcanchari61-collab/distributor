import { api } from '../../lib/apiClient'
import type { Alcance } from './permisoApi'

export const ESTADO_SOLICITUD = {
  pendiente: 0,
  aprobada: 1,
  rechazada: 2,
} as const

export type EstadoSolicitud = (typeof ESTADO_SOLICITUD)[keyof typeof ESTADO_SOLICITUD]

export interface SolicitudPermisoResponse {
  id: number
  usuarioId: number
  /** Nombre de quien pide. */
  usuario: string
  submodulo: string
  accion: string
  motivo: string | null
  /** El documento sobre el que iba, si venia de uno. */
  referencia: string | null
  estado: EstadoSolicitud
  fechaSolicitud: string
  fechaResolucion: string | null
  respuesta: string | null
}

export const solicitudApi = {
  /** POST /api/permiso/solicitar — pedir una acción bloqueada. */
  solicitar: (body: {
    submodulo: string
    accion: string
    motivo?: string | null
    referencia?: string | null
  }) => api.post<SolicitudPermisoResponse>('/permiso/solicitar', body),

  /** GET /api/permiso/solicitudes — la bandeja del admin. */
  bandeja: (soloPendientes = false) =>
    api.get<SolicitudPermisoResponse[]>(`/permiso/solicitudes?soloPendientes=${soloPendientes}`),

  /** GET /api/permiso/solicitudes/mias */
  mias: () => api.get<SolicitudPermisoResponse[]>('/permiso/solicitudes/mias'),

  /** POST /api/permiso/solicitudes/{id}/aprobar */
  aprobar: (id: number, body: { alcance: Alcance; expiraEn?: string | null; respuesta?: string | null }) =>
    api.post<SolicitudPermisoResponse>(`/permiso/solicitudes/${id}/aprobar`, body),

  /** POST /api/permiso/solicitudes/{id}/rechazar */
  rechazar: (id: number, respuesta?: string | null) =>
    api.post<SolicitudPermisoResponse>(`/permiso/solicitudes/${id}/rechazar`, { respuesta }),
}
