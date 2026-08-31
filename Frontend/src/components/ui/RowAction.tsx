import type { ReactNode } from 'react'
import { cn } from './cn'

export interface RowActionProps {
  /** Texto del tooltip y de la etiqueta accesible. */
  label: string
  onClick?: () => void
  tone?: 'default' | 'danger'
  children: ReactNode
  className?: string
}

/** Boton de icono de la columna Acciones. Toma el color del sistema activo. */
export function RowAction({
  label,
  onClick,
  tone = 'default',
  children,
  className,
}: RowActionProps) {
  return (
    <button
      type="button"
      title={label}
      aria-label={label}
      onClick={onClick}
      className={cn(
        'cursor-pointer rounded-md p-1.5 text-zinc-500 transition-colors',
        tone === 'danger'
          ? 'hover:bg-red-50 hover:text-red-600'
          : 'hover:bg-[rgb(var(--sys-rgb)/0.12)] hover:text-[rgb(var(--sys-ink-rgb))]',
        className,
      )}
    >
      {children}
    </button>
  )
}
