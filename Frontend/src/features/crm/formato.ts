import type { CicloCategorizacion, ColorCategoria } from './categorizacionApi'
import type { EstadoClave } from './crmApi'

/** Soles con separador de miles. Sin decimales por defecto: son cifras de gestión, no de caja. */
export const soles = (n: number, decimales = 0) =>
  `S/ ${n.toLocaleString('es-PE', { minimumFractionDigits: decimales, maximumFractionDigits: decimales })}`

/** Soles con signo explícito: "−S/ 120" o "+S/ 80". Para diferencias. */
export const solesConSigno = (n: number, decimales = 0) =>
  `${n < 0 ? '−' : n > 0 ? '+' : ''}${soles(Math.abs(n), decimales)}`

/** "−83.3 %" o "+12.0 %". Sin base de comparación, un guion. */
export const porcentaje = (n: number | null) =>
  n === null ? '—' : `${n < 0 ? '−' : n > 0 ? '+' : ''}${Math.abs(n).toFixed(1)} %`

/** Rojo si bajó, verde si subió: el color que cualquiera espera de una variación. */
export const colorCambio = (n: number) => (n < 0 ? 'text-red-600' : n > 0 ? 'text-emerald-600' : 'text-ink-soft')

// --- Estados (la escala de caída de 7power) ---

export interface EstadoUi {
  etiqueta: string
  /** Qué rango de caída cubre. */
  rango: string
  color: string
  fondo: string
}

/** De mayor a menor gravedad, que es el orden de las tarjetas. */
export const ORDEN_ESTADOS: EstadoClave[] = ['CRITICO', 'RIESGO', 'SEGUIMIENTO', 'NORMAL', 'SIN_BASE']

export const ESTADOS_UI: Record<EstadoClave, EstadoUi> = {
  CRITICO: { etiqueta: 'Crítico', rango: '71 % o más', color: '#dc2626', fondo: '#fef2f2' },
  RIESGO: { etiqueta: 'En riesgo', rango: '26 - 70 %', color: '#ea580c', fondo: '#fff7ed' },
  SEGUIMIENTO: { etiqueta: 'En seguimiento', rango: '11 - 25 %', color: '#2563eb', fondo: '#eff6ff' },
  NORMAL: { etiqueta: 'Normal', rango: '0 - 10 %', color: '#16a34a', fondo: '#f0fdf4' },
  SIN_BASE: { etiqueta: 'Sin comparación', rango: 'Sin ventas el año anterior', color: '#64748b', fondo: '#f1f5f9' },
}

/**
 * Los tramos de días sin comprar con los que se filtra Clientes con caída: la misma escala de siempre (0-15 normal,
 * 16-30 seguimiento, 31-60 en riesgo, 61 o más crítico). Un cliente que dejó de comprar se encuentra por aquí.
 */
export const TRAMOS_INACTIVIDAD: { id: string; label: string; desde: number; hasta: number | null }[] = [
  { id: '16', label: '16 a 30 días', desde: 16, hasta: 30 },
  { id: '31', label: '31 a 60 días', desde: 31, hasta: 60 },
  { id: '61', label: '61 días o más', desde: 61, hasta: null },
]

/** El color de los días sin comprar, con la misma escala. */
export const colorDeDias = (dias: number | null) => {
  if (dias === null) return ESTADOS_UI.SIN_BASE.color
  if (dias >= 61) return ESTADOS_UI.CRITICO.color
  if (dias >= 31) return ESTADOS_UI.RIESGO.color
  if (dias >= 16) return ESTADOS_UI.SEGUIMIENTO.color
  return ESTADOS_UI.NORMAL.color
}

/** "20/10/2026" para un día del servidor, sin pasar por una zona horaria. */
export const fechaDia = (iso: string | null) => {
  if (!iso) return '—'
  const [anio, mes, dia] = iso.slice(0, 10).split('-')
  return `${dia}/${mes}/${anio}`
}

/** Los meses abreviados, para los ejes de los gráficos. */
const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'set', 'oct', 'nov', 'dic']

/** El mes de un YYYY-MM-DD, abreviado ("oct"), sin pasar por una zona horaria. */
export const mesCorto = (iso: string) => MESES[Number(iso.slice(5, 7)) - 1] ?? ''

/** El nombre y la inicial del apellido: "GUSTAVO MIRANDA MARTINEZ" → "GUSTAVO M.". */
export const nombreCorto = (nombre: string | null) => {
  const partes = (nombre ?? '').trim().split(/\s+/).filter(Boolean)
  if (partes.length < 2) return partes[0] ?? ''
  return `${partes[0]} ${partes[1].charAt(0)}.`
}

// --- Categorización ---

export const CICLOS: { id: CicloCategorizacion; label: string }[] = [
  { id: 'MENSUAL', label: 'Mensual' },
  { id: 'TRIMESTRAL', label: 'Trimestral' },
  { id: 'CUATRIMESTRAL', label: 'Cuatrimestral' },
  { id: 'ANUAL', label: 'Anual' },
]

/** Un día como YYYY-MM-DD sin pasar por UTC (que en Perú lo correría al día anterior). */
const dia = (anio: number, mes: number, d: number) =>
  `${anio}-${String(mes).padStart(2, '0')}-${String(d).padStart(2, '0')}`

/** El día siguiente a uno YYYY-MM-DD: cuándo cambia el resultado. */
export function diaSiguiente(texto: string) {
  const [anio, mes, d] = texto.slice(0, 10).split('-').map(Number)
  const siguiente = new Date(anio, mes - 1, d + 1)
  return dia(siguiente.getFullYear(), siguiente.getMonth() + 1, siguiente.getDate())
}

export const COLORES_CATEGORIA: { id: ColorCategoria; label: string }[] = [
  { id: 'sky', label: 'Celeste' },
  { id: 'emerald', label: 'Verde' },
  { id: 'amber', label: 'Amarillo' },
  { id: 'orange', label: 'Naranja' },
  { id: 'violet', label: 'Violeta' },
  { id: 'rose', label: 'Rosa' },
  { id: 'slate', label: 'Gris' },
]
