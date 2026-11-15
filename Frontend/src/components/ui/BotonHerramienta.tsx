import { forwardRef } from 'react'
import type { ButtonHTMLAttributes, ReactNode } from 'react'
import { cn } from './cn'

export interface BotonHerramientaProps extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, 'title'> {
  /** Lo que hace: sale en la burbuja oscura al pasar el mouse y es la etiqueta accesible. */
  etiqueta: string
  /** El panel que abre está abierto: el botón se ve hundido. */
  activo?: boolean
  /** Contador en la esquina (filtros aplicados, columnas ocultas). 0 o nada: no se muestra. */
  contador?: number
  children: ReactNode
}

/**
 * Botón de icono de las herramientas de una tabla (columnas, filtros): una píldora plana del color del módulo con el
 * icono en blanco, sin relieve ni animación, y una burbuja oscura con su nombre encima al pasar el mouse.
 */
export const BotonHerramienta = forwardRef<HTMLButtonElement, BotonHerramientaProps>(function BotonHerramienta(
  { etiqueta, activo = false, contador = 0, className, children, ...resto },
  ref,
) {
  return (
    <span className="group/herr relative inline-flex">
      <button
        ref={ref}
        type="button"
        aria-label={etiqueta}
        aria-expanded={activo}
        {...resto}
        className={cn(
          'relative inline-flex h-6 w-9 cursor-pointer items-center justify-center rounded-full text-white [&_svg]:size-3.5',
          // Con su panel abierto, el tono oscuro del módulo.
          activo ? 'bg-[rgb(var(--sys-dark-rgb))]' : 'bg-[rgb(var(--sys-rgb))] hover:bg-[rgb(var(--sys-dark-rgb))]',
          'focus-visible:ring-2 focus-visible:ring-slate-400 focus-visible:ring-offset-1 focus-visible:outline-none',
          className,
        )}
      >
        {children}
        {contador > 0 && (
          <span className="absolute -top-1.5 -right-1.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-white px-1 text-[10px] leading-none font-bold text-[rgb(var(--sys-ink-rgb))] shadow-sm ring-1 ring-[rgb(var(--sys-rgb)/0.35)]">
            {contador}
          </span>
        )}
      </button>

      {/* Burbuja con el nombre. Con el panel abierto se esconde: taparía el menú. */}
      <span
        role="presentation"
        className={cn(
          'pointer-events-none absolute bottom-full left-1/2 z-40 mb-2 -translate-x-1/2 rounded-md bg-slate-800 px-2.5 py-1.5',
          'text-[11px] leading-none font-semibold tracking-wide whitespace-nowrap text-white uppercase opacity-0 shadow-lg',
          !activo && 'group-hover/herr:opacity-100 group-focus-within/herr:opacity-100',
          // flecha
          'after:absolute after:top-full after:left-1/2 after:-translate-x-1/2 after:border-[5px] after:border-transparent after:border-t-slate-800',
        )}
      >
        {etiqueta}
      </span>
    </span>
  )
})
