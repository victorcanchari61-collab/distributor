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
    <div className={cn('flex flex-wrap items-start justify-between gap-3', className)}>
      <div className="flex min-w-0 items-start gap-3">
        {icon && (
          <span className="inline-flex size-10 shrink-0 items-center justify-center rounded-field bg-[rgb(var(--sys-rgb)/0.1)] text-[rgb(var(--sys-ink-rgb))]">
            {icon}
          </span>
        )}
        <div className="min-w-0">
          <h1 className="text-xl font-bold tracking-tight text-ink sm:text-2xl">{title}</h1>
          {description && <p className="mt-1 text-sm text-ink-muted">{description}</p>}
        </div>
      </div>
      {actions && <div className="flex shrink-0 items-center gap-2">{actions}</div>}
    </div>
  )
}
