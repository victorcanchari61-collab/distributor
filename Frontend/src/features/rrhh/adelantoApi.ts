import { api } from '../../lib/apiClient'
import type { CuentaPagoOpcion } from './planillaApi'

export type EstadoAdelanto = 'PENDIENTE' | 'DESCONTADO' | 'ANULADO'

/** Una fila de la lista: solo lo que muestra la tabla. */
export interface AdelantoFila {
  id: number
  empleadoId: number
  empleado: string
  fecha: string
  monto: number
  descontado: number
  saldo: number
  /** El lunes de la primera semana en que se descuenta. */
  descontarDesde: string
  /** Cuánto por semana; null es todo de una vez. */
  cuotaSemanal: number | null
  estado: EstadoAdelanto
  cuentaFinanciera: string | null
}

/** Lo descontado de un adelanto en una planilla pagada. */
export interface AdelantoDescuento {
  planillaId: number
  desde: string
  hasta: string
  monto: number
  fechaPago: string | null
}

export interface AdelantoResponse extends AdelantoFila {
  cargo: string | null
  observacion: string | null
  usuario: string | null
  fechaCreacion: string
  descuentos: AdelantoDescuento[]
}

export interface ResumenAdelantos {
  saldoPendiente: number
  vigentes: number
  empleados: number
  entregadoMes: number
}

/** Un empleado para darle un adelanto: con su sueldo y lo que ya debe. */
export interface EmpleadoAdelanto {
  id: number
  nombreCompleto: string
  cargo: string | null
  sueldoSemanal: number | null
  saldoAdelantos: number
}

export interface CrearAdelantoRequest {
  empleadoId: number
  monto: number
  fecha: string
  cuentaFinancieraId: number
  /** Cualquier día de la primera semana en que se descuenta. */
  descontarDesde: string
  /** null: todo de una vez. */
  cuotaSemanal: number | null
  observacion?: string | null
}

export interface PlanAdelantoRequest {
  descontarDesde: string
  cuotaSemanal: number | null
}

export const adelantoApi = {
  listar: () => api.get<AdelantoFila[]>('/adelanto'),
  resumen: () => api.get<ResumenAdelantos>('/adelanto/resumen'),
  get: (id: number) => api.get<AdelantoResponse>(`/adelanto/${id}`),
  empleados: () => api.get<EmpleadoAdelanto[]>('/adelanto/empleados'),
  cuentas: () => api.get<CuentaPagoOpcion[]>('/adelanto/cuentas'),
  crear: (body: CrearAdelantoRequest) => api.post<AdelantoResponse>('/adelanto', body),
  cambiarPlan: (id: number, body: PlanAdelantoRequest) => api.put<AdelantoResponse>(`/adelanto/${id}/plan`, body),
  /** Solo si todavía no se descontó nada: la plata vuelve a la cuenta de donde salió. */
  anular: (id: number) => api.patch<AdelantoResponse>(`/adelanto/${id}/anular`),
}

/** El lunes de la semana de esa fecha (YYYY-MM-DD). */
export function lunesDe(fecha: string): string {
  const [a, m, d] = fecha.slice(0, 10).split('-').map(Number)
  const dia = new Date(a, m - 1, d)
  dia.setDate(dia.getDate() - ((dia.getDay() + 6) % 7))
  return isoLocal(dia)
}

/** Esa fecha más tantos días (YYYY-MM-DD). */
export function sumarDias(fecha: string, dias: number): string {
  const [a, m, d] = fecha.slice(0, 10).split('-').map(Number)
  return isoLocal(new Date(a, m - 1, d + dias))
}

const isoLocal = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`

/** "Todo de una vez" o "S/ 100 por semana". */
export const comoSeDescuenta = (a: Pick<AdelantoFila, 'cuotaSemanal'>) =>
  a.cuotaSemanal ? `S/ ${a.cuotaSemanal.toFixed(2)} por semana` : 'Todo de una vez'
