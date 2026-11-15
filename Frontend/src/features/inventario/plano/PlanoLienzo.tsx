import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import type { CSSProperties, DragEvent, PointerEvent as PunteroReact } from 'react'
import { RotateCw } from 'lucide-react'
import { cn } from '../../../components/ui'
import type { RectPlano } from '../inventarioApi'
import { estaLibre, MIME_PRODUCTO } from './geometria'

export type TipoFigura = 'LUGAR' | 'PASILLO' | 'ESCALERA'

/** Lo que se dibuja en el plano: un lugar (guarda mercadería), un pasillo o una escalera. */
export interface FiguraPlano extends RectPlano {
  /** "L12" para el lugar 12, "E3" para el pasillo o escalera 3. */
  clave: string
  tipo: TipoFigura
  /** El código del lugar ("01"); los pasillos y escaleras no tienen. */
  codigo?: string
  nombre: string
  /** Cuántos productos tiene puestos (solo lugares). */
  productos?: number
  inactivo?: boolean
}

/** Tamaño mínimo de cada cosa, en celdas: un lugar de 1×1 no se lee. */
const MINIMO: Record<TipoFigura, [number, number]> = { LUGAR: [2, 2], PASILLO: [1, 1], ESCALERA: [2, 2] }

/** Los rellenos con dibujo, en el color del módulo: el pasillo rayado, la escalera con sus peldaños. */
const ESTILO: Record<TipoFigura, CSSProperties> = {
  LUGAR: {},
  PASILLO: {
    backgroundImage:
      'repeating-linear-gradient(45deg,rgb(var(--sys-rgb) / 0.16) 0 7px,rgb(var(--sys-rgb) / 0.05) 7px 14px)',
  },
  ESCALERA: {
    backgroundImage: 'repeating-linear-gradient(0deg,rgb(var(--sys-dark-rgb) / 0.55) 0 2px,#ffffff 2px 8px)',
  },
}

/**
 * Desde dónde se arrastra: el cuerpo mueve; un borde estira hacia ese lado (n arriba, s abajo, o izquierda, e
 * derecha) y la esquina de abajo a la derecha, hacia los dos.
 */
type Asa = 'mover' | 'n' | 's' | 'o' | 'e' | 'se'

/** Los bordes que se pueden tomar para estirar: una franja fina sobre cada lado. */
const BORDES: { asa: Exclude<Asa, 'mover' | 'se'>; clase: string }[] = [
  { asa: 'n', clase: '-top-[3px] left-3 right-3 h-[6px] cursor-ns-resize' },
  { asa: 's', clase: '-bottom-[3px] left-3 right-3 h-[6px] cursor-ns-resize' },
  { asa: 'o', clase: '-left-[3px] top-3 bottom-3 w-[6px] cursor-ew-resize' },
  { asa: 'e', clase: '-right-[3px] top-3 bottom-3 w-[6px] cursor-ew-resize' },
]

interface Props {
  columnas: number
  filas: number
  figuras: FiguraPlano[]
  seleccionada?: string | null
  /** Las que hay que hacer notar: los lugares donde está lo que se buscó. */
  resaltadas?: ReadonlySet<string>
  /** Se pueden mover y estirar arrastrando. Sin esto, el plano solo se mira y se toca para elegir. */
  editable?: boolean
  /** Tocar un lugar lo elige; tocar un pasillo o escalera, o el fondo, no hace nada (para elegir dónde guardar). */
  soloLugares?: boolean
  onSeleccionar?: (clave: string | null) => void
  /** Al soltar lo que se movió o estiró. Quien lo usa guarda (y deshace si el servidor no acepta). */
  onCambiar?: (clave: string, rect: RectPlano) => void
  /** El botón ↻ de lo elegido: girarlo (el ancho pasa a ser el alto). */
  onGirar?: (clave: string) => void
  /** Un producto arrastrado se soltó sobre un lugar. */
  onSoltarProducto?: (clave: string, e: DragEvent) => void
}

