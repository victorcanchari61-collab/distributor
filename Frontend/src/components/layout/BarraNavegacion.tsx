import { useMemo, useState } from 'react'
import { ChevronDown, ChevronUp, Home } from 'lucide-react'
import { cn } from '../ui'
import { usePermisos } from '../../lib/permisos'
import { NAV_GROUPS, puedeAbrir } from './navigation'
import { SubmenuFlotante } from './SubmenuFlotante'

const BOTON = 'flex shrink-0 cursor-pointer items-center rounded-full px-3 py-2 text-sm font-semibold transition-colors'
const ACTIVO =
  'bg-[rgb(var(--sys-rgb)/0.16)] text-[rgb(var(--sys-ink-rgb))] shadow-[inset_3px_0_0_rgb(var(--sys-rgb))]'
const INACTIVO = 'text-ink-muted hover:bg-[rgb(var(--sys-rgb)/0.08)] hover:text-[rgb(var(--sys-ink-rgb))]'

/** Dónde va la barra: fija abajo o dentro de la franja de arriba. */
export type ColocacionBarra = 'inferior' | 'superior'

/**
 * El otro formato de navegación: una barra con Inicio y un botón por módulo. Cada módulo abre la lista de sus vistas
 * hacia arriba (barra inferior) o hacia abajo (barra superior). Lee los mismos grupos que el menú lateral, así los tres
 * formatos muestran siempre lo mismo.
 *
 * Abajo siempre está a la vista: no se esconde ni se mueve. El módulo de la vista abierta muestra su nombre; los demás,
 * solo el ícono (con tantos módulos no entran todos con nombre) y su nombre al pasar el mouse.
 */
export function BarraNavegacion({
  active,
  onSelect,
  colocacion = 'inferior',
}: {
  active: string
  onSelect: (id: string) => void
  colocacion?: ColocacionBarra
}) {
  const { puedeVer, cargando } = usePermisos()
  const [abierto, setAbierto] = useState<{ id: string; ancla: HTMLElement } | null>(null)
  const superior = colocacion === 'superior'

  // Como en el menú lateral: solo lo que esta persona puede abrir, y sin módulos vacíos.
  const grupos = useMemo(() => {
    if (cargando) return []
    return NAV_GROUPS.map((g) => ({ ...g, items: g.items.filter((i) => !i.hidden && puedeAbrir(i.id, puedeVer)) })).filter(
      (g) => g.items.length > 0,
    )
  }, [cargando, puedeVer])

  const grupoAbierto = grupos.find((g) => g.id === abierto?.id)

  return (
    <nav
      aria-label="Menú principal"
      className={cn(
        'pointer-events-none z-40 flex',
        superior ? 'relative w-full justify-start' : 'fixed inset-x-0 bottom-0 justify-center px-3 pb-3',
      )}
    >
      <div
        // SysDataTable solo aparta la paginación de la barra fija de abajo.
        data-barra-inferior={superior ? undefined : true}
        className={cn(
          'pointer-events-auto flex max-w-full items-center gap-1 overflow-x-auto rounded-full border border-line bg-white p-1.5 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden',
          superior ? 'shadow-sm' : 'shadow-panel',
        )}
      >
        <div data-sys="brand" className="shrink-0">
          <button
            type="button"
            onClick={() => {
              setAbierto(null)
              onSelect('')
            }}
            aria-current={active === '' ? 'page' : undefined}
            className={cn(BOTON, 'gap-2 px-4', active === '' ? ACTIVO : INACTIVO)}
          >
            <Home size={17} />
            Inicio
          </button>
        </div>

        {grupos.map((grupo) => {
          const tieneActiva = grupo.items.some((i) => i.id === active)
          const desplegado = abierto?.id === grupo.id
          return (
            <div key={grupo.id} data-sys={grupo.sys} className="shrink-0">
              <button
                type="button"
                aria-haspopup="menu"
                aria-expanded={desplegado}
                aria-label={grupo.label}
                title={grupo.label}
                onClick={(e) => {
                  const ancla = e.currentTarget
                  setAbierto((previo) => (previo?.id === grupo.id ? null : { id: grupo.id, ancla }))
                }}
                className={cn(BOTON, 'group', tieneActiva || desplegado ? ACTIVO : INACTIVO)}
              >
                <grupo.icon size={17} className="shrink-0 text-[rgb(var(--sys-rgb))]" />
                {/* El nombre: siempre en el módulo activo (o el desplegado); en los demás, al pasar el mouse. */}
                <span
                  aria-hidden="true"
                  className={cn(
                    'grid transition-[grid-template-columns,opacity] duration-200 ease-out',
                    tieneActiva || desplegado
                      ? 'grid-cols-[1fr] opacity-100'
                      : 'grid-cols-[0fr] opacity-0 group-hover:grid-cols-[1fr] group-hover:opacity-100 group-focus-visible:grid-cols-[1fr] group-focus-visible:opacity-100',
                  )}
                >
                  <span className="overflow-hidden whitespace-nowrap">
                    <span className="block pl-2">{grupo.label}</span>
                  </span>
                </span>
                {tieneActiva &&
                  (superior ? (
                    <ChevronDown size={14} className={cn('ml-1.5 transition-transform duration-200', desplegado && 'rotate-180')} />
                  ) : (
                    <ChevronUp size={14} className={cn('ml-1.5 transition-transform duration-200', !desplegado && 'rotate-180')} />
                  ))}
              </button>
            </div>
          )
        })}
      </div>

      {grupoAbierto && abierto && (
        <SubmenuFlotante
          group={grupoAbierto}
          ancla={abierto.ancla}
          active={active}
          colocacion={superior ? 'abajo' : 'arriba'}
          onSelect={(id) => {
            setAbierto(null)
            onSelect(id)
          }}
          onCerrar={() => setAbierto(null)}
        />
      )}
    </nav>
  )
}
