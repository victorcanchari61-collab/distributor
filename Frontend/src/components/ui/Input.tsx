import { useId, useState } from 'react'
import type { InputHTMLAttributes, ReactNode } from 'react'
import { cn } from './cn'

/**
 * Campo de texto del sistema.
 *
 * Es el UNICO lugar donde se define como se ve y se comporta un input: altura,
 * bordes, foco y transiciones. Cambiar algo aqui lo cambia en todas las
 * pantallas, y las alturas salen de los tokens --height-field-* de theme.css.
 */

/** sm 28px (tablas y barras) · md 32px (formularios) · lg 48px (login). */
export type FieldSize = 'sm' | 'md' | 'lg'

export const FIELD_HEIGHT: Record<FieldSize, string> = {
  sm: 'h-[var(--height-field-sm)]',
  md: 'h-[var(--height-field-md)]',
  lg: 'h-[var(--height-field-lg)]',
}

const FIELD_TEXT: Record<FieldSize, string> = {
  sm: 'text-[13px]',
  md: 'text-sm',
  lg: 'text-base',
}

/**
 * El aspecto de TODO campo del sistema: fondo gris azulado y sin borde visible; al pasar el mouse, un poco más
 * oscuro; al escribir, blanco con el borde del color del módulo. Lo usan Input, Select, Desplegable, los buscadores
 * y las fechas, así cambian todos juntos. `foco` dice si el foco lo recibe un hijo (un div con el input adentro) o
 * el mismo elemento (un select, un input suelto).
 */
export const claseCampo = (error = false, foco: 'hijo' | 'propio' = 'hijo') =>
  cn(
    'border bg-field',
    foco === 'hijo'
      ? '[&:not(:focus-within)]:hover:bg-field-hover focus-within:bg-surface'
      : '[&:not(:focus)]:hover:bg-field-hover focus:bg-surface',
    error
      ? 'border-red-600'
      : foco === 'hijo'
        ? 'border-transparent focus-within:border-[rgb(var(--sys-rgb)/0.5)]'
        : 'border-transparent focus:border-[rgb(var(--sys-rgb)/0.5)]',
  )

/**
 * El aspecto de los BUSCADORES (la barra de búsqueda de una tabla, buscar producto, buscar cliente...): blancos y con
 * el borde del color del módulo siempre a la vista, sin esperar el cursor. Así se distinguen de un campo de dato: un
 * buscador se usa a cada rato y tiene que encontrarse de un vistazo. Con el foco, el borde toma el color entero.
 */
export const claseBuscador = (foco: 'hijo' | 'propio' = 'hijo') =>
  cn(
    'border bg-surface border-[rgb(var(--sys-rgb)/0.55)]',
    foco === 'hijo' ? 'focus-within:border-[rgb(var(--sys-rgb))]' : 'focus:border-[rgb(var(--sys-rgb))]',
  )

export interface InputProps extends Omit<InputHTMLAttributes<HTMLInputElement>, 'size'> {
  /** Es un buscador: blanco y con el borde del color del módulo siempre a la vista (ver claseBuscador). */
  buscador?: boolean
  label?: string
  /** Contenido a la derecha de la etiqueta (por ejemplo un enlace de ayuda). */
  hint?: ReactNode
  error?: string
  icon?: ReactNode
  /** Muestra el boton ver/ocultar cuando type="password". */
  revealable?: boolean
  /** Añade "(opcional)" junto a la etiqueta, en gris y sin negrita. */
  optional?: boolean
  size?: FieldSize
}

export function Input({
  label,
  hint,
  error,
  icon,
  revealable = false,
  optional = false,
  buscador = false,
  size = 'md',
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
        <div className="mb-1.5 flex items-baseline justify-between gap-2">
          {label && (
            <label className="ui-label" htmlFor={inputId}>
              {label}
              {optional && (
                <span className="ml-1.5 font-normal text-ink-soft">(opcional)</span>
              )}
            </label>
          )}
          {hint}
        </div>
      )}

      {/*
        Fondo de campo (ver claseCampo). Sin anillo ni transicion, que llamaban la atencion mas que el propio dato.
        El borde siempre ocupa 1px (transparente si no hay foco), asi que el campo no cambia de tamano.
      */}
      <div
        className={cn(
          'flex items-center gap-2 rounded-field px-3',
          FIELD_HEIGHT[size],
          buscador && !error ? claseBuscador() : claseCampo(Boolean(error)),
        )}
      >
        {icon && <span className="shrink-0 text-[rgb(var(--sys-rgb))]">{icon}</span>}
        <input
          id={inputId}
          type={resolvedType}
          aria-invalid={Boolean(error)}
          className={cn(
            'min-w-0 flex-1 border-none bg-transparent text-ink outline-none placeholder:text-ink-soft',
            FIELD_TEXT[size],
          )}
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

      {error && <p className="mt-1.5 text-xs text-red-600">{error}</p>}
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
