/**
 * Roles del sistema. Los ids coinciden con el enum `Role` del backend
 * (Backend/Models/Enums/Role.cs): 1 Administrador, 2 Vendedor, 3 Almacenero.
 */
export type Rol = 1 | 2 | 3

export interface RolInfo {
  id: Rol
  label: string
  description: string
}

export const ROLES: Record<Rol, RolInfo> = {
  1: {
    id: 1,
    label: 'Administrador',
    description: 'Acceso total: configura el sistema, crea usuarios y ve todos los módulos.',
  },
  2: {
    id: 2,
    label: 'Vendedor',
    description: 'Trabaja con clientes, pedidos y cobranzas de su cartera.',
  },
  3: {
    id: 3,
    label: 'Almacenero',
    description: 'Opera inventario: recepciones, movimientos y conteos de su almacén.',
  },
}

export const ROLES_LIST: RolInfo[] = [ROLES[1], ROLES[2], ROLES[3]]

/** Lo que un rol puede hacer sobre un módulo. */
export type Permiso = 'ver' | 'crear' | 'editar' | 'eliminar'

export const PERMISOS: { id: Permiso; label: string }[] = [
  { id: 'ver', label: 'Ver' },
  { id: 'crear', label: 'Crear' },
  { id: 'editar', label: 'Editar' },
  { id: 'eliminar', label: 'Eliminar' },
]

/** Matriz rol → módulo → permisos concedidos. */
export type MatrizAccesos = Record<Rol, Record<string, Permiso[]>>

const TODO: Permiso[] = ['ver', 'crear', 'editar', 'eliminar']

/**
 * Punto de partida razonable. Se edita en pantalla y, cuando exista el
 * endpoint, se guardara en el backend.
 */
export const ACCESOS_INICIALES: MatrizAccesos = {
  1: {
    maestros: TODO,
    compras: TODO,
    inv: TODO,
    fact: TODO,
    tms: TODO,
    dms: TODO,
    rrhh: TODO,
    config: TODO,
  },
  2: {
    maestros: ['ver', 'crear', 'editar'],
    compras: [],
    inv: ['ver'],
    fact: ['ver', 'crear', 'editar'],
    tms: ['ver'],
    dms: ['ver', 'crear', 'editar'],
    rrhh: [],
    config: [],
  },
  3: {
    maestros: ['ver'],
    compras: ['ver', 'crear'],
    inv: TODO,
    fact: [],
    tms: ['ver'],
    dms: [],
    rrhh: [],
    config: [],
  },
}
