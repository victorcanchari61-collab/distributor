import type { ButtonHTMLAttributes } from 'react'
import type { CSSProperties } from 'react'
import { cn } from './cn'
import { ModuleIcon } from './ModuleIcon'
import type { ModuleIconKey } from './ModuleIcon'

export interface SystemCardProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  icon: ModuleIconKey
  title: string
  subtitle: string
  description: string
  /** Texto de la pastilla inferior izquierda, ej. "59 módulos". */
  badge: string
  /** Colores del degradado. Se pasan como variables CSS. */
  from: string
  to: string
}

export function SystemCard({
  icon,
  title,
  subtitle,
  description,
  badge,
  from,
  to,
  className,
  ...rest
}: SystemCardProps) {
  return (
    <button
      type="button"
      style={{ '--from': from, '--to': to } as CSSProperties}
      className={cn(
        'group relative flex w-full cursor-pointer flex-col gap-3 overflow-hidden rounded-panel p-5 text-left',
        'bg-linear-to-br from-(--from) to-(--to) text-white',
        'shadow-panel transition-transform duration-200 hover:-translate-y-1',
        'focus-visible:ring-4 focus-visible:ring-brand-ring focus-visible:outline-none',
        className,
      )}
      {...rest}
    >
      {/* Brillo decorativo */}
      <span
        aria-hidden="true"
        className="pointer-events-none absolute -top-16 -right-10 size-40 rounded-full bg-white/10 blur-2xl"
      />

      <div className="relative flex items-start gap-3">
        <span className="inline-flex size-11 shrink-0 items-center justify-center rounded-field bg-white/20 ring-1 ring-white/25">
          <ModuleIcon module={icon} size={22} />
        </span>
        <div className="min-w-0">
          <h3 className="text-lg leading-tight font-bold">{title}</h3>
          <p className="truncate text-sm text-white/80">{subtitle}</p>
        </div>
      </div>

      <p className="relative line-clamp-2 text-sm text-white/85">{description}</p>

      <div className="relative mt-1 flex items-center justify-between gap-3">
        <span className="rounded-full bg-white/20 px-3 py-1 text-xs font-semibold">{badge}</span>
        <span className="inline-flex items-center gap-1.5 text-sm font-semibold">
          Entrar
          <svg
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            className="transition-transform duration-200 group-hover:translate-x-1"
          >
            <path d="M5 12h13M13 6.5 18.5 12 13 17.5" />
          </svg>
        </span>
      </div>
    </button>
  )
}
