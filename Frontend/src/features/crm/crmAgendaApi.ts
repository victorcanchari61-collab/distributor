import { api } from '../../lib/apiClient'
import type { ResultadoGestion, TipoGestion } from './crmApi'

export type EstadoTarea = 'VENCIDA' | 'HOY' | 'PROXIMA'

/** Una próxima acción de seguimiento que sigue abierta. */
export interface TareaCrm {
  /** La gestión que dejó anotada esta acción. */
  gestionId: number
  clienteId: number
  codigo: string
  cliente: string
  telefono: string | null
  mercado: string | null
  ruta: string | null
  accion: string
  /** El día en que toca. */
  fecha: string
  estado: EstadoTarea
  /** Cuántos días lleva vencida (0 si no lo está). */
  diasAtraso: number
  /** Lo que se habló cuando se anotó esta acción. */
  nota: string
  tipo: TipoGestion
  resultado: ResultadoGestion
  registradaPor: string | null
}

export interface ResumenAgendaCrm {
  vencidas: number
  hoy: number
  proximas: number
  vencidaDesde: string | null
}

export interface AgendaCrm {
  quien: 'mias' | 'todas'
  /** Quien pregunta ve solo parte de la cartera (según su alcance). */
  soloPropios: boolean
  /** De todas las acciones de `quien`, antes de elegir un estado. */
  resumen: ResumenAgendaCrm
  items: TareaCrm[]
}

export const agendaApi = {
  tareas: (quien: 'mias' | 'todas', estado?: 'vencidas' | 'hoy' | 'proximas') => {
    const partes = new URLSearchParams({ quien })
    if (estado) partes.set('estado', estado)
    return api.get<AgendaCrm>(`/crm/tareas?${partes.toString()}`)
  },
}