/**
 * El plano de un piso: una cuadrícula donde cada lugar, pasillo y escalera es un rectángulo. Se ajusta al ancho y al
 * alto que tiene libre en la pantalla, así el piso entero se ve sin desplazarse.
 */
export function PlanoLienzo({
  columnas,
  filas,
  figuras,
  seleccionada = null,
  resaltadas,
  editable = false,
  soloLugares = false,
  onSeleccionar,
  onCambiar,
  onGirar,
  onSoltarProducto,
}: Props) {
  const caja = useRef<HTMLDivElement>(null)
  const [celda, setCelda] = useState(28)
  // Lo que se está arrastrando, dibujado donde va mientras no se suelta.
  const [vivo, setVivo] = useState<{ clave: string; rect: RectPlano } | null>(null)
  const [sobre, setSobre] = useState<string | null>(null)

  // La celda: lo que entra a lo ancho y, en pantallas bajas, también a lo alto. Se vuelve a medir cuando cambia lo
  // que hay arriba (la lista de lo que se buscó, por ejemplo) para que la página no tenga que bajar.
  useLayoutEffect(() => {
    const el = caja.current
    if (!el) return
    const medir = () => {
      const ancho = el.clientWidth - 6
      // Debajo quedan: el borde del plano (6), el relleno y borde del recuadro (13) y el margen de la página (24).
      const libreAlto = window.innerHeight - (el.getBoundingClientRect().top + window.scrollY) - 46
      const porAncho = ancho / columnas
      const porAlto = libreAlto > 200 ? libreAlto / filas : porAncho
      setCelda(Math.max(14, Math.floor(Math.min(porAncho, porAlto))))
    }
    medir()
    const ro = new ResizeObserver(medir)
    ro.observe(el)
    if (el.parentElement) ro.observe(el.parentElement)
    window.addEventListener('resize', medir)
    return () => {
      ro.disconnect()
      window.removeEventListener('resize', medir)
    }
  }, [columnas, filas])

  // Si cambian las figuras (otro piso, se recargó, se guardó), lo que se arrastraba ya no vale.
  useEffect(() => setVivo(null), [figuras])

  const empezar = (e: PunteroReact, f: FiguraPlano, asa: Asa) => {
    if (e.button > 0) return
    e.stopPropagation()
    if (soloLugares && f.tipo !== 'LUGAR') return
    onSeleccionar?.(f.clave)
    if (!editable) return
    e.preventDefault()

    const x0 = e.clientX
    const y0 = e.clientY
    const inicio: RectPlano = { x: f.x, y: f.y, ancho: f.ancho, alto: f.alto }
    const [minAncho, minAlto] = MINIMO[f.tipo]
    const limitar = (v: number, a: number, b: number) => Math.max(a, Math.min(b, v))
    const derecha = inicio.x + inicio.ancho
    const abajo = inicio.y + inicio.alto
    let actual = inicio

    const calcular = (dx: number, dy: number): RectPlano => {
      switch (asa) {
        case 'mover':
          return { ...inicio, x: limitar(inicio.x + dx, 0, columnas - inicio.ancho), y: limitar(inicio.y + dy, 0, filas - inicio.alto) }
        case 'e':
          return { ...inicio, ancho: limitar(inicio.ancho + dx, minAncho, columnas - inicio.x) }
        case 's':
          return { ...inicio, alto: limitar(inicio.alto + dy, minAlto, filas - inicio.y) }
        case 'se':
          return {
            ...inicio,
            ancho: limitar(inicio.ancho + dx, minAncho, columnas - inicio.x),
            alto: limitar(inicio.alto + dy, minAlto, filas - inicio.y),
          }
        case 'o': {
          // El borde derecho se queda donde está: se mueve el izquierdo.
          const x = limitar(inicio.x + dx, 0, derecha - minAncho)
          return { ...inicio, x, ancho: derecha - x }
        }
        case 'n': {
          const y = limitar(inicio.y + dy, 0, abajo - minAlto)
          return { ...inicio, y, alto: abajo - y }
        }
      }
    }

    const mover = (ev: PointerEvent) => {
      const r = calcular(Math.round((ev.clientX - x0) / celda), Math.round((ev.clientY - y0) / celda))
      const distinto = r.x !== actual.x || r.y !== actual.y || r.ancho !== actual.ancho || r.alto !== actual.alto
      if (distinto && estaLibre(figuras, f.clave, r)) {
        actual = r
        setVivo({ clave: f.clave, rect: r })
      }
    }
    const soltar = () => {
      window.removeEventListener('pointermove', mover)
      window.removeEventListener('pointerup', soltar)
      window.removeEventListener('pointercancel', soltar)
      const cambio = actual.x !== inicio.x || actual.y !== inicio.y || actual.ancho !== inicio.ancho || actual.alto !== inicio.alto
      if (cambio) onCambiar?.(f.clave, actual)
      else setVivo(null)
    }
    window.addEventListener('pointermove', mover)
    window.addEventListener('pointerup', soltar)
    window.addEventListener('pointercancel', soltar)
  }

  const fondo: CSSProperties = {
    width: celda * columnas,
    height: celda * filas,
    backgroundSize: `${celda}px ${celda}px`,
    backgroundImage:
      'linear-gradient(rgb(var(--sys-rgb) / 0.10) 1px,transparent 1px),linear-gradient(90deg,rgb(var(--sys-rgb) / 0.10) 1px,transparent 1px)',
  }

  return (
    <div ref={caja} className="w-full min-w-0 overflow-x-auto">
      <div
        className="relative box-content rounded-lg border-[3px] border-[rgb(var(--sys-dark-rgb))] bg-slate-50"
        style={fondo}
        onPointerDown={() => !soloLugares && onSeleccionar?.(null)}
      >
        {figuras.map((f) => {
          const r = vivo?.clave === f.clave ? vivo.rect : f
          const elegida = seleccionada === f.clave
          const resaltada = resaltadas?.has(f.clave) ?? false
          const esLugar = f.tipo === 'LUGAR'
          const moviendo = vivo?.clave === f.clave
          const encima = sobre === f.clave
          // Angosto y alto (un pasillo vertical): el nombre se escribe de arriba abajo.
          const vertical = r.ancho <= 2 && r.alto >= r.ancho * 2

          /*
           * Un solo color de borde y de fondo, elegido aquí: dos clases del mismo tipo juntas (border-slate-700 y
           * border-amber-500) no se pisan por orden en el className sino por orden en la hoja de estilos.
           */
          const borde = encima
            ? 'border-dashed border-[rgb(var(--sys-rgb))]'
            : elegida
              ? 'border-[rgb(var(--sys-rgb))]'
              : resaltada
                ? 'border-amber-500'
                : f.tipo === 'PASILLO'
                  ? 'border-dashed border-[rgb(var(--sys-rgb)/0.55)]'
                  : 'border-[rgb(var(--sys-dark-rgb)/0.8)]'
          const relleno = !esLugar
            ? ''
            : encima
              ? 'bg-[rgb(var(--sys-rgb)/0.25)]'
              : resaltada
                ? 'bg-amber-100'
                : elegida
                  ? 'bg-[rgb(var(--sys-rgb)/0.22)]'
                  : 'bg-[rgb(var(--sys-rgb)/0.07)]'

          return (
            <div
              key={f.clave}
              role={esLugar ? 'button' : undefined}
              aria-label={esLugar ? `${f.codigo ?? ''} ${f.nombre}` : f.nombre}
              className={cn(
                'group/fig absolute box-border overflow-visible select-none',
                f.tipo === 'PASILLO' ? 'border-2' : 'border-[3px]',
                esLugar && 'rounded-[3px]',
                borde,
                relleno,
                editable ? 'touch-none cursor-grab' : esLugar || !soloLugares ? 'cursor-pointer' : 'cursor-default',
                moviendo && 'z-20 cursor-grabbing opacity-90 shadow-xl',
                f.inactivo && 'opacity-50',
                elegida && 'z-10 ring-[3px] ring-[rgb(var(--sys-rgb)/0.3)]',
              )}
              style={{
                left: r.x * celda,
                top: r.y * celda,
                width: r.ancho * celda,
                height: r.alto * celda,
                ...ESTILO[f.tipo],
              }}
              onPointerDown={(e) => empezar(e, f, 'mover')}
              onDragOver={
                esLugar && onSoltarProducto
                  ? (e) => {
                      if (!e.dataTransfer.types.includes(MIME_PRODUCTO)) return
                      e.preventDefault()
                      e.dataTransfer.dropEffect = 'move'
                      setSobre(f.clave)
                    }
                  : undefined
              }
              onDragLeave={esLugar && onSoltarProducto ? () => setSobre((s) => (s === f.clave ? null : s)) : undefined}
              onDrop={
                esLugar && onSoltarProducto
                  ? (e) => {
                      e.preventDefault()
                      setSobre(null)
                      onSoltarProducto(f.clave, e)
                    }
                  : undefined
              }
            >
              <div
                className={cn('pointer-events-none h-full overflow-hidden p-1 leading-tight', vertical && 'flex justify-center')}
              >
                {esLugar && f.codigo && (
                  <div className="text-[10px] font-bold tracking-wide text-[rgb(var(--sys-ink-rgb))]">{f.codigo}</div>
                )}
                <div
                  className={cn(
                    'truncate text-xs font-semibold',
                    esLugar ? 'text-ink' : f.tipo === 'PASILLO' ? 'text-[rgb(var(--sys-ink-rgb))]' : '',
                    // La escalera lleva su nombre en una etiqueta oscura sobre los peldaños, como un cartel.
                    f.tipo === 'ESCALERA' && 'inline-block max-w-full rounded-sm bg-slate-800 px-1.5 text-white',
                    vertical && 'max-h-full [writing-mode:vertical-rl]',
                  )}
                >
                  {f.nombre}
                </div>
              </div>

              {esLugar && (f.productos ?? 0) > 0 && (
                <span className="pointer-events-none absolute top-1 right-1 inline-flex h-5 min-w-5 items-center justify-center rounded-full bg-[rgb(var(--sys-rgb))] px-1.5 text-[11px] font-bold text-white">
                  {f.productos}
                </span>
              )}

              {/* Estirar: los cuatro bordes se marcan al pasar el mouse; la esquina estira hacia los dos lados. */}
              {editable && !moviendo && (
                <>
                  {BORDES.map((b) => (
                    <div
                      key={b.asa}
                      aria-label="Estirar"
                      className={cn(
                        'absolute z-10 touch-none rounded-full bg-[rgb(var(--sys-rgb))] opacity-0 group-hover/fig:opacity-60 hover:!opacity-100',
                        b.clase,
                      )}
                      onPointerDown={(e) => empezar(e, f, b.asa)}
                    />
                  ))}
                  <div
                    aria-label="Estirar hacia los dos lados"
                    className={cn(
                      // Siempre a la vista: dice que se puede agrandar sin tener que descubrirlo.
                      'absolute right-0 bottom-0 z-10 size-[14px] cursor-nwse-resize touch-none',
                    )}
                    style={{ backgroundImage: 'linear-gradient(135deg,transparent 50%,rgb(var(--sys-rgb)) 50%)' }}
                    onPointerDown={(e) => empezar(e, f, 'se')}
                  />
                </>
              )}

              {/* Girar lo elegido: el ancho pasa a ser el alto. */}
              {editable && elegida && onGirar && !moviendo && (
                <button
                  type="button"
                  aria-label={`Girar ${f.nombre}`}
                  title="Girar"
                  className="absolute top-1 left-1/2 z-30 flex size-7 -translate-x-1/2 cursor-pointer items-center justify-center rounded-full border border-line bg-white text-[rgb(var(--sys-rgb))] shadow hover:bg-surface-alt"
                  onPointerDown={(e) => e.stopPropagation()}
                  onClick={() => onGirar(f.clave)}
                >
                  <RotateCw size={14} />
                </button>
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}
