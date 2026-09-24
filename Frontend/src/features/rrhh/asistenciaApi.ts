import { api } from '../../lib/apiClient'

export type EstadoAsistencia = 'PRESENTE' | 'TARDANZA' | 'FALTA' | 'PERMISO'

/** Un empleado, un día: si vino, faltó, llegó tarde o tuvo permiso. Se marca a mano. */
export interface AsistenciaResponse {
  id: number
  empleadoId: number
  empleado: string
  cargo: string | null
  /** Solo la fecha: la hora no importa. */
  fecha: string
  estado: EstadoAsistencia
  observacion: string | null
  usuario: string | null
  fechaRegistro: string
  anulado: boolean
}

export interface CrearAsistenciaRequest {
  empleadoId: number
  fecha: string
  estado: EstadoAsistencia
  observacion?: string | null
}

export interface EditarAsistenciaRequest {
  estado: EstadoAsistencia
  observacion?: string | null
}

/** Cuántos hay de cada estado en el rango consultado. */
export interface ResumenAsistencia {
  presentes: number
  tardanzas: number
  faltas: number
  permisos: number
}

const rango = (desde: string, hasta: string, empleadoId?: number | null) =>
  `?desde=${desde}&hasta=${hasta}${empleadoId ? `&empleadoId=${empleadoId}` : ''}`

export const asistenciaApi = {
  listar: (desde: string, hasta: string, empleadoId?: number | null) =>
    api.get<AsistenciaResponse[]>(`/asistencia${rango(desde, hasta, empleadoId)}`),

  resumen: (desde: string, hasta: string, empleadoId?: number | null) =>
    api.get<ResumenAsistencia>(`/asistencia/resumen${rango(desde, hasta, empleadoId)}`),

  crear: (body: CrearAsistenciaRequest) => api.post<AsistenciaResponse>('/asistencia', body),
  editar: (id: number, body: EditarAsistenciaRequest) =>
    api.put<AsistenciaResponse>(`/asistencia/${id}`, body),

  /** Deja sin efecto una marca hecha por error. No se borra: queda el historial. */
  anular: (id: number) => api.patch<AsistenciaResponse>(`/asistencia/${id}/anular`),
}
