import type { ReactNode } from 'react'
import { cn } from './cn'

export interface PageSectionProps {
  title: string
  description?: string
  icon?: ReactNode
  /** Botones a la derecha del titulo. */
  actions?: ReactNode
  children: ReactNode
  className?: string
}

/** Bloque blanco con cabecera, usado por todas las vistas del panel. */
export function PageSection({
  title,
  description,
  icon,
  actions,
  children,
  className,
}: PageSectionProps) {
  return (
    <section className={cn('rounded-panel border border-line bg-white p-4 sm:p-5', className)}>
      <div className="mb-4 flex flex-wrap items-start justify-between gap-3">
        <div className="flex min-w-0 items-start gap-2.5">
          {icon && <span className="mt-0.5 shrink-0 text-[rgb(var(--sys-rgb))]">{icon}</span>}
          <div className="min-w-0">
            <h2 className="text-base font-bold text-ink">{title}</h2>
            {description && <p className="mt-0.5 text-sm text-ink-muted">{description}</p>}
          </div>
        </div>
        {actions && <div className="flex shrink-0 items-center gap-2">{actions}</div>}
      </div>

      {children}
    </section>
  )
}
