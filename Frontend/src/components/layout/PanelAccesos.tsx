import type { RefObject } from 'react'
import { ArrowUpRight, Download, Plus, Upload } from 'lucide-react'
import { cn } from '../ui'
import type { AccesoRapido } from './accesosRapidos'
import type { NavItem } from './navigation'

const ANCHO_ACCESOS = 208 // w-52

/** De qué vista es el panel abierto y dónde va. */
export interface AccesosAbiertos {
  item: NavItem
  /** Color del módulo de la vista. */
  sys: string
  /** El renglón de la vista: el panel sale a su altura. */
  fila: DOMRect
  /** El borde de la lista (el submenú o el sider): el panel sale pegado a su costado. */
  borde: DOMRect
}

/** El ícono de un acceso, según lo que hace el botón. */
function IconoAcceso({ etiqueta }: { etiqueta: string }) {
  const props = { size: 12, strokeWidth: 2.5 }
  if (/^(Nuev|Agregar|Asignar|Armar|Crear)/.test(etiqueta)) return <Plus {...props} />
  if (/^Importar/.test(etiqueta)) return <Upload {...props} />
  if (/^(Exportar|Excel|PDF|Descargar|Reporte)/.test(etiqueta)) return <Download {...props} />
  return <ArrowUpRight {...props} />
}

/**
 * El panel con los botones de una vista, pegado a la lista a la altura del renglón de esa vista. Va a la derecha y, si
 * no entra (la barra de abajo deja el submenú cerca del borde), a la izquierda.
 *
 * Si la vista tiene pestañas internas, los botones van agrupados bajo el nombre de su pestaña.
 */
export function PanelAccesos({
  refPanel,
  abierto: { item, sys, fila, borde },
  accesos,
  onEntrar,
  onSalir,
  onElegir,
}: {
  refPanel: RefObject<HTMLDivElement | null>
  abierto: AccesosAbiertos
  accesos: AccesoRapido[]
  onEntrar: () => void
  onSalir: () => void
  onElegir: (acceso: AccesoRapido) => void
}) {
  // Agrupados por pestaña, en el orden en que aparecen. Los de la vista sin pestañas van en un grupo sin nombre.
  const grupos: { pestana?: string; accesos: AccesoRapido[] }[] = []
  for (const acceso of accesos) {
    const grupo = grupos.find((g) => g.pestana === acceso.pestana)
    if (grupo) grupo.accesos.push(acceso)
    else grupos.push({ pestana: acceso.pestana, accesos: [acceso] })
  }

  const aLaDerecha = borde.right + 6 + ANCHO_ACCESOS <= window.innerWidth - 8
  const left = aLaDerecha ? borde.right + 6 : Math.max(8, borde.left - 6 - ANCHO_ACCESOS)
  // Arriba del todo va el título (unos 30px): se sube para que el primer botón quede a la altura del renglón.
  const alto = Math.min(40 + accesos.length * 34 + grupos.filter((g) => g.pestana).length * 26, window.innerHeight * 0.7)
  const top = Math.max(8, Math.min(fila.top - 34, window.innerHeight - alto - 8))

  return (
    <div
      ref={refPanel}
      data-sys={sys}
      role="menu"
      aria-label={`Acciones de ${item.label}`}
      style={{ top, left }}
      onMouseEnter={onEntrar}
      onMouseLeave={onSalir}
      className={cn(
        'fixed z-50 max-h-[70vh] w-52 overflow-y-auto rounded-panel border border-line bg-white p-1.5 shadow-panel',
        'transition-[opacity,translate] duration-100 starting:opacity-0',
        aLaDerecha ? 'starting:-translate-x-1' : 'starting:translate-x-1',
      )}
    >
      <p className="truncate px-2.5 pt-1 pb-2 text-[11px] font-semibold tracking-wider text-[rgb(var(--sys-ink-rgb))] uppercase">
        {item.label}
      </p>
      {grupos.map((grupo, i) => (
        <div key={grupo.pestana ?? ''} className={cn(i > 0 && 'mt-1 border-t border-line pt-1')}>
          {grupo.pestana && (
            <p className="truncate px-2.5 pt-1 pb-0.5 text-[11px] font-medium text-ink-soft">{grupo.pestana}</p>
          )}
          {grupo.accesos.map((acceso) => (
            <button
              key={acceso.texto ?? acceso.etiqueta}
              type="button"
              role="menuitem"
              onClick={() => onElegir(acceso)}
              className={cn(
                'flex w-full cursor-pointer items-center gap-2.5 rounded-lg px-2.5 py-1.5 text-[13px] text-ink-muted transition-colors',
                'hover:bg-[rgb(var(--sys-rgb)/0.1)] hover:text-[rgb(var(--sys-ink-rgb))]',
              )}
            >
              <span className="inline-flex size-5 shrink-0 items-center justify-center rounded-md bg-[rgb(var(--sys-rgb)/0.12)] text-[rgb(var(--sys-rgb))]">
                <IconoAcceso etiqueta={acceso.texto ?? acceso.etiqueta} />
              </span>
              <span className="flex-1 truncate text-left">{acceso.texto ?? acceso.etiqueta}</span>
            </button>
          ))}
        </div>
      ))}
    </div>
  )
}
