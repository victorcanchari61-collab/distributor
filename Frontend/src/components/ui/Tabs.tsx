import type { ReactNode } from 'react'
import { cn } from './cn'

export interface TabItem {
  id: string
  label: string
  icon?: ReactNode
  /** Numero al costado: cuantos registros tiene la pestaña. */
  badge?: number
}

export interface TabsProps {
  items: TabItem[]
  active: string
  onChange: (id: string) => void
  className?: string
}

/**
 * Un nombre que llega TODO EN MAYÚSCULAS desde los datos ("TIENDA 1", "SEGUNDO PISO") se muestra como
 * "Tienda 1": en mayúsculas una fila de pestañas se lee como un grito y cuesta distinguir una de otra. Solo se
 * toca lo que viene entero en mayúsculas; un nombre escrito a mano ("Por rol") queda como está.
 */
function legible(texto: string) {
  const letras = texto.replace(/[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ]/g, '')
  if (letras.length < 2 || letras !== letras.toUpperCase()) return texto
  const bajo = texto.toLocaleLowerCase('es')
  return bajo.charAt(0).toLocaleUpperCase('es') + bajo.slice(1)
}

/**
 * Pestañas de una vista.
 *
 * Se usan cuando varias tablas pequeñas pertenecen al mismo tema y no merecen
 * entrada propia en el menu: categorias, marcas y unidades viven dentro de
 * Productos porque solo se tocan al dar de alta uno.
 *
 * Van juntas dentro de un rectángulo con fondo propio, que las separa de lo que
 * hay arriba y abajo. Cada pestaña es una tarjetita blanca con borde; la activa
 * se rellena con el color del módulo, igual que su contador.
 */
export function Tabs({ items, active, onChange, className }: TabsProps) {
  return (
    // El que se desliza en movil es el envoltorio, no el rectángulo: así la sombra de la activa y el borde redondo
    // no se recortan, y en escritorio el rectángulo mide lo que sus pestañas.
    <div
      className={cn(
        '-mx-4 overflow-x-auto px-4 py-1 sm:mx-0 sm:px-0',
        '[scrollbar-width:none] [&::-webkit-scrollbar]:hidden',
        className,
      )}
    >
      <div role="tablist" className="inline-flex min-w-max gap-1.5 rounded-xl border border-line bg-slate-200/70 p-1.5">
        {items.map((item) => {
          const activa = item.id === active
          const texto = legible(item.label)
          return (
            <button
              key={item.id}
              role="tab"
              type="button"
              aria-selected={activa}
              title={texto !== item.label ? item.label : undefined}
              onClick={() => onChange(item.id)}
              className={cn(
                'flex shrink-0 cursor-pointer items-center gap-2 rounded-lg border px-3 py-1.5 text-sm whitespace-nowrap',
                'transition-colors duration-150',
                activa
                  ? 'border-[rgb(var(--sys-rgb))] bg-[rgb(var(--sys-rgb)/0.12)] font-semibold text-[rgb(var(--sys-ink-rgb))] ring-1 ring-[rgb(var(--sys-rgb))]'
                  : 'border-line bg-white font-medium text-ink-muted hover:border-line-strong hover:text-ink',
              )}
            >
              {item.icon && (
                <span className={cn('flex shrink-0', activa ? 'text-[rgb(var(--sys-rgb))]' : 'text-ink-soft')}>
                  {item.icon}
                </span>
              )}
              {texto}
              {item.badge !== undefined && (
                <span
                  className={cn(
                    'rounded-full px-1.5 py-0.5 text-[11px] leading-none font-semibold',
                    activa ? 'bg-[rgb(var(--sys-rgb))] text-white' : 'bg-slate-100 text-slate-500',
                  )}
                >
                  {item.badge}
                </span>
              )}
            </button>
          )
        })}
      </div>
    </div>
  )
}
