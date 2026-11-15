import { api } from '../../lib/apiClient'

export interface RutaResponse {
  id: number
  nombre: string
  activo: boolean
  /** Cuántos clientes ya la usan. Si hay alguno, no se elimina. */
  clientes: number
  /** Quiénes la tienen a cargo. Puede ser más de uno (el titular y su reemplazo). */
  vendedores: string[]
  /** Los mercados donde están sus clientes activos. */
  mercados: string[]
  /** Qué días sale y en qué camión, según los recorridos de Flota, en orden de semana. */
  salidas: { dia: string; placa: string }[]
  /** Lo vendido este mes a sus clientes (S/). */
  ventasMes: number
  /** Cuántos de sus clientes compraron este mes. */
  clientesConCompraMes: number
  /** Lo que deben sus clientes en ventas al crédito (S/). */
  porCobrar: number
  /** Cuántos de sus clientes deben algo. */
  clientesConDeuda: number
}

export interface RutaRequest {
  nombre: string
}

export const rutaApi = {
  getAll: () => api.get<RutaResponse[]>('/ruta'),
  create: (body: RutaRequest) => api.post<RutaResponse>('/ruta', body),
  update: (id: number, body: RutaRequest & { activo: boolean }) =>
    api.put<RutaResponse>(`/ruta/${id}`, body),
}
