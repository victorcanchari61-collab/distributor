import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import type { CSSProperties, KeyboardEvent, MouseEvent, PointerEvent as EventoPuntero, WheelEvent } from 'react'
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

/** Cuánto hay que mover el mouse con el botón apretado para que deje de ser un clic y pase a ser un arrastre. */
const UMBRAL_ARRASTRE = 5

/** Cómo se corren las vecinas al arrastrar y cómo se acomoda la que se suelta: rápido y sin rebote, como Chrome. */
const DURACION = 160
const CURVA = 'cubic-bezier(0.2, 0, 0, 1)'

const sinMovimiento = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches

// Estilo navegador: la pestaña activa tiene el gris del contenido y dos esquinas curvas abajo (los "hombros") que la
// funden con la página. Cada hombro es un cuarto de círculo pintado con un radial-gradient.
const ACTIVA = [
  'z-10 min-w-16 bg-surface-alt font-semibold [--fondo-pestana:var(--color-surface-alt)]',
  "before:absolute before:bottom-0 before:-left-3 before:size-3 before:content-['']",
  'before:[background:radial-gradient(circle_at_0_0,transparent_12px,var(--fondo-pestana)_12.5px)]',
  "after:absolute after:bottom-0 after:-right-3 after:size-3 after:content-['']",
  'after:[background:radial-gradient(circle_at_100%_0,transparent_12px,var(--fondo-pestana)_12.5px)]',
].join(' ')

// Separador fino entre pestañas; se oculta junto a la activa y al pasar el mouse.
const INACTIVA = [
  'min-w-10 font-medium hover:bg-white/60',
  "after:absolute after:top-2.5 after:right-0 after:h-4 after:w-px after:bg-line-strong after:content-['']",
  "hover:after:opacity-0 has-[+[aria-selected='true']]:after:opacity-0",
].join(' ')

/** Una pestaña que se está arrastrando: dónde estaba cada una al empezar y a qué lugar iría si se suelta ahora. */
interface Arrastre {
  clave: string
  desde: number
  /** Posición y ancho de cada pestaña al empezar, en el orden de entonces. */
  cajas: { left: number; width: number }[]
  /** Cuánto se corrió la arrastrada (ya limitado a la barra). */
  dx: number
  hacia: number
}

/**
 * Una pestaña. Lleva su propio data-sys: el ícono, las letras y la barra de arriba toman el color de SU módulo, no
 * el del que esté abierto.
 *
 * Es un contenedor (@container): con muchas pestañas se encogen todas por igual, como en el navegador, y cuando ya no
 * entra el nombre queda solo el ícono (la activa conserva además la X para cerrarla).
 */
function Pestana({
  pestana,
  activa,
  estilo,
  onElegir,
  onCerrar,
  onMenu,
  onTeclear,
  onApretar,
}: {
  pestana: PestanaTrabajo
  activa: boolean
  estilo?: CSSProperties
  onElegir: () => void
  onCerrar: () => void
  onMenu: (e: MouseEvent) => void
  onTeclear: (e: KeyboardEvent<HTMLDivElement>) => void
  onApretar: (e: EventoPuntero<HTMLDivElement>) => void
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
      style={estilo}
      onClick={onElegir}
      onKeyDown={onTeclear}
      onContextMenu={onMenu}
      onPointerDown={onApretar}
      // Sin esto un clic dejaba el foco (y su borde) en la pestaña; el teclado sigue pudiendo enfocarla.
      onMouseDown={(e) => e.preventDefault()}
      // Clic central: cerrar, como en el navegador.
      onAuxClick={(e) => {
        if (e.button === 1 && pestana.cerrable) onCerrar()
      }}
      className={cn(
        // Todas parten del mismo ancho y se encogen juntas cuando no entran; no crecen más allá de 13rem.
        '@container group relative flex h-8 max-w-[13rem] flex-[0_1_13rem] cursor-pointer items-center rounded-t-xl',
        'text-[13px] text-[rgb(var(--sys-ink-rgb))] outline-none select-none',
        'focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-[rgb(var(--sys-rgb))]',
        activa ? ACTIVA : INACTIVA,
      )}
    >
      {/* barra de color del módulo, arriba de la activa */}
      {activa && <span aria-hidden="true" className="absolute inset-x-3 top-0 h-0.5 rounded-full bg-[rgb(var(--sys-rgb))]" />}

      {/* Al encogerse, como en Chrome: primero se va la X de las inactivas, después el nombre (en la activa antes, para
          que le quede sitio a su X). */}
      <div
        className={cn(
          'flex min-w-0 flex-1 items-center gap-2 pr-1.5 pl-3',
          activa
            ? '@max-[6rem]:justify-center @max-[6rem]:gap-1 @max-[6rem]:px-1'
            : '@max-[3.5rem]:justify-center @max-[3.5rem]:px-1',
        )}
      >
        <pestana.icono size={15} className="shrink-0 text-[rgb(var(--sys-rgb))]" />
        <span className={cn('flex-1 truncate', activa ? '@max-[6rem]:hidden' : '@max-[3.5rem]:hidden')}>{pestana.etiqueta}</span>

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
              activa
                ? 'opacity-100'
                : 'opacity-0 group-hover:opacity-100 @max-[6rem]:hidden [@media(hover:none)]:opacity-100',
            )}
          >
            <X size={12} aria-hidden />
          </button>
        )}
      </div>
    </div>
  )
}

