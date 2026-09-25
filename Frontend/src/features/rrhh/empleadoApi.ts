import { api } from '../../lib/apiClient'

/**
 * El padrón de la gente que trabaja en el negocio.
 *
 * Es un maestro, no una cuenta de acceso: existe aunque la persona nunca entre al sistema. Quien
 * además usa el sistema tiene un usuario enlazado a su ficha, pero ese enlace es opcional.
 */
export interface EmpleadoResponse {
  id: number
  documento: string
  /** DNI o CODIGO. */
  tipoDoc: string
  nombres: string
  apellidos: string
  /** Nombres y apellidos juntos, como se lee en una lista. */
  nombreCompleto: string
  telefono: string | null
  email: string | null
  direccion: string | null
  cargo: string | null
  area: string | null
  /** Fechas del servidor, en ISO. */
  fechaIngreso: string | null
  fechaCese: string | null
  /** Lo que cobra por una semana completa. Sin sueldo no entra en la planilla. */
  sueldoSemanal: number | null
  observacion: string | null
  activo: boolean
  fechaCreacion: string
  /** El usuario enlazado a esta ficha, si entra al sistema. */
  usuarioId: number | null
  usuario: string | null
}

export interface EmpleadoRequest {
  documento: string
  /** DNI o CODIGO. Vacío lo deduce el backend del largo del número. */
  tipoDoc?: string
  nombres: string
  apellidos: string
  telefono?: string | null
  email?: string | null
  direccion?: string | null
  cargo?: string | null
  area?: string | null
  fechaIngreso?: string | null
  fechaCese?: string | null
  sueldoSemanal?: number | null
  observacion?: string | null
}

export interface UpdateEmpleadoRequest extends EmpleadoRequest {
  activo: boolean
}

/** Lo justo para elegir un empleado al crear un usuario. */
export interface EmpleadoOpcion {
  id: number
  documento: string
  /** DNI o CODIGO: solo el DNI sirve para llenar el campo DNI de la cuenta. */
  tipoDoc: string
  nombreCompleto: string
  cargo: string | null
  /** Para proponerlo como correo de la cuenta. Puede no tener. */
  email: string | null
  /** Si ya tiene cuenta, cuál: el selector lo muestra ocupado en vez de esconderlo. */
  usuarioId: number | null
}

export const empleadoApi = {
  getAll: () => api.get<EmpleadoResponse[]>('/empleado'),

  /**
   * Los activos, para elegir uno al crear un usuario. Lo puede pedir quien administra usuarios
   * aunque no tenga el maestro de Empleados.
   */
  opciones: () => api.get<EmpleadoOpcion[]>('/empleado/opciones'),

  create: (body: EmpleadoRequest) => api.post<EmpleadoResponse>('/empleado', body),
  update: (id: number, body: UpdateEmpleadoRequest) => api.put<EmpleadoResponse>(`/empleado/${id}`, body),

  activar: (id: number) => api.patch<EmpleadoResponse>(`/empleado/${id}/activar`),

  /** Deja de aparecer para nuevas operaciones pero conserva su historial. */
  desactivar: (id: number) => api.patch<EmpleadoResponse>(`/empleado/${id}/desactivar`),

  /** Borrado definitivo. El backend lo rechaza si una cuenta usa la ficha. */
  remove: (id: number) => api.del<void>(`/empleado/${id}`),
}

/** Si esa persona trabajaba ese día (YYYY-MM-DD): ya había entrado y todavía no había cesado. */
export const trabajaba = (e: EmpleadoResponse, fecha: string) =>
  (!e.fechaIngreso || e.fechaIngreso.slice(0, 10) <= fecha) && (!e.fechaCese || e.fechaCese.slice(0, 10) >= fecha)
