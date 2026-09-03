import { useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { Search } from 'lucide-react'
import { cn } from './cn'

export interface OpcionBuscador<T> {
  item: T
  label: string
  /** Segunda línea, más chica y gris: documento, código... */
  detalle?: string
  /** Tercer dato, a la derecha: rubro, distrito... */
  nota?: string
}

export interface BuscadorCampoProps<T> {
  label?: string
  value: T | null
  onChange: (value: T | null) => void
  opciones: OpcionBuscador<T>[]
  placeholder?: string
  optional?: boolean
  disabled?: boolean
  error?: string
  className?: string
  vacio?: string
}

/**
 * Campo que se escribe directo, como cualquier input, y filtra una lista de
 * cientos de opciones a medida que se tipea — un proveedor, un cliente.
 *
 * A diferencia de [Desplegable] (que abre TODAS las opciones y deja
 * buscar adentro), acá el cursor entra al campo mismo: se empieza a escribir
 * sin un clic de más, y la lista aparece filtrada debajo. Se cierra solo al
 * elegir, al perder el foco o con Escape.
 */
export function BuscadorCampo<T>({
  label,
  value,
  onChange,
  opciones,
  placeholder = 'Buscar...',
  optional,
  disabled,
  error,
  className,
  vacio = 'Nada coincide',
}: BuscadorCampoProps<T>) {
  const [abierto, setAbierto] = useState(false)
  const [texto, setTexto] = useState('')
  const [pos, setPos] = useState<{ top: number; left: number; ancho: number } | null>(null)
  const campoRef = useRef<HTMLDivElement>(null)
  const panelRef = useRef<HTMLDivElement>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  const elegido = opciones.find((o) => o.item === value)

  // Lo que se ve en el input: mientras se escribe, lo tipeado; si no, el
  // nombre de lo elegido.
  const textoVisible = abierto ? texto : (elegido?.label ?? '')

  const term = texto.trim().toLowerCase()
  const visibles = term
    ? opciones.filter((o) =>
        `${o.label} ${o.detalle ?? ''} ${o.nota ?? ''}`.toLowerCase().includes(term),
      )
    : opciones

  useEffect(() => {
    if (!abierto) return

    const colocar = () => {
      const el = campoRef.current
      if (!el) return
      const r = el.getBoundingClientRect()
      setPos({ top: r.bottom + 6, left: r.left, ancho: r.width })
    }

    colocar()
    const fuera = (e: MouseEvent) => {
      const t = e.target as Node
      // El panel vive en un portal sobre document.body: no es descendiente
      // de campoRef, así que hay que revisarlo aparte. Sin esto, el propio
      // clic para elegir una opción se contaba como "afuera" y cerraba el
      // panel en el mousedown, antes de que el click en la opción llegara a
      // disparar — la lista se cerraba sola y nada quedaba elegido.
      if (!campoRef.current?.contains(t) && !panelRef.current?.contains(t)) {
        setAbierto(false)
        setTexto('')
      }
    }
    const escape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setAbierto(false)
        setTexto('')
      }
    }

    window.addEventListener('resize', colocar)
    window.addEventListener('scroll', colocar, true)
    document.addEventListener('mousedown', fuera)
    document.addEventListener('keydown', escape)
    return () => {
      window.removeEventListener('resize', colocar)
      window.removeEventListener('scroll', colocar, true)
      document.removeEventListener('mousedown', fuera)
      document.removeEventListener('keydown', escape)
    }
  }, [abierto])

  const elegir = (o: OpcionBuscador<T>) => {
    onChange(o.item)
    setTexto('')
    setAbierto(false)
  }

  return (
    <div className={cn('w-full', className)} ref={campoRef}>
      {label && (
        <div className="mb-1.5 flex min-h-5 items-center gap-2">
          <span className="ui-label truncate">
            {label}
            {optional && <span className="ml-1.5 font-normal text-ink-soft">(opcional)</span>}
          </span>
        </div>
      )}

      <div
        className={cn(
          'flex h-[var(--height-field-md)] items-center gap-2 rounded-field border bg-surface px-3',
          'focus-within:border-ink-soft',
          error ? 'border-red-600' : 'border-line',
        )}
      >
        <Search size={15} className="shrink-0 text-ink-soft" />
        <input
          ref={inputRef}
          type="text"
          disabled={disabled}
          value={textoVisible}
          placeholder={placeholder}
          onFocus={(e) => {
            setAbierto(true)
            setTexto('')
            e.currentTarget.select()
          }}
          onChange={(e) => setTexto(e.target.value)}
          className="min-w-0 flex-1 border-none bg-transparent text-sm text-ink outline-none placeholder:text-ink-soft"
        />
      </div>

      {error && <p className="mt-1.5 text-xs text-red-600">{error}</p>}

      {abierto &&
        pos &&
        createPortal(
          <div
            ref={panelRef}
            style={{ top: pos.top, left: pos.left, width: pos.ancho }}
            className="fixed z-50 max-h-[16rem] overflow-y-auto rounded-panel bg-white py-1 shadow-xl shadow-zinc-900/20 ring-1 ring-zinc-200"
          >
            {visibles.length === 0 ? (
              <p className="px-3 py-4 text-center text-xs text-ink-soft">{vacio}</p>
            ) : (
              visibles.map((o, i) => (
                <div
                  key={i}
                  role="option"
                  aria-selected={o.item === value}
                  onClick={() => elegir(o)}
                  className={cn(
                    'flex cursor-pointer items-center justify-between gap-3 px-3 py-2 hover:bg-slate-50',
                    o.item === value && 'bg-[rgb(var(--sys-rgb)/0.08)]',
                  )}
                >
                  <span className="min-w-0">
                    <span className="block truncate text-[13px] text-ink">{o.label}</span>
                    {o.detalle && (
                      <span className="block truncate text-[11px] text-ink-soft">{o.detalle}</span>
                    )}
                  </span>
                  {o.nota && (
                    <span className="shrink-0 text-[12px] font-medium text-ink-muted">{o.nota}</span>
                  )}
                </div>
              ))
            )}
          </div>,
          document.body,
        )}
    </div>
  )
}
