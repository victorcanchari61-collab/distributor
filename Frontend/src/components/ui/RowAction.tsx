import type { ReactNode } from 'react'
import { cn } from './cn'

/**
 * Significado de la accion. Cada uno tiene SU color, igual en todos los
 * modulos: eliminar es rojo en Usuarios, en TMS y en Inventario.
 */
export type RowActionTone = 'edit' | 'danger' | 'success' | 'warning' | 'neutral'

const TONES: Record<RowActionTone, string> = {
  edit: 'text-blue-600 hover:bg-blue-50 hover:text-blue-700',
  danger: 'text-red-600 hover:bg-red-50 hover:text-red-700',
  success: 'text-emerald-600 hover:bg-emerald-50 hover:text-emerald-700',
  warning: 'text-amber-600 hover:bg-amber-50 hover:text-amber-700',
  neutral: 'text-slate-500 hover:bg-slate-100 hover:text-slate-900',
}

export interface RowActionProps {
  /** Texto del tooltip y de la etiqueta accesible. */
  label: string
  onClick?: () => void
  tone?: RowActionTone
  children: ReactNode
  className?: string
}

/**
 * Boton de icono de la columna Acciones.
 *
 * Los colores son FIJOS por significado y no siguen el acento del modulo: asi
 * el usuario reconoce "eliminar" por su rojo en cualquier pantalla del sistema.
 */
export function RowAction({ label, onClick, tone = 'edit', children, className }: RowActionProps) {
  return (
    <button
      type="button"
      title={label}
      aria-label={label}
      onClick={onClick}
      className={cn('cursor-pointer rounded-md p-1.5 transition-colors', TONES[tone], className)}
    >
      {children}
    </button>
  )
}
