import { useCallback, useState } from 'react'

/** Cómo se navega: el menú lateral o la barra fija de abajo. */
export type FormatoNavegacion = 'lateral' | 'barra'

const leer = (clave: string): FormatoNavegacion => {
  try {
    return localStorage.getItem(clave) === 'barra' ? 'barra' : 'lateral'
  } catch {
    return 'lateral'
  }
}

/**
 * El formato de navegación que eligió la persona, recordado en este navegador bajo `clave` (con su id: al cambiar de
 * cuenta se lee el de la otra, no se mezclan).
 */
export function useFormatoNavegacion(clave: string): [FormatoNavegacion, (formato: FormatoNavegacion) => void] {
  const [estado, setEstado] = useState(() => ({ clave, formato: leer(clave) }))

  // Otra cuenta en el mismo navegador: se lee su preferencia, no la de la anterior.
  if (estado.clave !== clave) setEstado({ clave, formato: leer(clave) })

  const cambiar = useCallback(
    (formato: FormatoNavegacion) => {
      setEstado({ clave, formato })
      try {
        localStorage.setItem(clave, formato)
      } catch {
        // Modo privado: rige en esta sesión, solo no se recuerda.
      }
    },
    [clave],
  )

  return [estado.formato, cambiar]
}
