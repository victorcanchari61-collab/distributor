import { useEffect, useMemo, useRef, useState } from 'react'
import {
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Home,
  PanelLeft,
  PanelLeftClose,
  PanelLeftOpen,
  PanelRight,
  PanelRightClose,
  PanelRightOpen,
  EyeOff,
  X,
} from 'lucide-react'
import { cn, Logo } from '../ui'
import { NAV_GROUPS, puedeAbrir } from './navigation'
import { SubmenuFlotante } from './SubmenuFlotante'
import { useAccesosAlPasar } from './accesosAlPasar'
import type { NavGroup } from './navigation'
import type { LadoNavegacion } from './formatoNavegacion'
import { usePermisos } from '../../lib/permisos'

/** Espera corta antes de desplegar al pasar el cursor: evita que se abra al cruzar el borde sin querer. */
const ESPERA_HOVER = 140

export interface SidebarProps {
  active: string
  onSelect: (id: string) => void
  /** Colapsado a solo iconos (escritorio). */
  collapsed: boolean
  onToggleCollapsed: () => void
  /** Abierto como panel deslizante (movil). */
  mobileOpen: boolean
  onCloseMobile: () => void
  /** Oculto por completo: la vista gana todo el ancho. */
  oculto: boolean
  onOcultar: () => void
  /** De qué lado de la pantalla se ancla. */
  lado: LadoNavegacion
  /** Mover el menú al otro lado. */
  onLado: (lado: LadoNavegacion) => void
}

