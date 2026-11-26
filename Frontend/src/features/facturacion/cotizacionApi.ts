import { api } from '../../lib/apiClient'

/*
 * Las cotizaciones que los clientes mandan desde el portal (/portal). El panel las ve en su bandeja y las atiende
 * jalándolas al crear un pedido (POST /api/pedido con cotizacionId), o las descarta.
 */

export type EstadoCotizacion = 'EN_ESPERA' | 'ATENDIDA' | 'DESCARTADA' | 'CANCELADA'

export interface LineaCotizacion {
  id: number
  productoId: number
  codigo: string
  producto: string
  presentacionId: number
  presentacion: string
  /** Unidades base que trae una presentación. */
  factor: number
  /** Cuántas presentaciones. */
  cantidad: number
  /** Precio de UNA presentación, con el escalón que le tocaba por la cantidad (referencial). */
  precioPresentacion: number
  subtotal: number
}

export interface Cotizacion {
  id: number
  numero: string
  fecha: string
  estado: EstadoCotizacion
  clienteId: number
  cliente: string
  clienteDocumento: string
  ruta: string | null
  vendedorId: number | null
  vendedor: string | null
  listaPrecioId: number | null
  nota: string | null
  total: number
  /** El pedido que salió de ella, si ya se atendió. */
  pedidoId: number | null
  pedidoNumero: string | null
  fechaCierre: string | null
  cerradaPor: string | null
  motivoDescarte: string | null
  detalle: LineaCotizacion[]
}

/** Cómo se lee cada estado, para el cliente y para el panel. */
export const ESTADO_COTIZACION: Record<
  EstadoCotizacion,
  { etiqueta: string; tono: 'warning' | 'success' | 'danger' | 'neutral' }
> = {
  EN_ESPERA: { etiqueta: 'En espera', tono: 'warning' },
  ATENDIDA: { etiqueta: 'Atendida', tono: 'success' },
  DESCARTADA: { etiqueta: 'Descartada', tono: 'danger' },
  CANCELADA: { etiqueta: 'Cancelada', tono: 'neutral' },
}

export const cotizacionApi = {
  /** Las de la bandeja; con `clienteId` (y estado EN_ESPERA) las que se pueden jalar a un pedido de ese cliente. */
  listar: (filtro: { estado?: EstadoCotizacion; clienteId?: number } = {}) => {
    const q = new URLSearchParams()
    if (filtro.estado) q.set('estado', filtro.estado)
    if (filtro.clienteId) q.set('clienteId', String(filtro.clienteId))
    const query = q.toString()
    return api.get<Cotizacion[]>(`/cotizacion${query ? `?${query}` : ''}`)
  },
  getById: (id: number) => api.get<Cotizacion>(`/cotizacion/${id}`),
  descartar: (id: number, motivo: string) => api.patch<Cotizacion>(`/cotizacion/${id}/descartar`, { motivo }),
}
