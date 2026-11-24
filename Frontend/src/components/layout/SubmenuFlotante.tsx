import { useContext, useEffect, useRef, useState } from 'react'
import type { RefObject } from 'react'
import { createPortal } from 'react-dom'
import { ArrowUpRight, ChevronRight, Download, Plus, Upload } from 'lucide-react'
import { usePermisos } from '../../lib/permisos'
import { cn } from '../ui'
import { AccesoRapidoContexto } from './AccesoRapidoContexto'
import { ACCESOS_RAPIDOS, pulsarAccesoRapido } from './accesosRapidos'
import type { AccesoRapido } from './accesosRapidos'
import type { NavGroup, NavItem } from './navigation'

const ANCHO = 224 // w-56
const ANCHO_ACCESOS = 208 // w-52
/** Al salir del submenú hacia el panel de accesos el mouse cruza un hueco: se espera un poco antes de cerrarlo. */
const GRACIA_CIERRE = 180

/**
 * Las vistas de un grupo en un panel flotante: al lado del sider contraído, o encima de su botón en la barra inferior.
 *
 * Se pinta en un portal con position:fixed anclado al botón, porque dentro del sider (72px) o de la barra quedaría
 * recortado. Entra con una animación corta desde el propio botón.
 *
 * Al pasar el mouse por una vista que tiene botones en su cabecera (Nueva boleta, Nuevo pedido…), al lado sale otro
 * panel con ellos: elegir uno pulsa ese botón y su modal sale encima de la vista actual (ver accesosRapidos.ts).
 */
