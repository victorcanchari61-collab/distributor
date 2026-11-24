import { useEffect, useRef } from 'react'
import type { KeyboardEvent, MouseEvent, WheelEvent } from 'react'
import type { LucideIcon } from 'lucide-react'
import { X } from 'lucide-react'
import { cn } from '../ui'
import { MenuContextual } from './MenuContextual'
import type { OpcionMenu } from './MenuContextual'
import { useMenuContextual } from './useMenuContextual'
import { idPanel, idPestana } from './estadoPestanas'

/** Lo que la barra necesita para dibujar una pestaña. */
export interface PestanaTrabajo {
  /** La clave de la vista que muestra (única entre las abiertas). */
  clave: string
  etiqueta: string
  /** Ayuda al pasar el mouse: "Inventario › Plano del almacén". */
  titulo?: string
  icono: LucideIcon
  /** Color del módulo: un `data-sys` de styles/systems.css. */
  sys: string
  cerrable: boolean
}

// Estilo navegador: la pestaña activa tiene el gris del contenido y dos esquinas curvas abajo (los "hombros") que la
// funden con la página. Cada hombro es un cuarto de círculo pintado con un radial-gradient.
const ACTIVA = [
  'z-10 bg-surface-alt font-semibold [--fondo-pestana:var(--color-surface-alt)]',
  "before:absolute before:bottom-0 before:-left-3 before:size-3 before:content-['']",
  'before:[background:radial-gradient(circle_at_0_0,transparent_12px,var(--fondo-pestana)_12.5px)]',
  "after:absolute after:bottom-0 after:-right-3 after:size-3 after:content-['']",
  'after:[background:radial-gradient(circle_at_100%_0,transparent_12px,var(--fondo-pestana)_12.5px)]',
].join(' ')

// Separador fino entre pestañas; se oculta junto a la activa y al pasar el mouse.
const INACTIVA = [
  'font-medium hover:bg-white/60',
  "after:absolute after:top-2.5 after:right-0 after:h-4 after:w-px after:bg-line-strong after:content-['']",
  "hover:after:opacity-0 has-[+[aria-selected='true']]:after:opacity-0",
].join(' ')

/**
 * Una pestaña. Lleva su propio data-sys: el ícono, las letras y la barra de arriba toman el color de SU módulo, no
 * el del que esté abierto.
 */
function Pestana({
  pestana,
  activa,
  onElegir,
  onCerrar,
  onMenu,
  onTeclear,
}: {
  pestana: PestanaTrabajo
  activa: boolean
  onElegir: () => void
  onCerrar: () => void
  onMenu: (e: MouseEvent) => void
  onTeclear: (e: KeyboardEvent<HTMLDivElement>) => void
}) {
  return (
    <div
      data-sys={pestana.sys}
      role="tab"
      id={idPestana(pestana.clave)}
      aria-selected={activa}
      aria-controls={idPanel(pestana.clave)}
      tabIndex={activa ? 0 : -1}
      title={pestana.titulo ?? pestana.etiqueta}
      onClick={onElegir}
      onKeyDown={onTeclear}
      onContextMenu={onMenu}
      // Sin esto un clic dejaba el foco (y su borde) en la pestaña; el teclado sigue pudiendo enfocarla.
      onMouseDown={(e) => e.preventDefault()}
      // Clic central: cerrar, como en el navegador.
      onAuxClick={(e) => {
        if (e.button === 1 && pestana.cerrable) onCerrar()
      }}
      className={cn(
        'group relative flex h-8 max-w-[13rem] min-w-[7rem] shrink-0 cursor-pointer items-center gap-2 rounded-t-xl pr-1.5 pl-3',
        'text-[13px] text-[rgb(var(--sys-ink-rgb))] outline-none select-none',
        'focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-[rgb(var(--sys-rgb))]',
        activa ? ACTIVA : INACTIVA,
      )}
    >
      {/* barra de color del módulo, arriba de la activa */}
      {activa && <span aria-hidden="true" className="absolute inset-x-3 top-0 h-0.5 rounded-full bg-[rgb(var(--sys-rgb))]" />}

      <pestana.icono size={15} className="shrink-0 text-[rgb(var(--sys-rgb))]" />
      <span className="flex-1 truncate">{pestana.etiqueta}</span>

      {pestana.cerrable && (
        <button
          type="button"
          tabIndex={-1}
          aria-label={`Cerrar ${pestana.etiqueta}`}
          onClick={(e) => {
            e.stopPropagation()
            onCerrar()
          }}
          className={cn(
            'inline-flex size-5 shrink-0 cursor-pointer items-center justify-center rounded-full text-ink-soft',
            'hover:bg-black/10 hover:text-ink',
            // en pantallas táctiles no hay "hover": siempre visible
            activa ? 'opacity-100' : 'opacity-0 group-hover:opacity-100 [@media(hover:none)]:opacity-100',
          )}
        >
          <X size={12} aria-hidden />
        </button>
      )}
    </div>
  )
}

