import type { ReactNode } from 'react'
import { TrendingDown, TrendingUp } from 'lucide-react'
import { cn } from './cn'

export interface StatCardProps {
  label: string
  value: string
  /** Variacion respecto al periodo anterior, ej. 12.4 o -3.1. */
  trend?: number
  hint?: string
  icon?: ReactNode
  className?: string
}

/** Tarjeta de indicador. Toma el color del sistema activo (--sys-rgb). */
export function StatCard({ label, value, trend, hint, icon, className }: StatCardProps) {
  const up = (trend ?? 0) >= 0

  return (
    <div
      className={cn(
        'rounded-panel border border-line bg-white p-4 transition-shadow hover:shadow-md',
        className,
      )}
    >
      <div className="flex items-start justify-between gap-3">
        <p className="text-sm font-medium text-ink-muted">{label}</p>
        {icon && (
          <span className="inline-flex size-9 shrink-0 items-center justify-center rounded-field bg-[rgb(var(--sys-rgb)/0.1)] text-[rgb(var(--sys-ink-rgb))]">
            {icon}
          </span>
        )}
      </div>

      <p className="mt-2 text-2xl font-extrabold tracking-tight text-ink tabular-nums">{value}</p>

      <div className="mt-1 flex items-center gap-1.5 text-xs">
        {trend !== undefined && (
          <span
            className={cn(
              'inline-flex items-center gap-1 font-semibold',
              up ? 'text-emerald-600' : 'text-red-600',
            )}
          >
            {up ? <TrendingUp size={13} /> : <TrendingDown size={13} />}
            {up ? '+' : ''}
            {trend}%
          </span>
        )}
        {hint && <span className="truncate text-ink-soft">{hint}</span>}
      </div>
    </div>
  )
}
