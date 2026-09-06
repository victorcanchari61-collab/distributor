import { api } from '../../lib/apiClient'
import type { ConsultaTabla } from '../../components/ui'
import type { PaginaResponse } from '../../lib/paginacion'

// --- Almacenes ---

export interface AlmacenResponse {
  id: number
  codigo: string
  nombre: string
  direccion: string | null
  esPrincipal: boolean
  activo: boolean
  productos: number
  valorizado: number
}

export interface AlmacenRequest {
  codigo: string
  nombre: string
  direccion?: string | null
  /** Solo uno puede serlo: marcarlo aquí desmarca al anterior. */
  esPrincipal?: boolean
}

export const almacenApi = {
  getAll: () => api.get<AlmacenResponse[]>('/almacen'),
  create: (body: AlmacenRequest) => api.post<AlmacenResponse>('/almacen', body),
  update: (id: number, body: AlmacenRequest & { activo: boolean }) =>
    api.put<AlmacenResponse>(`/almacen/${id}`, body),
  remove: (id: number) => api.del<void>(`/almacen/${id}`),
}

// --- Motivos ---

export type TipoMovimiento = 'ENTRADA' | 'SALIDA'

export interface MotivoResponse {
  id: number
  codigo: string
  nombre: string
  tipo: TipoMovimiento
  /** Lo genera un documento del sistema: no se ofrece en un ajuste. */
  delSistema: boolean
  /** Si al usarlo hay que declarar el costo. */
  pideCosto: boolean
  activo: boolean
  movimientos: number
}

export interface MotivoRequest {
  codigo: string
  nombre: string
  tipo: TipoMovimiento
}

export const motivoApi = {
  getAll: () => api.get<MotivoResponse[]>('/motivo'),
  create: (body: MotivoRequest) => api.post<MotivoResponse>('/motivo', body),
  update: (id: number, body: MotivoRequest & { activo: boolean }) =>
    api.put<MotivoResponse>(`/motivo/${id}`, body),
  remove: (id: number) => api.del<void>(`/motivo/${id}`),
}

// --- Stock ---

export interface StockResponse {
  productoId: number
  codigo: string
  producto: string
  categoria: string | null
  marca: string | null
  unidadBase: string
  almacenId: number
  almacen: string
  stock: number
  /** Lo que apartan los pedidos Pendientes con reserva de stock activa. */
  reservado: number
  /** Stock menos lo reservado: lo que de verdad se puede prometer. */
  disponible: number
  stockMinimo: number
  bajoMinimo: boolean
  costoActual: number | null
  costoUltimo: number | null
  valorizado: number
  capas: CapaResponse[]
}

export interface CapaResponse {
  id: number
  cantidadInicial: number
  cantidadDisponible: number
  costoUnitario: number
  valor: number
  origen: string
  lote: string | null
  fechaVencimiento: string | null
  fecha: string
}

export interface LoteResponse {
  capaId: number
  productoId: number
  codigo: string
  producto: string
  unidadBase: string
  almacenId: number
  almacen: string
  lote: string | null
  fechaVencimiento: string | null
  /** Negativo si ya venció. Null si no tiene fecha de vencimiento. */
  diasParaVencer: number | null
  cantidadDisponible: number
  costoUnitario: number
  valor: number
}

export const loteApi = {
  getAll: () => api.get<LoteResponse[]>('/inventario/lotes'),
}

/** Totales del stock de todo el catálogo, no de la página visible. */
export interface ResumenStock {
  conStock: number
  bajoMinimo: number
  valorizado: number
}

export const stockApi = {
  /** Una página del stock, resuelta en el servidor. */
  listar: (consulta: ConsultaTabla, almacenId?: number) =>
    api.post<PaginaResponse<StockResponse>>(
      `/inventario/stock/listar${almacenId ? `?almacenId=${almacenId}` : ''}`,
      consulta,
    ),

  resumenTotales: (almacenId?: number) =>
    api.get<ResumenStock>(`/inventario/stock/resumen${almacenId ? `?almacenId=${almacenId}` : ''}`),

  getAll: (almacenId?: number) =>
    api.get<StockResponse[]>(`/inventario/stock${almacenId ? `?almacenId=${almacenId}` : ''}`),
  getProducto: (productoId: number, almacenId?: number) =>
    api.get<StockResponse>(
      `/inventario/stock/${productoId}${almacenId ? `?almacenId=${almacenId}` : ''}`,
    ),
}

// --- Kardex ---

export interface KardexResponse {
  id: number
  fecha: string
  documento: string
  motivo: string
  tipo: TipoMovimiento
  productoId: number
  producto: string
  unidadBase: string
  almacen: string
  presentacion: string | null
  cantidadPresentacion: number
  cantidad: number
  costoUnitario: number
  costoTotal: number
  saldo: number
  anulado: boolean
}

