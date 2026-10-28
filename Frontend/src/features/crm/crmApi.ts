import { api } from '../../lib/apiClient'

// --- Estados y periodo ---

/** El estado de un cliente por su caída de compras: la escala de siempre del negocio. */
export type EstadoClave = 'CRITICO' | 'RIESGO' | 'SEGUIMIENTO' | 'NORMAL' | 'SIN_BASE'

export interface Rango {
  desde: string
  hasta: string
}

/** Qué se mide y contra qué: el tramo pedido y el mismo tramo del año anterior. */
export interface PeriodoCaida {
  actual: Rango
  anterior: Rango
  /** "1 ene - 27 oct 2026" */
  etiqueta: string
  /** "1 ene - 27 oct 2025" */
  etiquetaAnterior: string
}

/** Una tarjeta de un reporte: cuántos hay en un estado y cuánta venta está en juego. */
export interface EstadoResumen {
  estado: EstadoClave
  etiqueta: string
  clientes: number
  monto: number
}

// --- Clientes con caída ---

export interface FilaCaida {
  id: number
  codigo: string
  cliente: string
  documento: string
  telefono: string | null
  vendedor: string | null
  vendedorId: number | null
  mercado: string | null
  mercadoId: number | null
  ruta: string | null
  rutaId: number | null
  categoriaCodigo: string | null
  categoria: string | null
  categoriaColor: string | null
  ultimaCompra: string | null
  diasSinCompra: number | null
  ventaAnterior: number
  ventaActual: number
  /** Actual menos anterior: negativa es plata que se dejó de vender. */
  variacion: number
  /** Positiva si cayó. Nula si el año anterior no compró. */
  caidaPct: number | null
  /** Lo que dejó de comprar (cero si compra igual o más). */
  montoRiesgo: number
  estado: EstadoClave
  saldoPorCobrar: number
  gestionResultado: string | null
  gestionEtiqueta: string | null
  gestionTono: TonoGestion | null
  gestionFecha: string | null
  proximoSeguimiento: string | null
  proximaAccion: string | null
  seguimientoVencido: boolean
}

export interface CaidaClientes {
  periodo: PeriodoCaida
  estados: EstadoResumen[]
  ventaAnterior: number
  ventaActual: number
  soloPropios: boolean
  items: FilaCaida[]
}

export interface ConsultaCaida {
  desde?: string
  hasta?: string
  mercadoId?: number
  rutaId?: number
  vendedorId?: number
  estado?: EstadoClave
  buscar?: string
}

export type SituacionProducto = 'DEJO' | 'NUEVO' | 'IGUAL' | 'MAS' | 'MENOS'

/** Un producto del cliente en los dos tramos: qué dejó de comprar, qué compra más y qué es nuevo. */
export interface SituacionProductoFila {
  productoId: number
  codigo: string
  producto: string
  ventaAnterior: number
  ventaActual: number
  variacion: number
  situacion: SituacionProducto
}

export interface QueDejoDeComprar {
  clienteId: number
  cliente: string
  periodo: PeriodoCaida
  productos: SituacionProductoFila[]
}

// --- Clientes inactivos ---

export interface FilaInactivo {
  id: number
  codigo: string
  cliente: string
  documento: string
  telefono: string | null
  vendedor: string | null
  mercado: string | null
  ruta: string | null
  categoriaCodigo: string | null
  categoria: string | null
  categoriaColor: string | null
  ultimaCompra: string
  diasSinCompra: number
  /** Lo comprado en los últimos 12 meses: lo que se pierde si no vuelve. */
  ventas12m: number
  compras12m: number
  ticketPromedio: number
  estado: EstadoClave
}

export interface Inactivos {
  corte: string
  estados: EstadoResumen[]
  soloPropios: boolean
  items: FilaInactivo[]
  /** Clientes activos que nunca compraron: aparte de la lista. */
  nuncaCompraron: number
}

export interface ConsultaInactivos {
  mercadoId?: number
  rutaId?: number
  vendedorId?: number
  estado?: EstadoClave
  buscar?: string
}

// --- Vendedores con caída ---

export interface FilaVendedor {
  usuarioId: number
  vendedor: string
  ventaAnterior: number
  ventaActual: number
  variacion: number
  caidaPct: number | null
  estado: EstadoClave
  /** Clientes a los que vendió en alguno de los dos tramos. */
  clientes: number
  /** De esos, cuántos compran menos que antes (En seguimiento o peor). */
  clientesEnCaida: number
  clientesCriticos: number
  /** Lo que dejaron de comprar los clientes que bajaron. */
  montoRiesgo: number
}

export interface VendedoresCaida {
  periodo: PeriodoCaida
  estados: EstadoResumen[]
  items: FilaVendedor[]
}

// --- Gestión y seguimiento ---

export type TipoContacto = 'LLAMADA' | 'WHATSAPP' | 'VISITA' | 'CORREO'
export type TonoGestion = 'positivo' | 'espera' | 'neutro' | 'objecion' | 'perdido'

export interface CatalogoSeguimiento {
  tipos: { clave: TipoContacto; etiqueta: string }[]
  resultados: { clave: string; etiqueta: string; tono: TonoGestion; cuando: string }[]
}

export interface ClienteBuscado {
  id: number
  codigo: string
  nombre: string
  documento: string
  mercado: string | null
  activo: boolean
}