/**
 * La barra de pestañas de trabajo, estilo navegador. Solo dibuja y avisa: no sabe de rutas ni de qué muestra cada
 * pestaña.
 *
 * Mouse: arrastrar una pestaña la cambia de lugar (las vecinas se corren mientras tanto); clic derecho: cerrar esta,
 * las demás o las de la derecha. Teclado: flechas e Inicio/Fin cambian de pestaña, Ctrl+Mayús+flecha la corre de
 * lugar, Supr la cierra. Con muchas pestañas se encogen para entrar todas; si aun así no entran, la rueda desliza.
 */
export function BarraPestanas({
  pestanas,
  activa,
  onElegir,
  onCerrar,
  onMover,
  opcionesDe,
}: {
  pestanas: PestanaTrabajo[]
  activa: string
  onElegir: (clave: string) => void
  onCerrar: (clave: string) => void
  /** Lleva la pestaña a la posición `a` (contando sin ella). */
  onMover: (clave: string, a: number) => void
  /** Opciones del clic derecho sobre una pestaña. */
  opcionesDe: (clave: string) => OpcionMenu[]
}) {
  const lista = useRef<HTMLDivElement>(null)
  const menu = useMenuContextual<string>()
  const [arrastre, setArrastre] = useState<Arrastre | null>(null)

  // Con muchas pestañas la activa puede quedar fuera de la vista.
  useEffect(() => {
    lista.current?.querySelector('[aria-selected="true"]')?.scrollIntoView({ block: 'nearest', inline: 'nearest' })
  }, [activa, pestanas.length])

  /*
   * Animaciones que dependen de cómo quedó el DOM después de un cambio, así que van con la Web Animations API recién
   * pintado el nuevo orden:
   *  - la que se soltó viaja de donde la dejó el mouse a su lugar;
   *  - la que se abrió crece desde cero (solo si hay una pestaña MÁS: cambiar la vista de la activa también monta una
   *    pestaña nueva, y ahí no tiene que crecer nada).
   */
  const soltada = useRef<{ clave: string; left: number } | null>(null)
  const anteriores = useRef<string[] | null>(null)
  useLayoutEffect(() => {
    const claves = pestanas.map((p) => p.clave)
    const antes = anteriores.current
    anteriores.current = claves
    if (sinMovimiento()) {
      soltada.current = null
      return
    }

    const s = soltada.current
    soltada.current = null
    if (s) {
      const el = document.getElementById(idPestana(s.clave))
      const delta = el ? s.left - el.getBoundingClientRect().left : 0
      if (el && Math.abs(delta) > 0.5) {
        el.animate([{ transform: `translateX(${delta}px)` }, { transform: 'none' }], { duration: DURACION, easing: CURVA })
      }
    }

    if (antes && claves.length > antes.length) {
      for (const clave of claves.filter((c) => !antes.includes(c))) {
        // Un solo keyframe en 0: termina en el ancho que le toque (el que le dé la barra, encogida o no).
        document
          .getElementById(idPestana(clave))
          ?.animate([{ offset: 0, maxWidth: '0px', minWidth: '0px', opacity: 0 }], { duration: 180, easing: 'ease-out' })
      }
    }
  }, [pestanas])

  const alRodar = (e: WheelEvent<HTMLDivElement>) => {
    if (e.deltaY !== 0 && e.deltaX === 0) e.currentTarget.scrollLeft += e.deltaY
  }

  /*
   * Arrastrar para ordenar. Mientras se arrastra, el DOM no cambia: la pestaña sigue al mouse con un transform y las
   * que quedan entre su lugar y el nuevo se corren su ancho. Al soltar se reordena de verdad y, sin transiciones en ese
   * cuadro, todo aparece donde ya se veía.
   */
  const alApretar = (i: number) => (e: EventoPuntero<HTMLDivElement>) => {
    if (e.button !== 0 || (e.target as HTMLElement).closest('button')) return
    const clave = pestanas[i].clave
    const x0 = e.clientX
    let actual: Arrastre | null = null

    const alMover = (ev: PointerEvent) => {
      const movido = ev.clientX - x0
      if (!actual) {
        if (Math.abs(movido) < UMBRAL_ARRASTRE || !lista.current) return
        const cajas = [...lista.current.querySelectorAll<HTMLElement>('[role="tab"]')].map((el) => {
          const r = el.getBoundingClientRect()
          return { left: r.left, width: r.width }
        })
        actual = { clave, desde: i, cajas, dx: 0, hacia: i }
      }
      const { cajas } = actual
      const propia = cajas[i]
      const ultima = cajas[cajas.length - 1]
      // No se sale de la barra: de la primera posición a la última.
      const dx = Math.max(cajas[0].left - propia.left, Math.min(ultima.left + ultima.width - propia.left - propia.width, movido))
      // Su lugar nuevo: cuántas de las otras quedan con el centro a su izquierda.
      const centro = propia.left + dx + propia.width / 2
      const hacia = cajas.filter((c, j) => j !== i && c.left + c.width / 2 < centro).length
      actual = { ...actual, dx, hacia }
      setArrastre(actual)
    }

    const alSoltar = () => {
      window.removeEventListener('pointermove', alMover)
      window.removeEventListener('pointerup', alSoltar)
      window.removeEventListener('pointercancel', alSoltar)
      if (!actual) return
      soltada.current = { clave, left: actual.cajas[i].left + actual.dx }
      setArrastre(null)
      if (actual.hacia !== actual.desde) onMover(clave, actual.hacia)
    }

    window.addEventListener('pointermove', alMover)
    window.addEventListener('pointerup', alSoltar)
    window.addEventListener('pointercancel', alSoltar)
  }

  /** Dónde se dibuja cada pestaña mientras se arrastra otra (o ella misma). */
  const estiloDe = (i: number): CSSProperties | undefined => {
    if (!arrastre) return undefined
    if (i === arrastre.desde) return { transform: `translateX(${arrastre.dx}px)`, zIndex: 20 }
    const { desde, hacia } = arrastre
    const ancho = arrastre.cajas[desde].width
    const corrida = desde < hacia && i > desde && i <= hacia ? -ancho : hacia < desde && i >= hacia && i < desde ? ancho : 0
    return { transform: corrida ? `translateX(${corrida}px)` : undefined, transition: `transform ${DURACION}ms ${CURVA}` }
  }

  // Pasa a la pestaña de la posición `a` dando la vuelta en los extremos, y le pone el foco cuando React ya la
  // marcó como activa (por eso el requestAnimationFrame).
  const mover = (a: number) => {
    const siguiente = pestanas[(a + pestanas.length) % pestanas.length]
    onElegir(siguiente.clave)
    requestAnimationFrame(() => document.getElementById(idPestana(siguiente.clave))?.focus())
  }

  // Corre la pestaña de lugar con el teclado y le deja el foco.
  const correr = (i: number, a: number) => {
    if (a < 0 || a >= pestanas.length) return
    const { clave } = pestanas[i]
    onMover(clave, a)
    requestAnimationFrame(() => document.getElementById(idPestana(clave))?.focus())
  }

  const alTeclear = (i: number) => (e: KeyboardEvent<HTMLDivElement>) => {
    const correrla = e.ctrlKey && e.shiftKey
    switch (e.key) {
      case 'ArrowRight':
        e.preventDefault()
        return correrla ? correr(i, i + 1) : mover(i + 1)
      case 'ArrowLeft':
        e.preventDefault()
        return correrla ? correr(i, i - 1) : mover(i - 1)
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
        className={cn(
          'flex min-w-0 items-end overflow-x-auto px-3 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden',
          arrastre && 'cursor-grabbing [&_[role=tab]]:cursor-grabbing',
        )}
      >
        {pestanas.map((p, i) => (
          <Pestana
            key={p.clave}
            pestana={p}
            activa={p.clave === activa}
            estilo={estiloDe(i)}
            onElegir={() => onElegir(p.clave)}
            onCerrar={() => onCerrar(p.clave)}
            onMenu={(e) => menu.abrir(e, p.clave)}
            onTeclear={alTeclear(i)}
            onApretar={alApretar(i)}
          />
        ))}
      </div>

      {menu.estado && (
        <MenuContextual x={menu.estado.x} y={menu.estado.y} opciones={opcionesDe(menu.estado.dato)} onCerrar={menu.cerrar} />
      )}
    </>
  )
}
