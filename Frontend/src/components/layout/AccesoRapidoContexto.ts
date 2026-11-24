import { createContext } from 'react'
import type { AccesoRapido } from './accesosRapidos'

/**
 * Cómo se usa un acceso rápido del menú: lo provee el panel de pestañas (App), que es quien puede montar una vista en
 * el fondo para pulsar su botón sin sacar a la persona de la vista en la que está.
 */
export const AccesoRapidoContexto = createContext<((vista: string, acceso: AccesoRapido) => void) | null>(null)