export function Sidebar({
  active,
  onSelect,
  collapsed,
  onToggleCollapsed,
  mobileOpen,
  onCloseMobile,
  oculto,
  onOcultar,
  lado,
  onLado,
}: SidebarProps) {
  const { puedeVer, cargando } = usePermisos()
  // Con el sider abierto, pasar el mouse por una vista muestra al lado sus accesos rápidos (Nuevo cliente, Importar…).
  const accesos = useAccesosAlPasar({ onAbrirVista: onSelect })
  const derecha = lado === 'derecha'

  /*
   * El menu solo muestra lo que este usuario puede abrir, y un grupo entero
   * desaparece si no le queda ningun submodulo: un modulo que al desplegarse
   * aparece vacio no informa de nada, solo hace ver el sistema roto.
   *
   * Mientras los permisos cargan no se pinta nada en vez de pintarlo todo: si
   * no, el menu completo parpadearia un instante para quien no lo tiene.
   */
  const grupos = useMemo(() => {
    if (cargando) return []
    return NAV_GROUPS.map((g) => ({ ...g, items: g.items.filter((i) => puedeAbrir(i.id, puedeVer)) })).filter(
      (g) => g.items.length > 0,
    )
  }, [cargando, puedeVer])

  // Empieza abierto el grupo que contiene la vista activa.
  const [open, setOpen] = useState<string[]>(() => {
    const group = NAV_GROUPS.find((g) => g.items.some((i) => i.id === active))
    return group ? [group.id] : []
  })

  // Contraído, el sider se despliega solo al pasar el cursor y vuelve a su ancho de iconos al salir.
  const [desplegadoAlPasar, setDesplegadoAlPasar] = useState(false)
  // En movil el panel deslizante siempre va desplegado: contraer es cosa de escritorio.
  const [escritorio, setEscritorio] = useState(() => window.matchMedia('(min-width: 1024px)').matches)
  const temporizador = useRef<number | undefined>(undefined)
  const cancelarEspera = () => window.clearTimeout(temporizador.current)
  useEffect(() => () => window.clearTimeout(temporizador.current), [])

  useEffect(() => {
    const mq = window.matchMedia('(min-width: 1024px)')
    const cambio = () => {
      setEscritorio(mq.matches)
      if (!mq.matches) setDesplegadoAlPasar(false)
    }
    mq.addEventListener('change', cambio)
    return () => mq.removeEventListener('change', cambio)
  }, [])

  const entrar = () => {
    if (!collapsed || oculto || !escritorio) return
    cancelarEspera()
    temporizador.current = window.setTimeout(() => setDesplegadoAlPasar(true), ESPERA_HOVER)
  }

  const salir = () => {
    cancelarEspera()
    setDesplegadoAlPasar(false)
    if (collapsed) setOpen([])
  }

  // El tirador y el botón del pie fijan el estado: si el cursor lo desplegó, al pulsar queda desplegado.
  const alternar = () => {
    cancelarEspera()
    setDesplegadoAlPasar(false)
    // Al fijar el ancho se cierra lo que hubiera abierto: los paneles flotantes
    // no tienen sentido con el sider ya desplegado.
    setOpen([])
    onToggleCollapsed()
  }

  // `contraido` es lo que se ve: contraído de verdad o desplegado solo por el cursor.
  const contraido = escritorio && collapsed && !desplegadoAlPasar

  const toggleGroup = (id: string) =>
    setOpen((prev) => {
      if (prev.includes(id)) return prev.filter((g) => g !== id)

      // Expandido pueden quedar varios grupos abiertos a la vez; contraido no,
      // porque los paneles flotantes se montarian uno sobre otro.
      return contraido ? [id] : [...prev, id]
    })

  return (
    <>
      {/* velo en movil */}
      {mobileOpen && (
        <div
          className="fixed inset-0 z-30 bg-ink/30 backdrop-blur-[2px] lg:hidden"
          onClick={onCloseMobile}
          aria-hidden="true"
        />
      )}

      <aside
        aria-label="Menú principal"
        onMouseEnter={entrar}
        onMouseLeave={salir}
        className={cn(
          'fixed inset-y-0 z-40 flex w-64 flex-col bg-white',
          'border-line transition-[width,transform] duration-200',
          derecha ? 'right-0 border-l' : 'left-0 border-r',
          // En escritorio manda el estado contraido; en movil el panel deslizante siempre va entero.
          contraido ? 'lg:w-[72px]' : 'lg:w-56',
          mobileOpen ? 'translate-x-0' : derecha ? 'translate-x-full' : '-translate-x-full',
          // Oculto se sale de pantalla deslizandose; el topbar deja un boton
          // para traerlo de vuelta.
          oculto ? (derecha ? 'lg:translate-x-full' : 'lg:-translate-x-full') : 'lg:translate-x-0',
          // La vista previa del cursor flota sobre la vista: se separa con una sombra.
          desplegadoAlPasar && 'lg:shadow-panel',
        )}
      >
        {/* tirador en el borde: contrae o expande sin buscar el pie */}
        {!oculto && (
          <button
            type="button"
            onClick={alternar}
            aria-label={collapsed ? 'Expandir menú' : 'Contraer menú'}
            title={collapsed ? 'Fijar menú expandido' : 'Contraer menú'}
            className={cn(
              'absolute top-1/2 z-50 hidden size-6 -translate-y-1/2 cursor-pointer items-center justify-center',
              'rounded-full border border-line bg-white text-ink-muted shadow-sm transition-colors',
              'hover:border-line-strong hover:text-ink lg:flex',
              derecha ? '-left-3' : '-right-3',
            )}
          >
            {collapsed ? (
              derecha ? <ChevronLeft size={14} /> : <ChevronRight size={14} />
            ) : derecha ? (
              <ChevronRight size={14} />
            ) : (
              <ChevronLeft size={14} />
            )}
          </button>
        )}

        {/* cabecera */}
        <div
          className={cn(
            'flex h-16 shrink-0 items-center border-b border-line px-3',
            contraido ? 'justify-center' : 'justify-between',
          )}
        >
          {contraido ? <Logo variant="mark" size={30} /> : <Logo variant="wordmark" size={26} tagline />}

          <button
            type="button"
            onClick={onCloseMobile}
            aria-label="Cerrar menú"
            className="cursor-pointer rounded-md p-1 text-ink-muted hover:bg-surface-alt lg:hidden"
          >
            <X size={18} />
          </button>
        </div>

        {/* navegacion */}
        <nav className="flex-1 space-y-1 overflow-x-hidden overflow-y-auto p-2">
          {/*
            Inicio va siempre, no dentro de `grupos`.

            No es de ningún módulo y no hay permiso que lo cubra: es justo la
            pantalla de quien todavía no tiene ninguno, desde la que se piden.
            Filtrarlo con el resto lo habría escondido precisamente a quien más
            lo necesita.
          */}
          <div data-sys="brand">
            <NavButton
              icon={<Home size={18} />}
              label="Inicio"
              active={active === ''}
              collapsed={contraido}
              lado={lado}
              onClick={() => onSelect('')}
            />
          </div>

          {grupos.map((group) => (
            <NavGroupBlock
              key={group.id}
              group={group}
              active={active}
              collapsed={contraido}
              lado={lado}
              open={open.includes(group.id)}
              onToggle={() => toggleGroup(group.id)}
              onSelect={onSelect}
              accesos={accesos}
            />
          ))}
        </nav>

        {/* pie: contraer y ocultar */}
        <div
          className={cn(
            'hidden shrink-0 gap-1 border-t border-line p-2 lg:flex',
            contraido && 'flex-col',
          )}
        >
          <button
            type="button"
            onClick={alternar}
            aria-label={collapsed ? 'Expandir menú' : 'Contraer menú'}
            title={collapsed ? 'Fijar expandido' : 'Contraer'}
            className={cn(
              'flex flex-1 cursor-pointer items-center gap-2 rounded-lg px-3 py-2 text-sm',
              'text-ink-muted transition-colors hover:bg-surface-alt hover:text-ink',
              contraido && 'justify-center px-0',
            )}
          >
            {collapsed ? (
              derecha ? <PanelRightOpen size={18} /> : <PanelLeftOpen size={18} />
            ) : derecha ? (
              <PanelRightClose size={18} />
            ) : (
              <PanelLeftClose size={18} />
            )}
            {!contraido && <span>{collapsed ? 'Expandir' : 'Contraer'}</span>}
          </button>

          <button
            type="button"
            onClick={() => {
              cancelarEspera()
              setDesplegadoAlPasar(false)
              onLado(derecha ? 'izquierda' : 'derecha')
            }}
            aria-label={derecha ? 'Mover menú a la izquierda' : 'Mover menú a la derecha'}
            title={derecha ? 'Mover a la izquierda' : 'Mover a la derecha'}
            className={cn(
              'flex cursor-pointer items-center justify-center rounded-lg px-3 py-2',
              'text-ink-muted transition-colors hover:bg-surface-alt hover:text-ink',
            )}
          >
            {derecha ? <PanelLeft size={18} /> : <PanelRight size={18} />}
          </button>

          <button
            type="button"
            onClick={() => {
              cancelarEspera()
              setDesplegadoAlPasar(false)
              onOcultar()
            }}
            aria-label="Ocultar menú"
            title="Ocultar menú"
            className={cn(
              'flex cursor-pointer items-center justify-center rounded-lg px-3 py-2',
              'text-ink-muted transition-colors hover:bg-surface-alt hover:text-ink',
            )}
          >
            <EyeOff size={18} />
          </button>
        </div>
      </aside>

      {accesos.panel}
    </>
  )
}

