import { useEffect, useRef } from 'react'

/** Cierra un popover/panel al hacer clic fuera o con Escape. */
export function useDismiss<E extends HTMLElement = HTMLDivElement>(onDismiss: () => void) {
  const ref = useRef<E>(null)

  useEffect(() => {
    const onClick = (e: MouseEvent) => {
      if (!ref.current?.contains(e.target as Node)) onDismiss()
    }
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onDismiss()

    document.addEventListener('mousedown', onClick)
    document.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('mousedown', onClick)
      document.removeEventListener('keydown', onKey)
    }
  }, [onDismiss])

  return ref
}
