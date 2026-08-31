import { useState } from 'react'
import { ChevronDown, PanelLeftClose, PanelLeftOpen, X } from 'lucide-react'
import { cn, Logo } from '../ui'
import { NAV_GROUPS } from './navigation'
import type { NavGroup } from './navigation'

export interface SidebarProps {
  active: string
  onSelect: (id: string) => void
  /** Colapsado a solo iconos (escritorio). */
  collapsed: boolean
  onToggleCollapsed: () => void
  /** Abierto como panel deslizante (movil). */
  mobileOpen: boolean
  onCloseMobile: () => void
}

export function Sidebar({
  active,
  onSelect,
  collapsed,
  onToggleCollapsed,
  mobileOpen,
  onCloseMobile,
}: SidebarProps) {
  // Empieza abierto el grupo que contiene la vista activa.
  const [open, setOpen] = useState<string[]>(() => {
    const group = NAV_GROUPS.find((g) => g.items.some((i) => i.id === active))
    return group ? [group.id] : []
  })

  const toggleGroup = (id: string) =>
    setOpen((prev) => (prev.includes(id) ? prev.filter((g) => g !== id) : [...prev, id]))

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
          collapsed ? 'w-[72px]' : 'w-64',
          mobileOpen ? 'translate-x-0' : '-translate-x-full',
          'lg:translate-x-0',
        )}
      >
        {/* cabecera */}
        <div
          className={cn(
            'flex h-16 shrink-0 items-center border-b border-line px-3',
            collapsed ? 'justify-center' : 'justify-between',
          )}
        >
          {collapsed ? (
            <Logo size="sm" showText={false} />
          ) : (
            <Logo size="sm" text="DISTRIBUIDORA" />
          )}

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
          {NAV_GROUPS.map((group) => (
            <NavGroupBlock
              key={group.id}
              group={group}
              active={active}
              collapsed={collapsed}
              open={open.includes(group.id)}
              onToggle={() => toggleGroup(group.id)}
              onSelect={onSelect}
            />
          ))}
        </nav>

        {/* pie: colapsar */}
        <div className="shrink-0 border-t border-line p-2">
          <button
            type="button"
            onClick={onToggleCollapsed}
            aria-label={collapsed ? 'Expandir menú' : 'Contraer menú'}
            className={cn(
              'hidden w-full cursor-pointer items-center gap-2 rounded-lg px-3 py-2 text-sm',
              'text-ink-muted transition-colors hover:bg-surface-alt hover:text-ink lg:flex',
              collapsed && 'justify-center px-0',
            )}
          >
            {collapsed ? <PanelLeftOpen size={18} /> : <PanelLeftClose size={18} />}
            {!collapsed && <span>Contraer</span>}
          </button>
        </div>
      </aside>
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
}: {
  group: NavGroup
  active: string
  collapsed: boolean
  open: boolean
  onToggle: () => void
  onSelect: (id: string) => void
}) {
  const hasActive = group.items.some((i) => i.id === active)
  const GroupIcon = group.icon

  // Colapsado: solo el icono del grupo, que lleva a su primera vista.
  if (collapsed) {
    return (
      <div data-sys={group.sys}>
        <NavButton
          icon={<GroupIcon size={18} />}
          label={group.label}
          active={hasActive}
          collapsed
          onClick={() => onSelect(group.items[0].id)}
        />
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
            {group.items.map((item) => (
              <NavButton
                key={item.id}
                icon={<item.icon size={16} />}
                label={item.label}
                badge={item.badge}
                active={active === item.id}
                collapsed={false}
                onClick={() => onSelect(item.id)}
                small
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
  active,
  collapsed,
  onClick,
  small = false,
}: {
  icon: React.ReactNode
  label: string
  badge?: string
  active: boolean
  collapsed: boolean
  onClick: () => void
  small?: boolean
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      title={collapsed ? label : undefined}
      aria-current={active ? 'page' : undefined}
      className={cn(
        'group relative flex w-full cursor-pointer items-center gap-2.5 rounded-lg transition-colors',
        small ? 'px-2.5 py-1.5 text-[13px]' : 'px-3 py-2 text-sm font-medium',
        collapsed && 'justify-center px-0',
        active
          ? 'bg-[rgb(var(--sys-rgb)/0.1)] font-semibold text-[rgb(var(--sys-ink-rgb))]'
          : 'text-ink-muted hover:bg-surface-alt hover:text-ink',
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
    </button>
  )
}
