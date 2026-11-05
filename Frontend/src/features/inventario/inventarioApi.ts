import { api } from '../../lib/apiClient'
import type { ConsultaTabla } from '../../components/ui'
import type { PaginaResponse } from '../../lib/paginacion'

// --- Almacenes ---

export type TipoAlmacen = 'ALMACEN' | 'DEPOSITO' | 'TIENDA' | 'CASA' | 'EDIFICIO'

export const TIPOS_ALMACEN: { value: TipoAlmacen; label: string }[] = [
  { value: 'ALMACEN', label: 'Almacén' },
  { value: 'DEPOSITO', label: 'Depósito' },
  { value: 'TIENDA', label: 'Tienda' },
  { value: 'CASA', label: 'Casa' },
  { value: 'EDIFICIO', label: 'Edificio' },
]

export interface AlmacenResponse {
  id: number
  codigo: string
  nombre: string
  tipo: TipoAlmacen
  tipoEtiqueta: string
  /** Calle, número, manzana y lote. El distrito va aparte. */
  direccion: string | null
  distritoId: number | null
  distrito: string | null
  provinciaId: number | null
  provincia: string | null
  departamentoId: number | null
  departamento: string | null
  /** Cómo llegar: "frente al mercado, portón verde". */
  referencia: string | null
  responsable: string | null
  telefono: string | null
  esPrincipal: boolean
  activo: boolean
  /** Cuántos lugares (pisos y cuartos) tiene definidos. */
  ubicaciones: number
  productos: number
  valorizado: number
}

/**
 * Un almacén para elegirlo en un documento.
 *
 * Sin valorizado ni cuántos productos tiene: lo usan ventas y compras, que no
 * tienen por qué ver cuánta plata hay en cada almacén para decidir de cuál sale
 * un pedido.
 */
export type AlmacenOpcion = Pick<AlmacenResponse, 'id' | 'codigo' | 'nombre' | 'esPrincipal' | 'activo'>

/** Cuánto se puede prometer de un producto: stock menos lo reservado. */
export interface DisponibleResponse {
  productoId: number
  disponible: number
  /** Lo que ya apartan pedidos pendientes; solo informa, ya viene descontado de `disponible`. */
  reservado: number
}

export interface AlmacenRequest {
  codigo: string
  nombre: string
  tipo?: TipoAlmacen
  direccion?: string | null
  /** El distrito del ubigeo oficial. */
  distritoId?: number | null
  referencia?: string | null
  responsable?: string | null
  telefono?: string | null
  /** Solo uno puede serlo: marcarlo aquí desmarca al anterior. */
  esPrincipal?: boolean
}

export const almacenApi = {
  getAll: () => api.get<AlmacenResponse[]>('/almacen'),
  /**
   * Los activos, solo para elegir uno. Lo puede leer quien vende o compra sin
   * acceso a la pantalla de Almacenes, que es la que pide `getAll`.
   */
  opciones: () => api.get<AlmacenOpcion[]>('/almacen/opciones'),
  create: (body: AlmacenRequest) => api.post<AlmacenResponse>('/almacen', body),
  update: (id: number, body: AlmacenRequest & { activo: boolean }) =>
    api.put<AlmacenResponse>(`/almacen/${id}`, body),
  remove: (id: number) => api.del<void>(`/almacen/${id}`),
}

// --- Ubicaciones (pisos y cuartos dentro de un almacén) ---

export type TipoUbicacion = 'PISO' | 'CUARTO'

export const TIPOS_UBICACION: { value: TipoUbicacion; label: string }[] = [
  { value: 'PISO', label: 'Piso' },
  { value: 'CUARTO', label: 'Cuarto' },
]

export interface UbicacionResponse {
  id: number
  almacenId: number
  padreId: number | null
  tipo: TipoUbicacion
  tipoEtiqueta: string
  /** El código corto de este punto: "P1", "A", "03". */
  codigo: string
  nombre: string | null
  /** Los códigos desde la raíz, unidos con guion: "P1-A-03". Es como se nombra el lugar. */
  ruta: string
  /** Cuántos escalones tiene arriba: 0 en la raíz del almacén. */
  nivel: number
  activo: boolean
  /** Cuántos lugares tiene directamente adentro. */
  hijos: number
  /** Cuántos productos están puestos aquí. */
  productos: number
}

