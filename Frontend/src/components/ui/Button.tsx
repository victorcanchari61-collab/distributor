import type { ButtonHTMLAttributes, ReactNode } from 'react'
import { cn } from './cn'

type Variant = 'primary' | 'secondary' | 'ghost'
type Size = 'sm' | 'md' | 'lg'

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant
  size?: Size
  block?: boolean
  loading?: boolean
  iconRight?: ReactNode
  /**
   * La persona no tiene permiso para esta acción: el botón se ve, apagado en gris y con el aviso al pasar el mouse. Un botón
   * que desaparece no explica nada; uno apagado con su razón, sí.
   */
  sinPermiso?: boolean
}

/** Lo que dice el aviso de un botón apagado por falta de permiso. */
export const AVISO_SIN_PERMISO = 'No tienes permiso para esta acción'

const VARIANTS: Record<Variant, string> = {
  // Color del modulo abierto (--sys-rgb, definido por DashboardLayout): el
  // boton principal de Clientes sale navy, el de Ajustes verde, etc. Fuera de
  // un modulo (login) cae al azul de marca, que es el valor por defecto de
  // --sys-rgb en :root.
  primary:
    'bg-[rgb(var(--sys-rgb))] text-[var(--sys-on)] shadow-sm hover:not-disabled:bg-[rgb(var(--sys-dark-rgb))] active:not-disabled:bg-[rgb(var(--sys-dark-rgb))]',
  secondary: 'bg-surface text-ink border border-line hover:not-disabled:bg-surface-alt',
  ghost: 'bg-transparent text-[rgb(var(--sys-ink-rgb))] hover:not-disabled:bg-[rgb(var(--sys-rgb)/0.08)]',
}

// Alturas propias (--height-button-*): los campos son mas bajos que los botones a proposito.
const SIZES: Record<Size, string> = {
  sm: 'h-[var(--height-button-sm)] px-3 text-sm',
  md: 'h-[var(--height-button-md)] px-5 text-sm',
  lg: 'h-[var(--height-button-lg)] px-7 text-base',
}

export function Button({
  variant = 'primary',
  size = 'md',
  block = false,
  loading = false,
  iconRight,
  sinPermiso = false,
  className,
  children,
  disabled,
  type = 'button',
  ...rest
}: ButtonProps) {
  return (
    <button
      type={type}
      disabled={disabled || loading || sinPermiso}
      title={sinPermiso ? AVISO_SIN_PERMISO : undefined}
      className={cn(
        'inline-flex cursor-pointer items-center justify-center gap-2 rounded-field font-semibold whitespace-nowrap',
        'transition-colors duration-150',
        'focus-visible:ring-4 focus-visible:ring-[rgb(var(--sys-rgb)/0.25)] focus-visible:outline-none',
        'disabled:cursor-not-allowed disabled:opacity-60',
        variant === 'ghost' ? 'px-2 py-1 text-sm' : SIZES[size],
        VARIANTS[variant],
        block && 'w-full',
        sinPermiso && 'border border-slate-200 bg-slate-200! text-slate-400! opacity-100! shadow-none',
        className,
      )}
      {...rest}
    >
      {loading && (
        <span
          aria-hidden="true"
          className="size-4 animate-spin rounded-full border-2 border-current border-r-transparent"
        />
      )}
      {children}
      {!loading && iconRight}
    </button>
  )
}
