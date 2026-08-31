const TOKEN_KEY = 'distribuidora.token'
const USER_KEY = 'distribuidora.usuario'

/**
 * Con "recordarme" la sesión va a localStorage (sobrevive al cierre del navegador);
 * sin él, a sessionStorage (se borra al cerrar la pestaña).
 */
export function saveSession(token: string, usuario: unknown, remember: boolean) {
  clearSession()
  const store = remember ? localStorage : sessionStorage
  store.setItem(TOKEN_KEY, token)
  store.setItem(USER_KEY, JSON.stringify(usuario))
}

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY) ?? sessionStorage.getItem(TOKEN_KEY)
}

export function getUsuario<T>(): T | null {
  const raw = localStorage.getItem(USER_KEY) ?? sessionStorage.getItem(USER_KEY)
  if (!raw) return null
  try {
    return JSON.parse(raw) as T
  } catch {
    return null
  }
}

export function clearSession() {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(USER_KEY)
  sessionStorage.removeItem(TOKEN_KEY)
  sessionStorage.removeItem(USER_KEY)
}
