import { api } from '../../lib/apiClient'

export interface AlmacenResponse {
  id: number
  codigo: string
  nombre: string
  direccion: string | null
  esPrincipal: boolean
  activo: boolean
}

/** Una entrada de mercadería con su propio costo. */
export interface CapaCostoResponse {
  id: number
  productoId: number
  almacenId: number
  almacen: string
  cantidadInicial: number
  cantidadDisponible: number
  /** Costo por unidad base, flete incluido. */
  costoUnitario: number
  valor: number
  /** SALDO_INICIAL · COMPRA · AJUSTE */
  origen: string
  referencia: string | null
  fecha: string
}

export interface StockProductoResponse {
  productoId: number
  producto: string
  unidadBase: string
  stock: number
  /** Costo de la capa más antigua: la que se consume ahora. */
  costoAntiguo: number | null
  costoUltimo: number | null
  valorizado: number
  capas: CapaCostoResponse[]
}

export interface EntradaRequest {
  productoId: number
  almacenId?: number | null
  /** En qué presentación entró; vacío significa unidad base. */
  presentacionId?: number | null
  cantidad: number
  /** Lo que costó UNA presentación completa: el saco entero. */
  costoTotal: number
  flete: number
  referencia?: string | null
  origen: 'SALDO_INICIAL' | 'COMPRA' | 'AJUSTE'
  fecha?: string | null
}

export interface ConsumoCapaResponse {
  capaId: number
  cantidad: number
  costoUnitario: number
  subtotal: number
  fecha: string
}

export interface CostoSalidaResponse {
  productoId: number
  cantidad: number
  costo: number
  costoUnitarioPromedio: number
  consumos: ConsumoCapaResponse[]
}

export const inventarioApi = {
  /** GET /api/inventario/producto/{id} — stock, costos y capas. */
  stock: (productoId: number, almacenId?: number) =>
    api.get<StockProductoResponse>(
      `/inventario/producto/${productoId}${almacenId ? `?almacenId=${almacenId}` : ''}`,
    ),

  /** POST /api/inventario/entrada — crea una capa nueva sin tocar las anteriores. */
  entrada: (body: EntradaRequest) => api.post<CapaCostoResponse>('/inventario/entrada', body),

  /** POST /api/inventario/salida — consume las capas más antiguas primero. */
  salida: (body: { productoId: number; cantidad: number; presentacionId?: number | null }) =>
    api.post<CostoSalidaResponse>('/inventario/salida', body),

  /** Lo mismo pero sin tocar el stock: para ver el margen antes de vender. */
  simular: (body: { productoId: number; cantidad: number; presentacionId?: number | null }) =>
    api.post<CostoSalidaResponse>('/inventario/simular-salida', body),
}

export const almacenApi = {
  getAll: () => api.get<AlmacenResponse[]>('/almacen'),
}
