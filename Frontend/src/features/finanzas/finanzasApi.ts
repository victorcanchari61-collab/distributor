import { api } from '../../lib/apiClient'

// --- Métodos de pago ---
//
// Catálogo compartido: compras, cuentas por cobrar, cuentas por pagar, mis
// cobros y Mi Caja lo reusan en vez de declarar cada uno el suyo.

/** Efectivo no pide cuenta; billetera y transferencia sí identifican una. */
export type TipoMetodoPago = 'EFECTIVO' | 'BILLETERA_DIGITAL' | 'TRANSFERENCIA'

export interface MetodoPagoResponse {
  id: number
  nombre: string
  /** Como se muestra al elegirlo: con banco, cuenta, número y titular (o titular y celular en una billetera). */
  etiqueta: string
  tipo: TipoMetodoPago
  /** El número de celular asociado, solo si tipo es Billetera digital. */
  numero: string | null
  /** A qué cuenta financiera va la plata. Null solo en Efectivo. */
  cuentaFinancieraId: number | null
  cuentaFinanciera: string | null
  activo: boolean
  /** Cuántos documentos ya lo usan. Si hay alguno, no se elimina. */
  usos: number
}

export interface MetodoPagoRequest {
  nombre: string
  tipo: TipoMetodoPago
  /** Obligatorio solo en Billetera digital. */
  numero?: string | null
  /** A qué cuenta financiera va la plata. Obligatorio salvo en Efectivo. */
  cuentaFinancieraId?: number | null
}

/** Lo justo para elegir con cuál se cobra: sin saldos ni contadores. */
export interface MetodoPagoOpcion {
  id: number
  nombre: string
  /** Como se muestra al elegirlo: con banco, cuenta, número y titular (o titular y celular en una billetera). */
  etiqueta: string
  tipo: TipoMetodoPago
}

/**
 * El texto de un método en una lista para elegir: el completo, que dice a qué cuenta y a qué
 * titular va la plata. El nombre solo ("BCP-Víctor") no lo dice.
 */
export const etiquetaMetodo = (m: { nombre: string; etiqueta?: string | null }) => m.etiqueta || m.nombre

export const metodoPagoApi = {
  getAll: () => api.get<MetodoPagoResponse[]>('/metodopago'),
  /**
   * Los métodos activos para cobrar. Lo puede pedir quien entrega pedidos aunque
   * no tenga acceso al catálogo de Finanzas.
   */
  opciones: () => api.get<MetodoPagoOpcion[]>('/metodopago/opciones'),
  create: (body: MetodoPagoRequest) => api.post<MetodoPagoResponse>('/metodopago', body),
  update: (id: number, body: MetodoPagoRequest & { activo: boolean }) =>
    api.put<MetodoPagoResponse>(`/metodopago/${id}`, body),
  remove: (id: number) => api.del<void>(`/metodopago/${id}`),
}

