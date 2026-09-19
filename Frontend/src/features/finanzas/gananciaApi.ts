import { api } from '../../lib/apiClient'
import type { ConsultaTabla } from '../../components/ui'
import type { PaginaResponse } from '../../lib/paginacion'

// --- Ganancias ---
//
// La base es el producto: cuánto se ganó con cada uno, que es lo vendido
// menos lo que costó la mercadería (el costo real de cada salida, la más
// antigua primero). Fecha, vendedor, venta, categoría y marca son filtros que
// recortan qué ventas entran en la suma.

export interface GananciaProducto {
  productoId: number
  codigo: string
  producto: string
  categoria: string
  marca: string
  /** Cuánto se vendió, en unidad base. */
  cantidad: number
  unidadBase: string
  /** En cuántas ventas salió. */
  ventas: number
  /** Los números de esas ventas: NV-0004. */
  notas: string[]
  vendedores: string[]
  /** Un día suelto, sin hora: se muestra tal cual, no se convierte de UTC. */
  ultimaVenta: string
  importe: number
  costo: number
  ganancia: number
  /** En %. Vacío si no hubo importe. */
  margen: number | null
  /** Parte de esa mercadería entró sin declarar su costo. */
  sinCosto: boolean
}

/** Los totales de TODO lo filtrado, no solo de la página que se ve. */
export interface GananciaResumen {
  desde: string
  hasta: string
  /** Si lo que se ve es solo lo propio o todo el negocio. */
  soloPropio: boolean
  ventas: number
  productos: number
  importe: number
  costo: number
  ganancia: number
  margen: number | null
  /**
   * Líneas vendidas sin costo: la mercadería entró sin declararlo. En esas la
   * ganancia sale igual al precio y el total queda inflado.
   */
  lineasSinCosto: number
}

/** Lo que hay para elegir en los filtros, dentro del rango de fechas. */
export interface GananciaOpciones {
  vendedores: string[]
  categorias: string[]
  marcas: string[]
  /** Los productos que se vendieron en el rango. */
  productos: string[]
  /** Los números de las ventas del rango: NV-0004. */
  ventas: string[]
}

export interface GananciaPagina extends PaginaResponse<GananciaProducto> {
  resumen: GananciaResumen
  opciones: GananciaOpciones
}

export const gananciaApi = {
  /** Una página de productos con su ganancia, ya filtrada y ordenada en el servidor. */
  listar: (consulta: ConsultaTabla) => api.post<GananciaPagina>('/ganancia/listar', consulta),
}
