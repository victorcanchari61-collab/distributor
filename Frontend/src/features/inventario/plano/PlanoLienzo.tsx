import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import type { CSSProperties, DragEvent, PointerEvent as PunteroReact, ReactNode } from 'react'
import { RotateCw } from 'lucide-react'
import { cn } from '../../../components/ui'
import type { RectPlano } from '../inventarioApi'
import { bordeExterior, estaLibre, formanUnaFigura, MIME_PRODUCTO, rectsDe } from './geometria'

export type TipoFigura = 'LUGAR' | 'PASILLO' | 'ESCALERA'

/** Lo que se dibuja en el plano: un lugar (guarda mercadería), un pasillo o una escalera. */
export interface FiguraPlano extends RectPlano {
  /** "L12" para el lugar 12, "E3" para el pasillo o escalera 3. */
  clave: string
  tipo: TipoFigura
  /** La ruta del lugar ("P1-01"); los pasillos y escaleras no tienen. */
  codigo?: string
  nombre: string
  /** Cuántos productos tiene puestos (solo lugares). */
  productos?: number
  inactivo?: boolean
  /** Partes extra pegadas al rectángulo principal: un lugar en forma de L que rodea la escalera. */
  partes?: RectPlano[]
  /** Una línea más bajo el nombre: hacia dónde lleva una escalera desde este piso ("Sube a P2"). */
  detalle?: string
  /** El mismo rumbo dicho entero ("Sube a P3 — Baja a P1"): sale al pasar el mouse. */
  detalleCompleto?: string
}

/** Tamaño mínimo de cada cosa, en celdas: un lugar de 1×1 no se lee. Las partes extra pueden ser de una celda. */
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
 * Desde dónde se arrastra: el cuerpo mueve (la figura entera, con todas sus partes); un borde estira esa parte hacia
 * ese lado (n arriba, s abajo, o izquierda, e derecha) y la esquina de abajo a la derecha, hacia los dos.
 */
type Asa = 'mover' | 'n' | 's' | 'o' | 'e' | 'se'

/** Los bordes que se pueden tomar para estirar: una franja fina sobre cada lado. */
const BORDES: { asa: Exclude<Asa, 'mover' | 'se'>; clase: string }[] = [
  { asa: 'n', clase: '-top-[3px] left-3 right-3 h-[6px] cursor-ns-resize' },
  { asa: 's', clase: '-bottom-[3px] left-3 right-3 h-[6px] cursor-ns-resize' },
  { asa: 'o', clase: '-left-[3px] top-3 bottom-3 w-[6px] cursor-ew-resize' },
  { asa: 'e', clase: '-right-[3px] top-3 bottom-3 w-[6px] cursor-ew-resize' },
]

const igual = (a: RectPlano[], b: RectPlano[]) =>
  a.length === b.length && a.every((r, i) => r.x === b[i].x && r.y === b[i].y && r.ancho === b[i].ancho && r.alto === b[i].alto)

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
  /** Al soltar lo que se movió o estiró: el rectángulo principal y las partes extra. Quien lo usa guarda. */
  onCambiar?: (clave: string, rect: RectPlano, partes: RectPlano[]) => void
  /** El botón ↻ de lo elegido: girarlo (el ancho pasa a ser el alto). */
  onGirar?: (clave: string) => void
  /** Un producto arrastrado se soltó sobre un lugar. */
  onSoltarProducto?: (clave: string, e: DragEvent) => void
  /** Modo "Ampliar": el lugar al que se le suma una parte; arrastrar sobre el espacio vacío dibuja esa parte. */
  ampliando?: string | null
  onAmpliar?: (clave: string, rect: RectPlano) => void
}

