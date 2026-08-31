import { API_BASE_URL } from './const_glob'
import { getToken } from './authStorage'

/** Error tipado con la forma que devuelve ExceptionMiddleware del backend. */
export class ApiError extends Error {
  readonly statusCode: number
  readonly errors: string[]

  constructor(message: string, statusCode: number, errors: string[] = []) {
    super(message)
    this.name = 'ApiError'
    this.statusCode = statusCode
    this.errors = errors
  }
}

interface ApiErrorBody {
  statusCode?: number
  message?: string
  errors?: string[] | null
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
    throw new ApiError(
      problem.message ?? `Error ${response.status}`,
      problem.statusCode ?? response.status,
      problem.errors ?? [],
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