/** Contadores del kardex completo del almacén, no de la página visible. */
export interface ResumenKardex {
  entradas: number
  salidas: number
}

export const kardexApi = {
  /** Una página del kardex, con el saldo acumulado ya resuelto en el servidor. */
  listar: (consulta: ConsultaTabla, almacenId?: number) =>
    api.post<PaginaResponse<KardexResponse>>(
      `/inventario/kardex/listar${almacenId ? `?almacenId=${almacenId}` : ''}`,
      consulta,
    ),

  resumen: (almacenId?: number) =>
    api.get<ResumenKardex>(`/inventario/kardex/resumen${almacenId ? `?almacenId=${almacenId}` : ''}`),

  getAll: (filtros: {
    productoId?: number
    almacenId?: number
    desde?: string
    hasta?: string
  }) => {
    const q = new URLSearchParams()
    if (filtros.productoId) q.set('productoId', String(filtros.productoId))
    if (filtros.almacenId) q.set('almacenId', String(filtros.almacenId))
    if (filtros.desde) q.set('desde', filtros.desde)
    if (filtros.hasta) q.set('hasta', filtros.hasta)
    const qs = q.toString()
    return api.get<KardexResponse[]>(`/inventario/kardex${qs ? `?${qs}` : ''}`)
  },
}

// --- Ajustes ---

export interface LineaAjusteRequest {
  productoId: number
  presentacionId?: number | null
  cantidad: number
  /** Solo en motivos de entrada: lo que costó una presentación completa. */
  costoPresentacion?: number | null
  /** Solo en motivos de entrada: el lote del proveedor, si lo trae. */
  lote?: string | null
  /** Solo en motivos de entrada: cuándo vence, si aplica. */
  fechaVencimiento?: string | null
}

export interface CrearAjusteRequest {
  almacenId: number
  motivoId: number
  fecha?: string | null
  observacion?: string | null
  flete: number
  detalle: LineaAjusteRequest[]
}

export interface LineaDocumentoResponse {
  id: number
  productoId: number
  codigo: string
  producto: string
  unidadBase: string
  presentacionId: number | null
  presentacion: string | null
  cantidadPresentacion: number
  cantidad: number
  costoUnitario: number
  costoTotal: number
  /** ENTRADA o SALIDA: en una transferencia hay líneas de los dos tipos. */
  tipo: TipoMovimiento
  almacenId: number
  almacen: string
}

export interface DocumentoInventarioResponse {
  id: number
  numero: string
  tipo: string
  fecha: string
  almacenId: number
  almacen: string
  /** Solo en transferencias: el almacén que recibe. */
  almacenDestinoId: number | null
  almacenDestino: string | null
  /** Solo en recepciones: la compra que se está descargando. */
  compraId: number | null
  compra: string | null
  motivoId: number
  motivo: string
  motivoTipo: TipoMovimiento
  estado: 'CONFIRMADO' | 'ANULADO'
  observacion: string | null
  usuario: string | null
  anuladoPor: string | null
  total: number
  lineas: number
  detalle: LineaDocumentoResponse[]
}

/** Contadores de una familia completa de documentos, no de la página visible. */
export interface ResumenDocumentos {
  total: number
  confirmados: number
  anulados: number
}

/** Una página de documentos de una familia, resuelta en el servidor. */
const listarDocumentos = (familia: string) => (consulta: ConsultaTabla) =>
  api.post<PaginaResponse<DocumentoInventarioResponse>>(
    `/inventario/documentos/listar?familia=${familia}`,
    consulta,
  )

const resumenDocumentos = (familia: string) => () =>
  api.get<ResumenDocumentos>(`/inventario/documentos/resumen?familia=${familia}`)

export const ajusteApi = {
  listar: listarDocumentos('AJUSTE'),
  resumen: resumenDocumentos('AJUSTE'),
  getAll: () => api.get<DocumentoInventarioResponse[]>('/inventario/ajustes'),
  getById: (id: number) => api.get<DocumentoInventarioResponse>(`/inventario/ajustes/${id}`),
  create: (body: CrearAjusteRequest) =>
    api.post<DocumentoInventarioResponse>('/inventario/ajustes', body),
  /** PATCH /api/inventario/ajustes/{id}/anular — crea el documento espejo, no borra. */
  anular: (id: number) =>
    api.patch<DocumentoInventarioResponse>(`/inventario/ajustes/${id}/anular`),
}

// --- Transferencias ---