function NavGroupBlock({
  group,
  active,
  collapsed,
  lado,
  open,
  onToggle,
  onSelect,
  accesos,
}: {
  group: NavGroup
  active: string
  collapsed: boolean
  lado: LadoNavegacion
  open: boolean
  onToggle: () => void
  onSelect: (id: string) => void
  accesos: ReturnType<typeof useAccesosAlPasar>
}) {
  const hasActive = group.items.some((i) => i.id === active)
  const GroupIcon = group.icon
  const derecha = lado === 'derecha'

  // Boton desde el que se abre el panel flotante cuando el sider esta contraido.
  const [ancla, setAncla] = useState<HTMLElement | null>(null)

  // Colapsado: el icono abre un panel flotante con los submodulos, en vez de
  // saltar a ciegas a la primera vista del grupo.
  if (collapsed) {
    return (
      <div data-sys={group.sys}>
        <NavButton
          icon={<GroupIcon size={18} />}
          label={group.label}
          active={hasActive}
          collapsed
          lado={lado}
          onClick={(e) => {
            setAncla(e.currentTarget)
            onToggle()
          }}
        />

        {open && ancla && (
          <SubmenuFlotante
            group={group}
            ancla={ancla}
            active={active}
            lado={lado}
            onSelect={(id) => {
              onSelect(id)
              onToggle()
            }}
            onCerrar={onToggle}
          />
        )}
      </div>
    )
  }

  return (
    <div data-sys={group.sys}>
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={open}
        className={cn(
          'flex w-full cursor-pointer items-center gap-2.5 rounded-lg px-3 py-2 text-sm font-semibold',
          'transition-colors',
          hasActive
            ? 'text-[rgb(var(--sys-ink-rgb))]'
            : 'text-ink-muted hover:bg-surface-alt hover:text-ink',
        )}
      >
        <GroupIcon size={18} className="shrink-0 text-[rgb(var(--sys-rgb))]" />
        <span className="flex-1 truncate text-left">{group.label}</span>
        <ChevronDown
          size={15}
          className={cn('shrink-0 transition-transform duration-200', open && 'rotate-180')}
        />
      </button>

      <div
        className={cn(
          'grid transition-[grid-template-rows] duration-200',
          open ? 'grid-rows-[1fr]' : 'grid-rows-[0fr]',
        )}
      >
        <div className="overflow-hidden">
          <div
            className={cn(
              'mt-1 space-y-0.5 border-line',
              derecha ? 'mr-4 border-r pr-2' : 'ml-4 border-l pl-2',
            )}
          >
            {group.items
              .filter((item) => !item.hidden)
              .map((item) => (
              <NavButton
                key={item.id}
                icon={<item.icon size={16} />}
                label={item.label}
                badge={item.badge}
                pending={item.pending}
                active={active === item.id}
                collapsed={false}
                lado={lado}
                onClick={() => onSelect(item.id)}
                small
                conAccesos={accesos.tieneAccesos(item.id)}
                resaltado={accesos.mostrando(item.id)}
                onMouseEnter={(e) => {
                  // El panel sale pegado al borde del sider, a la altura de este renglón.
                  const sider = e.currentTarget.closest('aside')?.getBoundingClientRect()
                  if (sider) accesos.entrar(item, group.sys, e.currentTarget.getBoundingClientRect(), sider)
                }}
                onMouseLeave={accesos.salir}
                />
              ))}
          </div>
        </div>
      </div>
    </div>
  )
}