export interface DatosCliente {
  id: number
  codigo: string
  nombre: string
  /** Empresa si tiene RUC; Persona si no. */
  tipo: 'Empresa' | 'Persona'
  tipoDoc: string
  documento: string
  telefono: string | null
  email: string | null
  direccion: string | null
  ciudad: string | null
  mercado: string | null
  ruta: string | null
  vendedor: string | null
  listaPrecio: string | null
  diaVisita: string | null
  categoriaCodigo: string | null
  categoria: string | null
  categoriaColor: string | null
  activo: boolean
  fechaAlta: string
  estado: { clave: EstadoClave; etiqueta: string }
}

export interface Gestion {
  id: number
  clienteId: number
  /** Cuándo se hizo el contacto (instante, UTC). */
  fecha: string
  tipoContacto: TipoContacto
  tipoEtiqueta: string
  resultado: string
  resultadoEtiqueta: string
  tono: TonoGestion
  comentario: string | null
  registradoPor: string | null
  /** El día y la hora del siguiente contacto (instante, UTC). */
  proximoSeguimiento: string | null
  proximoTipoContacto: TipoContacto | null
  proximoTipoEtiqueta: string | null
  proximaAccion: string | null
  seguimientoEstado: 'PROGRAMADO' | 'CUMPLIDO' | null
  /** El siguiente contacto sigue programado y su hora ya pasó. */
  vencida: boolean
}

export interface PeriodoCliente {
  desde: string
  hasta: string
  etiqueta: string
  etiquetaAnterior: string
  ventas: number
  compras: number
  ticketPromedio: number
  ventasAnterior: number
  /** Positiva si vendió más que el año anterior, negativa si cayó. */
  variacion: number
  /** Positiva si cayó. Nula si el año anterior no compró. */
  caidaPct: number | null
}

export interface FichaCliente {
  cliente: DatosCliente
  kpis: {
    diasSinComprar: number | null
    ultimaCompra: { id: number; fecha: string; documento: string; monto: number } | null
    saldoPorCobrar: number
  }
  periodo: PeriodoCliente
  ultimaGestion: Gestion | null
  proximaGestion: Gestion | null
  productosPrincipales: { producto: string; codigo: string | null; monto: number; porcentaje: number }[]
  /** Los últimos 24 meses: los primeros 12 son el año anterior y los últimos 12, el año en curso. */
  meses: { mes: string; importe: number }[]
}

export interface GestionesCliente {
  items: Gestion[]
  proximaGestion: Gestion | null
  totalAnio: number
  desdeAnio: string
}

export interface GuardarGestion {
  tipoContacto: TipoContacto
  resultado: string
  comentario?: string
  /** Hora de Perú, sin zona: "2026-10-30T10:00:00". Sin esto no hay siguiente contacto. */
  proximoSeguimiento?: string
  proximoTipoContacto?: TipoContacto
  proximaAccion?: string
}

export interface ComprasCliente {
  periodo: PeriodoCliente
  ventas: {
    notaVentaId: number
    numero: string
    fecha: string
    estado: string
    formaPago: string
    vendedor: string | null
    total: number
    pagado: number
    saldo: number
  }[]
  productos: SituacionProductoFila[]
}

export interface DocumentosCliente {
  pedidos: { id: number; numero: string; fecha: string; estado: string; condicionPago: string }[]
  devoluciones: { id: number; numero: string; notaVenta: string; fecha: string; estado: string; motivo: string | null }[]
}

const query = (c: Record<string, string | number | undefined>) => {
  const partes = new URLSearchParams()
  for (const [clave, valor] of Object.entries(c)) {
    if (valor !== undefined && valor !== '') partes.set(clave, String(valor))
  }
  const texto = partes.toString()
  return texto ? `?${texto}` : ''
}

export const crmApi = {
  // Gestión y seguimiento
  catalogo: () => api.get<CatalogoSeguimiento>('/crm/seguimiento/catalogo'),
  buscar: (texto: string) => api.get<ClienteBuscado[]>(`/crm/seguimiento/clientes${query({ buscar: texto })}`),
  ficha: (id: number) => api.get<FichaCliente>(`/crm/seguimiento/${id}/ficha`),
  gestiones: (id: number) => api.get<GestionesCliente>(`/crm/seguimiento/${id}/gestiones`),
  registrar: (id: number, body: GuardarGestion) => api.post<Gestion>(`/crm/seguimiento/${id}/gestiones`, body),
  actualizar: (gestionId: number, body: GuardarGestion) => api.put<Gestion>(`/crm/seguimiento/gestiones/${gestionId}`, body),
  reprogramar: (gestionId: number, proximoSeguimiento: string) =>
    api.put<Gestion>(`/crm/seguimiento/gestiones/${gestionId}/reprogramar`, { proximoSeguimiento }),
  compras: (id: number) => api.get<ComprasCliente>(`/crm/seguimiento/${id}/compras`),
  documentos: (id: number) => api.get<DocumentosCliente>(`/crm/seguimiento/${id}/documentos`),

  // Reportes
  caida: (c: ConsultaCaida) => api.get<CaidaClientes>(`/crm/caida${query({ ...c })}`),
  queDejoDeComprar: (clienteId: number, c: { desde?: string; hasta?: string }) =>
    api.get<QueDejoDeComprar>(`/crm/caida/${clienteId}/productos${query({ ...c })}`),
  inactivos: (c: ConsultaInactivos) => api.get<Inactivos>(`/crm/inactivos${query({ ...c })}`),
  vendedores: (c: { desde?: string; hasta?: string }) => api.get<VendedoresCaida>(`/crm/vendedores${query({ ...c })}`),
}
