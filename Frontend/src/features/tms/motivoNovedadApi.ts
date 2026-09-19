import { api } from '../../lib/apiClient'

// --- Motivos de novedad ---
//
// Por qué no se entregó algo: "Cliente no quiso", "Producto dañado", "Faltó en
// el carro". Los crea el dueño; se desactivan, no se borran, porque cada
// novedad registrada apunta a uno.

export interface MotivoNovedadResponse {
  id: number
  nombre: string
  descripcion: string | null
  /** Salió en el camión y hay que esperarlo de vuelta. En falso, nunca salió del almacén. */
  regresaAlAlmacen: boolean
  activo: boolean
  /** En cuántas novedades se usó. */
  usos: number
}

/** Lo justo para elegir al entregar: solo los activos. */
export interface MotivoNovedadOpcion {
  id: number
  nombre: string
  descripcion: string | null
}

export interface MotivoNovedadRequest {
  nombre: string
  descripcion?: string | null
  regresaAlAlmacen: boolean
  activo: boolean
}

export const motivoNovedadApi = {
  getAll: () => api.get<MotivoNovedadResponse[]>('/motivonovedad'),
  /** Los activos, para quien convierte pedidos en venta: no necesita ver el catálogo. */
  opciones: () => api.get<MotivoNovedadOpcion[]>('/motivonovedad/opciones'),
  create: (body: MotivoNovedadRequest) => api.post<MotivoNovedadResponse>('/motivonovedad', body),
  update: (id: number, body: MotivoNovedadRequest) =>
    api.put<MotivoNovedadResponse>(`/motivonovedad/${id}`, body),
}
