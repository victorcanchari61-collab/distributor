import { useEffect, useRef, useState } from 'react'
import type { ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { ChevronDown } from 'lucide-react'
import { cn } from './cn'

export interface ItemLista {
  id: string | number
  /** Lo que se lee a la izquierda: el nombre del elemento. */
  label: string
  /** Dato de la derecha, en gris: una equivalencia, un total. */
  detalle?: ReactNode
  /** Etiqueta corta bajo el nombre, para marcar el elemento principal. */
  nota?: string
  onClick?: () => void
}

export interface ListaDesplegableProps {
  /** Texto del boton cerrado: "4 presentaciones". */
  resumen: string
  items: ItemLista[]
  icono?: ReactNode
  /** Titulo dentro del panel. */
  titulo?: string
  vacio?: string
  className?: string
}

/**
 * Lista corta dentro de una celda.
 *
 * Un `select` nativo no sirve aqui: sugiere que se elige algo, y el sistema
 * operativo decide como se ve el menu, asi que rompe con el resto del panel.
 * Esto es un boton que abre una lista con el diseno del sistema.
 *
 * El panel se pinta con position:fixed sobre document.body, igual que el
 * buscador de columna, porque la tabla necesita overflow-hidden para sincronizar
 * su cabecera y recortaria cualquier cosa que sobresalga de la celda.
 */
export function ListaDesplegable({
  resumen,
  items,
  icono,
  titulo,
  vacio = 'Sin elementos',
  className,
}: ListaDesplegableProps) {
  const [abierto, setAbierto] = useState(false)
  const [visible, setVisible] = useState(false)
  const [pos, setPos] = useState<{ top: number; left: number } | null>(null)
  const botonRef = useRef<HTMLButtonElement>(null)
  const panelRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!abierto) {
      setVisible(false)
      return
    }

    const colocar = () => {
      const boton = botonRef.current
      if (!boton) return

      const r = boton.getBoundingClientRect()
      const ancho = 260
      const alto = Math.min(items.length * 40 + 52, 320)

      // Si no cabe debajo, se abre hacia arriba.
      const cabeAbajo = r.bottom + alto < window.innerHeight
      setPos({
        top: cabeAbajo ? r.bottom + 6 : Math.max(8, r.top - alto - 6),
        left: Math.min(Math.max(8, r.left), window.innerWidth - ancho - 8),
      })
    }

    colocar()
    const id = requestAnimationFrame(() => setVisible(true))

    const fuera = (e: MouseEvent) => {
      const t = e.target as Node
      if (!panelRef.current?.contains(t) && !botonRef.current?.contains(t)) {
        setAbierto(false)
      }
    }
    const escape = (e: KeyboardEvent) => e.key === 'Escape' && setAbierto(false)

    window.addEventListener('resize', colocar)
    window.addEventListener('scroll', colocar, true)
    document.addEventListener('mousedown', fuera)
    document.addEventListener('keydown', escape)

    return () => {
      cancelAnimationFrame(id)
      window.removeEventListener('resize', colocar)
      window.removeEventListener('scroll', colocar, true)
      document.removeEventListener('mousedown', fuera)
      document.removeEventListener('keydown', escape)
    }
  }, [abierto, items.length])

  return (
    <>
      <button
        ref={botonRef}
        type="button"
        aria-expanded={abierto}
        onClick={(e) => {
          e.stopPropagation()
          setAbierto((v) => !v)
        }}
        className={cn(
          'inline-flex max-w-full items-center gap-1.5 rounded-full border px-2.5 py-1',
          'text-[12px] transition-colors duration-150',
          abierto
            ? 'border-[rgb(var(--sys-rgb))] bg-[rgb(var(--sys-rgb)/0.08)] text-[rgb(var(--sys-ink-rgb))]'
            : 'border-line bg-white text-ink-muted hover:border-line-strong',
          className,
        )}
      >
        {icono}
        <span className="truncate">{resumen}</span>
        <ChevronDown
          size={13}
          className={cn('shrink-0 transition-transform duration-150', abierto && 'rotate-180')}
        />
      </button>

      {abierto &&
        pos &&
        createPortal(
          <div
            ref={panelRef}
            style={{ top: pos.top, left: pos.left }}
            className={cn(
              'fixed z-50 w-[min(16.25rem,calc(100vw-2rem))] origin-top overflow-hidden',
              'rounded-panel bg-white shadow-xl shadow-zinc-900/20 ring-1 ring-zinc-200',
              'transition-all duration-150',
              visible ? 'translate-y-0 scale-100 opacity-100' : '-translate-y-1 scale-95 opacity-0',
            )}
          >
            {titulo && (
              <p className="border-b border-line px-3 py-2 text-[11px] font-semibold tracking-wide text-ink-soft uppercase">
                {titulo}
              </p>
            )}

            {items.length === 0 ? (
              <p className="px-3 py-4 text-center text-xs text-ink-soft">{vacio}</p>
            ) : (
              <ul className="max-h-[16rem] overflow-y-auto py-1">
                {items.map((item) => (
                  <li key={item.id}>
                    <div
                      role={item.onClick ? 'button' : undefined}
                      onClick={item.onClick}
                      className={cn(
                        'flex items-center justify-between gap-3 px-3 py-2',
                        item.onClick && 'cursor-pointer hover:bg-slate-50',
                      )}
                    >
                      <span className="min-w-0">
                        <span className="block truncate text-[13px] text-ink">{item.label}</span>
                        {item.nota && (
                          <span className="block text-[11px] text-ink-soft">{item.nota}</span>
                        )}
                      </span>
                      {item.detalle && (
                        <span className="shrink-0 text-[12px] font-medium text-ink-muted">
                          {item.detalle}
                        </span>
                      )}
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </div>,
          document.body,
        )}
    </>
  )
}