export interface UbicacionProductoResponse {
  productoId: number
  codigo: string
  producto: string
  categoria: string | null
  unidadBase: string
}

export interface UbicacionRequest {
  tipo: TipoUbicacion
  codigo: string
  nombre?: string | null
}

export interface GenerarUbicacionesRequest {
  padreId?: number | null
  tipo: TipoUbicacion
  prefijo?: string
  desde: number
  hasta: number
  digitos: number
}

export const ubicacionApi = {
  listar: (almacenId: number) => api.get<UbicacionResponse[]>(`/almacen/${almacenId}/ubicaciones`),
  crear: (almacenId: number, body: UbicacionRequest & { padreId?: number | null }) =>
    api.post<UbicacionResponse>(`/almacen/${almacenId}/ubicaciones`, body),
  generar: (almacenId: number, body: GenerarUbicacionesRequest) =>
    api.post<UbicacionResponse[]>(`/almacen/${almacenId}/ubicaciones/lote`, body),
  actualizar: (id: number, body: UbicacionRequest & { activo: boolean }) =>
    api.put<UbicacionResponse>(`/ubicacion/${id}`, body),
  eliminar: (id: number) => api.del<void>(`/ubicacion/${id}`),
  productos: (id: number) => api.get<UbicacionProductoResponse[]>(`/ubicacion/${id}/productos`),
  asignar: (id: number, productoId: number) =>
    api.post<UbicacionProductoResponse[]>(`/ubicacion/${id}/productos`, { productoId }),
  quitar: (id: number, productoId: number) =>
    api.del<UbicacionProductoResponse[]>(`/ubicacion/${id}/productos/${productoId}`),
}

// --- Ubicación de productos (pantalla propia) ---

export interface LugarDeProducto {
  ubicacionId: number
  /** "P1-C2". */
  ruta: string
  nombre: string | null
}

export interface ProductoUbicado {
  productoId: number
  codigo: string
  producto: string
  categoria: string | null
  marca: string | null
  unidadBase: string
  /** Lo que hay en el almacén, en unidad base. */
  stock: number
  /** Vacío: tiene stock pero nadie sabe dónde está. */
  lugares: LugarDeProducto[]
}

export interface ProductosUbicados {
  almacenId: number
  /** Cuántos lugares tiene definidos el almacén. */
  lugares: number
  sinLugar: number
  items: ProductoUbicado[]
}

