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
  /** Día por día: lo fiado, lo cobrado de lo fiado y lo que se debía al cierre. */
  evolucion: { fecha: string; fiado: number; cobrado: number; saldo: number }[]
  /** Lo que se debe hoy por ruta del cliente (cantidad = clientes). */
  porRuta: DashItem[]
  /** Lo cobrado por quien lo registró (cantidad = cobros). */
  porCobrador: DashItem[]
  porMetodo: DashItem[]
}

// ----------------------------------------------------------------- Compras

export interface DashAcreedor {
  proveedor: string
  saldo: number
  compras: number
  dias: number
}

export interface DashCostoProducto {
  producto: string
  unidad: string
  costoAnterior: number
  costoActual: number
  /** En %: positivo subió, negativo bajó. */
  variacion: number
}

export interface DashboardCompras {
  desde: string
  hasta: string
  totalPorPagar: number
  cuentas: number
  proveedores: number
  antiguedad: DashItem[]
  acreedores: DashAcreedor[]
  porRecibir: number
  comprado: number
  compradoAnterior: number
  compras: number
  compradoCredito: number
  pagadoPeriodo: number
  metodos: string[]
  pagos: { fecha: string; valores: number[] }[]
  serie: { fecha: string; contado: number; credito: number }[]
  porProveedor: DashItem[]
  porCategoria: DashItem[]
  costos: DashCostoProducto[]
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

// ----------------------------------------------------------------- Reportes

/** Los dashboards que tienen pestaña Reportes; es también el pedazo de su ruta en el API. */
export type Tablero = 'ventas' | 'rentabilidad' | 'cobranza' | 'compras' | 'inventario' | 'reparto'

export type TipoDato = 'texto' | 'entero' | 'cantidad' | 'moneda' | 'porcentaje' | 'fecha'

export interface ColumnaReporte {
  clave: string
  titulo: string
  tipo: TipoDato
  /** Otra llave de la fila que va debajo, más chica. */
  apoyo: string | null
  /** Se resalta; un monto negativo, en rojo. */
  destacada: boolean
  suma: boolean
}

export interface OpcionReporte {
  valor: string
  texto: string
}

/**
 * El reporte de un dashboard, ya armado por el backend: sus vistas, columnas, filas, totales y
 * filtros. La pestaña lo dibuja sin saber de qué dashboard es.
 */
export interface Reporte {
  tablero: Tablero
  titulo: string
  vista: string
  vistas: { id: string; texto: string }[]
  conFechas: boolean
  desde: string | null
  hasta: string | null
  columnas: ColumnaReporte[]
  filas: Record<string, unknown>[]
  totales: Record<string, unknown>
  filtros: { clave: string; titulo: string; opciones: OpcionReporte[] }[]
  resumen: { titulo: string; valor: number; tipo: TipoDato; nota: string | null; tono: 'sys' | 'neutral' | 'success' | 'warning' | 'danger' }[]
  aviso: string | null
  nota: string | null
}

export interface ConsultaReporte {
  desde?: string
  hasta?: string
  vista?: string
  /** Solo para el PDF: la tabla ya busca en pantalla. */
  buscar?: string
  /** Los filtros de lista, por su clave (cliente, ruta...). */
  filtros: Record<string, string | undefined>
}

const queryReporte = (c: ConsultaReporte) => {
  const q = new URLSearchParams()
  for (const [k, v] of Object.entries({ desde: c.desde, hasta: c.hasta, vista: c.vista, buscar: c.buscar }))
    if (v) q.set(k, v)
  for (const [k, v] of Object.entries(c.filtros)) if (v) q.set(`f.${k}`, v)
  return `?${q.toString()}`
}

const rango = (desde: string, hasta: string) => `?desde=${desde}&hasta=${hasta}`

export const dashboardApi = {
  ventas: (desde: string, hasta: string) => api.get<DashboardVentas>(`/dashboard/ventas${rango(desde, hasta)}`),
  ganancias: (desde: string, hasta: string) => api.get<DashboardGanancias>(`/dashboard/ganancias${rango(desde, hasta)}`),
  cobranza: (desde: string, hasta: string) => api.get<DashboardCobranza>(`/dashboard/cobranza${rango(desde, hasta)}`),
  compras: (desde: string, hasta: string) => api.get<DashboardCompras>(`/dashboard/compras${rango(desde, hasta)}`),
  inventario: () => api.get<DashboardInventario>('/dashboard/inventario'),
  reparto: (desde: string, hasta: string) => api.get<DashboardReparto>(`/dashboard/reparto${rango(desde, hasta)}`),

  reporte: (tablero: Tablero, c: ConsultaReporte) => api.get<Reporte>(`/dashboard/${tablero}/reporte${queryReporte(c)}`),
  /** El mismo reporte en PDF, con la búsqueda de la tabla incluida. */
  rutaReportePdf: (tablero: Tablero, c: ConsultaReporte) => `/dashboard/${tablero}/reporte/pdf${queryReporte(c)}`,
}
