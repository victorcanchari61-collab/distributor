import { api } from '../../lib/apiClient'
import type { ResultadoImportacion } from '../../components/ui'

export interface ClienteResponse {
  id: number
  documento: string
  /** DNI, RUC o CODIGO, deducido del largo del documento. */
  tipoDoc: string
  nombre: string
  direccion: string | null
  distrito: string | null
  telefono: string | null
  email: string | null
  diaVisita: string | null
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
  distrito?: string | null
  telefono?: string | null
  email?: string | null
  diaVisita?: string | null
  ruta?: string | null
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

// --- Mercados ---
//
// Dónde se entrega: un mercado de abastos, pero también puede ser una zona
// con tiendas o empresas.

export interface MercadoResponse {
  id: number
  nombre: string
  activo: boolean
  /** Cuántos clientes ya lo usan. Si hay alguno, no se elimina. */
  clientes: number
}

export const mercadoApi = {
  getAll: () => api.get<MercadoResponse[]>('/mercado'),
  create: (body: { nombre: string }) => api.post<MercadoResponse>('/mercado', body),
  update: (id: number, body: { nombre: string; activo: boolean }) =>
    api.put<MercadoResponse>(`/mercado/${id}`, body),
  remove: (id: number) => api.del<void>(`/mercado/${id}`),
}
