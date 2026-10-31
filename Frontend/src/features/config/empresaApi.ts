import { api } from '../../lib/apiClient'
import type { TipoCpe } from '../facturacion/comprobanteApi'

export type { TipoCpe }

export interface EmpresaResponse {
  id: number
  razonSocial: string
  nombreComercial: string
  ruc: string
  direccion: string | null
  departamento: string | null
  provincia: string | null
  distrito: string | null
  telefono: string | null
  email: string | null
  sitioWeb: string | null
  representanteLegal: string | null
  /** La empresa con la que opera el sistema. Solo una a la vez. */
  activa: boolean
  /** Disponible para usarse. Una deshabilitada no se puede activar. */
  habilitada: boolean
  /** Ubigeo de 6 dígitos del domicilio fiscal: el comprobante electrónico lo exige. */
  ubigeo: string | null
  usuarioSol: string | null
  /** Hay una clave SOL guardada. La clave en sí nunca llega al navegador. */
  tieneClaveSol: boolean
  /** true: emite al entorno de pruebas de SUNAT (sin validez tributaria). false: producción. */
  modoPrueba: boolean
  /** Del certificado digital subido: a nombre de quién y hasta cuándo vale. Nulos si no hay. */
  certificadoTitular: string | null
  /** Hay un certificado guardado. El certificado en sí nunca llega al navegador. */
  tieneCertificado: boolean
  certificadoVenceEl: string | null
  certificadoVencido: boolean
  /** Si cada comprobante aceptado por SUNAT se manda solo por WhatsApp al cliente. */
  whatsAppAutomatico: boolean
  /** El mensaje con sus {variables}; nulo: el mensaje de siempre. */
  whatsAppPlantilla: string | null
  fechaCreacion: string
}

/** Cómo está el servicio de WhatsApp de la empresa. */
export interface EstadoWhatsApp {
  /** conectado, esperando-qr, desconectado o sin-servicio. */
  estado: string
  enCola: number
  /** El QR a escanear, como imagen (data URL). Nulo si no hace falta. */
  qrImagen: string | null
  error: string | null
  /** Falta el token en la configuración del servidor. */
  faltaToken: boolean
}

export interface SubirCertificadoResponse {
  mensaje: string
  advertencias: string[]
  empresa: EmpresaResponse
}

/** Una serie de comprobantes de la empresa y hasta qué número llegó. */
export interface SerieCpe {
  id: number
  tipo: TipoCpe
  serie: string
  /** Solo en notas: 01 si corrigen facturas, 03 si corrigen boletas. */
  aplicaA: TipoCpe | null
  /** El último número usado; el siguiente comprobante sale con este más uno. */
  ultimoNumero: number
  activa: boolean
  /** Comprobantes emitidos con esta serie desde el sistema. */
  emitidos: number
}

export interface SerieCpeRequest {
  tipo: TipoCpe
  serie: string
  aplicaA?: TipoCpe | null
  ultimoNumero: number
  activa: boolean
}

export interface EmpresaRequest {
  razonSocial: string
  nombreComercial: string
  ruc: string
  direccion?: string | null
  departamento?: string | null
  provincia?: string | null
  distrito?: string | null
  telefono?: string | null
  email?: string | null
  /** Se puede escribir sin http: el backend le pone https al guardar. */
  sitioWeb?: string | null
  representanteLegal?: string | null
  ubigeo?: string | null
  usuarioSol?: string | null
  /** Vacía al editar = dejar la que está. */
  claveSol?: string | null
  modoPrueba: boolean
  whatsAppAutomatico: boolean
  /** Vacío: el mensaje de siempre. */
  whatsAppPlantilla?: string | null
  activa: boolean
}

export const empresaApi = {
  /** GET /api/empresa */
  getAll: () => api.get<EmpresaResponse[]>('/empresa'),

  /** GET /api/empresa/activa — la empresa con la que opera el sistema. */
  getActiva: () => api.get<EmpresaResponse>('/empresa/activa'),

  /** POST /api/empresa */
  create: (body: EmpresaRequest) => api.post<EmpresaResponse>('/empresa', body),

  /** PUT /api/empresa/{id} */
  update: (id: number, body: EmpresaRequest) => api.put<EmpresaResponse>(`/empresa/${id}`, body),

  /** POST /api/empresa/{id}/certificado — sube el .pem (en texto) a la API de facturación. */
  subirCertificado: (id: number, certificado: string) =>
    api.post<SubirCertificadoResponse>(`/empresa/${id}/certificado`, { certificado }),

  /** GET /api/empresa/{id}/series */
  series: (id: number) => api.get<SerieCpe[]>(`/empresa/${id}/series`),

  /** POST /api/empresa/{id}/series */
  crearSerie: (id: number, body: SerieCpeRequest) => api.post<SerieCpe>(`/empresa/${id}/series`, body),

  /** PUT /api/empresa/{id}/series/{serieId} */
  actualizarSerie: (id: number, serieId: number, body: SerieCpeRequest) =>
    api.put<SerieCpe>(`/empresa/${id}/series/${serieId}`, body),

  /** DELETE /api/empresa/{id}/series/{serieId} — solo si nunca emitió. */
  eliminarSerie: (id: number, serieId: number) => api.del<void>(`/empresa/${id}/series/${serieId}`),

  /** POST /api/empresa/{id}/series/estandar — F001, B001 y las de notas que falten. */
  crearSeriesEstandar: (id: number) => api.post<SerieCpe[]>(`/empresa/${id}/series/estandar`),

  /** GET /api/whatsapp/estado */
  estadoWhatsApp: () => api.get<EstadoWhatsApp>('/whatsapp/estado'),

  /** POST /api/whatsapp/desvincular — cierra la sesión y pide un QR nuevo. */
  desvincularWhatsApp: () => api.post<{ mensaje: string }>('/whatsapp/desvincular'),

  /** PATCH /api/empresa/{id}/activar — activa una y desactiva la anterior. */
  activar: (id: number) => api.patch<EmpresaResponse>(`/empresa/${id}/activar`),

  /** PATCH /api/empresa/{id}/deshabilitar — la retira sin eliminarla. */
  deshabilitar: (id: number) => api.patch<EmpresaResponse>(`/empresa/${id}/deshabilitar`),

  /** PATCH /api/empresa/{id}/habilitar */
  habilitar: (id: number) => api.patch<EmpresaResponse>(`/empresa/${id}/habilitar`),

  /** DELETE /api/empresa/{id} */
  remove: (id: number) => api.del<void>(`/empresa/${id}`),
}