export function SubmenuFlotante({
  group,
  ancla,
  active,
  onSelect,
  onCerrar,
  colocacion = 'derecha',
}: {
  group: NavGroup
  ancla: HTMLElement
  active: string
  onSelect: (id: string) => void
  onCerrar: () => void
  /** A la derecha del sider (por defecto) o encima del botón, para la barra inferior. */
  colocacion?: 'derecha' | 'arriba'
}) {
  const ref = useRef<HTMLDivElement>(null)
  const refAccesos = useRef<HTMLDivElement>(null)
  const [visible, setVisible] = useState(false)
  const [pos, setPos] = useState<{ top?: number; bottom?: number; left: number } | null>(null)
  const arriba = colocacion === 'arriba'
  const { puede } = usePermisos()
  const usarAcceso = useContext(AccesoRapidoContexto)

  // La vista bajo el mouse que muestra sus accesos, y el renglón del que salen (para colocar el panel a su altura).
  const [conAccesos, setConAccesos] = useState<{ item: NavItem; fila: DOMRect; submenu: DOMRect } | null>(null)
  const temporizador = useRef<number | undefined>(undefined)
  const seguirAbierto = () => window.clearTimeout(temporizador.current)
  const cerrarLuego = () => {
    seguirAbierto()
    temporizador.current = window.setTimeout(() => setConAccesos(null), GRACIA_CIERRE)
  }
  useEffect(() => () => window.clearTimeout(temporizador.current), [])

  /** Los accesos de una vista que esta persona puede usar. */
  const accesosDe = (id: string): AccesoRapido[] =>
    (ACCESOS_RAPIDOS[id] ?? []).filter((a) => !a.permiso || puede(a.submodulo ?? id, a.permiso))

  useEffect(() => {
    const colocar = () => {
      const r = ancla.getBoundingClientRect()

      if (arriba) {
        // Centrado sobre el botón, sin salirse de la pantalla.
        const centro = r.left + r.width / 2 - ANCHO / 2
        setPos({
          bottom: window.innerHeight - r.top + 8,
          left: Math.min(Math.max(8, centro), window.innerWidth - ANCHO - 8),
        })
        return
      }

      const alto = 52 + group.items.length * 34
      // Se ancla al borde del sider, no al del icono: si no, el panel se monta
      // sobre la propia barra porque el boton esta centrado dentro de ella.
      const barra = ancla.closest('aside')?.getBoundingClientRect()
      setPos({
        // Si el grupo esta al final del sider, el panel sube para no cortarse.
        top: Math.min(r.top, Math.max(8, window.innerHeight - alto - 8)),
        left: (barra?.right ?? r.right) + 8,
      })
    }

    colocar()
    const id = requestAnimationFrame(() => setVisible(true))

    const fuera = (e: MouseEvent) => {
      const t = e.target as Node
      if (!ref.current?.contains(t) && !refAccesos.current?.contains(t) && !ancla.contains(t)) onCerrar()
    }
    const escape = (e: KeyboardEvent) => e.key === 'Escape' && onCerrar()
    // Al moverse la página el renglón ya no está donde se midió.
    const soltarAccesos = () => setConAccesos(null)

    document.addEventListener('mousedown', fuera)
    document.addEventListener('keydown', escape)
    window.addEventListener('resize', colocar)
    window.addEventListener('scroll', colocar, true)
    window.addEventListener('scroll', soltarAccesos, true)

    return () => {
      cancelAnimationFrame(id)
      document.removeEventListener('mousedown', fuera)
      document.removeEventListener('keydown', escape)
      window.removeEventListener('resize', colocar)
      window.removeEventListener('scroll', colocar, true)
      window.removeEventListener('scroll', soltarAccesos, true)
    }
  }, [ancla, arriba, group.items.length, onCerrar])

  if (!pos) return null

  const accesos = conAccesos ? accesosDe(conAccesos.item.id) : []

  return createPortal(
    <>
      <div
        ref={ref}
        data-sys={group.sys}
        style={{ top: pos.top, bottom: pos.bottom, left: pos.left }}
        onMouseLeave={cerrarLuego}
        className={cn(
          'fixed z-50 w-56 rounded-panel border border-line bg-white p-1.5 shadow-panel',
          arriba ? 'max-h-[70vh] origin-bottom overflow-y-auto' : 'origin-left',
          'transition-all duration-150',
          visible
            ? 'translate-x-0 translate-y-0 scale-100 opacity-100'
            : arriba
              ? 'translate-y-2 scale-95 opacity-0'
              : '-translate-x-2 scale-95 opacity-0',
        )}
      >
        <p className="px-2.5 pt-1 pb-2 text-[11px] font-semibold tracking-wider text-[rgb(var(--sys-ink-rgb))] uppercase">
          {group.label}
        </p>

        {group.items
          .filter((item) => !item.hidden)
          .map((item) => {
            const tieneAccesos = accesosDe(item.id).length > 0
            const mostrando = conAccesos?.item.id === item.id
            return (
              <button
                key={item.id}
                type="button"
                onClick={() => onSelect(item.id)}
                onMouseEnter={(e) => {
                  seguirAbierto()
                  const submenu = ref.current?.getBoundingClientRect()
                  setConAccesos(
                    tieneAccesos && submenu ? { item, fila: e.currentTarget.getBoundingClientRect(), submenu } : null,
                  )
                }}
                className={cn(
                  // Todas llevan el borde (transparente) para que el texto no salte al marcarse la activa. La activa: borde
                  // fino del color del módulo alrededor y uno grueso a la izquierda, con las esquinas redondeadas.
                  'flex w-full cursor-pointer items-center gap-2.5 rounded-lg border border-l-[3px] px-2.5 py-1.5 text-[13px]',
                  'transition-colors',
                  active === item.id
                    ? 'border-[rgb(var(--sys-rgb)/0.3)] border-l-[rgb(var(--sys-rgb))] bg-[rgb(var(--sys-rgb)/0.12)] font-semibold text-[rgb(var(--sys-ink-rgb))]'
                    : cn('border-transparent text-ink-muted hover:bg-surface-alt hover:text-ink', mostrando && 'bg-surface-alt text-ink'),
                )}
              >
                <item.icon size={15} className={cn('shrink-0', active === item.id && 'text-[rgb(var(--sys-rgb))]')} />
                <span className="flex-1 truncate text-left">{item.label}</span>
                {item.badge && (
                  <span className="rounded-full bg-[rgb(var(--sys-rgb)/0.12)] px-1.5 py-0.5 text-[10px] font-bold text-[rgb(var(--sys-ink-rgb))]">
                    {item.badge}
                  </span>
                )}
                {!item.badge && item.pending && <span aria-hidden="true" className="size-1.5 rounded-full bg-line-strong" />}
                {/* Avisa que al lado hay más: los botones de esa vista. */}
                {tieneAccesos && (
                  <ChevronRight
                    size={14}
                    aria-hidden="true"
                    className={cn('shrink-0 transition-opacity', mostrando ? 'opacity-100' : 'opacity-40')}
                  />
                )}
              </button>
            )
          })}
      </div>

      {conAccesos && accesos.length > 0 && (
        <PanelAccesos
          refPanel={refAccesos}
          sys={group.sys}
          item={conAccesos.item}
          fila={conAccesos.fila}
          submenu={conAccesos.submenu}
          accesos={accesos}
          onEntrar={seguirAbierto}
          onSalir={cerrarLuego}
          onElegir={(acceso) => {
            const vista = conAccesos.item.id
            onCerrar()
            // Con el panel de pestañas, el modal sale sobre la vista actual; sin él, se abre la vista y se pulsa ahí.
            if (usarAcceso) usarAcceso(vista, acceso)
            else {
              onSelect(vista)
              pulsarAccesoRapido(vista, acceso, () => {})
            }
          }}
        />
      )}
    </>,
    document.body,
  )
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
 * El panel con los botones de una vista, pegado al submenú a la altura del renglón de esa vista. Va a la derecha y,
 * si no entra (la barra de abajo deja el submenú cerca del borde), a la izquierda.
 *
 * Si la vista tiene pestañas internas, los botones van agrupados bajo el nombre de su pestaña.
 */
function PanelAccesos({
  refPanel,
  sys,
  item,
  fila,
  submenu,
  accesos,
  onEntrar,
  onSalir,
  onElegir,
}: {
  refPanel: RefObject<HTMLDivElement | null>
  sys: string
  item: NavItem
  fila: DOMRect
  submenu: DOMRect
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

  const aLaDerecha = submenu.right + 6 + ANCHO_ACCESOS <= window.innerWidth - 8
  const left = aLaDerecha ? submenu.right + 6 : Math.max(8, submenu.left - 6 - ANCHO_ACCESOS)
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