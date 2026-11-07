import { api } from './apiClient'

export type SeveridadAlerta = 'CRITICA' | 'ADVERTENCIA' | 'INFO'

export type TipoAlerta =
  | 'STOCK_BAJO'
  | 'LOTE_POR_VENCER'
  | 'COMPRA_PENDIENTE'
  | 'CREDITO_PENDIENTE'
  | 'RESERVA_VENCIDA'
  | 'STOCK_REPUESTO'
  | 'DOCUMENTO_VEHICULO'
  | 'LICENCIA_CONDUCTOR'
  | 'SOLICITUD_ACCESO'
  | 'SEGUIMIENTO_CLIENTE'
  /** Una solicitud de compra enviada por el almacén y todavía sin atender (solo para quien la atiende). */
  | 'SOLICITUD_COMPRA'
  /** La respuesta a una solicitud propia: rechazada con su motivo, o ya con su orden de compra. */
  | 'SOLICITUD_COMPRA_RESPUESTA'

export interface AlertaResponse {
  id: string
  tipo: TipoAlerta
  severidad: SeveridadAlerta
  titulo: string
  detalle: string
  /** Id de vista del menú ("inv.stock") para navegar al hacer clic. */
  ruta: string | null
  fecha: string | null
}

export const alertaApi = {
  getAll: () => api.get<AlertaResponse[]>('/alertas'),
}
