import { api } from '../../lib/apiClient'

export type PeriodoCrm = 'semana' | 'mes' | 'anio'

export type NivelCliente = 'CRITICO' | 'ALTO' | 'MEDIO' | 'ESTABLE' | 'NUEVO' | 'INACTIVO'

/** Un rango de días, ambos incluidos. */
export interface RangoCrm {
  desde: string
  hasta: string
}

/** Qué se compara con qué: el periodo en curso contra el anterior, del mismo largo. */
export interface VentanasCrm {
  periodo: PeriodoCrm
  actual: RangoCrm
  anterior: RangoCrm
}

export interface ClienteCrm {
  clienteId: number
  codigo: string
  documento: string
  tipoDoc: string
  nombre: string
  telefono: string | null
  /** La letra de su categoría (A a F) según el último cálculo; nulo si nunca se calculó. */
  categoriaCodigo: string | null
  /** El nombre de esa categoría (Socio, Distribuidor...). */
  categoria: string | null
  categoriaColor: string | null
  direccion: string | null
  distrito: string | null
  /** El flag del maestro de clientes. Distinto de `inactivo`, que mira las compras. */
  activo: boolean
  rutaId: number | null
  ruta: string | null
  mercadoId: number | null
  mercado: string | null
  vendedorId: number | null
  vendedor: string | null
  actual: number
  anterior: number
  /** Actual menos anterior: negativo es plata que se dejó de vender. */
  diferencia: number
  /** Cambio en %, o null si antes no había compras con qué comparar. */
  variacion: number | null
  nivel: NivelCliente
  ultimaCompra: string | null
  diasSinComprar: number | null
  /** Lleva más de `diasInactivo` sin comprar nada. */
  inactivo: boolean
  saldoPorCobrar: number
  /** La acción pendiente más próxima anotada en su seguimiento. */
  proximaAccion: string | null
  /** El día de esa acción. */
  proximaFecha: string | null
  /** Esa acción ya debió hacerse. */
  accionVencida: boolean
  /** Cuándo fue la última gestión con el cliente. */
  ultimaGestion: string | null
}

export interface ResumenCrm {
  clientes: number
  criticos: number
  altos: number
  medios: number
  estables: number
  nuevos: number
  inactivos: number
  /** Clientes con una acción de seguimiento cuyo día ya pasó. */
  accionesVencidas: number
  actual: number
  anterior: number
  diferencia: number
  variacion: number | null
  /** Lo que se dejó de vender solo entre los clientes que bajaron. */
  ventaPerdida: number
}

export interface CarteraCrm {
  ventanas: VentanasCrm
  resumen: ResumenCrm
  items: ClienteCrm[]
  /** Quien pregunta ve solo parte de la cartera (según su alcance). */
  soloPropios: boolean
  diasInactivo: number
}

export interface ConsultaCartera {
  periodo: PeriodoCrm
  mercadoId?: number
  rutaId?: number
  vendedorId?: number
}

export interface ComparativoCrm {
  periodo: PeriodoCrm
  actual: RangoCrm
  anterior: RangoCrm
  importeActual: number
  importeAnterior: number
  diferencia: number
  variacion: number | null
  nivel: NivelCliente
}

export interface CompraCrm {
  notaVentaId: number
  numero: string
  fecha: string
  estado: string
  formaPago: string
  vendedor: string | null
  total: number
  pagado: number
  saldo: number
}

export interface ProductoPerdidoCrm {
  productoId: number
  codigo: string
  producto: string
  actual: number
  anterior: number
  diferencia: number
  /** En el periodo en curso no compró nada de este producto. */
  dejoDeComprar: boolean
}

export interface PedidoCrm {
  id: number
  numero: string
  fecha: string
  estado: string
  condicionPago: string
}

export interface DevolucionCrm {
  id: number
  numero: string
  notaVenta: string
  fecha: string
  estado: string
  motivo: string | null
}

export interface FichaCrm {
  cliente: ClienteCrm
  /** Con qué periodo se calcularon el nivel, la caída y los productos perdidos. */
  periodo: PeriodoCrm
  email: string | null
  diaVisita: string | null
  listaPrecio: string | null
  fechaAlta: string
  /** La caída en las tres escalas a la vez: semana, mes y año. */
  comparativos: ComparativoCrm[]
  compras: CompraCrm[]
  productosPerdidos: ProductoPerdidoCrm[]
  pedidos: PedidoCrm[]
  devoluciones: DevolucionCrm[]
}

const query = (c: ConsultaCartera) => {
  const partes = new URLSearchParams({ periodo: c.periodo })
  if (c.mercadoId) partes.set('mercadoId', String(c.mercadoId))
  if (c.rutaId) partes.set('rutaId', String(c.rutaId))
  if (c.vendedorId) partes.set('vendedorId', String(c.vendedorId))
  return `?${partes.toString()}`
}

export const crmApi = {
  cartera: (c: ConsultaCartera) => api.get<CarteraCrm>(`/crm/cartera${query(c)}`),
  ficha: (clienteId: number, periodo: PeriodoCrm) =>
    api.get<FichaCrm>(`/crm/clientes/${clienteId}?periodo=${periodo}`),
}

// --- Seguimiento ---

export type TipoGestion = 'LLAMADA' | 'VISITA' | 'WHATSAPP' | 'OTRO'

export type ResultadoGestion =
  | 'CONTACTADO'
  | 'SIN_RESPUESTA'
  | 'PROMESA_COMPRA'
  | 'PROMESA_PAGO'
  | 'RECLAMO'
  | 'PERDIDO'

export interface GestionCrm {
  id: number
  clienteId: number
  /** Cuándo se hizo el contacto. */
  fecha: string
  tipo: TipoGestion
  resultado: ResultadoGestion
  nota: string
  proximaAccion: string | null
  /** El día de la próxima acción. */
  proximaFecha: string | null
  cumplida: boolean
  cumplidaEn: string | null
  /** La acción sigue abierta y su día ya pasó. */
  vencida: boolean
  usuarioId: number | null
  usuario: string | null
}

export interface GestionRequest {
  tipo: TipoGestion
  resultado: ResultadoGestion
  nota: string
  proximaAccion?: string
  /** YYYY-MM-DD. Va junto con `proximaAccion`. */
  proximaFecha?: string
}

export const seguimientoApi = {
  listar: (clienteId: number) => api.get<GestionCrm[]>(`/crm/clientes/${clienteId}/gestiones`),
  registrar: (clienteId: number, body: GestionRequest) =>
    api.post<GestionCrm>(`/crm/clientes/${clienteId}/gestiones`, body),
  cumplir: (id: number, cumplida: boolean) =>
    api.patch<GestionCrm>(`/crm/gestiones/${id}/cumplida`, { cumplida }),
  eliminar: (id: number) => api.del<void>(`/crm/gestiones/${id}`),
}
