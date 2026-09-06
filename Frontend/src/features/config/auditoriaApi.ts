import { api } from '../../lib/apiClient'

export type AccionAuditoria = 'CREADO' | 'ACTUALIZADO' | 'ELIMINADO'

export interface AuditoriaResponse {
  id: number
  fecha: string
  usuarioId: number | null
  /** "Sistema" cuando el cambio no vino de una sesión. */
  usuario: string
  entidad: string
  entidadId: string
  accion: AccionAuditoria
  /** Campo → valor. En una edición solo los que cambiaron; en alta o baja el registro entero. */
  valoresAnteriores: Record<string, unknown> | null
  valoresNuevos: Record<string, unknown> | null
  /** El producto de la línea editada. Solo lo llena el historial de un documento. */
  descripcion?: string | null
}

export interface FiltrosAuditoria {
  entidad?: string
  accion?: AccionAuditoria | ''
  usuarioId?: number
  desde?: string
  hasta?: string
}

export const auditoriaApi = {
  getAll: (filtros: FiltrosAuditoria = {}) => {
    const q = new URLSearchParams()
    if (filtros.entidad) q.set('entidad', filtros.entidad)
    if (filtros.accion) q.set('accion', filtros.accion)
    if (filtros.usuarioId) q.set('usuarioId', String(filtros.usuarioId))
    if (filtros.desde) q.set('desde', filtros.desde)
    if (filtros.hasta) q.set('hasta', filtros.hasta)
    const qs = q.toString()
    return api.get<AuditoriaResponse[]>(`/auditoria${qs ? `?${qs}` : ''}`)
  },
  getEntidades: () => api.get<string[]>('/auditoria/entidades'),
}
