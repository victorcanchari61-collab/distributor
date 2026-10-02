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

// --- Resultados de la revisión ---
//
// Lo que encontró el encargado al contar lo que volvió en el camión: "Volvió
// completa", "Faltó algo", "Pesaron mal el producto". Los crea el dueño, como
// los motivos. Cada uno dice si volvió todo: si no, se pide cuánto volvió.

export interface ResultadoRevisionResponse {
  id: number
  nombre: string
  descripcion: string | null
  /** Volvió todo lo que no se entregó: la novedad queda Recibida. Si no, Faltante. */
  volvioTodo: boolean
  activo: boolean
  /** En cuántas revisiones se usó. */
  usos: number
}

export interface ResultadoRevisionOpcion {
  id: number
  nombre: string
  descripcion: string | null
  volvioTodo: boolean
}

export interface ResultadoRevisionRequest {
  nombre: string
  descripcion?: string | null
  volvioTodo: boolean
  activo: boolean
}

export const resultadoRevisionApi = {
  getAll: () => api.get<ResultadoRevisionResponse[]>('/resultadorevision'),
  /** Los activos, para elegir uno al revisar. */
  opciones: () => api.get<ResultadoRevisionOpcion[]>('/resultadorevision/opciones'),
  create: (body: ResultadoRevisionRequest) => api.post<ResultadoRevisionResponse>('/resultadorevision', body),
  update: (id: number, body: ResultadoRevisionRequest) =>
    api.put<ResultadoRevisionResponse>(`/resultadorevision/${id}`, body),
}

export const motivoNovedadApi = {
  getAll: () => api.get<MotivoNovedadResponse[]>('/motivonovedad'),
  /** Los activos, para quien convierte pedidos en venta: no necesita ver el catálogo. */
  opciones: () => api.get<MotivoNovedadOpcion[]>('/motivonovedad/opciones'),
  create: (body: MotivoNovedadRequest) => api.post<MotivoNovedadResponse>('/motivonovedad', body),
  update: (id: number, body: MotivoNovedadRequest) =>
    api.put<MotivoNovedadResponse>(`/motivonovedad/${id}`, body),
}