/**
 * La barra de pestañas de trabajo, estilo navegador. Solo dibuja y avisa: no sabe de rutas ni de qué muestra cada
 * pestaña.
 *
 * Teclado: flechas e Inicio/Fin cambian de pestaña, Supr la cierra. Clic derecho: cerrar esta, las demás o las de la
 * derecha. La rueda del mouse la desliza cuando no entran todas.
 */
export function BarraPestanas({
  pestanas,
  activa,
  onElegir,
  onCerrar,
  opcionesDe,
}: {
  pestanas: PestanaTrabajo[]
  activa: string
  onElegir: (clave: string) => void
  onCerrar: (clave: string) => void
  /** Opciones del clic derecho sobre una pestaña. */
  opcionesDe: (clave: string) => OpcionMenu[]
}) {
  const lista = useRef<HTMLDivElement>(null)
  const menu = useMenuContextual<string>()

  // Con muchas pestañas la activa puede quedar fuera de la vista.
  useEffect(() => {
    lista.current?.querySelector('[aria-selected="true"]')?.scrollIntoView({ block: 'nearest', inline: 'nearest' })
  }, [activa, pestanas.length])

  const alRodar = (e: WheelEvent<HTMLDivElement>) => {
    if (e.deltaY !== 0 && e.deltaX === 0) e.currentTarget.scrollLeft += e.deltaY
  }

  const mover = (a: number) => {
    const siguiente = pestanas[(a + pestanas.length) % pestanas.length]
    onElegir(siguiente.clave)
    requestAnimationFrame(() => document.getElementById(idPestana(siguiente.clave))?.focus())
  }

  const alTeclear = (i: number) => (e: KeyboardEvent<HTMLDivElement>) => {
    switch (e.key) {
      case 'ArrowRight':
        e.preventDefault()
        return mover(i + 1)
      case 'ArrowLeft':
        e.preventDefault()
        return mover(i - 1)
      case 'Home':
        e.preventDefault()
        return mover(0)
      case 'End':
        e.preventDefault()
        return mover(pestanas.length - 1)
      case 'Delete':
        if (pestanas[i].cerrable) onCerrar(pestanas[i].clave)
    }
  }

  return (
    <>
      <div
        ref={lista}
        role="tablist"
        aria-label="Pestañas abiertas"
        onWheel={alRodar}
        // px-3: deja sitio a los hombros curvos de la primera y la última pestaña
        className="flex min-w-0 items-end overflow-x-auto px-3 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
      >
        {pestanas.map((p, i) => (
          <Pestana
            key={p.clave}
            pestana={p}
            activa={p.clave === activa}
            onElegir={() => onElegir(p.clave)}
            onCerrar={() => onCerrar(p.clave)}
            onMenu={(e) => menu.abrir(e, p.clave)}
            onTeclear={alTeclear(i)}
          />
        ))}
      </div>

      {menu.estado && (
        <MenuContextual x={menu.estado.x} y={menu.estado.y} opciones={opcionesDe(menu.estado.dato)} onCerrar={menu.cerrar} />
      )}
    </>
  )
}
