import { api } from '../../lib/apiClient'
import type { ConsultaTabla } from '../../components/ui'
import type { PaginaResponse } from '../../lib/paginacion'
import type { ResultadoImportacion } from '../../components/ui'

// --- Catalogos de apoyo ---

export interface CategoriaResponse {
  id: number
  nombre: string
  descripcion: string | null
  activo: boolean
  /** Cuantos productos la usan. */
  productos: number
}

export interface MarcaResponse {
  id: number
  nombre: string
  activo: boolean
  productos: number
}

/** CONTEO se cuenta, PESO se pesa, VOLUMEN se mide. */
export type TipoUnidad = 'CONTEO' | 'PESO' | 'VOLUMEN'

export interface UnidadResponse {
  id: number
  codigo: string
  nombre: string
  tipo: TipoUnidad
  /** Admite decimales: 2.5 kilos sí, 2.5 sacos no. */
  fraccionable: boolean
  activo: boolean
  delSistema: boolean
  usos: number
}

// --- Productos ---

export interface PresentacionResponse {
  id: number
  productoId: number
  unidadId: number
  unidad: string
  nombre: string
  /** Cuántas unidades base equivale. Un saco de 50 kg tiene factor 50. */
  factor: number
  /** La de factor 1: no se elimina ni cambia. */
  esBase: boolean
  esCompra: boolean
  esVenta: boolean
  predeterminadaVenta: boolean
  predeterminadaCompra: boolean
  codigoBarras: string | null
  activo: boolean
}

export interface ProductoResponse {
  id: number
  codigo: string
  nombre: string
  descripcion: string | null
  categoriaId: number | null
  categoria: string | null
  marcaId: number | null
  marca: string | null
  unidadBaseId: number
  /** Código de la unidad en la que se lleva el stock: KG, UND, LT. */
  unidadBase: string
  contenido: number | null
  contenidoUnidadId: number | null
  contenidoUnidad: string | null
  /** Lo que suele costar una unidad base. Referencia, no el costo del stock. */
  costoReferencia: number | null
  controlaStock: boolean
  stockMinimo: number
  activo: boolean
  fechaCreacion: string
  presentaciones: PresentacionResponse[]
}

export interface PresentacionRequest {
  unidadId: number
  nombre: string
  factor: number
  esCompra: boolean
  esVenta: boolean
  predeterminadaVenta?: boolean
  predeterminadaCompra?: boolean
  codigoBarras?: string | null
  activo?: boolean
}

export interface ProductoRequest {
  codigo: string
  nombre: string
  descripcion?: string | null
  categoriaId?: number | null
  marcaId?: number | null
  unidadBaseId: number
  contenido?: number | null
  contenidoUnidadId?: number | null
  costoReferencia?: number | null
  controlaStock: boolean
  stockMinimo: number
}

export interface CreateProductoRequest extends ProductoRequest {
  /** Las que van además de la base, que el backend crea sola. */
  presentaciones: PresentacionRequest[]
}

export interface UpdateProductoRequest extends ProductoRequest {
  activo: boolean
}

/** Una fila de un catálogo externo: unidad por código, hasta tres precios sueltos. */
export interface ProductoImportRequest {
  codigo: string
  nombre: string
  unidadBaseCodigo: string
  costoReferencia?: number | null
  presentaciones: number[]
  precioContado?: number | null
  precioPorSaco?: number | null
  precioMayorista?: number | null
}

/** Contadores y valores de filtro del catálogo completo. */
export interface ResumenProductos {
  activos: number
  desactivados: number
  presentaciones: number
  categorias: string[]
  marcas: string[]
}

export const productoApi = {
  /** Una página del catálogo, resuelta en el servidor. */
  listar: (consulta: ConsultaTabla) =>
    api.post<PaginaResponse<ProductoResponse>>('/producto/listar', consulta),

  resumen: () => api.get<ResumenProductos>('/producto/resumen'),

  getAll: () => api.get<ProductoResponse[]>('/producto'),
  getById: (id: number) => api.get<ProductoResponse>(`/producto/${id}`),
  create: (body: CreateProductoRequest) => api.post<ProductoResponse>('/producto', body),
  update: (id: number, body: UpdateProductoRequest) =>
    api.put<ProductoResponse>(`/producto/${id}`, body),
  activar: (id: number) => api.patch<ProductoResponse>(`/producto/${id}/activar`),
  desactivar: (id: number) => api.patch<ProductoResponse>(`/producto/${id}/desactivar`),
  remove: (id: number) => api.del<void>(`/producto/${id}`),

  /** POST /api/producto/{id}/presentaciones */
  agregarPresentacion: (productoId: number, body: PresentacionRequest) =>
    api.post<PresentacionResponse>(`/producto/${productoId}/presentaciones`, body),

  actualizarPresentacion: (presentacionId: number, body: PresentacionRequest) =>
    api.put<PresentacionResponse>(`/producto/presentaciones/${presentacionId}`, body),

  eliminarPresentacion: (presentacionId: number) =>
    api.del<void>(`/producto/presentaciones/${presentacionId}`),

  /** POST /api/producto/importar — alta masiva desde un catálogo externo. */
  importar: (filas: ProductoImportRequest[], actualizarExistentes: boolean) =>
    api.post<ResultadoImportacion>('/producto/importar', { filas, actualizarExistentes }),
}

export const categoriaApi = {
  getAll: () => api.get<CategoriaResponse[]>('/categoria'),
  create: (body: { nombre: string; descripcion?: string | null }) =>
    api.post<CategoriaResponse>('/categoria', body),
  update: (id: number, body: { nombre: string; descripcion?: string | null; activo: boolean }) =>
    api.put<CategoriaResponse>(`/categoria/${id}`, body),
  remove: (id: number) => api.del<void>(`/categoria/${id}`),
}

export const marcaApi = {
  getAll: () => api.get<MarcaResponse[]>('/marca'),
  create: (body: { nombre: string }) => api.post<MarcaResponse>('/marca', body),
  update: (id: number, body: { nombre: string; activo: boolean }) =>
    api.put<MarcaResponse>(`/marca/${id}`, body),
  remove: (id: number) => api.del<void>(`/marca/${id}`),
}

export interface UnidadRequest {
  codigo: string
  nombre: string
  tipo: TipoUnidad
  fraccionable: boolean
}

export const unidadApi = {
  getAll: () => api.get<UnidadResponse[]>('/unidad'),
  create: (body: UnidadRequest) => api.post<UnidadResponse>('/unidad', body),
  update: (id: number, body: UnidadRequest & { activo: boolean }) =>
    api.put<UnidadResponse>(`/unidad/${id}`, body),
  remove: (id: number) => api.del<void>(`/unidad/${id}`),
}
