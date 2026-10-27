import { api } from '../../lib/apiClient'

export type CicloCategorizacion = 'MENSUAL' | 'TRIMESTRAL' | 'CUATRIMESTRAL' | 'ANUAL'

export type ColorCategoria = 'sky' | 'emerald' | 'amber' | 'orange' | 'violet' | 'slate' | 'rose'

export interface CategoriaCliente {
  /** A a F. La A es la más alta. */
  codigo: string
  nombre: string
  color: ColorCategoria
  /** Desde cuántos soles comprados entra en esta categoría. */
  desde: number
  /** El tope del tramo (el "desde" de la de arriba menos uno). Nulo en la más alta. */
  hasta: number | null
  /** Cuántos clientes tiene según el último cálculo. */
  clientes: number
}

export interface VentanaCategorizacion {
  evaluadoDesde: string
  evaluadoHasta: string
  vigenteDesde: string
  /** El último día en que rige: el resultado cambia al día siguiente. */
  vigenteHasta: string
}

export interface CalculoVigente {
  id: number
  ciclo: CicloCategorizacion
  ventana: VentanaCategorizacion
  /** Cuándo se calculó. */
  calculadoEn: string
  /** Lo hizo el cambio de ciclo y no una persona. */
  automatico: boolean
  usuario: string | null
  clientes: number
  /** Ya pasó su último día y nadie recalculó. */
  vencido: boolean
}

export interface Categorizacion {
  ciclo: CicloCategorizacion
  categorias: CategoriaCliente[]
  /** Lo que se evaluaría si se calculara hoy con el ciclo guardado. */
  ventana: VentanaCategorizacion
  /** Nulo mientras nadie haya calculado. */
  vigente: CalculoVigente | null
  /** El ciclo guardado no es el del cálculo vigente. */
  cicloDistinto: boolean
}

export type MovimientoCategoria = 'SUBE' | 'BAJA' | 'IGUAL' | 'NUEVO' | ''

export interface ClienteCategorizado {
  clienteId: number
  codigo: string
  documento: string
  nombre: string
  ruta: string | null
  mercado: string | null
  /** La letra de su categoría. */
  categoria: string
  /** Lo que compró en el ciclo evaluado. */
  monto: number
  categoriaAnterior: string | null
  movimiento: MovimientoCategoria
}

export interface GuardarCategorizacion {
  ciclo: CicloCategorizacion
  categorias: { codigo: string; nombre: string; color: ColorCategoria; desde: number }[]
}

export const categorizacionApi = {
  obtener: () => api.get<Categorizacion>('/crm/categorizacion'),
  guardar: (body: GuardarCategorizacion) => api.put<Categorizacion>('/crm/categorizacion', body),
  calcular: () => api.post<Categorizacion>('/crm/categorizacion/calcular'),
  clientes: () => api.get<ClienteCategorizado[]>('/crm/categorizacion/clientes'),
}
