import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import type { CSSProperties, DragEvent, PointerEvent as PunteroReact, ReactNode } from 'react'
import { RotateCw } from 'lucide-react'
import { cn } from '../../../components/ui'
import type { RectPlano } from '../inventarioApi'
import { bordeExterior, estaLibre, formanUnaFigura, MIME_PRODUCTO, rectsDe } from './geometria'

/** VACIO: la doble altura de algo del piso de abajo; aquí no hay suelo y no se pone nada. */
export type TipoFigura = 'LUGAR' | 'PASILLO' | 'ESCALERA' | 'VACIO'

/** Lo que se dibuja en el plano: un lugar (guarda mercadería), un pasillo, una escalera o un vacío. */
export interface FiguraPlano extends RectPlano {
  /** "L12" para el lugar 12, "E3" para el pasillo o escalera 3, "VL12"/"VE3" para sus vacíos en pisos de arriba. */
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
  /** Una línea más bajo el nombre: hacia dónde lleva una escalera ("↑ P2"), de quién es un vacío. */
  detalle?: string
  /** El mismo detalle dicho entero ("Sube a P3 — Baja a P1"): sale al pasar el mouse. */
  detalleCompleto?: string
  /** Solo lugares: elige su color (el id del lugar), así cada lugar se distingue del de al lado. */
  color?: number
}

/** Tamaño mínimo de cada cosa, en celdas: un lugar de 1×1 no se lee. Las partes extra pueden ser de una celda. */
const MINIMO: Record<TipoFigura, [number, number]> = { LUGAR: [2, 2], PASILLO: [1, 1], ESCALERA: [2, 2], VACIO: [1, 1] }

/**
 * Los colores de los lugares: uno distinto para cada lugar (por su id), suaves de fondo y fuertes de borde, para que
 * dos lugares pegados no se confundan. Sin amarillo: es el color de lo que se buscó.
 */
const PALETA = [
  { fondo: '#dbeafe', borde: '#2563eb', texto: '#1e40af' }, // azul
  { fondo: '#dcfce7', borde: '#16a34a', texto: '#166534' }, // verde
  { fondo: '#ede9fe', borde: '#7c3aed', texto: '#5b21b6' }, // violeta
  { fondo: '#fce7f3', borde: '#db2777', texto: '#9d174d' }, // rosa
  { fondo: '#cffafe', borde: '#0891b2', texto: '#155e75' }, // cian
  { fondo: '#ffedd5', borde: '#ea580c', texto: '#9a3412' }, // naranja
  { fondo: '#ecfccb', borde: '#65a30d', texto: '#3f6212' }, // lima
  { fondo: '#e0e7ff', borde: '#4f46e5', texto: '#3730a3' }, // índigo
]
const colorDeLugar = (f: FiguraPlano) => PALETA[Math.abs(f.color ?? 0) % PALETA.length]

/** Cómo se pinta cada cosa que no es lugar: el pasillo gris rayado, la escalera con peldaños, el vacío oscuro. */
const NO_LUGAR = {
  PASILLO: {
    fondo: '#f1f5f9',
    patron: 'repeating-linear-gradient(45deg,#e2e8f0 0 7px,#f8fafc 7px 14px)',
    borde: '#94a3b8',
    texto: '#475569',
    discontinuo: true,
    grosor: 2,
  },
  ESCALERA: {
    fondo: '#ffffff',
    patron: 'repeating-linear-gradient(0deg,#64748b 0 2px,#ffffff 2px 8px)',
    borde: '#334155',
    texto: '#ffffff',
    discontinuo: false,
    grosor: 3,
  },
  VACIO: {
    fondo: 'rgba(15,23,42,0.14)',
    patron: 'repeating-linear-gradient(135deg,rgba(15,23,42,0.28) 0 5px,rgba(15,23,42,0.07) 5px 11px)',
    borde: '#475569',
    texto: '#0f172a',
    discontinuo: true,
    grosor: 2,
  },
}

