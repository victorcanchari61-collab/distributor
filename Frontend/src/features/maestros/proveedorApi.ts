import { api } from '../../lib/apiClient'
import type { ResultadoImportacion } from '../../components/ui'

export interface ProveedorResponse {
  id: number
  documento: string
  tipoDoc: string
  /** Razon social. */
  nombre: string
  nombreComercial: string | null
  direccion: string | null
  departamento: string | null
  distrito: string | null
  telefono: string | null
  telefono2: string | null
  email: string | null
  /** Que vende: "FIDEOS Y HARINAS". */
  rubro: string | null
  activo: boolean
  fechaCreacion: string
}

export interface ProveedorRequest {
  documento: string
  nombre: string
  nombreComercial?: string | null
  direccion?: string | null
  departamento?: string | null
  distrito?: string | null
  telefono?: string | null
  telefono2?: string | null
  email?: string | null
  rubro?: string | null
}

export interface UpdateProveedorRequest extends ProveedorRequest {
  activo: boolean
}

export const proveedorApi = {
  getAll: () => api.get<ProveedorResponse[]>('/proveedor'),
  create: (body: ProveedorRequest) => api.post<ProveedorResponse>('/proveedor', body),
  update: (id: number, body: UpdateProveedorRequest) =>
    api.put<ProveedorResponse>(`/proveedor/${id}`, body),
  /** PATCH /api/proveedor/{id}/activar */
  activar: (id: number) => api.patch<ProveedorResponse>(`/proveedor/${id}/activar`),

  /** PATCH /api/proveedor/{id}/desactivar — deja de usarse pero conserva su historial. */
  desactivar: (id: number) => api.patch<ProveedorResponse>(`/proveedor/${id}/desactivar`),

  /** DELETE /api/proveedor/{id} — borrado definitivo. */
  remove: (id: number) => api.del<void>(`/proveedor/${id}`),

  /** POST /api/proveedor/importar */
  importar: (filas: ProveedorRequest[], actualizarExistentes: boolean) =>
    api.post<ResultadoImportacion>('/proveedor/importar', { filas, actualizarExistentes }),
}
