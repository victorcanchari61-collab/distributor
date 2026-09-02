import type { ReactNode } from 'react'
import { cn } from './cn'

export interface PageHeaderProps {
  title: string
  description?: string
  /** Icono a la izquierda del titulo, con el color del sistema activo. */
  icon?: ReactNode
  /** Botones a la derecha del titulo. */
  actions?: ReactNode
  className?: string
}

/**
 * Cabecera de la vista: va suelta sobre el fondo gris, antes de las tarjetas.
 * No se pone dentro de la tabla ni de un bloque blanco.
 */
export function PageHeader({
  title,
  description,
  icon,
  actions,
  className,
}: PageHeaderProps) {
  return (
    <div className={cn('flex flex-col gap-2', className)}>
      {/*
        Titulo y botones SIEMPRE en la misma fila, tambien en movil: apilados
        gastaban tres alturas antes del primer dato y empujaban la tabla fuera
        de la pantalla. La descripcion baja a su propia linea, que es texto de
        apoyo y puede esperar.
      */}
      <div className="flex flex-wrap items-center justify-between gap-x-3 gap-y-2">
        {/* flex-1 con un minimo: el titulo se lleva el ancho sobrante y nunca
            se recorta a dos letras para dejarle sitio a los botones. */}
        <div className="flex min-w-[7rem] flex-1 items-center gap-3">
          {icon && (
            <span className="inline-flex size-10 shrink-0 items-center justify-center rounded-field bg-[rgb(var(--sys-rgb)/0.1)] text-[rgb(var(--sys-ink-rgb))]">
              {icon}
            </span>
          )}
          <h1 className="truncate text-xl font-bold tracking-tight text-ink sm:text-2xl">
            {title}
          </h1>
        </div>

        {/* Los botones bajan a su propia linea solo si no entran: con uno
            comparten fila con el titulo, con dos largos se acomodan debajo. */}
        {actions && <div className="ml-auto flex shrink-0 items-center gap-2">{actions}</div>}
      </div>

      {description && <p className="text-sm text-ink-muted">{description}</p>}
    </div>
  )
}
