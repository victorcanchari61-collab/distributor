import { useCallback, useEffect, useState } from 'react'
import type { ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { X } from 'lucide-react'
import { cn } from './cn'

/** Cuánto dura la animación de abrir y cerrar. */
const DURACION = 220

interface Abierta {
  src: string
  titulo: string
  /** Centro de la miniatura en pantalla: de ahí crece la imagen y ahí vuelve al cerrar. */
  origen: { x: number; y: number }
}

/**
 * Una foto que se amplía al hacer clic: crece desde la miniatura hasta una ventana centrada sobre un fondo oscuro, y
 * vuelve a ella al cerrar (clic afuera, la X o Escape).
 *
 * `children` es la miniatura tal como se ve en la tabla o la ficha; esto solo la vuelve clicable.
 */
export function VisorImagen({
  src,
  titulo,
  children,
  className,
  zoom = true,
}: {
  src: string
  titulo: string
  children: ReactNode
  className?: string
  /** Agrandar un poco la miniatura al pasar el mouse. Sin sentido cuando lo que se pasa es un botón de texto. */
  zoom?: boolean
}) {
  const [abierta, setAbierta] = useState<Abierta | null>(null)

  return (
    <>
      <button
        type="button"
        title="Ver la foto"
        aria-label={`Ver la foto de ${titulo}`}
        onClick={(e) => {
          // Que el clic no abra además la fila (las tablas con onRowClick).
          e.stopPropagation()
          const r = e.currentTarget.getBoundingClientRect()
          setAbierta({ src, titulo, origen: { x: r.left + r.width / 2, y: r.top + r.height / 2 } })
        }}
        className={cn(
          'group/visor relative block cursor-zoom-in overflow-hidden rounded-field',
          'focus-visible:ring-2 focus-visible:ring-[rgb(var(--sys-rgb))] focus-visible:outline-none',
          className,
        )}
      >
        <span className={cn('block transition-transform duration-200', zoom && 'group-hover/visor:scale-110')}>
          {children}
        </span>
      </button>

      {abierta && <VentanaImagen {...abierta} onCerrar={() => setAbierta(null)} />}
    </>
  )
}

function VentanaImagen({ src, titulo, origen, onCerrar }: Abierta & { onCerrar: () => void }) {
  // Se monta cerrada y en el cuadro siguiente se abre: así la transición tiene desde dónde partir.
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    const id = requestAnimationFrame(() => setVisible(true))
    return () => cancelAnimationFrame(id)
  }, [])

  const cerrar = useCallback(() => {
    setVisible(false)
    window.setTimeout(onCerrar, DURACION)
  }, [onCerrar])

  useEffect(() => {
    const alTeclear = (e: KeyboardEvent) => e.key === 'Escape' && cerrar()
    document.addEventListener('keydown', alTeclear)
    return () => document.removeEventListener('keydown', alTeclear)
  }, [cerrar])

  // Desde dónde crece: la miniatura, medida respecto del centro de la pantalla.
  const dx = origen.x - window.innerWidth / 2
  const dy = origen.y - window.innerHeight / 2

  return createPortal(
    <div
      role="dialog"
      aria-modal="true"
      aria-label={titulo}
      onMouseDown={(e) => e.target === e.currentTarget && cerrar()}
      className={cn(
        'fixed inset-0 z-[60] flex items-center justify-center p-4 sm:p-10',
        'bg-ink/70 backdrop-blur-sm transition-opacity',
        visible ? 'opacity-100' : 'opacity-0',
      )}
      style={{ transitionDuration: `${DURACION}ms` }}
    >
      <figure
        className="relative flex max-h-full max-w-full flex-col overflow-hidden rounded-panel bg-white shadow-2xl transition-[transform,opacity] ease-out"
        style={{
          transitionDuration: `${DURACION}ms`,
          opacity: visible ? 1 : 0,
          transform: visible ? 'none' : `translate(${dx}px, ${dy}px) scale(0.15)`,
        }}
      >
        <div className="flex items-center justify-between gap-3 bg-[rgb(var(--sys-rgb))] px-4 py-2.5">
          <figcaption className="truncate text-sm font-bold text-white">{titulo}</figcaption>
          <button
            type="button"
            onClick={cerrar}
            aria-label="Cerrar"
            className="cursor-pointer rounded-md p-1 text-white/80 transition-colors hover:bg-white/15 hover:text-white"
          >
            <X size={16} />
          </button>
        </div>
        <img
          src={src}
          alt={titulo}
          className="block max-h-[78vh] max-w-[min(90vw,56rem)] bg-slate-50 object-contain"
        />
      </figure>
    </div>,
    document.getElementById('modal-root') ?? document.body,
  )
}
