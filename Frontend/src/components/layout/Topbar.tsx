import { useCallback, useEffect, useRef, useState } from 'react'
import { AlertTriangle, Bell, LogOut, Menu, PackageX, PanelLeftOpen, Search } from 'lucide-react'
import { cn } from '../ui'
import { alertaApi } from '../../lib/alertasApi'
import type { AlertaResponse } from '../../lib/alertasApi'
import { useRealtime } from '../../lib/realtime'

export interface TopbarProps {
  /** El sider esta oculto: se muestra el boton para traerlo de vuelta. */
  siderOculto: boolean
  onMostrarSider: () => void
  userName: string
  userEmail: string
  onOpenMenu: () => void
  /** Navega a una vista del menú por su id ("inv.stock"), al tocar una alerta. */
  onNavigate: (id: string) => void
  onLogout: () => void
}

export function Topbar({
  siderOculto,
  onMostrarSider,
  userName,
  userEmail,
  onOpenMenu,
  onNavigate,
  onLogout,
}: TopbarProps) {
  const [alertas, setAlertas] = useState<AlertaResponse[]>([])
  const [abierto, setAbierto] = useState(false)
  const contenedorRef = useRef<HTMLDivElement>(null)

  const cargar = useCallback(() => {
    void alertaApi.getAll().then(setAlertas).catch(() => {
      // Sin alertas la app sigue funcionando: solo no avisa. No hay
      // pantalla de error para esto, es un adorno del topbar.
    })
  }, [])

  useEffect(() => {
    cargar()
  }, [cargar])

  // Cualquiera de estos módulos puede crear, resolver o vencer una alerta.
  useRealtime(['stock', 'compras', 'recepciones', 'notasventa', 'pedidos'], cargar)

  useEffect(() => {
    if (!abierto) return
    const onClickFuera = (e: MouseEvent) => {
      if (contenedorRef.current && !contenedorRef.current.contains(e.target as Node)) {
        setAbierto(false)
      }
    }
    document.addEventListener('mousedown', onClickFuera)
    return () => document.removeEventListener('mousedown', onClickFuera)
  }, [abierto])

  const criticas = alertas.filter((a) => a.severidad === 'CRITICA').length

  const irA = (a: AlertaResponse) => {
    setAbierto(false)
    if (a.ruta) onNavigate(a.ruta)
  }

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

      {/* Solo aparece con el sider oculto: es la unica forma de recuperarlo. */}
      {siderOculto && (
        <button
          type="button"
          onClick={onMostrarSider}
          aria-label="Mostrar menú"
          title="Mostrar menú"
          className="hidden cursor-pointer rounded-lg p-2 text-ink-muted transition-colors hover:bg-surface-alt hover:text-ink lg:block"
        >
          <PanelLeftOpen size={20} />
        </button>
      )}

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
            'focus:border-line-strong focus:bg-white',
          )}
        />
      </div>

      <div ref={contenedorRef} className="relative">
        <button
          type="button"
          aria-label="Notificaciones"
          onClick={() => setAbierto((a) => !a)}
          className="relative cursor-pointer rounded-lg p-2 text-ink-muted transition-colors hover:bg-surface-alt"
        >
          <Bell size={19} />
          {alertas.length > 0 && (
            <span
              className={cn(
                'absolute top-0.5 right-0.5 flex size-4 items-center justify-center rounded-full text-[9px] font-bold text-white ring-2 ring-white',
                criticas > 0 ? 'bg-red-600' : 'bg-amber-500',
              )}
            >
              {alertas.length > 9 ? '9+' : alertas.length}
            </span>
          )}
        </button>

        {abierto && (
          <div className="absolute top-full right-0 z-30 mt-2 w-80 rounded-panel border border-line bg-white shadow-panel sm:w-96">
            <div className="border-b border-line px-4 py-3">
              <h3 className="text-sm font-bold text-ink">Alertas</h3>
              <p className="text-xs text-ink-soft">
                {alertas.length === 0 ? 'Todo en orden' : `${alertas.length} cosas para revisar`}
              </p>
            </div>

            <div className="max-h-96 overflow-y-auto">
              {alertas.length === 0 ? (
                <p className="px-4 py-6 text-center text-sm text-ink-soft">No hay nada pendiente.</p>
              ) : (
                alertas.map((a) => (
                  <button
                    key={a.id}
                    type="button"
                    onClick={() => irA(a)}
                    disabled={!a.ruta}
                    className={cn(
                      'flex w-full items-start gap-3 border-b border-line px-4 py-3 text-left last:border-0',
                      a.ruta ? 'cursor-pointer hover:bg-surface-alt' : 'cursor-default',
                    )}
                  >
                    <span
                      className={cn(
                        'mt-0.5 shrink-0 rounded-full p-1.5',
                        a.severidad === 'CRITICA' ? 'bg-red-50 text-red-600' : 'bg-amber-50 text-amber-600',
                      )}
                    >
                      {a.tipo === 'LOTE_POR_VENCER' ? <PackageX size={14} /> : <AlertTriangle size={14} />}
                    </span>
                    <span className="min-w-0">
                      <span className="block truncate text-sm font-semibold text-ink">{a.titulo}</span>
                      <span className="block truncate text-xs text-ink-soft">{a.detalle}</span>
                    </span>
                  </button>
                ))
              )}
            </div>
          </div>
        )}
      </div>

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
