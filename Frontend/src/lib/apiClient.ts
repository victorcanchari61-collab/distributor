import { API_BASE_URL } from './const_glob'
import { getToken } from './authStorage'

/** La acción que el servidor negó, tal como la nombra el catálogo de permisos. */
export interface PermisoNegado {
  submodulo: string
  accion: string
}

/** Error tipado con la forma que devuelve ExceptionMiddleware del backend. */
export class ApiError extends Error {
  readonly statusCode: number
  readonly errors: string[]

  /** Qué permiso faltaba, cuando el servidor devolvió un 403 del filtro. */
  readonly permiso?: PermisoNegado

  constructor(message: string, statusCode: number, errors: string[] = [], permiso?: PermisoNegado) {
    super(message)
    this.name = 'ApiError'
    this.statusCode = statusCode
    this.errors = errors
    this.permiso = permiso
  }
}

interface ApiErrorBody {
  statusCode?: number
  message?: string
  errors?: string[] | null
  /** Solo en los 403 del filtro de permisos. */
  submodulo?: string
  accion?: string
}

/**
 * A quién avisar cuando el servidor niega una acción.
 *
 * Es un solo enganche global en vez de un try/catch en cada pantalla: hay
 * decenas de sitios que pueden toparse con un 403, y pedirle a cada uno que se
 * acuerde de abrir el modal garantiza que la mitad no lo haga. Aquí se avisa
 * una vez y quien escucha decide qué mostrar.
 */
let avisarPermisoNegado: ((permiso: PermisoNegado) => void) | null = null

export function alNegarPermiso(callback: ((permiso: PermisoNegado) => void) | null) {
  avisarPermisoNegado = callback
}

export interface RequestOptions extends Omit<RequestInit, 'body'> {
  body?: unknown
  /** Adjunta el token guardado en la cabecera Authorization. Por defecto true. */
  auth?: boolean
}

export async function apiFetch<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { body, auth = true, headers, ...rest } = options

  const finalHeaders = new Headers(headers)
  finalHeaders.set('Accept', 'application/json')
  if (body !== undefined) finalHeaders.set('Content-Type', 'application/json')

  const token = auth ? getToken() : null
  if (token) finalHeaders.set('Authorization', `Bearer ${token}`)

  let response: Response
  try {
    response = await fetch(`${API_BASE_URL}${path}`, {
      ...rest,
      headers: finalHeaders,
      body: body === undefined ? undefined : JSON.stringify(body),
    })
  } catch {
    throw new ApiError('No pudimos conectar con el servidor. Revisa tu conexión.', 0)
  }

  const raw = await response.text()
  const data = raw ? (JSON.parse(raw) as unknown) : null

  if (!response.ok) {
    const problem = (data ?? {}) as ApiErrorBody

    // El 403 del filtro de permisos trae qué faltaba; el resto de 403 (o un
    // 401 de sesion vencida) no, y ahi no hay nada que solicitar.
    const permiso =
      response.status === 403 && problem.submodulo && problem.accion
        ? { submodulo: problem.submodulo, accion: problem.accion }
        : undefined

    /*
     * Solo se ofrece pedir permiso para lo que la persona pulsó. Un "ver"
     * negado casi nunca lo pidió ella: las pantallas cargan de paso catálogos
     * de otros módulos — métodos de pago, almacenes — y saltarle un modal por
     * cada uno al abrir una vista es ruido que además desconcierta ("¿por qué
     * me habla de Métodos de pago si abrí Notas de venta?"). Entrar a una
     * pantalla se pide desde la propia pantalla bloqueada.
     */
    if (permiso && permiso.accion !== 'ver') avisarPermisoNegado?.(permiso)

    throw new ApiError(
      problem.message ?? `Error ${response.status}`,
      problem.statusCode ?? response.status,
      problem.errors ?? [],
      permiso,
    )
  }

  return data as T
}

export const api = {
  get: <T>(path: string, options?: RequestOptions) => apiFetch<T>(path, { ...options, method: 'GET' }),
  post: <T>(path: string, body?: unknown, options?: RequestOptions) =>
    apiFetch<T>(path, { ...options, method: 'POST', body }),
  put: <T>(path: string, body?: unknown, options?: RequestOptions) =>
    apiFetch<T>(path, { ...options, method: 'PUT', body }),
  patch: <T>(path: string, body?: unknown, options?: RequestOptions) =>
    apiFetch<T>(path, { ...options, method: 'PATCH', body }),
  del: <T>(path: string, options?: RequestOptions) =>
    apiFetch<T>(path, { ...options, method: 'DELETE' }),
}
