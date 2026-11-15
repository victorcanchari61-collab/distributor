import { createContext } from 'react'

/**
 * Si lo que se pinta está dentro de una ventana emergente (`Modal`).
 *
 * Lo lee `SysDataTable` para portarse como tabla de modal sin que cada ventana tenga que decírselo: sin pie de
 * paginación cuando todo cabe en una página y sin alto fijo reservado, que en una ventana chica solo dejaba un hueco
 * vacío y el "Sin registros · Por página" de una lista que no la necesita.
 */
export const DentroDeModal = createContext(false)
