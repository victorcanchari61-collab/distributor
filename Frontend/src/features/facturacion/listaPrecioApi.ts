import { ApiError, api } from '../../lib/apiClient'

export interface ListaPrecioResponse {
  id: number
  nombre: string
  descripcion: string | null
  /** La que se aplica al cliente que no tiene lista propia. */
  esPredeterminada: boolean
  activo: boolean
  precios: number
}

/**
 * El precio que corresponde cobrar por una presentacion, venga de donde venga.
 *
 * Se dice de donde salio y no solo el numero: la pantalla avisa "precio de referencia" cuando la
 * lista no lo tenia, que es lo que permite ver una lista a medio armar en vez de cobrar un precio
 * viejo creyendo que es el de la lista.
 */
export interface PrecioVentaResponse {
  /** Precio de UNA presentacion: el saco, la caja. */
  precio: number
  origen: 'LISTA' | 'REFERENCIA'
  /** Desde que cantidad rige, cuando salio de un escalon de la lista. */
  cantidadMinima: number | null
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

  /**
   * Qué precio corresponde a esa presentación por esa cantidad.
   *
   * La cantidad importa: el servidor elige el tramo más alto que alcanza, así
   * que 5 sacos pueden costar menos por saco que 4. Devuelve null cuando esa
   * presentación no tiene precio en la lista (el endpoint responde 404).
   */
  /**
   * El precio que corresponde cobrar: el de la lista, y si no lo tiene el de referencia del
   * producto. Sin lista va directo a la referencia. Null si no hay ninguno de los dos.
   */
  precioVenta: (presentacionId: number, cantidad: number, listaId?: number) =>
    api
      .get<PrecioVentaResponse>(
        `/listaprecio/precio-venta?presentacionId=${presentacionId}&cantidad=${cantidad}` +
          (listaId ? `&listaId=${listaId}` : ''),
      )
      .catch((e) => {
        if (e instanceof ApiError && e.statusCode === 404) return null
        throw e
      }),

  resolver: (id: number, presentacionId: number, cantidad: number) =>
    api
      .get<PrecioResponse>(
        `/listaprecio/${id}/resolver?presentacionId=${presentacionId}&cantidad=${cantidad}`,
      )
      .catch((e) => {
        if (e instanceof ApiError && e.statusCode === 404) return null
        throw e
      }),
}
