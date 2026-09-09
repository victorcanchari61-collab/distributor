import { api, ApiError } from '../../lib/apiClient'
import { getToken } from '../../lib/authStorage'
import { API_BASE_URL } from '../../lib/const_glob'

/** vencido · porVencer · alDia · sinFecha. Lo decide el servidor. */
export type EstadoDocumento = 'vencido' | 'porVencer' | 'alDia' | 'sinFecha'

export interface VencimientoResponse {
  nombre: string
  vence: string | null
  /** Días que faltan. Negativo si ya pasó. Nulo si no hay fecha. */
  diasRestantes: number | null
  estado: EstadoDocumento
}

export interface TipoVehiculoResponse {
  id: number
  nombre: string
  descripcion: string | null
  capacidadKgReferencia: number | null
  activo: boolean
  /** Cuántos vehículos son de este tipo. Si hay alguno, no se elimina. */
  vehiculos: number
}

export interface TipoVehiculoRequest {
  nombre: string
  descripcion: string | null
  capacidadKgReferencia: number | null
  activo: boolean
}

export interface VehiculoResponse {
  id: number
  placa: string
  tipoVehiculoId: number
  tipoVehiculo: string
  marca: string | null
  modelo: string | null
  anio: number | null
  color: string | null
  capacidadKg: number | null
  soatNumero: string | null
  soatVence: string | null
  revisionTecnicaVence: string | null
  permisoCirculacionVence: string | null
  foto: string | null
  conductorId: number | null
  conductor: string | null
  observacion: string | null
  activo: boolean
  fechaCreacion: string
  vencimientos: VencimientoResponse[]
  /** El peor estado de sus documentos, para pintar la fila de un vistazo. */
  estadoDocumentos: EstadoDocumento
}

export interface VehiculoRequest {
  placa: string
  tipoVehiculoId: number
  marca: string | null
  modelo: string | null
  anio: number | null
  color: string | null
  capacidadKg: number | null
  soatNumero: string | null
  soatVence: string | null
  revisionTecnicaVence: string | null
  permisoCirculacionVence: string | null
  /** Ruta que devolvió la subida; el archivo no viaja aquí. */
  foto: string | null
  conductorId: number | null
  observacion: string | null
  activo: boolean
}

export interface ConductorResponse {
  id: number
  nombre: string
  documento: string
  telefono: string | null
  direccion: string | null
  licenciaNumero: string | null
  licenciaCategoria: string | null
  licenciaVence: string | null
  foto: string | null
  fechaIngreso: string | null
  observacion: string | null
  activo: boolean
  fechaCreacion: string
  /** Placas que tiene asignadas como conductor habitual. */
  vehiculos: string[]
  vencimientos: VencimientoResponse[]
  estadoDocumentos: EstadoDocumento
}

export interface ConductorRequest {
  nombre: string
  documento: string
  telefono: string | null
  direccion: string | null
  licenciaNumero: string | null
  licenciaCategoria: string | null
  licenciaVence: string | null
  foto: string | null
  fechaIngreso: string | null
  observacion: string | null
  activo: boolean
}

export interface ResumenFlotaResponse {
  vehiculos: number
  activos: number
  conDocumentoVencido: number
  porVencer: number
}

export interface ResumenConductoresResponse {
  conductores: number
  activos: number
  conLicenciaVencida: number
  porVencer: number
}

export interface ArchivoSubidoResponse {
  ruta: string
}

export const tipoVehiculoApi = {
  getAll: () => api.get<TipoVehiculoResponse[]>('/tipovehiculo'),
  create: (body: TipoVehiculoRequest) => api.post<TipoVehiculoResponse>('/tipovehiculo', body),
  update: (id: number, body: TipoVehiculoRequest) =>
    api.put<TipoVehiculoResponse>(`/tipovehiculo/${id}`, body),
}

export const vehiculoApi = {
  getAll: () => api.get<VehiculoResponse[]>('/vehiculo'),
  resumen: () => api.get<ResumenFlotaResponse>('/vehiculo/resumen'),
  create: (body: VehiculoRequest) => api.post<VehiculoResponse>('/vehiculo', body),
  update: (id: number, body: VehiculoRequest) => api.put<VehiculoResponse>(`/vehiculo/${id}`, body),
}

export const conductorApi = {
  getAll: () => api.get<ConductorResponse[]>('/conductor'),
  resumen: () => api.get<ResumenConductoresResponse>('/conductor/resumen'),
  create: (body: ConductorRequest) => api.post<ConductorResponse>('/conductor', body),
  update: (id: number, body: ConductorRequest) =>
    api.put<ConductorResponse>(`/conductor/${id}`, body),
}

export type CarpetaImagen = 'vehiculos' | 'conductores'

/**
 * Sube la imagen y devuelve dónde quedó.
 *
 * No usa `apiFetch` porque este fija `Content-Type: application/json`, y en un
 * multipart la cabecera tiene que llevar el `boundary` que el navegador genera
 * junto al FormData. Fijarla a mano rompe el parseo en el servidor, así que
 * aquí solo se pone el token y se deja que el navegador ponga la suya.
 */
export const archivoApi = {
  subirImagen: async (archivo: File, carpeta: CarpetaImagen): Promise<ArchivoSubidoResponse> => {
    const datos = new FormData()
    datos.append('archivo', archivo)

    const token = getToken()

    let respuesta: Response
    try {
      respuesta = await fetch(`${API_BASE_URL}/archivo/imagen?carpeta=${carpeta}`, {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: datos,
      })
    } catch {
      throw new ApiError('No pudimos conectar con el servidor. Revisa tu conexión.', 0)
    }

    const texto = await respuesta.text()
    const cuerpo = texto ? (JSON.parse(texto) as unknown) : null

    if (!respuesta.ok) {
      const problema = (cuerpo ?? {}) as { message?: string; errors?: string[] | null }
      throw new ApiError(
        problema.message ?? `Error ${respuesta.status}`,
        respuesta.status,
        problema.errors ?? [],
      )
    }

    return cuerpo as ArchivoSubidoResponse
  },
}

/**
 * URL para mostrar una imagen subida.
 *
 * `ruta` llega como "/uploads/...", que el backend sirve desde su raíz y no
 * bajo "/api": por eso se le quita ese sufijo a API_BASE_URL en vez de
 * concatenarlo tal cual, que daría "/api/uploads/..." y un 404.
 */
export function urlImagen(ruta: string): string {
  return `${API_BASE_URL.replace(/\/api\/?$/, '')}${ruta}`
}