export interface LineaTransferenciaRequest {
  productoId: number
  presentacionId?: number | null
  cantidad: number
}

export interface CrearTransferenciaRequest {
  almacenOrigenId: number
  almacenDestinoId: number
  fecha?: string | null
  observacion?: string | null
  detalle: LineaTransferenciaRequest[]
}

export const transferenciaApi = {
  listar: listarDocumentos('TRANSFERENCIA'),
  resumen: resumenDocumentos('TRANSFERENCIA'),
  getAll: () => api.get<DocumentoInventarioResponse[]>('/inventario/transferencias'),
  getById: (id: number) => api.get<DocumentoInventarioResponse>(`/inventario/transferencias/${id}`),
  create: (body: CrearTransferenciaRequest) =>
    api.post<DocumentoInventarioResponse>('/inventario/transferencias', body),
  /** Usa el mismo endpoint de anulación que los ajustes: es el mismo concepto. */
  anular: (id: number) =>
    api.patch<DocumentoInventarioResponse>(`/inventario/ajustes/${id}/anular`),
}

// --- Prestamos ---

export type TipoPrestamo = 'DADO' | 'RECIBIDO'
export type EstadoPrestamo = 'PENDIENTE' | 'DEVUELTO'

export interface LineaPrestamoRequest {
  productoId: number
  presentacionId?: number | null
  cantidad: number
  /** Solo para RECIBIDO: si no, se usa el costo de referencia del producto. */
  costoPresentacion?: number | null
}

export interface CrearPrestamoRequest {
  tipo: TipoPrestamo
  contraparte: string
  almacenId: number
  fecha?: string | null
  observacion?: string | null
  detalle: LineaPrestamoRequest[]
}

export interface PrestamoDetalleResponse {
  id: number
  productoId: number
  codigo: string
  producto: string
  unidadBase: string
  presentacionId: number | null
  presentacion: string | null
  cantidadPresentacion: number
  cantidad: number
  cantidadDevuelta: number
  cantidadPendiente: number
  costoUnitario: number
  costoTotal: number
}

export interface PrestamoResponse {
  id: number
  numero: string
  tipo: TipoPrestamo
  contraparte: string
  almacenId: number
  almacen: string
  fecha: string
  estado: EstadoPrestamo
  observacion: string | null
  usuario: string | null
  total: number
  detalle: PrestamoDetalleResponse[]
}

export interface LineaDevolucionPrestamoRequest {
  prestamoDetalleId: number
  /** En unidad base. */
  cantidad: number
}

/** Contadores del listado completo de préstamos. */
export interface ResumenPrestamos {
  total: number
  pendientes: number
  devueltos: number
}

export const prestamoApi = {
  resumen: () => api.get<ResumenPrestamos>('/inventario/prestamos/resumen'),

  /** Una página del listado, resuelta en el servidor. */
  listar: (consulta: ConsultaTabla) =>
    api.post<PaginaResponse<PrestamoResponse>>('/inventario/prestamos/listar', consulta),
  getAll: () => api.get<PrestamoResponse[]>('/inventario/prestamos'),
  getById: (id: number) => api.get<PrestamoResponse>(`/inventario/prestamos/${id}`),
  create: (body: CrearPrestamoRequest) =>
    api.post<PrestamoResponse>('/inventario/prestamos', body),
  /** Devolución total o parcial: una o varias líneas a la vez. */
  devolver: (id: number, detalle: LineaDevolucionPrestamoRequest[]) =>
    api.post<PrestamoResponse>(`/inventario/prestamos/${id}/devolucion`, { detalle }),
}

// --- Recepciones ---

export interface LineaRecepcionRequest {
  compraDetalleId: number
  /** En unidad base: lo que llegó ahora. */
  cantidad: number
  /** El lote del proveedor, si lo trae. */
  lote?: string | null
  /** Cuándo vence, si aplica. */
  fechaVencimiento?: string | null
}

export interface CrearRecepcionRequest {
  compraId: number
  almacenId: number
  fecha?: string | null
  observacion?: string | null
  detalle: LineaRecepcionRequest[]
}

export const recepcionApi = {
  listar: listarDocumentos('RECEPCION'),
  resumen: resumenDocumentos('RECEPCION'),
  getAll: () => api.get<DocumentoInventarioResponse[]>('/inventario/recepciones'),
  getById: (id: number) => api.get<DocumentoInventarioResponse>(`/inventario/recepciones/${id}`),
  create: (body: CrearRecepcionRequest) =>
    api.post<DocumentoInventarioResponse>('/inventario/recepciones', body),
  anular: (id: number) =>
    api.patch<DocumentoInventarioResponse>(`/inventario/recepciones/${id}/anular`),
}
