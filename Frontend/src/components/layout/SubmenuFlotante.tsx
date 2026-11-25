import { useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { ChevronRight } from 'lucide-react'
import { cn } from '../ui'
import { useAccesosAlPasar } from './accesosAlPasar'
import type { NavGroup } from './navigation'

const ANCHO = 224 // w-56

/**
 * Las vistas de un grupo en un panel flotante: al lado del sider contraído, o encima de su botón en la barra inferior.
 *
 * Se pinta en un portal con position:fixed anclado al botón, porque dentro del sider (72px) o de la barra quedaría
 * recortado. Entra con una animación corta desde el propio botón.
 *
 * Al pasar el mouse por una vista que tiene botones en su cabecera (Nueva boleta, Nuevo pedido…), al lado sale otro
 * panel con ellos: elegir uno pulsa ese botón y su modal sale encima de la vista actual (ver accesosRapidos.ts).
 */
export function SubmenuFlotante({
  group,
  ancla,
  active,
  onSelect,
  onCerrar,
  colocacion = 'derecha',
  lado = 'izquierda',
}: {
  group: NavGroup
  ancla: HTMLElement
  active: string
  onSelect: (id: string) => void
  onCerrar: () => void
  /** A la derecha del sider (por defecto) o encima del botón, para la barra inferior. */
  colocacion?: 'derecha' | 'arriba'
  /** De qué lado está el sider: el panel sale hacia el lado opuesto. */
  lado?: 'izquierda' | 'derecha'
}) {
  const ref = useRef<HTMLDivElement>(null)
  const [visible, setVisible] = useState(false)
  const [pos, setPos] = useState<{ top?: number; bottom?: number; left: number } | null>(null)
  const arriba = colocacion === 'arriba'
  const siderDerecha = lado === 'derecha'
  const accesos = useAccesosAlPasar({ onAbrirVista: onSelect, onElegido: onCerrar })
  const refAccesos = accesos.refPanel

  useEffect(() => {
    const colocar = () => {
      const r = ancla.getBoundingClientRect()

      if (arriba) {
        // Centrado sobre el botón, sin salirse de la pantalla.
        const centro = r.left + r.width / 2 - ANCHO / 2
        setPos({
          bottom: window.innerHeight - r.top + 8,
          left: Math.min(Math.max(8, centro), window.innerWidth - ANCHO - 8),
        })
        return
      }

      const alto = 52 + group.items.length * 34
      // Se ancla al borde del sider, no al del icono: si no, el panel se monta
      // sobre la propia barra porque el boton esta centrado dentro de ella.
      const barra = ancla.closest('aside')?.getBoundingClientRect()
      const borde = siderDerecha ? (barra?.left ?? r.left) : (barra?.right ?? r.right)
      setPos({
        // Si el grupo esta al final del sider, el panel sube para no cortarse.
        top: Math.min(r.top, Math.max(8, window.innerHeight - alto - 8)),
        // Con el sider a la derecha el panel sale hacia la izquierda, y al reves.
        left: siderDerecha ? Math.max(8, borde - 8 - ANCHO) : borde + 8,
      })
    }

    colocar()
    const id = requestAnimationFrame(() => setVisible(true))

    const fuera = (e: MouseEvent) => {
      const t = e.target as Node
      if (!ref.current?.contains(t) && !refAccesos.current?.contains(t) && !ancla.contains(t)) onCerrar()
    }
    const escape = (e: KeyboardEvent) => e.key === 'Escape' && onCerrar()

    document.addEventListener('mousedown', fuera)
    document.addEventListener('keydown', escape)
    window.addEventListener('resize', colocar)
    window.addEventListener('scroll', colocar, true)

    return () => {
      cancelAnimationFrame(id)
      document.removeEventListener('mousedown', fuera)
      document.removeEventListener('keydown', escape)
      window.removeEventListener('resize', colocar)
      window.removeEventListener('scroll', colocar, true)
    }
  }, [ancla, arriba, group.items.length, onCerrar, refAccesos, siderDerecha])

  if (!pos) return null

  return createPortal(
    <>
      <div
        ref={ref}
        data-sys={group.sys}
        style={{ top: pos.top, bottom: pos.bottom, left: pos.left }}
        onMouseLeave={accesos.salir}
        className={cn(
          'fixed z-50 w-56 rounded-panel border border-line bg-white p-1.5 shadow-panel',
          arriba ? 'max-h-[70vh] origin-bottom overflow-y-auto' : siderDerecha ? 'origin-right' : 'origin-left',
          'transition-all duration-150',
          visible
            ? 'translate-x-0 translate-y-0 scale-100 opacity-100'
            : arriba
              ? 'translate-y-2 scale-95 opacity-0'
              : siderDerecha
                ? 'translate-x-2 scale-95 opacity-0'
                : '-translate-x-2 scale-95 opacity-0',
        )}
      >
        <p className="px-2.5 pt-1 pb-2 text-[11px] font-semibold tracking-wider text-[rgb(var(--sys-ink-rgb))] uppercase">
          {group.label}
        </p>

        {group.items
          .filter((item) => !item.hidden)
          .map((item) => {
            const tieneAccesos = accesos.tieneAccesos(item.id)
            const mostrando = accesos.mostrando(item.id)
            return (
              <button
                key={item.id}
                type="button"
                onClick={() => onSelect(item.id)}
                onMouseEnter={(e) => {
                  const submenu = ref.current?.getBoundingClientRect()
                  if (submenu) accesos.entrar(item, group.sys, e.currentTarget.getBoundingClientRect(), submenu)
                }}
                className={cn(
                  // Todas llevan el borde (transparente) para que el texto no salte al marcarse la activa. La activa: borde
                  // fino del color del módulo alrededor y uno grueso a la izquierda, con las esquinas redondeadas.
                  'flex w-full cursor-pointer items-center gap-2.5 rounded-lg border border-l-[3px] px-2.5 py-1.5 text-[13px]',
                  'transition-colors',
                  active === item.id
                    ? 'border-[rgb(var(--sys-rgb)/0.3)] border-l-[rgb(var(--sys-rgb))] bg-[rgb(var(--sys-rgb)/0.12)] font-semibold text-[rgb(var(--sys-ink-rgb))]'
                    : cn('border-transparent text-ink-muted hover:bg-surface-alt hover:text-ink', mostrando && 'bg-surface-alt text-ink'),
                )}
              >
                <item.icon size={15} className={cn('shrink-0', active === item.id && 'text-[rgb(var(--sys-rgb))]')} />
                <span className="flex-1 truncate text-left">{item.label}</span>
                {item.badge && (
                  <span className="rounded-full bg-[rgb(var(--sys-rgb)/0.12)] px-1.5 py-0.5 text-[10px] font-bold text-[rgb(var(--sys-ink-rgb))]">
                    {item.badge}
                  </span>
                )}
                {!item.badge && item.pending && <span aria-hidden="true" className="size-1.5 rounded-full bg-line-strong" />}
                {/* Avisa que al lado hay más: los botones de esa vista. */}
                {tieneAccesos && (
                  <ChevronRight
                    size={14}
                    aria-hidden="true"
                    className={cn('shrink-0 transition-opacity', mostrando ? 'opacity-100' : 'opacity-40')}
                  />
                )}
              </button>
            )
          })}
      </div>

      {accesos.panel}
    </>,
    document.body,
  )
}

