import type { ReactNode } from 'react'
import { cn } from './cn'

/**
 * Significado de la accion. Cada uno tiene SU color, igual en todos los
 * modulos: eliminar es rojo en Usuarios, en TMS y en Inventario.
 */
export type RowActionTone = 'view' | 'edit' | 'danger' | 'success' | 'warning' | 'neutral' | 'documento'

const TONES: Record<RowActionTone, string> = {
  /** Ver detalle: azul. */
  view: 'bg-sky-600 [--d:#075985]',
  /** Editar: cian. */
  edit: 'bg-cyan-600 [--d:#155e75]',
  /** Anular / eliminar: rojo. */
  danger: 'bg-rose-600 [--d:#9f1239]',
  /** Confirmar / recibir / activar: verde. */
  success: 'bg-emerald-600 [--d:#065f46]',
  /** Desactivar, devolver y otras acciones intermedias: naranja. */
  warning: 'bg-amber-600 [--d:#92400e]',
  neutral: 'bg-slate-500 [--d:#334155]',
  /** PDF, impresión y otros documentos para descargar: rojo (el rojo clásico del PDF; eliminar usa un rosa más fuerte). */
  documento: 'bg-red-600 [--d:#991b1b]',
}

export interface RowActionProps {
  /** Texto del tooltip y de la etiqueta accesible. */
  label: string
  onClick?: () => void
  tone?: RowActionTone
  disabled?: boolean
  /**
   * Motivo por el que la accion no esta disponible. Se muestra al pasar el
   * mouse: un boton que desaparece no explica nada, uno apagado con su razon
   * si.
   */
  disabledReason?: string
  /** La persona no tiene permiso: la acción se ve apagada en gris, con el aviso al pasar el mouse. */
  sinPermiso?: boolean
  children: ReactNode
  className?: string
}

/**
 * Boton de icono de la columna Acciones: una pildora de color con el icono en blanco, como en el Ecommerce.
 *
 * Los colores son FIJOS por significado y no siguen el acento del modulo: asi
 * el usuario reconoce "eliminar" por su rojo y "editar" por su cian en cualquier pantalla del sistema. Sin permiso o
 * deshabilitada, se apaga en gris.
 */
export function RowAction({
  label,
  onClick,
  tone = 'edit',
  disabled = false,
  disabledReason,
  sinPermiso = false,
  children,
  className,
}: RowActionProps) {
  if (sinPermiso) {
    disabled = true
    disabledReason = 'No tienes permiso para esta acción'
  }
  return (
    <button
      type="button"
      title={disabled ? (disabledReason ?? label) : label}
      aria-label={label}
      disabled={disabled}
      onClick={onClick}
      className={cn(
        'inline-flex items-center justify-center rounded-lg px-2.5 py-[3px] [&_svg]:size-3.5 [&_svg]:stroke-[2.5]',
        disabled
          ? 'cursor-not-allowed bg-slate-200 text-slate-400'
          : cn(
              // El efecto 3D: una base sólida más oscura bajo el botón; al pasar el mouse se levanta y al pulsar se hunde
              // hasta tocar la base.
              'cursor-pointer text-white shadow-[0_3px_0_var(--d)] transition-[transform,translate,box-shadow,filter] duration-[120ms]',
              'hover:-translate-y-px hover:brightness-[1.08] active:translate-y-[2px] active:shadow-[0_1px_0_var(--d)]',
              'focus-visible:ring-2 focus-visible:ring-slate-400 focus-visible:ring-offset-1 focus-visible:outline-none',
              TONES[tone],
            ),
        className,
      )}
    >
      {children}
    </button>
  )
}
