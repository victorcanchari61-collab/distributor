import { api, guardarArchivo, obtenerArchivo } from '../../lib/apiClient'

/** Los tipos de comprobante electrónico (Catálogo 01 de SUNAT). */
export type TipoCpe = '01' | '03' | '07' | '08'

/** En qué quedó el comprobante frente a SUNAT. */
export type EstadoCpe = 'GENERADO' | 'ACEPTADO' | 'RECHAZADO' | 'ERROR'

export const TIPOS_CPE: Record<TipoCpe, { nombre: string; corto: string }> = {
  '01': { nombre: 'Factura electrónica', corto: 'Factura' },
  '03': { nombre: 'Boleta de venta electrónica', corto: 'Boleta' },
  '07': { nombre: 'Nota de crédito electrónica', corto: 'Nota de crédito' },
  '08': { nombre: 'Nota de débito electrónica', corto: 'Nota de débito' },
}

export const ESTADOS_CPE: Record<EstadoCpe, { label: string; tone: 'success' | 'danger' | 'warning' | 'neutral'; ayuda: string }> = {
  ACEPTADO: { label: 'Aceptado', tone: 'success', ayuda: 'SUNAT lo aceptó.' },
  RECHAZADO: { label: 'Rechazado', tone: 'danger', ayuda: 'SUNAT lo rechazó: el motivo está en el CDR.' },
  GENERADO: { label: 'Sin enviar', tone: 'warning', ayuda: 'Está firmado pero todavía no llegó a SUNAT.' },
  ERROR: { label: 'Sin respuesta', tone: 'warning', ayuda: 'El envío falló antes de tener respuesta: se puede reenviar.' },
}

/** Los motivos de SUNAT (Catálogos 09 y 10): lo que se elige al corregir un comprobante. */
export const MOTIVOS_NOTA: Record<'07' | '08', { codigo: string; label: string }[]> = {
  '07': [
    { codigo: '01', label: 'Anulación de la operación' },
    { codigo: '02', label: 'Anulación por error en el RUC' },
    { codigo: '03', label: 'Corrección por error en la descripción' },
    { codigo: '04', label: 'Descuento global' },
    { codigo: '05', label: 'Descuento por ítem' },
    { codigo: '06', label: 'Devolución total' },
    { codigo: '07', label: 'Devolución por ítem' },
    { codigo: '08', label: 'Bonificación' },
    { codigo: '09', label: 'Disminución en el valor' },
    { codigo: '13', label: 'Ajustes de montos y/o fechas de pago' },
  ],
  '08': [
    { codigo: '01', label: 'Intereses por mora' },
    { codigo: '02', label: 'Aumento en el valor' },
    { codigo: '03', label: 'Penalidades u otros conceptos' },
  ],
}

export interface LineaComprobante {
  descripcion: string
  cantidad: number
  /** Por unidad, con IGV si la línea es gravada. */
  precio: number
  afectoIgv: boolean
}

export interface ComprobanteResponse {
  id: number
  tipo: TipoCpe
  tipoNombre: string
  serie: string
  numero: number
  numeroCompleto: string
  notaVentaId: number | null
  notaVentaNumero: string | null
  /** En una nota: el comprobante que corrige. */
  afectadoId: number | null
  afectadoNumero: string | null
  fechaEmision: string
  clienteTipoDoc: string
  clienteDocumento: string
  clienteNombre: string
  moneda: string
  opGravada: number
  opExonerada: number
  igv: number
  total: number
  codMotivo: string | null
  desMotivo: string | null
  estado: EstadoCpe
  codigoSunat: string | null
  mensajeSunat: string | null
  notasSunat: string | null
  nombreArchivo: string
  hash: string
  qrInfo: string
  /** Hay constancia de recepción (CDR) para descargar. */
  tieneCdr: boolean
  /** beta (pruebas) o produccion. */
  entorno: string
  usuario: string | null
  fechaCreacion: string
  enviadoEn: string | null
  lineas: LineaComprobante[]
}

export interface SerieCpe {
  id: number
  tipo: TipoCpe
  serie: string
  aplicaA: TipoCpe | null
  ultimoNumero: number
  activa: boolean
}

export interface FiltrosComprobantes {
  tipo?: TipoCpe
  estado?: EstadoCpe
  desde?: string
  hasta?: string
  notaVentaId?: number
  afectadoId?: number
}

export interface EmitirNota {
  tipo: '07' | '08'
  codMotivo: string
  desMotivo: string
  /** Sin líneas, una nota de crédito repite las del comprobante (anulación o devolución total). */
  lineas?: LineaComprobante[]
}

const query = (f: FiltrosComprobantes) => {
  const partes = new URLSearchParams()
  for (const [clave, valor] of Object.entries(f)) {
    if (valor !== undefined && valor !== '') partes.set(clave, String(valor))
  }
  const texto = partes.toString()
  return texto ? `?${texto}` : ''
}

export const comprobanteApi = {
  listar: (filtros: FiltrosComprobantes = {}) => api.get<ComprobanteResponse[]>(`/comprobante${query(filtros)}`),
  obtener: (id: number) => api.get<ComprobanteResponse>(`/comprobante/${id}`),
  series: () => api.get<SerieCpe[]>('/comprobante/series'),

  /** Factura o boleta de una nota de venta: la firma, la envía a SUNAT y devuelve lo que respondió. */
  emitir: (notaVentaId: number, tipo: '01' | '03') => api.post<ComprobanteResponse>('/comprobante/emitir', { notaVentaId, tipo }),

  /** Nota de crédito o débito sobre un comprobante aceptado. */
  emitirNota: (id: number, body: EmitirNota) => api.post<ComprobanteResponse>(`/comprobante/${id}/nota`, body),

  /** Reenvía a SUNAT un comprobante que quedó sin respuesta. */
  reenviar: (id: number) => api.post<ComprobanteResponse>(`/comprobante/${id}/reenviar`),

  /** Baja el XML firmado. */
  descargarXml: async (c: Pick<ComprobanteResponse, 'id' | 'nombreArchivo'>) => {
    const archivo = await obtenerArchivo(`/comprobante/${c.id}/xml`, `${c.nombreArchivo}.xml`)
    guardarArchivo(archivo.blob, archivo.nombre)
  },

  /** Baja la constancia de recepción (CDR) de SUNAT, en zip. */
  descargarCdr: async (c: Pick<ComprobanteResponse, 'id' | 'nombreArchivo'>) => {
    const archivo = await obtenerArchivo(`/comprobante/${c.id}/cdr`, `R-${c.nombreArchivo}.zip`)
    guardarArchivo(archivo.blob, archivo.nombre)
  },
}
