import { createContext } from 'react'

/**
 * El color (data-sys) de la vista a la que pertenece lo que se está pintando.
 *
 * Los modales se pintan en #modal-root, que hereda el color de la vista que está a la vista. Casi siempre es la misma
 * que abrió el modal, pero un acceso rápido del menú abre el modal de OTRA vista (montada oculta) encima de la actual:
 * sin esto, "Nuevo empleado" abierto desde Boletas salía con los colores de Facturación. Cada panel de pestaña provee
 * el color de su vista y el modal lo vuelve a poner en su raíz.
 */
export const SysVistaContext = createContext<string | undefined>(undefined)
