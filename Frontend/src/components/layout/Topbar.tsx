import { Bell, LogOut, Menu, Search } from 'lucide-react'
import { cn } from '../ui'

export interface TopbarProps {
  userName: string
  userEmail: string
  onOpenMenu: () => void
  onLogout: () => void
}

export function Topbar({
  userName,
  userEmail,
  onOpenMenu,
  onLogout,
}: TopbarProps) {
  return (
    <header className="sticky top-0 z-20 flex h-16 shrink-0 items-center gap-3 border-b border-line bg-white px-4 sm:px-6">
      <button
        type="button"
        onClick={onOpenMenu}
        aria-label="Abrir menú"
        className="cursor-pointer rounded-lg p-2 text-ink-muted transition-colors hover:bg-surface-alt lg:hidden"
      >
        <Menu size={20} />
      </button>

      {/* El titulo de la vista vive en la propia pagina (PageHeader), no aqui. */}
      <div className="flex-1" />

      <div className="relative hidden md:block">
        <Search
          size={15}
          className="pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-ink-soft"
        />
        <input
          type="search"
          placeholder="Buscar en el sistema..."
          className={cn(
            'w-64 rounded-lg border border-line bg-surface-alt py-2 pr-3 pl-9 text-sm outline-none',
            'transition-colors placeholder:text-ink-soft',
            'focus:border-[rgb(var(--sys-rgb)/0.6)] focus:bg-white focus:ring-2 focus:ring-[rgb(var(--sys-rgb)/0.15)]',
          )}
        />
      </div>

      <button
        type="button"
        aria-label="Notificaciones"
        className="relative cursor-pointer rounded-lg p-2 text-ink-muted transition-colors hover:bg-surface-alt"
      >
        <Bell size={19} />
        <span className="absolute top-1.5 right-1.5 size-2 rounded-full bg-[rgb(var(--sys-rgb))] ring-2 ring-white" />
      </button>

      <div className="flex items-center gap-2 border-l border-line pl-3">
        <span className="hidden text-right sm:block">
          <span className="block text-sm leading-tight font-semibold text-ink">{userName}</span>
          <span className="block text-[11px] text-ink-muted">{userEmail}</span>
        </span>
        <span
          aria-hidden="true"
          className="inline-flex size-9 items-center justify-center rounded-full bg-[rgb(var(--sys-rgb))] text-sm font-bold text-[var(--sys-on)]"
        >
          {userName.charAt(0).toUpperCase()}
        </span>
        <button
          type="button"
          onClick={onLogout}
          aria-label="Cerrar sesión"
          title="Cerrar sesión"
          className="cursor-pointer rounded-lg p-2 text-ink-muted transition-colors hover:bg-surface-alt hover:text-ink"
        >
          <LogOut size={18} />
        </button>
      </div>
    </header>
  )
}