function NavButton({
  icon,
  label,
  badge,
  pending = false,
  active,
  collapsed,
  lado = 'izquierda',
  onClick,
  small = false,
  conAccesos = false,
  resaltado = false,
  onMouseEnter,
  onMouseLeave,
}: {
  icon: React.ReactNode
  label: string
  badge?: string
  pending?: boolean
  active: boolean
  collapsed: boolean
  /** De qué lado del sider va el botón: cambia de lado la marca de la vista activa. */
  lado?: LadoNavegacion
  onClick: (e: React.MouseEvent<HTMLButtonElement>) => void
  small?: boolean
  /** La vista tiene accesos rápidos: se marca con una flecha que se ve al pasar el mouse. */
  conAccesos?: boolean
  /** Su panel de accesos está abierto. */
  resaltado?: boolean
  onMouseEnter?: (e: React.MouseEvent<HTMLButtonElement>) => void
  onMouseLeave?: () => void
}) {
  const derecha = lado === 'derecha'
  return (
    <button
      type="button"
      onClick={onClick}
      onMouseEnter={onMouseEnter}
      onMouseLeave={onMouseLeave}
      title={collapsed ? label : pending ? `${label} — vista pendiente` : undefined}
      aria-current={active ? 'page' : undefined}
      className={cn(
        'group relative flex w-full cursor-pointer items-center gap-2.5 rounded-lg transition-colors',
        small ? 'px-2.5 py-1.5 text-[13px]' : 'px-3 py-2 text-sm font-medium',
        collapsed && 'justify-center px-0',
        active
          ? 'bg-[rgb(var(--sys-rgb)/0.1)] font-semibold text-[rgb(var(--sys-ink-rgb))]'
          : cn('text-ink-muted hover:bg-surface-alt hover:text-ink', resaltado && 'bg-surface-alt text-ink'),
      )}
    >
      {active && (
        <span
          className={cn(
            'absolute top-1/2 h-5 w-1 -translate-y-1/2 bg-[rgb(var(--sys-rgb))]',
            derecha ? '-right-2 rounded-l-full' : '-left-2 rounded-r-full',
          )}
        />
      )}
      <span className={cn('shrink-0', active && 'text-[rgb(var(--sys-rgb))]')}>{icon}</span>
      {!collapsed && <span className="flex-1 truncate text-left">{label}</span>}
      {!collapsed && badge && (
        <span className="shrink-0 rounded-full bg-[rgb(var(--sys-rgb)/0.12)] px-1.5 py-0.5 text-[10px] font-bold text-[rgb(var(--sys-ink-rgb))]">
          {badge}
        </span>
      )}
      {/* punto tenue: la vista todavia no existe */}
      {!collapsed && !badge && pending && (
        <span
          aria-hidden="true"
          className="size-1.5 shrink-0 rounded-full bg-line-strong"
          title="Pendiente"
        />
      )}
      {!collapsed && conAccesos && (
        derecha ? (
          <ChevronLeft
            size={14}
            aria-hidden="true"
            className={cn('shrink-0 transition-opacity', resaltado ? 'opacity-100' : 'opacity-0 group-hover:opacity-60')}
          />
        ) : (
          <ChevronRight
            size={14}
            aria-hidden="true"
            className={cn('shrink-0 transition-opacity', resaltado ? 'opacity-100' : 'opacity-0 group-hover:opacity-60')}
          />
        )
      )}
    </button>
  )
}
