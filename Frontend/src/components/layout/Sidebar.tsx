import { useEffect, useMemo, useState } from 'react'
import { ChevronDown, ChevronRight, Home, PanelLeftClose, PanelLeftOpen, EyeOff, X } from 'lucide-react'
import { cn, Logo } from '../ui'
import { NAV_GROUPS, puedeAbrir } from './navigation'
import { SubmenuFlotante } from './SubmenuFlotante'
import { useAccesosAlPasar } from './accesosAlPasar'
import type { NavGroup } from './navigation'
import { usePermisos } from '../../lib/permisos'

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
}: SidebarProps) {
  const { puedeVer, cargando } = usePermisos()
  // Con el sider abierto, pasar el mouse por una vista muestra al lado sus accesos rápidos (Nuevo cliente, Importar…).
  const accesos = useAccesosAlPasar({ onAbrirVista: onSelect })

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

  // Al cambiar de contraido a expandido (o al reves) se cierra lo que hubiera
  // abierto: un panel flotante no tiene sentido con el sider ya desplegado.
  useEffect(() => {
    setOpen([])
  }, [collapsed])

  const toggleGroup = (id: string) =>
    setOpen((prev) => {
      if (prev.includes(id)) return prev.filter((g) => g !== id)

      // Expandido pueden quedar varios grupos abiertos a la vez; contraido no,
      // porque los paneles flotantes se montarian uno sobre otro.
      return collapsed ? [id] : [...prev, id]
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
        className={cn(
          'fixed inset-y-0 left-0 z-40 flex flex-col border-r border-line bg-white',
          'transition-[width,transform] duration-200',
          collapsed ? 'w-[72px]' : 'w-56',
          mobileOpen ? 'translate-x-0' : '-translate-x-full',
          // Oculto se sale de pantalla deslizandose; el topbar deja un boton
          // para traerlo de vuelta.
          oculto ? 'lg:-translate-x-full' : 'lg:translate-x-0',
        )}
      >
        {/* cabecera */}
        <div
          className={cn(
            'flex h-16 shrink-0 items-center border-b border-line px-3',
            collapsed ? 'justify-center' : 'justify-between',
          )}
        >
          {collapsed ? <Logo variant="mark" size={30} /> : <Logo variant="wordmark" size={26} tagline />}

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
              collapsed={collapsed}
              onClick={() => onSelect('')}
            />
          </div>

          {grupos.map((group) => (
            <NavGroupBlock
              key={group.id}
              group={group}
              active={active}
              collapsed={collapsed}
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
            collapsed && 'flex-col',
          )}
        >
          <button
            type="button"
            onClick={onToggleCollapsed}
            aria-label={collapsed ? 'Expandir menú' : 'Contraer menú'}
            title={collapsed ? 'Expandir' : 'Contraer'}
            className={cn(
              'flex flex-1 cursor-pointer items-center gap-2 rounded-lg px-3 py-2 text-sm',
              'text-ink-muted transition-colors hover:bg-surface-alt hover:text-ink',
              collapsed && 'justify-center px-0',
            )}
          >
            {collapsed ? <PanelLeftOpen size={18} /> : <PanelLeftClose size={18} />}
            {!collapsed && <span>Contraer</span>}
          </button>

          <button
            type="button"
            onClick={onOcultar}
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
  open,
  onToggle,
  onSelect,
  accesos,
}: {
  group: NavGroup
  active: string
  collapsed: boolean
  open: boolean
  onToggle: () => void
  onSelect: (id: string) => void
  accesos: ReturnType<typeof useAccesosAlPasar>
}) {
  const hasActive = group.items.some((i) => i.id === active)
  const GroupIcon = group.icon

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
          <div className="mt-1 ml-4 space-y-0.5 border-l border-line pl-2">
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
  onClick: (e: React.MouseEvent<HTMLButtonElement>) => void
  small?: boolean
  /** La vista tiene accesos rápidos: se marca con una flecha que se ve al pasar el mouse. */
  conAccesos?: boolean
  /** Su panel de accesos está abierto. */
  resaltado?: boolean
  onMouseEnter?: (e: React.MouseEvent<HTMLButtonElement>) => void
  onMouseLeave?: () => void
}) {
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
        <span className="absolute top-1/2 -left-2 h-5 w-1 -translate-y-1/2 rounded-r-full bg-[rgb(var(--sys-rgb))]" />
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
        <ChevronRight
          size={14}
          aria-hidden="true"
          className={cn('shrink-0 transition-opacity', resaltado ? 'opacity-100' : 'opacity-0 group-hover:opacity-60')}
        />
      )}
    </button>
  )
}
