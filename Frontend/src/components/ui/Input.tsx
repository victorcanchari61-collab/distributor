import { useId, useState } from 'react'
import type { InputHTMLAttributes, ReactNode } from 'react'
import { cn } from './cn'

export interface InputProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'size'> {
  label?: string
  /** Contenido a la derecha de la etiqueta (por ejemplo un enlace de ayuda). */
  hint?: ReactNode
  error?: string
  icon?: ReactNode
  /** Muestra el botón ver/ocultar cuando type="password". */
  revealable?: boolean
}

export function Input({
  label,
  hint,
  error,
  icon,
  revealable = false,
  type = 'text',
  id,
  className,
  ...rest
}: InputProps) {
  const autoId = useId()
  const inputId = id ?? autoId
  const [visible, setVisible] = useState(false)
  const resolvedType = revealable && type === 'password' && visible ? 'text' : type

  return (
    <div className={cn('w-full', className)}>
      {(label || hint) && (
        <div className="mb-2 flex items-baseline justify-between gap-2">
          {label && (
            <label className="ui-label" htmlFor={inputId}>
              {label}
            </label>
          )}
          {hint}
        </div>
      )}

      <div
        className={cn(
          'flex min-h-control items-center gap-2 rounded-field border bg-surface px-3',
          'transition-colors duration-150',
          'focus-within:border-brand focus-within:ring-4 focus-within:ring-brand-ring',
          error ? 'border-red-600' : 'border-line',
        )}
      >
        {icon && <span className="shrink-0 text-ink-soft">{icon}</span>}
        <input
          id={inputId}
          type={resolvedType}
          aria-invalid={Boolean(error)}
          className="min-w-0 flex-1 border-none bg-transparent text-base text-ink outline-none placeholder:text-ink-soft"
          {...rest}
        />
        {revealable && type === 'password' && (
          <button
            type="button"
            onClick={() => setVisible((v) => !v)}
            aria-label={visible ? 'Ocultar contraseña' : 'Mostrar contraseña'}
            className="cursor-pointer rounded p-1 text-ink-soft transition-colors hover:text-brand"
          >
            {visible ? <EyeOffIcon /> : <EyeIcon />}
          </button>
        )}
      </div>

      {error && <p className="mt-2 text-xs text-red-600">{error}</p>}
    </div>
  )
}

function EyeIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
      <path d="M2 12s3.6-6.5 10-6.5S22 12 22 12s-3.6 6.5-10 6.5S2 12 2 12Z" />
      <circle cx="12" cy="12" r="2.75" />
    </svg>
  )
}

function EyeOffIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
      <path d="M3 3l18 18M10.6 10.7a2.75 2.75 0 0 0 3.8 3.8" />
      <path d="M6.6 6.7C4 8.3 2 12 2 12s3.6 6.5 10 6.5c1.7 0 3.2-.4 4.5-1M19.5 15.4C21.2 13.9 22 12 22 12s-3.6-6.5-10-6.5c-.8 0-1.6.1-2.3.3" />
    </svg>
  )
}
