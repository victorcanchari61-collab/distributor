import { api } from '../../lib/apiClient'

export interface ListaPrecioResponse {
  id: number
  nombre: string
  descripcion: string | null
  /** La que se aplica al cliente que no tiene lista propia. */
  esPredeterminada: boolean
  activo: boolean
  precios: number
}

export interface PrecioResponse {
  id: number
  listaPrecioId: number
  listaPrecio: string
  presentacionId: number
  presentacion: string
  productoId: number
  producto: string
  precio: number
  /** Desde cuántas presentaciones aplica. 1 es el precio normal. */
  cantidadMinima: number
  /** Precio / factor: lo que deja comparar el saco contra el kilo suelto. */
  precioUnidadBase: number
  unidadBase: string
  activo: boolean
  fechaActualizacion: string
}

export interface GuardarPrecioRequest {
  presentacionId: number
  precio: number
  cantidadMinima: number
}

export const listaPrecioApi = {
  getAll: () => api.get<ListaPrecioResponse[]>('/listaprecio'),
  create: (body: { nombre: string; descripcion?: string | null; esPredeterminada: boolean }) =>
    api.post<ListaPrecioResponse>('/listaprecio', body),
  update: (id: number, body: { nombre: string; descripcion?: string | null; activo: boolean }) =>
    api.put<ListaPrecioResponse>(`/listaprecio/${id}`, body),

  /** PATCH /api/listaprecio/{id}/predeterminada */
  predeterminada: (id: number) => api.patch<ListaPrecioResponse>(`/listaprecio/${id}/predeterminada`),

  remove: (id: number) => api.del<void>(`/listaprecio/${id}`),

  getPrecios: (id: number) => api.get<PrecioResponse[]>(`/listaprecio/${id}/precios`),

  /** Repetir presentación y cantidad mínima actualiza en vez de duplicar. */
  guardarPrecios: (id: number, precios: GuardarPrecioRequest[]) =>
    api.put<PrecioResponse[]>(`/listaprecio/${id}/precios`, { precios }),

  eliminarPrecio: (precioId: number) => api.del<void>(`/listaprecio/precios/${precioId}`),
}
