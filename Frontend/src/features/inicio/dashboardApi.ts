import { api } from '../../lib/apiClient'

/**
 * El tablero pide un bloque por cada pantalla de la que saca datos. Así uno que falla, o al que
 * la persona no tiene acceso, no le quita a los demás su gráfico.
 *
 * Los `Date` del backend llegan como "2026-09-05T00:00:00Z": son días de calle, no instantes,
 * así que se leen tal cual (ver `diaCorto`), sin pasarlos por la zona horaria.
 */

export interface DashItem {
  nombre: string
  valor: number
  cantidad: number
}

// ------------------------------------------------------------------ Ventas

export interface DashTotalesVentas {
  importe: number
  notas: number
  clientes: number
  ticket: number
}

export interface DashDiaVenta {
  fecha: string
  importe: number
  notas: number
  importeAnterior: number
}

export interface DashMes {
  nombre: string
  diaActual: number
  diasMes: number
  acumulado: number
  proyectado: number
  mesAnterior: number
  mesAnteriorMismoPunto: number
  serieActual: number[]
  serieAnterior: number[]
  serieProyeccion: (number | null)[]
}

export interface DashPareto {
  nombre: string
  valor: number
  acumulado: number
}

export interface DashCalor {
  dia: number
  hora: number
  importe: number
  notas: number
}

export interface DashboardVentas {
  desde: string
  hasta: string
  soloPropio: boolean
  actual: DashTotalesVentas
  anterior: DashTotalesVentas
  serie: DashDiaVenta[]
  atipicos: { indice: number; tipo: 'PICO' | 'CAIDA' }[]
  mes: DashMes
  porVendedor: DashItem[]
  porCategoria: DashItem[]
  porFormaPago: DashItem[]
  topProductos: DashItem[]
  pareto: DashPareto[]
  clientesAl80: number
  clientesTotal: number
  calor: DashCalor[]
}

// --------------------------------------------------------------- Ganancias

export interface DashDiaGanancia {
  fecha: string
  importe: number
  ganancia: number
  margen: number | null
}

export interface DashProductoGanancia {
  nombre: string
  categoria: string
  importe: number
  ganancia: number
  margen: number | null
}

export interface DashboardGanancias {
  desde: string
  hasta: string
  soloPropio: boolean
  importe: number
  costo: number
  ganancia: number
  margen: number | null
  gananciaAnterior: number
  margenAnterior: number | null
  serie: DashDiaGanancia[]
  productos: DashProductoGanancia[]
  porCategoria: DashItem[]
  lineasSinCosto: number
}

// ---------------------------------------------------------------- Cobranza

export interface DashDeudor {
  cliente: string
  saldo: number
  notas: number
  dias: number
}

export interface DashboardCobranza {
  desde: string
  hasta: string
  totalPorCobrar: number
  cuentas: number
  clientes: number
  antiguedad: DashItem[]
  deudores: DashDeudor[]
  cobradoPeriodo: number
  metodos: string[]
  cobros: { fecha: string; valores: number[] }[]
  creditoOtorgado: number
}

// -------------------------------------------------------------- Inventario

export interface DashCobertura {
  producto: string
  stock: number
  unidad: string
  ventaDiaria: number
  dias: number
}

export interface DashboardInventario {
  valorTotal: number
  productos: number
  cobertura: DashCobertura[]
  salud: DashItem[]
  valorPorCategoria: DashItem[]
  dormido: DashItem[]
  dormidoTotal: number
  vencimientos: DashItem[]
}

// ----------------------------------------------------------------- Reparto

export interface DashboardReparto {
  desde: string
  hasta: string
  soloPropio: boolean
  serie: { fecha: string; pendientes: number; confirmados: number; anulados: number }[]
  porEstado: DashItem[]
  embudo: DashItem[]
  novedadesPorMotivo: DashItem[] | null
  importeNovedades: number
  entregaCompleta: number | null
}

const rango = (desde: string, hasta: string) => `?desde=${desde}&hasta=${hasta}`

export const dashboardApi = {
  ventas: (desde: string, hasta: string) => api.get<DashboardVentas>(`/dashboard/ventas${rango(desde, hasta)}`),
  ganancias: (desde: string, hasta: string) => api.get<DashboardGanancias>(`/dashboard/ganancias${rango(desde, hasta)}`),
  cobranza: (desde: string, hasta: string) => api.get<DashboardCobranza>(`/dashboard/cobranza${rango(desde, hasta)}`),
  inventario: () => api.get<DashboardInventario>('/dashboard/inventario'),
  reparto: (desde: string, hasta: string) => api.get<DashboardReparto>(`/dashboard/reparto${rango(desde, hasta)}`),
}
