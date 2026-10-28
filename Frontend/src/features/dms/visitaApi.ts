import { api } from '../../lib/apiClient'
import type { EstadoClave } from '../crm/crmApi'

/** Un cliente al que toca visitar ese día. */
export interface VisitaResponse {
  /** El día al que corresponde la visita. */
  fecha: string
  /** LUNES, MARTES... el día de visita del cliente. */
  dia: string
  clienteId: number
  cliente: string
  documento: string
  direccion: string | null
  mercado: string | null
  telefono: string | null
  rutaId: number | null
  ruta: string | null
  vendedorId: number | null
  vendedor: string | null
  /** Si ya se le tomó pedido ese día: lo que separa lo hecho de lo que falta. */
  atendido: boolean
  pedidoId: number | null
  pedidoNumero: string | null
  total: number
  /**
   * Cómo viene comprando el cliente este año frente al mismo tramo del anterior (CRITICO, RIESGO, SEGUIMIENTO,
   * NORMAL o SIN_BASE). Null si no hay datos o quien mira no puede abrir Clientes con caída del CRM.
   */
  riesgo: EstadoClave | null
  /** Positiva si el cliente cayó, en %. */
  caidaPct: number | null
  /** La próxima acción de su seguimiento programado. */
  accionPendiente: string | null
  accionVencida: boolean
}

export interface ResumenVisitas {
  programadas: number
  atendidas: number
  pendientes: number
  total: number
}

/** Los filtros de la lista. */
export interface ConsultaVisitas {
  desde?: string
  hasta?: string
  rutaId?: number
  vendedorId?: number
}

const query = (c: ConsultaVisitas) => {
  const partes = new URLSearchParams()
  if (c.desde) partes.set('desde', c.desde)
  if (c.hasta) partes.set('hasta', c.hasta)
  if (c.rutaId) partes.set('rutaId', String(c.rutaId))
  if (c.vendedorId) partes.set('vendedorId', String(c.vendedorId))
  const texto = partes.toString()
  return texto ? `?${texto}` : ''
}

export const visitaApi = {
  /** Sin rango, hoy. */
  listar: (c: ConsultaVisitas = {}) => api.get<VisitaResponse[]>(`/visita${query(c)}`),
  resumen: (c: ConsultaVisitas = {}) => api.get<ResumenVisitas>(`/visita/resumen${query(c)}`),

  /**
   * Los días válidos, servidos por el backend.
   *
   * La pantalla no lleva su propia copia a propósito: dos listas iguales en
   * dos sitios acaban siendo dos listas distintas.
   */
  dias: () => api.get<string[]>('/visita/dias'),
}
