import { api } from '../../lib/apiClient'
import type { ConsultaTabla } from '../../components/ui'
import type { PaginaResponse } from '../../lib/paginacion'

// --- Motivos de gasto ---

export interface MotivoGastoResponse {
  id: number
  nombre: string
  descripcion: string | null
  activo: boolean
  /** En cuántos cuadres se usó. Si hay alguno, no se elimina. */
  usos: number
}

export interface MotivoGastoRequest {
  nombre: string
  descripcion?: string | null
  activo: boolean
}

export const motivoGastoApi = {
  getAll: () => api.get<MotivoGastoResponse[]>('/motivogasto'),
  create: (body: MotivoGastoRequest) => api.post<MotivoGastoResponse>('/motivogasto', body),
  update: (id: number, body: MotivoGastoRequest) =>
    api.put<MotivoGastoResponse>(`/motivogasto/${id}`, body),
  remove: (id: number) => api.del<void>(`/motivogasto/${id}`),
}

// --- El cuadre del reparto ---

/** pendiente · cuadrado · conDiferencia · anulado */
export type EstadoCuadre = 'pendiente' | 'cuadrado' | 'conDiferencia' | 'anulado'

/** Una fila de la lista de cuadres: un día y una persona. */
export interface CuadrePendienteResponse {
  fecha: string
  usuarioId: number
  usuario: string
  /** Lo que el sistema dice que cobró en efectivo ese día. */
  efectivo: number
  /** Lo que le entró por Yape, Plin o transferencia. */
  bancos: number
  total: number
  /** Solo si ya cuadró. Negativa: falta dinero. */
  diferenciaEfectivo: number | null
  estado: EstadoCuadre
  /** El cuadre registrado, si lo hay: para editarlo o anularlo. */
  arqueoId: number | null
  /** Lo que quedó debiendo ese día, si faltó. */
  faltante: number
  faltanteSaldado: boolean
}

/** Un cobro concreto: de quién vino y cuánto. */
export interface CobroDelDiaResponse {
  pagoId: number
  fecha: string
  cliente: string
  /** El documento al que se aplicó: NV-000012. */
  documento: string
  metodoPago: string
  /** EFECTIVO, BILLETERA_DIGITAL, TRANSFERENCIA... */
  tipoMetodo: string
  monto: number
  /** El cobro salda una venta de otro día: deuda vieja cobrada en la ruta. */
  esDeudaAnterior: boolean
}

export interface ArqueoGastoResponse {
  id: number
  motivoGastoId: number
  motivoGasto: string
  monto: number
  descripcion: string | null
}

export interface ArqueoPagoDigitalResponse {
  id: number
  clienteId: number | null
  cliente: string | null
  metodoPagoId: number
  metodoPago: string
  numeroOperacion: string | null
  monto: number
}

export interface ArqueoCajaResponse {
  id: number
  fecha: string
  usuarioId: number
  usuario: string
  billetes: number
  monedas: number
  efectivoSistema: number
  bancosSistema: number
  totalEfectivoReal: number
  totalDigitalReal: number
  diferenciaEfectivo: number
  diferenciaBancos: number
  /** Lo que la persona debe reponer, si faltó dinero. */
  faltante: number
  /** Lo que trajo de más. Solo se informa. */
  sobrante: number
  faltanteSaldado: boolean
  fechaSaldado: string | null
  observacion: string | null
  estado: string
  registradoPor: string | null
  fechaCreacion: string
  gastos: ArqueoGastoResponse[]
  pagosDigitales: ArqueoPagoDigitalResponse[]
}

/** Todo lo necesario para cuadrar a una persona en un día. */
export interface DetalleCuadreResponse {
  fecha: string
  usuarioId: number
  usuario: string
  efectivoSistema: number
  bancosSistema: number
  /** Los cobros en efectivo, uno a uno: de quién y cuánto. */
  efectivo: CobroDelDiaResponse[]
  /** Los cobros digitales que el sistema ya tiene registrados. */
  digital: CobroDelDiaResponse[]
  /** Lo declarado, si ya se cuadró. */
  arqueo: ArqueoCajaResponse | null
}

/** Lo que una persona debe por faltantes, para descontárselo. */
export interface DeudaUsuarioResponse {
  usuarioId: number
  usuario: string
  /** Faltantes todavía sin saldar. */
  pendiente: number
  /** Cuántos días le faltó dinero y siguen sin saldar. */
  dias: number
  /** Lo ya descontado o repuesto, para ver el historial. */
  saldado: number
  detalle: ArqueoCajaResponse[]
}

export interface ArqueoGastoRequest {
  motivoGastoId: number
  monto: number
  descripcion?: string | null
}

export interface ArqueoPagoDigitalRequest {
  clienteId?: number | null
  metodoPagoId: number
  numeroOperacion?: string | null
  monto: number
}

/**
 * Solo viaja lo que la persona declaró haber contado: los totales del sistema
 * los calcula el backend al cerrar. Si los mandara el cliente, bastaría con
 * editarlos en el navegador para que cualquier cuadre saliera perfecto.
 */
export interface RegistrarArqueoRequest {
  fecha: string
  usuarioId: number
  billetes: number
  monedas: number
  observacion?: string | null
  gastos: ArqueoGastoRequest[]
  pagosDigitales: ArqueoPagoDigitalRequest[]
}

export const arqueoApi = {
  cuadres: (desde: string, hasta: string) =>
    api.get<CuadrePendienteResponse[]>(`/arqueo/cuadres?desde=${desde}&hasta=${hasta}`),

  detalle: (fecha: string, usuarioId: number) =>
    api.get<DetalleCuadreResponse>(`/arqueo/detalle?fecha=${fecha}&usuarioId=${usuarioId}`),

  deudas: () => api.get<DeudaUsuarioResponse[]>('/arqueo/deudas'),

  /** Una página del historial de cuadres, resuelta en el servidor. */
  listar: (consulta: ConsultaTabla) =>
    api.post<PaginaResponse<ArqueoCajaResponse>>('/arqueo/listar', consulta),

  /** Registra o corrige: el mismo día y persona reemplaza el cuadre anterior. */
  registrar: (body: RegistrarArqueoRequest) => api.post<ArqueoCajaResponse>('/arqueo', body),

  anular: (id: number) => api.patch<ArqueoCajaResponse>(`/arqueo/${id}/anular`),

  /** Marca que el faltante ya se le descontó o lo repuso. */
  saldar: (id: number) => api.patch<ArqueoCajaResponse>(`/arqueo/${id}/saldar`),
}
