import { api } from '../../lib/apiClient'

export type TipoMovimientoOperativo = 'INGRESO' | 'EGRESO'

/** Operativo: del giro del negocio. No operativo: aportes, retiros, activos. */
export type OrigenMovimiento = 'OPERATIVO' | 'NO_OPERATIVO'

export const ORIGENES: { value: OrigenMovimiento; label: string }[] = [
  { value: 'OPERATIVO', label: 'Operativo' },
  { value: 'NO_OPERATIVO', label: 'No operativo' },
]

export const origenLabel = (o: string) => ORIGENES.find((x) => x.value === o)?.label ?? o

export interface CategoriaMovimientoResponse {
  id: number
  nombre: string
  descripcion: string | null
  tipo: TipoMovimientoOperativo
  origen: OrigenMovimiento
  activo: boolean
  /** La registra el sistema solo (ventas, préstamos, planilla...): no se edita, no se borra, no se elige a mano. */
  esSistema: boolean
  /** En cuántos movimientos o plantillas se usa. Si hay alguno, no se elimina. */
  usos: number
}

export interface CategoriaMovimientoRequest {
  nombre: string
  descripcion?: string | null
  tipo: TipoMovimientoOperativo
  origen: OrigenMovimiento
  activo: boolean
}

/** Lo justo para elegir la categoría al registrar un movimiento. */
export interface CategoriaOpcion {
  id: number
  nombre: string
  tipo: TipoMovimientoOperativo
  origen: OrigenMovimiento
}

export interface GastoRecurrenteResponse {
  id: number
  nombre: string
  motivoGastoId: number
  motivoGasto: string
  montoEstimado: number
  diaVencimiento: number
  cuentaFinancieraSugeridaId: number | null
  cuentaFinancieraSugerida: string | null
  activo: boolean
}

export interface GastoRecurrenteRequest {
  nombre: string
  motivoGastoId: number
  montoEstimado: number
  diaVencimiento: number
  cuentaFinancieraSugeridaId?: number | null
  activo: boolean
}

/** Una plantilla recurrente que este mes todavía no tiene su pago registrado. */
export interface GastoPendienteResponse {
  gastoRecurrenteId: number
  nombre: string
  motivoGastoId: number
  motivoGasto: string
  montoEstimado: number
  cuentaFinancieraSugeridaId: number | null
  proximoVencimiento: string
  vencido: boolean
}

export interface MovimientoOperativoResponse {
  id: number
  cuentaFinancieraId: number
  cuentaFinanciera: string
  tipo: TipoMovimientoOperativo
  motivoGastoId: number
  motivoGasto: string
  origen: OrigenMovimiento
  /** Lo generó otro módulo (la planilla): se anula desde allí. */
  esSistema: boolean
  monto: number
  fecha: string
  descripcion: string | null
  gastoRecurrenteId: number | null
  usuario: string | null
  anulado: boolean
}

export interface MovimientoOperativoRequest {
  cuentaFinancieraId: number
  tipo: TipoMovimientoOperativo
  motivoGastoId: number
  monto: number
  fecha?: string | null
  descripcion?: string | null
  gastoRecurrenteId?: number | null
}

export const gastoOperativoApi = {
  getCategorias: () => api.get<CategoriaMovimientoResponse[]>('/gastooperativo/categorias'),
  /** Las activas, opcionalmente de un tipo. No pide permiso de Finanzas: lo usa Mi Caja. */
  categoriasOpciones: (tipo?: TipoMovimientoOperativo) =>
    api.get<CategoriaOpcion[]>(`/gastooperativo/categorias/opciones${tipo ? `?tipo=${tipo}` : ''}`),
  crearCategoria: (body: CategoriaMovimientoRequest) =>
    api.post<CategoriaMovimientoResponse>('/gastooperativo/categorias', body),
  actualizarCategoria: (id: number, body: CategoriaMovimientoRequest) =>
    api.put<CategoriaMovimientoResponse>(`/gastooperativo/categorias/${id}`, body),
  eliminarCategoria: (id: number) => api.del<void>(`/gastooperativo/categorias/${id}`),

  getRecurrentes:() => api.get<GastoRecurrenteResponse[]>('/gastooperativo/recurrentes'),
  crearRecurrente: (body: GastoRecurrenteRequest) =>
    api.post<GastoRecurrenteResponse>('/gastooperativo/recurrentes', body),
  actualizarRecurrente: (id: number, body: GastoRecurrenteRequest) =>
    api.put<GastoRecurrenteResponse>(`/gastooperativo/recurrentes/${id}`, body),
  eliminarRecurrente: (id: number) => api.del<void>(`/gastooperativo/recurrentes/${id}`),

  getPendientes: () => api.get<GastoPendienteResponse[]>('/gastooperativo/pendientes'),

  listar: (desde: string, hasta: string) =>
    api.get<MovimientoOperativoResponse[]>(`/gastooperativo?desde=${desde}&hasta=${hasta}`),
  crear: (body: MovimientoOperativoRequest) =>
    api.post<MovimientoOperativoResponse>('/gastooperativo', body),
  anular: (id: number) => api.patch<MovimientoOperativoResponse>(`/gastooperativo/${id}/anular`),
}
