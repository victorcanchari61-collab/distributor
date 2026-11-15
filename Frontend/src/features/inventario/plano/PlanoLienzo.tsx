import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import type { CSSProperties, DragEvent, PointerEvent as PunteroReact } from 'react'
import { cn } from '../../../components/ui'
import type { RectPlano } from '../inventarioApi'
import { MIME_PRODUCTO, estaLibre } from './geometria'

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

const ESTILO: Record<TipoFigura, CSSProperties> = {
  LUGAR: {},
  PASILLO: { backgroundImage: 'repeating-linear-gradient(45deg,#eef2f1 0 6px,#e1e9e6 6px 12px)' },
  ESCALERA: { backgroundImage: 'repeating-linear-gradient(0deg,#94a3b8 0 2px,#ffffff 2px 7px)' },
}

interface Props {
  columnas: number
  filas: number
  figuras: FiguraPlano[]
  seleccionada?: string | null
  /** Las que hay que hacer notar: los lugares donde está lo que se buscó. */
  resaltadas?: ReadonlySet<string>
  /** Se pueden mover y agrandar arrastrando. Sin esto, el plano solo se mira y se toca para elegir. */
  editable?: boolean
  /** Tocar un lugar lo elige; tocar un pasillo o escalera, o el fondo, no hace nada (para elegir dónde guardar). */
  soloLugares?: boolean
  onSeleccionar?: (clave: string | null) => void
  /** Al soltar lo que se movió o agrandó. Quien lo usa guarda (y deshace si el servidor no acepta). */
  onCambiar?: (clave: string, rect: RectPlano) => void
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
  onSoltarProducto,
}: Props) {
  const caja = useRef<HTMLDivElement>(null)
  const [celda, setCelda] = useState(28)
  // Lo que se está arrastrando, dibujado donde va mientras no se suelta.
  const [vivo, setVivo] = useState<{ clave: string; rect: RectPlano } | null>(null)
  const [sobre, setSobre] = useState<string | null>(null)

  // La celda: lo que entra a lo ancho y, en pantallas bajas, también a lo alto.
  useLayoutEffect(() => {
    const el = caja.current
    if (!el) return
    const medir = () => {
      const ancho = el.clientWidth - 6
      // Lo que queda de pantalla debajo del plano (sin bajar la página).
      const libreAlto = window.innerHeight - (el.getBoundingClientRect().top + window.scrollY) - 24
      const porAncho = ancho / columnas
      const porAlto = libreAlto > 200 ? libreAlto / filas : porAncho
      setCelda(Math.max(14, Math.floor(Math.min(porAncho, porAlto))))
    }
    medir()
    const ro = new ResizeObserver(medir)
    ro.observe(el)
    window.addEventListener('resize', medir)
    return () => {
      ro.disconnect()
      window.removeEventListener('resize', medir)
    }
  }, [columnas, filas])

  // Si cambian las figuras (otro piso, se recargó), lo que se arrastraba ya no vale.
  useEffect(() => setVivo(null), [figuras])

  const empezar = (e: PunteroReact, f: FiguraPlano, modo: 'mover' | 'agrandar') => {
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
    let actual = inicio

    const mover = (ev: PointerEvent) => {
      const dx = Math.round((ev.clientX - x0) / celda)
      const dy = Math.round((ev.clientY - y0) / celda)
      const r: RectPlano =
        modo === 'mover'
          ? { ...inicio, x: limitar(inicio.x + dx, 0, columnas - inicio.ancho), y: limitar(inicio.y + dy, 0, filas - inicio.alto) }
          : {
              ...inicio,
              ancho: limitar(inicio.ancho + dx, minAncho, columnas - inicio.x),
              alto: limitar(inicio.alto + dy, minAlto, filas - inicio.y),
            }
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
    backgroundImage: 'linear-gradient(#e2e8f0 1px,transparent 1px),linear-gradient(90deg,#e2e8f0 1px,transparent 1px)',
  }

  return (
    <div ref={caja} className="w-full min-w-0 overflow-x-auto">
      <div
        className="relative box-content rounded-lg border-[3px] border-slate-700 bg-white"
        style={fondo}
        onPointerDown={() => !soloLugares && onSeleccionar?.(null)}
      >
        {figuras.map((f) => {
          const r = vivo?.clave === f.clave ? vivo.rect : f
          const elegida = seleccionada === f.clave
          const resaltada = resaltadas?.has(f.clave) ?? false
          const esLugar = f.tipo === 'LUGAR'
          const moviendo = vivo?.clave === f.clave

          return (
            <div
              key={f.clave}
              role={esLugar ? 'button' : undefined}
              aria-label={esLugar ? `${f.codigo ?? ''} ${f.nombre}` : f.nombre}
              className={cn(
                'absolute box-border overflow-hidden select-none',
                esLugar ? 'rounded-[3px] border-[3px] bg-white' : f.tipo === 'PASILLO' ? 'border-2 border-dashed border-slate-300' : 'border-[3px] border-slate-700',
                esLugar && 'border-slate-700',
                editable ? 'touch-none cursor-grab' : esLugar || !soloLugares ? 'cursor-pointer' : 'cursor-default',
                moviendo && 'z-20 cursor-grabbing opacity-90 shadow-xl',
                f.inactivo && 'opacity-50',
                resaltada && 'border-amber-500 bg-amber-100',
                elegida && 'z-10 border-[rgb(var(--sys-rgb))] ring-[3px] ring-[rgb(var(--sys-rgb)/0.3)]',
                elegida && esLugar && !resaltada && 'bg-[rgb(var(--sys-rgb)/0.08)]',
                sobre === f.clave && 'border-dashed border-[rgb(var(--sys-rgb))] bg-[rgb(var(--sys-rgb)/0.12)]',
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
              <div className="pointer-events-none p-1 leading-tight">
                {esLugar && f.codigo && <div className="text-[10px] font-bold text-ink-soft">{f.codigo}</div>}
                <div
                  className={cn(
                    'truncate text-xs font-semibold',
                    esLugar ? 'text-ink' : 'text-ink-soft',
                    f.tipo === 'ESCALERA' && 'inline-block max-w-full rounded-sm bg-white px-1',
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
              {editable && elegida && (
                <div
                  aria-label="Cambiar tamaño"
                  className="absolute right-0 bottom-0 size-[18px] cursor-nwse-resize touch-none"
                  style={{ backgroundImage: 'linear-gradient(135deg,transparent 50%,rgb(var(--sys-rgb)) 50%)' }}
                  onPointerDown={(e) => empezar(e, f, 'agrandar')}
                />
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}
