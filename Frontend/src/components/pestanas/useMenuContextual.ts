import { useCallback, useState } from 'react'
import type { MouseEvent as EventoReact } from 'react'

/** El estado de un menú contextual: dónde está abierto y sobre qué. */
export function useMenuContextual<T>() {
  const [estado, setEstado] = useState<{ x: number; y: number; dato: T } | null>(null)
  const abrir = useCallback((e: EventoReact, dato: T) => {
    e.preventDefault()
    setEstado({ x: e.clientX, y: e.clientY, dato })
  }, [])
  const cerrar = useCallback(() => setEstado(null), [])
  return { estado, abrir, cerrar }
}

