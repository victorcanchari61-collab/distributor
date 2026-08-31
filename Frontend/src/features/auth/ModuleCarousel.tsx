import { useCallback, useEffect, useRef, useState } from 'react'
import type { CSSProperties } from 'react'
import { cn } from '../../components/ui'
import { MODULES } from './modules'

const INTERVAL = 6000

export function ModuleCarousel() {
  const [index, setIndex] = useState(0)
  const [paused, setPaused] = useState(false)
  const timer = useRef<number | null>(null)

  const go = useCallback((next: number) => {
    setIndex(((next % MODULES.length) + MODULES.length) % MODULES.length)
  }, [])

  useEffect(() => {
    if (paused) return
    timer.current = window.setTimeout(() => go(index + 1), INTERVAL)
    return () => {
      if (timer.current) window.clearTimeout(timer.current)
    }
  }, [index, paused, go])

  const active = MODULES[index]

  return (
    <section
      aria-roledescription="carrusel"
      aria-label="Módulos de la suite"
      onMouseEnter={() => setPaused(true)}
      onMouseLeave={() => setPaused(false)}
      onFocusCapture={() => setPaused(true)}
      onBlurCapture={() => setPaused(false)}
      className="flex w-full max-w-2xl flex-col gap-6"
    >
      {/* Pestanas de módulos */}
      <div role="tablist" className="grid grid-cols-3 gap-2 sm:grid-cols-5">
        {MODULES.map((m, i) => (
          <button
            key={m.key}
            type="button"
            role="tab"
            aria-selected={i === index}
            onClick={() => go(i)}
            style={{ '--accent': m.accent } as CSSProperties}
            className={cn(
              'inline-flex h-10 w-full min-w-0 cursor-pointer items-center justify-center gap-1.5 rounded-full border px-2 text-xs font-semibold xl:gap-2 xl:text-sm',
              'transition-all duration-200 focus-visible:ring-4 focus-visible:ring-brand-ring focus-visible:outline-none',
              i === index
                ? 'border-(--accent) bg-white text-(--accent) shadow-sm'
                : 'border-line bg-white/60 text-ink-muted hover:border-line-strong hover:text-ink',
            )}
          >
            <span className="shrink-0 text-(--accent)" aria-hidden="true">
              <ModuleIcon module={m.key} />
            </span>
            <span className="truncate">{m.label}</span>
          </button>
        ))}
      </div>

      {/* Contenido del módulo activo */}
      <div key={active.key} className="ui-fade-up flex flex-col gap-4">
        <h2 className="text-2xl leading-tight font-bold tracking-tight text-ink sm:text-3xl lg:text-4xl">
          {active.title}
        </h2>
        <p className="max-w-lg text-base text-ink-muted sm:text-lg">{active.description}</p>

        <div
          style={{ '--accent': active.accent } as CSSProperties}
          className="ui-surface mt-2 overflow-hidden bg-white/80 shadow-panel backdrop-blur-sm"
        >
          <ul className="divide-y divide-line">
            {active.rows.map((row) => (
              <li key={row.title} className="flex items-center gap-3 px-4 py-3 sm:px-5">
                <span
                  aria-hidden="true"
                  className="inline-flex size-9 shrink-0 items-center justify-center rounded-full bg-surface-alt text-(--accent)"
                >
                  <ModuleIcon module={active.key} />
                </span>
                <span className="flex min-w-0 flex-1 flex-col">
                  <strong className="truncate text-sm font-semibold text-ink">{row.title}</strong>
                  <small className="truncate text-xs text-ink-muted">{row.subtitle}</small>
                </span>
                <span className="shrink-0 text-xs font-semibold text-(--accent)">{row.status}</span>
              </li>
            ))}
          </ul>
          <p className="flex items-center gap-2 border-t border-line bg-surface-alt/70 px-4 py-3 text-xs font-medium text-ink-muted sm:px-5">
            <span className="inline-block size-2 rounded-full bg-(--accent)" aria-hidden="true" />
            {active.footer}
          </p>
        </div>
      </div>

      {/* Indicadores */}
      <div className="flex items-center gap-2">
        {MODULES.map((m, i) => (
          <button
            key={m.key}
            type="button"
            aria-label={`Ir al módulo ${m.label}`}
            aria-current={i === index}
            onClick={() => go(i)}
            style={{ '--accent': m.accent } as CSSProperties}
            className={cn(
              'h-1.5 cursor-pointer rounded-full transition-all duration-300',
              'focus-visible:ring-4 focus-visible:ring-brand-ring focus-visible:outline-none',
              i === index ? 'w-10 bg-(--accent)' : 'w-5 bg-line-strong hover:bg-ink-soft',
            )}
          />
        ))}
      </div>

      <p className="max-w-lg text-sm leading-relaxed text-ink-soft">
        Cinco módulos, una sola base de datos. El pedido se factura, inventario descuenta el stock,
        transporte lo lleva, DMS confirma qué pasó en el cliente y RR. HH. mantiene al equipo detrás
        de todo.
      </p>
    </section>
  )
}

function ModuleIcon({ module }: { module: string }) {
  const common = {
    width: 16,
    height: 16,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 1.8,
  }
  switch (module) {
    case 'INV':
      return (
        <svg {...common}>
          <path d="M3 7.5 12 3l9 4.5v9L12 21l-9-4.5z" />
          <path d="m3 7.5 9 4.5 9-4.5M12 12v9" />
        </svg>
      )
    case 'TMS':
      return (
        <svg {...common}>
          <path d="M2 7h11v9H2zM13 10h4l3 3v3h-7z" />
          <circle cx="6.5" cy="18" r="1.8" />
          <circle cx="16.5" cy="18" r="1.8" />
        </svg>
      )
    case 'DMS':
      return (
        <svg {...common}>
          <path d="M4 9V20h16V9" />
          <path d="M3 9 4.8 4h14.4L21 9a3 3 0 0 1-6 0 3 3 0 0 1-6 0 3 3 0 0 1-6 0Z" />
          <path d="M10 20v-5h4v5" />
        </svg>
      )
    case 'RRHH':
      return (
        <svg {...common}>
          <rect x="3" y="7" width="18" height="13" rx="2" />
          <path d="M9 7V5h6v2M3 12h18" />
        </svg>
      )
    default:
      // Facturación
      return (
        <svg {...common}>
          <path d="M6 3h12v18l-3-1.6-3 1.6-3-1.6L6 21z" />
          <path d="M9.5 8h5M9.5 12h5" />
        </svg>
      )
  }
}
