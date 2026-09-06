import { api } from '../../lib/apiClient'
import type { ResultadoImportacion } from '../../components/ui'

export interface ClienteResponse {
  id: number
  documento: string
  /** DNI, RUC o CODIGO, deducido del largo del documento. */
  tipoDoc: string
  nombre: string
  direccion: string | null
  distritoId: number | null
  /** Nombre del distrito, del ubigeo oficial. */
  distrito: string | null
  provinciaId: number | null
  provincia: string | null
  departamentoId: number | null
  departamento: string | null
  telefono: string | null
  email: string | null
  diaVisita: string | null
  rutaId: number | null
  /** Nombre de la ruta de reparto. */
  ruta: string | null
  mercadoId: number | null
  /** Nombre del mercado, zona o punto de reparto. */
  mercado: string | null
  activo: boolean
  fechaCreacion: string
}

export interface ClienteRequest {
  documento: string
  /** DNI, RUC o CODIGO. Si va vacío el backend lo deduce del largo. */
  tipoDoc?: string
  nombre: string
  direccion?: string | null
  distritoId?: number | null
  /** Solo para importación: se busca por nombre en el ubigeo oficial (no se crea uno nuevo). */
  distritoNombre?: string | null
  telefono?: string | null
  email?: string | null
  diaVisita?: string | null
  rutaId?: number | null
  /** Solo para importación: si no hay rutaId, crea o reutiliza una con este nombre. */
  rutaNombre?: string | null
  mercadoId?: number | null
  /** Solo para importación: si no hay mercadoId, crea o reutiliza uno con este nombre. */
  mercadoNombre?: string | null
}

export interface UpdateClienteRequest extends ClienteRequest {
  activo: boolean
}

export const clienteApi = {
  getAll: () => api.get<ClienteResponse[]>('/cliente'),
  create: (body: ClienteRequest) => api.post<ClienteResponse>('/cliente', body),
  update: (id: number, body: UpdateClienteRequest) =>
    api.put<ClienteResponse>(`/cliente/${id}`, body),
  /** PATCH /api/cliente/{id}/activar */
  activar: (id: number) => api.patch<ClienteResponse>(`/cliente/${id}/activar`),

  /** PATCH /api/cliente/{id}/desactivar — deja de usarse pero conserva su historial. */
  desactivar: (id: number) => api.patch<ClienteResponse>(`/cliente/${id}/desactivar`),

  /** DELETE /api/cliente/{id} — borrado definitivo. */
  remove: (id: number) => api.del<void>(`/cliente/${id}`),

  /** POST /api/cliente/importar — alta masiva desde archivo. */
  importar: (filas: ClienteRequest[], actualizarExistentes: boolean) =>
    api.post<ResultadoImportacion>('/cliente/importar', { filas, actualizarExistentes }),
}
