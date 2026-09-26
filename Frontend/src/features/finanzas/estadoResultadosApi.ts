import { api } from '../../lib/apiClient'

/** Un renglón del estado: una categoría con lo que sumó en el rango. */
export interface LineaResultado {
  concepto: string
  monto: number
  /** Cuántos movimientos la forman. */
  movimientos: number
}

/**
 * Si el negocio gana: lo vendido menos lo que costó, menos los gastos de
 * operar. Lo no operativo (préstamos, aportes, retiros) va aparte y no suma.
 */
export interface EstadoResultadosResponse {
  desde: string
  hasta: string
  /** Lo cobrado en las ventas, con IGV y con los recojos restados. */
  ventasBrutas: number
  igv: number
  /** Las ventas sin IGV: el ingreso real. */
  ventasNetas: number
  costoVentas: number
  utilidadBruta: number
  margenBruto: number | null
  otrosIngresos: LineaResultado[]
  totalOtrosIngresos: number
  gastosOperativos: LineaResultado[]
  totalGastosOperativos: number
  utilidadOperativa: number
  margenOperativo: number | null
  ingresosNoOperativos: LineaResultado[]
  totalIngresosNoOperativos: number
  egresosNoOperativos: LineaResultado[]
  totalEgresosNoOperativos: number
  /** Cuántas notas de venta entraron. */
  ventas: number
  /** Líneas vendidas sin costo: ahí la utilidad sale inflada. */
  lineasSinCosto: number
}

export const estadoResultadosApi = {
  /** Entre dos días (YYYY-MM-DD), ambos incluidos. Nunca más de un año. */
  calcular: (desde: string, hasta: string) =>
    api.get<EstadoResultadosResponse>(`/estadoresultados?desde=${desde}&hasta=${hasta}`),
}