/**
 * El plano de un piso: una cuadrícula donde cada lugar, pasillo y escalera es un rectángulo (o, un lugar, varios
 * pegados: una L). Se ajusta al ancho y al alto que tiene libre en la pantalla, así el piso entero se ve sin desplazarse.
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
  ampliando = null,
  onAmpliar,
}: Props) {
  const caja = useRef<HTMLDivElement>(null)
  const lienzo = useRef<HTMLDivElement>(null)
  const [celda, setCelda] = useState(28)
  // Lo que se está arrastrando, dibujado donde va mientras no se suelta: todos sus rectángulos.
  const [vivo, setVivo] = useState<{ clave: string; rects: RectPlano[] } | null>(null)
  const [sobre, setSobre] = useState<string | null>(null)
  // El recuadro punteado que se dibuja al ampliar un lugar.
  const [trazo, setTrazo] = useState<RectPlano | null>(null)

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

  const limitar = (v: number, a: number, b: number) => Math.max(a, Math.min(b, v))

  /** Arrastrar una figura: moverla entera o estirar una de sus partes (`parte`: 0 la principal, 1… las extra). */
  const empezar = (e: PunteroReact, f: FiguraPlano, asa: Asa, parte = 0) => {
    if (e.button > 0) return
    // Ampliando, lo que se toca es el fondo: el evento sigue hasta el plano, que dibuja la parte nueva.
    if (ampliando) return
    e.stopPropagation()
    if (soloLugares && f.tipo !== 'LUGAR') return
    onSeleccionar?.(f.clave)
    if (!editable) return
    e.preventDefault()

    const x0 = e.clientX
    const y0 = e.clientY
    const inicio = rectsDe(f)
    // Lo que ocupa la figura entera: no se puede mover fuera de la cuadrícula.
    const minX = Math.min(...inicio.map((r) => r.x))
    const minY = Math.min(...inicio.map((r) => r.y))
    const maxX = Math.max(...inicio.map((r) => r.x + r.ancho))
    const maxY = Math.max(...inicio.map((r) => r.y + r.alto))
    const [minAncho, minAlto] = parte === 0 ? MINIMO[f.tipo] : [1, 1]
    let actual = inicio

    const calcular = (dx: number, dy: number): RectPlano[] => {
      if (asa === 'mover') {
        const mx = limitar(dx, -minX, columnas - maxX)
        const my = limitar(dy, -minY, filas - maxY)
        return inicio.map((r) => ({ ...r, x: r.x + mx, y: r.y + my }))
      }
      const r0 = inicio[parte]
      const derecha = r0.x + r0.ancho
      const abajo = r0.y + r0.alto
      let r: RectPlano
      switch (asa) {
        case 'e':
          r = { ...r0, ancho: limitar(r0.ancho + dx, minAncho, columnas - r0.x) }
          break
        case 's':
          r = { ...r0, alto: limitar(r0.alto + dy, minAlto, filas - r0.y) }
          break
        case 'se':
          r = { ...r0, ancho: limitar(r0.ancho + dx, minAncho, columnas - r0.x), alto: limitar(r0.alto + dy, minAlto, filas - r0.y) }
          break
        case 'o': {
          // El borde derecho se queda donde está: se mueve el izquierdo.
          const x = limitar(r0.x + dx, 0, derecha - minAncho)
          r = { ...r0, x, ancho: derecha - x }
          break
        }
        case 'n': {
          const y = limitar(r0.y + dy, 0, abajo - minAlto)
          r = { ...r0, y, alto: abajo - y }
          break
        }
      }
      return inicio.map((x, i) => (i === parte ? r : x))
    }

    const mover = (ev: PointerEvent) => {
      const nuevas = calcular(Math.round((ev.clientX - x0) / celda), Math.round((ev.clientY - y0) / celda))
      if (!igual(nuevas, actual) && formanUnaFigura(nuevas) && estaLibre(figuras, f.clave, nuevas)) {
        actual = nuevas
        setVivo({ clave: f.clave, rects: nuevas })
      }
    }
    const soltar = () => {
      window.removeEventListener('pointermove', mover)
      window.removeEventListener('pointerup', soltar)
      window.removeEventListener('pointercancel', soltar)
      if (!igual(actual, inicio)) onCambiar?.(f.clave, actual[0], actual.slice(1))
      else setVivo(null)
    }
    window.addEventListener('pointermove', mover)
    window.addEventListener('pointerup', soltar)
    window.addEventListener('pointercancel', soltar)
  }

  /** En el fondo: sin ampliar, deselecciona; ampliando, dibuja el recuadro de la parte nueva celda por celda. */
  const enFondo = (e: PunteroReact) => {
    if (!ampliando) {
      if (!soloLugares) onSeleccionar?.(null)
      return
    }
    const el = lienzo.current
    if (!el || e.button > 0) return
    e.preventDefault()
    const marco = el.getBoundingClientRect()
    // El borde del plano mide 3px: la celda 0 empieza después.
    const celdaDe = (cx: number, cy: number) => ({
      x: limitar(Math.floor((cx - marco.left - 3) / celda), 0, columnas - 1),
      y: limitar(Math.floor((cy - marco.top - 3) / celda), 0, filas - 1),
    })
    const desde = celdaDe(e.clientX, e.clientY)
    const recuadro = (hasta: { x: number; y: number }): RectPlano => ({
      x: Math.min(desde.x, hasta.x),
      y: Math.min(desde.y, hasta.y),
      ancho: Math.abs(hasta.x - desde.x) + 1,
      alto: Math.abs(hasta.y - desde.y) + 1,
    })
    let actual = recuadro(desde)
    setTrazo(actual)
    const mover = (ev: PointerEvent) => {
      actual = recuadro(celdaDe(ev.clientX, ev.clientY))
      setTrazo(actual)
    }
    const soltar = () => {
      window.removeEventListener('pointermove', mover)
      window.removeEventListener('pointerup', soltar)
      window.removeEventListener('pointercancel', soltar)
      setTrazo(null)
      onAmpliar?.(ampliando, actual)
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

  const posicion = (r: RectPlano): CSSProperties => ({
    left: r.x * celda,
    top: r.y * celda,
    width: r.ancho * celda,
    height: r.alto * celda,
  })

  /** Lo que hace de un rectángulo un lugar donde soltar productos. */
  const destinoProducto = (f: FiguraPlano) =>
    f.tipo === 'LUGAR' && onSoltarProducto
      ? {
          onDragOver: (e: DragEvent) => {
            if (!e.dataTransfer.types.includes(MIME_PRODUCTO)) return
            e.preventDefault()
            e.dataTransfer.dropEffect = 'move'
            setSobre(f.clave)
          },
          onDragLeave: () => setSobre((s) => (s === f.clave ? null : s)),
          onDrop: (e: DragEvent) => {
            e.preventDefault()
            setSobre(null)
            onSoltarProducto(f.clave, e)
          },
        }
      : {}

  /**
   * Los bordes para estirar una parte y la esquina que la estira hacia los dos lados. En un lugar con partes, solo los
   * del contorno: un lado pegado a otra parte del mismo lugar es una unión por dentro, y ahí no se marca nada.
   */
  const asas = (f: FiguraPlano, parte: number, moviendo: boolean, rects: RectPlano[]): ReactNode => {
    if (!editable || moviendo || ampliando) return null
    const r = rects[parte]
    const otras = rects.filter((_, i) => i !== parte)
    const pegado: Record<Exclude<Asa, 'mover' | 'se'>, boolean> = {
      n: otras.some((o) => o.y + o.alto === r.y && o.x < r.x + r.ancho && r.x < o.x + o.ancho),
      s: otras.some((o) => o.y === r.y + r.alto && o.x < r.x + r.ancho && r.x < o.x + o.ancho),
      o: otras.some((o) => o.x + o.ancho === r.x && o.y < r.y + r.alto && r.y < o.y + o.alto),
      e: otras.some((o) => o.x === r.x + r.ancho && o.y < r.y + r.alto && r.y < o.y + o.alto),
    }
    return (
      <>
        {BORDES.filter((b) => !pegado[b.asa]).map((b) => (
          <div
            key={b.asa}
            aria-label="Estirar"
            className={cn(
              'absolute z-10 touch-none rounded-full bg-[rgb(var(--sys-rgb))] opacity-0 group-hover/fig:opacity-60 hover:!opacity-100',
              b.clase,
            )}
            onPointerDown={(e) => empezar(e, f, b.asa, parte)}
          />
        ))}
        {/* Siempre a la vista: dice que se puede agrandar. Si cae en una unión por dentro, no va. */}
        {!pegado.e && !pegado.s && (
          <div
            aria-label="Estirar hacia los dos lados"
            className="absolute right-0 bottom-0 z-10 size-[14px] cursor-nwse-resize touch-none"
            style={{ backgroundImage: 'linear-gradient(135deg,transparent 50%,rgb(var(--sys-rgb)) 50%)' }}
            onPointerDown={(e) => empezar(e, f, 'se', parte)}
          />
        )}
      </>
    )
  }

  const etiqueta = (f: FiguraPlano, vertical: boolean) => (
    <div className={cn('pointer-events-none h-full overflow-hidden p-1 leading-tight', vertical && 'flex justify-center')}>
      {f.tipo === 'LUGAR' && f.codigo && (
        <div className="text-[10px] font-bold tracking-wide text-[rgb(var(--sys-ink-rgb))]">{f.codigo}</div>
      )}
      <div
        className={cn(
          'truncate text-xs font-semibold',
          f.tipo === 'LUGAR' ? 'text-ink' : f.tipo === 'PASILLO' ? 'text-[rgb(var(--sys-ink-rgb))]' : '',
          // La escalera lleva su nombre en una etiqueta oscura sobre los peldaños, como un cartel.
          f.tipo === 'ESCALERA' && 'inline-block max-w-full rounded-sm bg-slate-800 px-1.5 text-white',
          vertical && 'max-h-full [writing-mode:vertical-rl]',
        )}
      >
        {f.nombre}
      </div>
      {/* Hacia dónde lleva la escalera desde este piso: "Sube a P2", "Baja a P1". */}
      {f.detalle && !vertical && (
        <div
          title={f.detalleCompleto}
          className="pointer-events-auto mt-0.5 block w-fit max-w-full truncate rounded-sm bg-[rgb(var(--sys-rgb))] px-1.5 text-[10px] font-semibold text-white"
        >
          {f.detalle}
        </div>
      )}
    </div>
  )

  const insignia = (f: FiguraPlano) =>
    f.tipo === 'LUGAR' &&
    (f.productos ?? 0) > 0 && (
      <span className="pointer-events-none absolute top-1 right-1 inline-flex h-5 min-w-5 items-center justify-center rounded-full bg-[rgb(var(--sys-rgb))] px-1.5 text-[11px] font-bold text-white">
        {f.productos}
      </span>
    )

  const botonGirar = (f: FiguraPlano) => (
    <button
      type="button"
      aria-label={`Girar ${f.nombre}`}
      title="Girar"
      className="absolute top-1 left-1/2 z-30 flex size-7 -translate-x-1/2 cursor-pointer items-center justify-center rounded-full border border-line bg-white text-[rgb(var(--sys-rgb))] shadow hover:bg-surface-alt"
      onPointerDown={(e) => e.stopPropagation()}
      onClick={() => onGirar?.(f.clave)}
    >
      <RotateCw size={14} />
    </button>
  )

  return (
    <div ref={caja} className="w-full min-w-0 overflow-x-auto">
      <div
        ref={lienzo}
        className={cn(
          'relative box-content rounded-lg border-[3px] border-[rgb(var(--sys-dark-rgb))] bg-slate-50',
          ampliando && 'cursor-crosshair',
        )}
        style={fondo}
        onPointerDown={enFondo}
      >
        {figuras.map((f) => {
          const rects = vivo?.clave === f.clave ? vivo.rects : rectsDe(f)
          const principal = rects[0]
          const elegida = seleccionada === f.clave
          const resaltada = resaltadas?.has(f.clave) ?? false
          const esLugar = f.tipo === 'LUGAR'
          const moviendo = vivo?.clave === f.clave
          const encima = sobre === f.clave
          const cursor = ampliando
            ? 'cursor-crosshair'
            : editable
              ? 'touch-none cursor-grab'
              : esLugar || !soloLugares
                ? 'cursor-pointer'
                : 'cursor-default'

          // ---- Un lugar de varias partes (una L): un relleno y un solo borde por fuera, sin línea en medio.
          if (rects.length > 1) {
            const minX = Math.min(...rects.map((r) => r.x))
            const minY = Math.min(...rects.map((r) => r.y))
            const maxX = Math.max(...rects.map((r) => r.x + r.ancho))
            const maxY = Math.max(...rects.map((r) => r.y + r.alto))
            const relleno = encima
              ? 'rgb(var(--sys-rgb) / 0.25)'
              : resaltada
                ? '#fef3c7'
                : elegida
                  ? 'rgb(var(--sys-rgb) / 0.22)'
                  : 'rgb(var(--sys-rgb) / 0.07)'
            const colorBorde = encima || elegida ? 'rgb(var(--sys-rgb))' : resaltada ? '#f59e0b' : 'rgb(var(--sys-dark-rgb) / 0.8)'
            const idRecorte = `recorte-${f.clave}`
            return (
              <div key={f.clave} className={cn(moviendo && 'opacity-90', f.inactivo && 'opacity-50')}>
                <svg
                  className={cn('pointer-events-none absolute', moviendo && 'drop-shadow-xl', elegida && 'z-10')}
                  style={{ left: minX * celda, top: minY * celda }}
                  width={(maxX - minX) * celda}
                  height={(maxY - minY) * celda}
                >
                  <defs>
                    <clipPath id={idRecorte}>
                      {rects.map((r, i) => (
                        <rect key={i} x={(r.x - minX) * celda} y={(r.y - minY) * celda} width={r.ancho * celda} height={r.alto * celda} />
                      ))}
                    </clipPath>
                  </defs>
                  <g clipPath={`url(#${idRecorte})`}>
                    {rects.map((r, i) => (
                      <rect
                        key={i}
                        x={(r.x - minX) * celda}
                        y={(r.y - minY) * celda}
                        width={r.ancho * celda}
                        height={r.alto * celda}
                        style={{ fill: relleno }}
                      />
                    ))}
                    {/* El borde se dibuja al doble y se recorta a la figura: queda 3px por dentro, como los demás. */}
                    {bordeExterior(rects).map((t, i) => (
                      <line
                        key={i}
                        x1={(t.x1 - minX) * celda}
                        y1={(t.y1 - minY) * celda}
                        x2={(t.x2 - minX) * celda}
                        y2={(t.y2 - minY) * celda}
                        strokeWidth={6}
                        strokeLinecap="square"
                        strokeDasharray={encima ? '6 4' : undefined}
                        style={{ stroke: colorBorde }}
                      />
                    ))}
                  </g>
                </svg>
                {rects.map((r, i) => (
                  <div
                    key={i}
                    role={i === 0 ? 'button' : undefined}
                    aria-label={i === 0 ? `${f.codigo ?? ''} ${f.nombre}` : `${f.nombre} (parte ${i + 1})`}
                    className={cn('group/fig absolute select-none', cursor, elegida && 'z-10')}
                    style={posicion(r)}
                    onPointerDown={(e) => empezar(e, f, 'mover', i)}
                    {...destinoProducto(f)}
                  >
                    {i === 0 && etiqueta(f, false)}
                    {i === 0 && insignia(f)}
                    {/* Sin botón de girar: un lugar con partes no se gira (primero se le quitan). */}
                    {asas(f, i, moviendo, rects)}
                  </div>
                ))}
              </div>
            )
          }

          // ---- Un solo rectángulo.
          // Angosto y alto (un pasillo vertical): el nombre se escribe de arriba abajo.
          const vertical = principal.ancho <= 2 && principal.alto >= principal.ancho * 2

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
                cursor,
                moviendo && 'z-20 cursor-grabbing opacity-90 shadow-xl',
                f.inactivo && 'opacity-50',
                elegida && 'z-10 ring-[3px] ring-[rgb(var(--sys-rgb)/0.3)]',
              )}
              style={{ ...posicion(principal), ...ESTILO[f.tipo] }}
              onPointerDown={(e) => empezar(e, f, 'mover')}
              {...destinoProducto(f)}
            >
              {etiqueta(f, vertical)}
              {insignia(f)}
              {asas(f, 0, moviendo, [principal])}
              {editable && elegida && onGirar && !moviendo && !ampliando && botonGirar(f)}
            </div>
          )
        })}

        {/* La parte que se está sumando al lugar: un recuadro punteado. */}
        {trazo && (
          <div
            className="pointer-events-none absolute z-30 border-2 border-dashed border-[rgb(var(--sys-rgb))] bg-[rgb(var(--sys-rgb)/0.15)]"
            style={posicion(trazo)}
          />
        )}
      </div>
    </div>
  )
}
