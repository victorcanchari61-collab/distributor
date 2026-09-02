import { useEffect, useRef, useState } from 'react'
import type { ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { Check, ChevronDown } from 'lucide-react'
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
  /** Texto del boton cerrado: "4 presentaciones" o el valor elegido. */
  resumen: string
  items: ItemLista[]
  icono?: ReactNode
  /** Titulo dentro del panel. */
  titulo?: string
  vacio?: string

  /**
   * pastilla: para consultar dentro de una celda de tabla.
   * campo: para elegir dentro de un formulario, con la altura de un Input.
   */
  variante?: 'pastilla' | 'campo'

  /** Item elegido: se marca con un check y se cierra el panel al elegir. */
  seleccionado?: string | number

  deshabilitado?: boolean
  error?: boolean
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
  variante = 'pastilla',
  seleccionado,
  deshabilitado,
  error,
  className,
}: ListaDesplegableProps) {
  const [abierto, setAbierto] = useState(false)
  const [visible, setVisible] = useState(false)
  const [pos, setPos] = useState<{ top: number; left: number; ancho: number } | null>(null)
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
      // De campo, el panel mide lo mismo que el campo: se lee como su
      // continuacion y no como una ventana suelta.
      const ancho = variante === 'campo' ? r.width : 260
      // Alto real del panel: la lista no pasa de max-h-[16rem] y el titulo
      // ocupa 33px. Estimarlo de mas hacia que se abriera hacia arriba sin
      // necesidad, tapando lo que hay encima del campo.
      const alto = Math.min(items.length * 40 + 8, 256) + (titulo ? 33 : 0)

      // Si no cabe debajo, se abre hacia arriba.
      const cabeAbajo = r.bottom + alto < window.innerHeight
      setPos({
        top: cabeAbajo ? r.bottom + 6 : Math.max(8, r.top - alto - 6),
        left: Math.min(Math.max(8, r.left), window.innerWidth - ancho - 8),
        ancho,
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
  }, [abierto, items.length, variante, titulo])

  return (
    <>
      <button
        ref={botonRef}
        type="button"
        disabled={deshabilitado}
        aria-expanded={abierto}
        aria-haspopup="listbox"
        onClick={(e) => {
          e.stopPropagation()
          setAbierto((v) => !v)
        }}
        className={cn(
          'flex items-center transition-colors duration-150 disabled:opacity-50',
          variante === 'campo' &&
            'h-[var(--height-field-md)] w-full justify-between gap-2 rounded-field border bg-surface px-3 text-left text-sm text-ink',
          variante === 'campo' &&
            (error ? 'border-red-600' : abierto ? 'border-ink-soft' : 'border-line'),

          variante === 'pastilla' &&
            'inline-flex max-w-full gap-1.5 rounded-full border px-2.5 py-1 text-[12px]',
          variante === 'pastilla' &&
            (abierto
              ? 'border-[rgb(var(--sys-rgb))] bg-[rgb(var(--sys-rgb)/0.08)] text-[rgb(var(--sys-ink-rgb))]'
              : 'border-line bg-white text-ink-muted hover:border-line-strong'),
          className,
        )}
      >
        <span className="flex min-w-0 items-center gap-1.5">
          {icono}
          <span className="truncate">{resumen}</span>
        </span>
        <ChevronDown
          size={variante === 'campo' ? 16 : 13}
          className={cn(
            'shrink-0 text-ink-soft transition-transform duration-150',
            abierto && 'rotate-180',
          )}
        />
      </button>

      {abierto &&
        pos &&
        createPortal(
          <div
            ref={panelRef}
            style={{ top: pos.top, left: pos.left, width: pos.ancho }}
            className={cn(
              'fixed z-50 max-w-[calc(100vw-2rem)] origin-top overflow-hidden',
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
                      role={item.onClick ? 'option' : undefined}
                      aria-selected={item.id === seleccionado}
                      onClick={() => {
                        item.onClick?.()
                        // Elegir cierra: en un campo, el panel ya cumplio.
                        if (seleccionado !== undefined) setAbierto(false)
                      }}
                      className={cn(
                        'flex items-center justify-between gap-3 px-3 py-2',
                        item.onClick && 'cursor-pointer hover:bg-slate-50',
                        item.id === seleccionado && 'bg-[rgb(var(--sys-rgb)/0.08)]',
                      )}
                    >
                      <span className="flex min-w-0 items-center gap-2">
                        {seleccionado !== undefined && (
                          <Check
                            size={14}
                            className={cn(
                              'shrink-0 text-[rgb(var(--sys-ink-rgb))]',
                              item.id !== seleccionado && 'invisible',
                            )}
                          />
                        )}
                        <span className="min-w-0">
                          <span className="block truncate text-[13px] text-ink">{item.label}</span>
                          {item.nota && (
                            <span className="block text-[11px] text-ink-soft">{item.nota}</span>
                          )}
                        </span>
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
