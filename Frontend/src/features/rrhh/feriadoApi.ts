import { api } from '../../lib/apiClient'

export type PagoFeriado = 'NORMAL' | 'DOBLE' | 'TRIPLE'

/** Un día no laborable o de pago especial. Se registra a mano: no hay calendario oficial cargado. */
export interface FeriadoResponse {
  id: number
  fecha: string
  nombre: string
  pago: PagoFeriado
}

export interface FeriadoRequest {
  fecha: string
  nombre: string
  pago: PagoFeriado
}

export const feriadoApi = {
  getAll: () => api.get<FeriadoResponse[]>('/feriado'),
  create: (body: FeriadoRequest) => api.post<FeriadoResponse>('/feriado', body),
  update: (id: number, body: FeriadoRequest) => api.put<FeriadoResponse>(`/feriado/${id}`, body),
  remove: (id: number) => api.del<void>(`/feriado/${id}`),
}
