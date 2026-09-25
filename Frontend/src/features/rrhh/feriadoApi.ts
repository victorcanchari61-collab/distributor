import { api } from '../../lib/apiClient'

/**
 * Un día no laborable. Se registra a mano: no hay calendario oficial cargado.
 * Quien trabaja un feriado cobra ese día doble en la planilla.
 */
export interface FeriadoResponse {
  id: number
  fecha: string
  nombre: string
}

export interface FeriadoRequest {
  fecha: string
  nombre: string
}

export const feriadoApi = {
  getAll: () => api.get<FeriadoResponse[]>('/feriado'),
  create: (body: FeriadoRequest) => api.post<FeriadoResponse>('/feriado', body),
  update: (id: number, body: FeriadoRequest) => api.put<FeriadoResponse>(`/feriado/${id}`, body),
  remove: (id: number) => api.del<void>(`/feriado/${id}`),
}
