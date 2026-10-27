import type { BadgeTone } from '../../components/ui'
import { fechaCorta } from '../../lib/fechas'
import type { CicloCategorizacion, ColorCategoria } from './categorizacionApi'
import type { NivelCliente, PeriodoCrm, RangoCrm, ResultadoGestion, TipoGestion } from './crmApi'

/** Soles con separador de miles, siempre con céntimos. */
export const soles = (n: number) =>
  `S/ ${n.toLocaleString('es-PE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`

/** Soles con signo explícito: "−S/ 120.00" o "+S/ 80.00". Para diferencias. */
export const solesConSigno = (n: number) =>
  `${n < 0 ? '−' : n > 0 ? '+' : ''}${soles(Math.abs(n))}`

/** "−83.3 %" o "+12.0 %". Sin base de comparación, un guion. */
export const porcentaje = (n: number | null) =>
  n === null ? '—' : `${n < 0 ? '−' : n > 0 ? '+' : ''}${Math.abs(n).toFixed(1)} %`

export const PERIODOS: { id: PeriodoCrm; label: string; contra: string }[] = [
  { id: 'semana', label: 'Semana', contra: 'los 7 días anteriores' },
  { id: 'mes', label: 'Mes', contra: 'el mes anterior' },
  { id: 'anio', label: 'Año', contra: 'el mismo periodo del año pasado' },
]

export const rango = (r: RangoCrm) => `${fechaCorta(r.desde)} – ${fechaCorta(r.hasta)}`

export const NIVELES: Record<NivelCliente, { label: string; tone: BadgeTone }> = {
  CRITICO: { label: 'Crítico', tone: 'danger' },
  ALTO: { label: 'Alto', tone: 'warning' },
  MEDIO: { label: 'Medio', tone: 'sys' },
  ESTABLE: { label: 'Estable', tone: 'success' },
  NUEVO: { label: 'Nuevo', tone: 'neutral' },
  INACTIVO: { label: 'Inactivo', tone: 'neutral' },
}

/** Rojo si bajó, verde si subió: el color que cualquiera espera de una variación. */
export const colorCambio = (n: number) =>
  n < 0 ? 'text-red-600' : n > 0 ? 'text-emerald-600' : 'text-ink-soft'

export const TIPOS_GESTION: Record<TipoGestion, string> = {
  LLAMADA: 'Llamada',
  VISITA: 'Visita',
  WHATSAPP: 'WhatsApp',
  OTRO: 'Otro',
}

export const RESULTADOS_GESTION: Record<ResultadoGestion, { label: string; tone: BadgeTone }> = {
  CONTACTADO: { label: 'Contactado', tone: 'neutral' },
  SIN_RESPUESTA: { label: 'Sin respuesta', tone: 'warning' },
  PROMESA_COMPRA: { label: 'Promete comprar', tone: 'success' },
  PROMESA_PAGO: { label: 'Promete pagar', tone: 'success' },
  RECLAMO: { label: 'Reclamo', tone: 'danger' },
  PERDIDO: { label: 'Cliente perdido', tone: 'danger' },
}

// --- Categorización ---

export const CICLOS: { id: CicloCategorizacion; label: string; meses: number }[] = [
  { id: 'MENSUAL', label: 'Mensual', meses: 1 },
  { id: 'TRIMESTRAL', label: 'Trimestral', meses: 3 },
  { id: 'CUATRIMESTRAL', label: 'Cuatrimestral', meses: 4 },
  { id: 'ANUAL', label: 'Anual', meses: 12 },
]

/** Un día como YYYY-MM-DD sin pasar por UTC (que en Perú lo correría al día anterior). */
const dia = (anio: number, mes: number, d: number) =>
  `${anio}-${String(mes).padStart(2, '0')}-${String(d).padStart(2, '0')}`

/**
 * Qué se evaluaría y cuándo rige un ciclo, calculado en pantalla para mostrar el efecto de cambiar
 * el ciclo antes de guardarlo. Es la misma cuenta del backend (CicloCategorizacion.Ventana): los
 * ciclos son de calendario y se evalúa el ciclo ANTERIOR al que contiene a hoy.
 */
export function ventanaDelCiclo(ciclo: CicloCategorizacion, hoy: Date) {
  const meses = CICLOS.find((c) => c.id === ciclo)?.meses ?? 3
  const indice = hoy.getFullYear() * 12 + Math.floor(hoy.getMonth() / meses) * meses
  const aMes = (i: number) => ({ anio: Math.floor(i / 12), mes: (i % 12) + 1 })
  const ultimoDia = (i: number) => {
    const { anio, mes } = aMes(i)
    return new Date(anio, mes, 0).getDate()
  }

  const evaluadoIni = aMes(indice - meses)
  const evaluadoFin = aMes(indice - 1)
  const vigenteIni = aMes(indice)
  const vigenteFin = aMes(indice + meses - 1)

  return {
    evaluadoDesde: dia(evaluadoIni.anio, evaluadoIni.mes, 1),
    evaluadoHasta: dia(evaluadoFin.anio, evaluadoFin.mes, ultimoDia(indice - 1)),
    vigenteDesde: dia(vigenteIni.anio, vigenteIni.mes, 1),
    vigenteHasta: dia(vigenteFin.anio, vigenteFin.mes, ultimoDia(indice + meses - 1)),
  }
}

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