const AMARILLO = { fondo: '#fef08a', borde: '#ca8a04' }

/** La leyenda: qué es cada color. */
const LEYENDA: { nombre: string; muestra: CSSProperties }[] = [
  {
    nombre: 'Lugares (cada uno su color)',
    muestra: { backgroundImage: `linear-gradient(90deg,${PALETA[0].fondo} 33%,${PALETA[1].fondo} 33% 66%,${PALETA[2].fondo} 66%)`, borderColor: '#334155' },
  },
  { nombre: 'Pasillo', muestra: { backgroundImage: NO_LUGAR.PASILLO.patron, borderColor: NO_LUGAR.PASILLO.borde, borderStyle: 'dashed' } },
  { nombre: 'Escalera (une pisos)', muestra: { backgroundImage: NO_LUGAR.ESCALERA.patron, borderColor: NO_LUGAR.ESCALERA.borde } },
  { nombre: 'Vacío (doble altura, sin suelo)', muestra: { backgroundImage: NO_LUGAR.VACIO.patron, borderColor: NO_LUGAR.VACIO.borde, borderStyle: 'dashed' } },
  { nombre: 'Lo que buscaste', muestra: { backgroundColor: AMARILLO.fondo, borderColor: AMARILLO.borde } },
]

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
  /** Tocar un lugar lo elige; tocar un pasillo, escalera, vacío o el fondo no hace nada (para elegir dónde guardar). */
  soloLugares?: boolean
  /** Muestra debajo qué es cada color. */
  leyenda?: boolean
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
  leyenda = false,
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
      // Debajo quedan: el borde del plano (6), el relleno y borde del recuadro (13), el margen de abajo de la página
      // (se mide: con la barra de navegación abajo es más alto) y, si va, la leyenda (30).
      const main = el.closest('main')
      const margen = main ? parseFloat(getComputedStyle(main).paddingBottom) || 0 : 24
      const libreAlto = window.innerHeight - (el.getBoundingClientRect().top + window.scrollY) - 22 - margen - (leyenda ? 30 : 0)
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
  }, [columnas, filas, leyenda])

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
    // Un vacío no se mueve desde aquí: se mueve lo de abajo, y el vacío lo sigue.
    if (!editable || f.tipo === 'VACIO') return
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
      'linear-gradient(rgba(148,163,184,0.25) 1px,transparent 1px),linear-gradient(90deg,rgba(148,163,184,0.25) 1px,transparent 1px)',
  }

  const posicion = (r: RectPlano): CSSProperties => ({
    left: r.x * celda,
    top: r.y * celda,
    width: r.ancho * celda,
    height: r.alto * celda,
  })

  /**
   * Los colores de una figura según lo que es y cómo está: cada lugar el suyo; lo que se buscó, amarillo; donde se va
   * a soltar un producto, punteado del color del módulo. Lo elegido conserva su color y gana un borde oscuro.
   */
  const pintura = (f: FiguraPlano, elegida: boolean, resaltada: boolean, encima: boolean) => {
    const base =
      f.tipo === 'LUGAR'
        ? { ...colorDeLugar(f), patron: undefined as string | undefined, discontinuo: false, grosor: 3 }
        : NO_LUGAR[f.tipo]
    let fondo = base.fondo
    let borde = base.borde
    let discontinuo = base.discontinuo
    if (resaltada) {
      fondo = AMARILLO.fondo
      borde = AMARILLO.borde
    }
    if (encima) {
      fondo = 'rgb(var(--sys-rgb) / 0.25)'
      borde = 'rgb(var(--sys-rgb))'
      discontinuo = true
    }
    if (elegida) borde = '#0f172a'
    return { fondo, borde, discontinuo, grosor: base.grosor, patron: resaltada || encima ? undefined : base.patron, texto: base.texto }
  }

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
  const asas = (f: FiguraPlano, parte: number, moviendo: boolean, rects: RectPlano[], color: string): ReactNode => {
    if (!editable || moviendo || ampliando || f.tipo === 'VACIO') return null
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
            className={cn('absolute z-10 touch-none rounded-full opacity-0 group-hover/fig:opacity-60 hover:!opacity-100', b.clase)}
            style={{ backgroundColor: color }}
            onPointerDown={(e) => empezar(e, f, b.asa, parte)}
          />
        ))}
        {/* Siempre a la vista: dice que se puede agrandar. Si cae en una unión por dentro, no va. */}
        {!pegado.e && !pegado.s && (
          <div
            aria-label="Estirar hacia los dos lados"
            className="absolute right-0 bottom-0 z-10 size-[14px] cursor-nwse-resize touch-none"
            style={{ backgroundImage: `linear-gradient(135deg,transparent 50%,${color} 50%)` }}
            onPointerDown={(e) => empezar(e, f, 'se', parte)}
          />
        )}
      </>
    )
  }

  const etiqueta = (f: FiguraPlano, vertical: boolean, colorTexto: string) => (
    <div className={cn('pointer-events-none h-full overflow-hidden p-1 leading-tight', vertical && 'flex justify-center')}>
      {f.tipo === 'LUGAR' && f.codigo && (
        <div className="text-[10px] font-bold tracking-wide" style={{ color: colorTexto }}>
          {f.codigo}
        </div>
      )}
      <div
        className={cn(
          'truncate text-xs font-semibold',
          f.tipo === 'LUGAR' && 'text-ink',
          // La escalera lleva su nombre en una etiqueta oscura sobre los peldaños, como un cartel.
          f.tipo === 'ESCALERA' && 'inline-block max-w-full rounded-sm bg-slate-800 px-1.5',
          f.tipo === 'VACIO' && 'inline-block max-w-full rounded-sm bg-white/80 px-1.5',
          vertical && 'max-h-full [writing-mode:vertical-rl]',
        )}
        style={f.tipo === 'LUGAR' ? undefined : { color: colorTexto }}
      >
        {f.nombre}
      </div>
      {/* Hacia dónde lleva la escalera desde este piso ("↑ P2"), o de quién es el vacío. */}
      {f.detalle && !vertical && (
        <div
          title={f.detalleCompleto ?? f.detalle}
          className={cn(
            'pointer-events-auto mt-0.5 block w-fit max-w-full truncate rounded-sm px-1.5 text-[10px] font-semibold',
            f.tipo === 'VACIO' ? 'bg-white/80 text-slate-800' : 'bg-indigo-600 text-white',
          )}
        >
          {f.detalle}
        </div>
      )}
    </div>
  )

  const insignia = (f: FiguraPlano, color: string) =>
    f.tipo === 'LUGAR' &&
    (f.productos ?? 0) > 0 && (
      <span
        className="pointer-events-none absolute top-1 right-1 inline-flex h-5 min-w-5 items-center justify-center rounded-full px-1.5 text-[11px] font-bold text-white"
        style={{ backgroundColor: color }}
      >
        {f.productos}
      </span>
    )

  const botonGirar = (f: FiguraPlano) => (
    <button
      type="button"
      aria-label={`Girar ${f.nombre}`}
      title="Girar"
      className="absolute top-1 left-1/2 z-30 flex size-7 -translate-x-1/2 cursor-pointer items-center justify-center rounded-full border border-line bg-white text-slate-700 shadow hover:bg-surface-alt"
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
          'relative box-content rounded-lg border-[3px] border-[rgb(var(--sys-dark-rgb))] bg-white',
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
          const p = pintura(f, elegida, resaltada, encima)
          const cursor = ampliando
            ? 'cursor-crosshair'
            : soloLugares && !esLugar
              ? 'cursor-default'
              : editable && f.tipo !== 'VACIO'
                ? 'touch-none cursor-grab'
                : 'cursor-pointer'

          // ---- Varias partes (una L): un relleno y un solo borde por fuera, sin línea en medio.
          if (rects.length > 1) {
            const minX = Math.min(...rects.map((r) => r.x))
            const minY = Math.min(...rects.map((r) => r.y))
            const maxX = Math.max(...rects.map((r) => r.x + r.ancho))
            const maxY = Math.max(...rects.map((r) => r.y + r.alto))
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
                        style={{ fill: p.fondo }}
                      />
                    ))}
                    {/* El borde se dibuja al doble y se recorta a la figura: queda por dentro, como los demás. */}
                    {bordeExterior(rects).map((t, i) => (
                      <line
                        key={i}
                        x1={(t.x1 - minX) * celda}
                        y1={(t.y1 - minY) * celda}
                        x2={(t.x2 - minX) * celda}
                        y2={(t.y2 - minY) * celda}
                        strokeWidth={p.grosor * 2}
                        strokeLinecap="square"
                        strokeDasharray={p.discontinuo ? '6 4' : undefined}
                        style={{ stroke: p.borde }}
                      />
                    ))}
                  </g>
                </svg>
                {rects.map((r, i) => (
                  <div
                    key={i}
                    role={i === 0 && esLugar ? 'button' : undefined}
                    aria-label={i === 0 ? `${f.codigo ?? ''} ${f.nombre}` : `${f.nombre} (parte ${i + 1})`}
                    className={cn('group/fig absolute select-none', cursor, elegida && 'z-10')}
                    // Los vacíos llevan su rayado oscuro en cada parte (el SVG solo lo tiñe).
                    style={{ ...posicion(r), backgroundImage: p.patron }}
                    onPointerDown={(e) => empezar(e, f, 'mover', i)}
                    {...destinoProducto(f)}
                  >
                    {i === 0 && etiqueta(f, false, p.texto)}
                    {i === 0 && insignia(f, p.borde)}
                    {/* Sin botón de girar: un lugar con partes no se gira (primero se le quitan). */}
                    {asas(f, i, moviendo, rects, p.borde)}
                  </div>
                ))}
              </div>
            )
          }

          // ---- Un solo rectángulo.
          // Angosto y alto (un pasillo vertical): el nombre se escribe de arriba abajo.
          const vertical = principal.ancho <= 2 && principal.alto >= principal.ancho * 2

          return (
            <div
              key={f.clave}
              role={esLugar ? 'button' : undefined}
              aria-label={esLugar ? `${f.codigo ?? ''} ${f.nombre}` : f.nombre}
              className={cn(
                'group/fig absolute box-border overflow-visible select-none',
                esLugar && 'rounded-[3px]',
                cursor,
                moviendo && 'z-20 cursor-grabbing opacity-90 shadow-xl',
                f.inactivo && 'opacity-50',
                elegida && 'z-10 ring-[3px] ring-slate-900/25',
              )}
              style={{
                ...posicion(principal),
                backgroundColor: p.fondo,
                backgroundImage: p.patron,
                borderColor: p.borde,
                borderWidth: p.grosor,
                borderStyle: p.discontinuo ? 'dashed' : 'solid',
              }}
              onPointerDown={(e) => empezar(e, f, 'mover')}
              {...destinoProducto(f)}
            >
              {etiqueta(f, vertical, p.texto)}
              {insignia(f, p.borde)}
              {asas(f, 0, moviendo, [principal], p.borde)}
              {editable && elegida && onGirar && f.tipo !== 'VACIO' && !moviendo && !ampliando && botonGirar(f)}
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

      {leyenda && (
        <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-[11px] text-ink-muted">
          {LEYENDA.map((l) => (
            <span key={l.nombre} className="inline-flex items-center gap-1.5">
              <span className="inline-block h-3 w-5 rounded-[2px] border-2" style={l.muestra} />
              {l.nombre}
            </span>
          ))}
        </div>
      )}
    </div>
  )
}
