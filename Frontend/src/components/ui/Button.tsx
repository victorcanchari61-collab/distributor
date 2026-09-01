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
}

const VARIANTS: Record<Variant, string> = {
  primary:
    'bg-brand text-on-brand shadow-sm hover:not-disabled:bg-brand-hover active:not-disabled:bg-brand-active',
  secondary: 'bg-surface text-ink border border-line hover:not-disabled:bg-surface-alt',
  ghost: 'bg-transparent text-brand hover:not-disabled:bg-brand-soft',
}

// Mismas alturas que los campos, para que un boton junto a un input calce.
const SIZES: Record<Size, string> = {
  sm: 'h-[var(--height-field-sm)] px-3 text-sm',
  md: 'h-[var(--height-field-md)] px-5 text-sm',
  lg: 'h-[var(--height-field-lg)] px-7 text-base',
}

export function Button({
  variant = 'primary',
  size = 'md',
  block = false,
  loading = false,
  iconRight,
  className,
  children,
  disabled,
  type = 'button',
  ...rest
}: ButtonProps) {
  return (
    <button
      type={type}
      disabled={disabled || loading}
      className={cn(
        'inline-flex cursor-pointer items-center justify-center gap-2 rounded-field font-semibold',
        'transition-colors duration-150',
        'focus-visible:ring-4 focus-visible:ring-brand-ring focus-visible:outline-none',
        'disabled:cursor-not-allowed disabled:opacity-60',
        variant === 'ghost' ? 'px-2 py-1 text-sm' : SIZES[size],
        VARIANTS[variant],
        block && 'w-full',
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
