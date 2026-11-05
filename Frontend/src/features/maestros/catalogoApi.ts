import { api } from '../../lib/apiClient'

export interface CatalogoEscalon {
  cantidadMinima: number
  precio: number
}

export interface CatalogoPresentacion {
  /** Como se lee: "Saco 50 kg", "Caja x 12". */
  nombre: string
  unidad: string
  /** Cuántas unidades base trae. */
  factor: number
  /** Precio de UNA presentación completa. */
  precio: number
  /** Por unidad base (el kilo, la botella): deja comparar el saco con el suelto. */
  precioUnidadBase: number
  /** Precios por volumen: desde N, a tal precio. */
  escalones: CatalogoEscalon[]
}

export interface CatalogoProducto {
  /** Solo del cliente (índice): el API público no expone ids internos. Sirve de `key` al pintar. */
  clave: number
  nombre: string
  descripcion: string | null
  categoria: string | null
  marca: string | null
  /** Ruta de la foto ("/uploads/productos/..."); se arma con `urlImagen`. */
  foto: string | null
  unidadBase: string
  /** Contenido del envase ya legible: "900 ML". */
  contenido: string | null
  /** El precio más bajo entre sus presentaciones. */
  precioDesde: number
  presentaciones: CatalogoPresentacion[]
}

export interface CatalogoResponse {
  empresa: string
  telefono: string | null
  categorias: string[]
  marcas: string[]
  productos: CatalogoProducto[]
}

export const catalogoApi = {
  /**
   * El catálogo público: no pide sesión (`auth: false`) ni lleva el token aunque lo haya, porque es el mismo que
   * ve cualquiera con el enlace. Los precios son los de la lista predeterminada.
   */
  obtener: async (): Promise<CatalogoResponse> => {
    const r = await api.get<Omit<CatalogoResponse, 'productos'> & { productos: Omit<CatalogoProducto, 'clave'>[] }>(
      '/publico/catalogo',
      { auth: false },
    )
    return { ...r, productos: r.productos.map((p, i) => ({ ...p, clave: i })) }
  },
}

/** Ruta pública del catálogo: la que se comparte con los clientes. */
export const RUTA_CATALOGO_PUBLICO = '/catalogo'
