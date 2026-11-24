import { useEffect, useLayoutEffect, useRef } from 'react'
import type { KeyboardEvent } from 'react'
import { createPortal } from 'react-dom'
import type { LucideIcon } from 'lucide-react'
import { cn } from '../ui'

export interface OpcionMenu {
  etiqueta: string
  icono?: LucideIcon
  onElegir: () => void
  desactivada?: boolean
  /** Texto de apoyo a la derecha (por qué está desactivada). */
  nota?: string
}

/**
 * Menú de clic derecho. Se abre en el puntero, no se sale de la pantalla y se cierra con un clic fuera, Escape,
 * scroll o al cambiar el tamaño de la ventana. Va en #modal-root, dentro del color del módulo abierto.
 */
export function MenuContextual({ x, y, opciones, onCerrar }: { x: number; y: number; opciones: OpcionMenu[]; onCerrar: () => void }) {
  const ref = useRef<HTMLDivElement>(null)

  // Se mide ya pintado y se corrige directo en el DOM: sin estado extra ni parpadeo.
  useLayoutEffect(() => {
    const el = ref.current
    if (!el) return
    const { width, height } = el.getBoundingClientRect()
    el.style.left = `${Math.max(8, Math.min(x, window.innerWidth - width - 8))}px`
    el.style.top = `${Math.max(8, Math.min(y, window.innerHeight - height - 8))}px`
  }, [x, y, opciones.length])

  useEffect(() => {
    const fuera = (e: MouseEvent) => {
      if (!ref.current?.contains(e.target as Node)) onCerrar()
    }
    const escape = (e: globalThis.KeyboardEvent) => e.key === 'Escape' && onCerrar()
    document.addEventListener('mousedown', fuera)
    document.addEventListener('keydown', escape)
    window.addEventListener('resize', onCerrar)
    window.addEventListener('blur', onCerrar)
    window.addEventListener('scroll', onCerrar, true)
    ref.current?.querySelector<HTMLButtonElement>('button:not(:disabled)')?.focus()
    return () => {
      document.removeEventListener('mousedown', fuera)
      document.removeEventListener('keydown', escape)
      window.removeEventListener('resize', onCerrar)
      window.removeEventListener('blur', onCerrar)
      window.removeEventListener('scroll', onCerrar, true)
    }
  }, [onCerrar])

  // Flechas arriba/abajo recorren las opciones habilitadas.
  const alTeclear = (e: KeyboardEvent<HTMLDivElement>) => {
    if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp') return
    e.preventDefault()
    const botones = [...e.currentTarget.querySelectorAll<HTMLButtonElement>('button:not(:disabled)')]
    if (!botones.length) return
    const en = botones.indexOf(document.activeElement as HTMLButtonElement)
    const siguiente = e.key === 'ArrowDown' ? en + 1 : en - 1
    botones[(siguiente + botones.length) % botones.length].focus()
  }

  return createPortal(
    <div
      ref={ref}
      role="menu"
      onKeyDown={alTeclear}
      onContextMenu={(e) => e.preventDefault()}
      style={{ left: x, top: y }}
      className="fixed z-[70] min-w-48 rounded-panel border border-line bg-white p-1 shadow-panel"
    >
      {opciones.map((o) => (
        <button
          key={o.etiqueta}
          type="button"
          role="menuitem"
          disabled={o.desactivada}
          onClick={() => {
            onCerrar()
            o.onElegir()
          }}
          className={cn(
            'flex w-full cursor-pointer items-center gap-2 rounded-lg px-2.5 py-1.5 text-left text-[13px] text-ink outline-none',
            'hover:bg-surface-alt focus-visible:bg-surface-alt disabled:cursor-not-allowed disabled:opacity-45',
          )}
        >
          {o.icono && <o.icono size={15} className="shrink-0 text-ink-soft" />}
          <span className="flex-1">{o.etiqueta}</span>
          {o.nota && <span className="text-[11px] text-ink-soft">{o.nota}</span>}
        </button>
      ))}
    </div>,
    document.getElementById('modal-root') ?? document.body,
  )
}