export const ubicacionProductoApi = {
  /** Los productos del almacén con el lugar donde está cada uno. */
  listar: (almacenId: number) => api.get<ProductosUbicados>(`/ubicacion-producto?almacenId=${almacenId}`),
  /** Pone varios productos en un lugar; con `reemplazar`, los mueve (les quita el lugar que tenían en ese almacén). */
  asignar: (body: { ubicacionId: number; productoIds: number[]; reemplazar: boolean }) =>
    api.post<ProductosUbicados>('/ubicacion-producto/asignar', body),
  quitar: (body: { ubicacionId: number; productoIds: number[] }) =>
    api.post<ProductosUbicados>('/ubicacion-producto/quitar', body),
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
  /** Comprado y todavía sin llegar. Del negocio entero, no de un almacén. */
  enTransito: number
  ultimaEntrada: string | null
  ultimaSalida: string | null
  /** Para cuántos días alcanza al ritmo del último mes. Null si no se vendió. */
  diasStock: number | null
  capas: CapaResponse[]
  /**
   * Dónde está puesto: las rutas de sus lugares ("P1-A-03"). Con todos los almacenes a la vista, cada
   * una lleva delante el código del almacén ("PRIN · P1-A-03").
   */
  ubicaciones: string[]
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

  /**
   * Solo cuánto se puede prometer, por producto: sin costos.
   *
   * Es lo que usan pedidos, ventas y compras. `getAll` pide el permiso de la
   * pantalla de Stock, y un vendedor sin él recibía un 403 que nadie mostraba:
   * todos los productos salían con stock 0.
   */
  disponible: (almacenId?: number) =>
    api.get<DisponibleResponse[]>(
      `/inventario/disponible${almacenId ? `?almacenId=${almacenId}` : ''}`,
    ),
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
  /** AJUSTE, TRANSFERENCIA, etc. Vacío en una reserva: no nace de ningún documento. */
  tipoDocumento: string
  motivo: string
  /** RESERVA no es un movimiento: aparta mercadería sin sacarla del almacén. */
  tipo: TipoMovimiento | 'RESERVA'
  productoId: number
  producto: string
  unidadBase: string
  almacen: string
  presentacion: string | null
  cantidadPresentacion: number
  cantidad: number
  costoUnitario: number
  costoTotal: number
  /** Stock con el que llegaba el producto a este movimiento. */
  saldoAnterior: number
  saldo: number
  /** Cuánto valía ese stock antes y después, al costo de cada capa. */
  valorizadoAnterior: number
  valorizado: number
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
  /** Dónde se guarda en el almacén de destino. Opcional. */
  ubicacionDestinoId?: number | null
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
export type EstadoPrestamo = 'PENDIENTE' | 'DEVUELTO' | 'ANULADO'

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

/** Un préstamo como fila del listado: sin su detalle ni sus devoluciones (vienen con getById). */
export interface PrestamoFila {
  id: number
  numero: string
  tipo: PrestamoResponse['tipo']
  contraparte: string
  almacenId: number
  almacen: string
  fecha: string
  estado: PrestamoResponse['estado']
  total: number
  /** Si ya se devolvió algo: entonces no se puede anular. */
  tieneDevolucion: boolean
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
  /** Cada devolución registrada, más reciente primero — con su propio estado, por si se anuló. */
  devoluciones: PrestamoDevolucionResponse[]
}

/** Una devolución registrada: el documento que movió stock, con sus líneas. */
export interface PrestamoDevolucionResponse {
  /** El id del documento de inventario: por él se anula y se imprime. */
  id: number
  numero: string
  fecha: string
  estado: 'CONFIRMADO' | 'ANULADO'
  /** A qué almacén entró (DADO) o de cuál salió (RECIBIDO). Hoy siempre el del préstamo. */
  almacenId: number
  almacen: string
  usuario: string | null
  detalle: LineaDevolucionPrestamoDetalle[]
}

export interface LineaDevolucionPrestamoDetalle {
  prestamoDetalleId: number
  producto: string
  presentacion: string | null
  unidadBase: string
  cantidadPresentacion: number
  cantidad: number
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
    api.post<PaginaResponse<PrestamoFila>>('/inventario/prestamos/listar', consulta),
  getAll: () => api.get<PrestamoResponse[]>('/inventario/prestamos'),
  getById: (id: number) => api.get<PrestamoResponse>(`/inventario/prestamos/${id}`),
  create: (body: CrearPrestamoRequest) =>
    api.post<PrestamoResponse>('/inventario/prestamos', body),
  /** Devolución total o parcial: una o varias líneas a la vez. No tiene que ser el almacén del préstamo. */
  devolver: (id: number, almacenId: number, detalle: LineaDevolucionPrestamoRequest[]) =>
    api.post<PrestamoResponse>(`/inventario/prestamos/${id}/devolucion`, { almacenId, detalle }),
  /** Anula una devolución registrada por error. El id es el del documento de la devolución. */
  anularDevolucion: (devolucionId: number) =>
    api.patch<DocumentoInventarioResponse>(`/inventario/prestamos/devoluciones/${devolucionId}/anular`),
  /** Anula el préstamo completo. Se bloquea si ya tiene alguna devolución registrada. */
  anular: (id: number) =>
    api.patch<PrestamoResponse>(`/inventario/prestamos/${id}/anular`),
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
  /** Dónde se guardó dentro del almacén. Opcional: sin lugar, entra al almacén igual. */
  ubicacionId?: number | null
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
