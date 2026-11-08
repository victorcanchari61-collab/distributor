import { ApiError } from './apiClient'

/**
 * Carga un dato de apoyo de una pantalla (un catálogo de otro módulo: rutas, almacenes, métodos de pago...) sin que su
 * ausencia tumbe la pantalla.
 *
 * Las pantallas piden de paso catálogos que quizá el rol no puede ver. Antes un solo 403 hacía que toda la vista mostrara
 * "No tienes permiso para esta acción" aunque la persona solo quisiera ver su lista. Con esto, un 403 deja ese catálogo
 * vacío (el filtro o el selector sale sin opciones) y la pantalla sigue; cualquier otro error se propaga como antes.
 */
export async function opcional<T>(promesa: Promise<T>, vacio: T): Promise<T> {
  try {
    return await promesa
  } catch (e) {
    if (e instanceof ApiError && e.statusCode === 403) return vacio
    throw e
  }
}
