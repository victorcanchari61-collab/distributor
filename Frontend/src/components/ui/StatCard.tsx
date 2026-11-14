import type { ReactNode } from 'react'
import { TrendingDown, TrendingUp } from 'lucide-react'
import { cn } from './cn'

/**
 * Tarjeta de indicador.
 *
 * El icono es obligatorio a proposito: en una fila de tres o cuatro tarjetas
 * el ojo se guia por la forma antes que por el texto, y una sin icono rompe el
 * ritmo de la fila.
 */

export type StatTono = 'sys' | 'neutral' | 'success' | 'warning' | 'danger'

const TONOS: Record<StatTono, { chip: string; barra: string }> = {
  sys: {
    chip: 'bg-[rgb(var(--sys-rgb)/0.12)] text-[rgb(var(--sys-ink-rgb))]',
    barra: 'bg-[rgb(var(--sys-rgb))]',
  },
  neutral: { chip: 'bg-slate-100 text-slate-600', barra: 'bg-slate-300' },
  success: { chip: 'bg-emerald-50 text-emerald-600', barra: 'bg-emerald-500' },
  warning: { chip: 'bg-amber-50 text-amber-600', barra: 'bg-amber-500' },
  danger: { chip: 'bg-red-50 text-red-600', barra: 'bg-red-500' },
}

export interface StatCardProps {
  label: string
  value: string
  /** Obligatorio: toda tarjeta lleva icono. */
  icon: ReactNode
  tono?: StatTono
  /** Variacion respecto al periodo anterior, ej. 12.4 o -3.1. */
  trend?: number
  /** Aclaracion corta bajo el numero. */
  hint?: string
  /**
   * Que parte del total es este numero, de 0 a 1: se dibuja una barra y el porcentaje al lado del numero. "29" solo
   * no dice si es mucho o poco; "29 · 100%" si.
   */
  progreso?: number
  /**
   * El enlace al pie de la tarjeta: lo normal es que aplique su filtro en la tabla de abajo ("Ver los 29"), para
   * que la tarjeta lleve a lo que cuenta en vez de solo mostrarlo.
   */
  accion?: { label: string; onClick: () => void }
  className?: string
}

export function StatCard({
  label,
  value,
  icon,
  tono = 'sys',
  trend,
  hint,
  progreso,
  accion,
  className,
}: StatCardProps) {
  const estilo = TONOS[tono]
  const sube = (trend ?? 0) >= 0
  const pct = progreso === undefined ? undefined : Math.round(Math.min(1, Math.max(0, progreso)) * 100)
  // Con accion, la aclaracion baja al pie junto a ella: asi la tarjeta no suma una linea mas de alto.
  const hintArriba = accion ? undefined : hint

  return (
    <div
      className={cn(
        'group relative flex flex-col overflow-hidden rounded-panel border border-line bg-white',
        'transition-shadow duration-200 hover:shadow-md',
        // En la fila desplazable de movil cada tarjeta conserva un ancho
        // legible; en la grilla de escritorio se reparte el espacio.
        'w-[62%] shrink-0 snap-start sm:w-auto sm:shrink',
        className,
      )}
    >
      {/* Franja de color: da identidad sin llenar la tarjeta de fondo */}
      <span
        aria-hidden="true"
        className={cn('absolute inset-y-0 left-0 w-1', estilo.barra)}
      />

      <div className="flex flex-1 items-center gap-3 px-4 py-3">
      <span
        className={cn(
          'inline-flex size-9 shrink-0 items-center justify-center rounded-field',
          'transition-transform duration-200 group-hover:scale-105',
          estilo.chip,
        )}
      >
        {icon}
      </span>

      <div className="min-w-0 flex-1">
        <p className="truncate text-[13px] font-medium text-ink-muted">{label}</p>

        <div className="mt-0.5 flex items-center gap-2">
          <p className="text-2xl leading-none font-extrabold tracking-tight text-ink tabular-nums">{value}</p>
          {pct !== undefined && (
            <span className={cn('rounded-full px-1.5 py-0.5 text-[11px] leading-none font-semibold', estilo.chip)}>
              {pct}%
            </span>
          )}
        </div>

        {(trend !== undefined || hintArriba) && (
          <div className="mt-1.5 flex flex-wrap items-center gap-x-2 gap-y-0.5 text-xs">
            {trend !== undefined && (
              <span
                className={cn(
                  'inline-flex items-center gap-1 rounded-full px-1.5 py-0.5 font-semibold',
                  sube ? 'bg-emerald-50 text-emerald-700' : 'bg-red-50 text-red-700',
                )}
              >
                {sube ? <TrendingUp size={12} /> : <TrendingDown size={12} />}
                {sube ? '+' : ''}
                {trend}%
              </span>
            )}
            {hintArriba && <span className="truncate text-ink-soft">{hintArriba}</span>}
          </div>
        )}

      </div>
      </div>

      {/* La barra va de borde a borde, fina, sin sumar una fila: dice qué parte del total es el número. */}
      {pct !== undefined && (
          <div
            className="h-1 bg-slate-100"
            role="progressbar"
            aria-valuenow={pct}
            aria-valuemin={0}
            aria-valuemax={100}
            aria-label={`${label}: ${pct}%`}
          >
            <span
              className={cn('block h-full transition-[width] duration-500', estilo.barra)}
              style={{ width: `${pct}%` }}
            />
          </div>
      )}

      {accion && (
        <div
          className={cn(
            'flex items-center justify-between gap-2 px-4 py-1.5 text-xs',
            pct === undefined && 'border-t border-line',
          )}
        >
          <span className="min-w-0 truncate text-ink-soft">{hint}</span>
          <button
            type="button"
            onClick={accion.onClick}
            className="shrink-0 cursor-pointer font-semibold whitespace-nowrap text-[rgb(var(--sys-ink-rgb))] hover:underline"
          >
            {accion.label} →
          </button>
        </div>
      )}
    </div>
  )
}
