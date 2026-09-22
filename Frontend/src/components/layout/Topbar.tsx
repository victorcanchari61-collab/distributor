import { useCallback, useEffect, useRef, useState } from 'react'
import {
  AlertTriangle,
  Bell,
  Check,
  CheckCheck,
  LockKeyhole,
  LogOut,
  Menu,
  PackageCheck,
  PackageX,
  PanelLeftOpen,
  Search,
} from 'lucide-react'
import { cn } from '../ui'
import { alertaApi } from '../../lib/alertasApi'
import type { AlertaResponse } from '../../lib/alertasApi'
import { alertasLeidas, marcarLeida, marcarTodasLeidas } from '../../lib/alertasLeidas'
import { useRealtime } from '../../lib/realtime'
import { resolveNav } from './navigation'

/** Como se lee la accion pedida, sin la pantalla al lado. */
const ACCION_PEDIDA: Record<string, string> = {
  ver: 'entrar',
  crear: 'crear',
  editar: 'editar',
  anular: 'anular',
  eliminar: 'eliminar',
  exportar: 'exportar',
  importar: 'importar',
  confirmar: 'confirmar',
  cobrar: 'cobrar',
}
import { urlImagen } from '../../features/tms/flotaApi'

export interface TopbarProps {
  /** El sider esta oculto: se muestra el boton para traerlo de vuelta. */
  siderOculto: boolean
  onMostrarSider: () => void
  userName: string
  userEmail: string
  /** Ruta de la foto de perfil, o null si no tiene. */
  userFoto: string | null
  onOpenMenu: () => void
  /** Navega a una vista del menú por su id ("inv.stock"), al tocar una alerta. */
  onNavigate: (id: string) => void
  /** Abre Mi Perfil al tocar el nombre o el avatar. */
  onPerfil: () => void
  onLogout: () => void
}

export function Topbar({
  siderOculto,
  onMostrarSider,
  userName,
  userEmail,
  userFoto,
  onOpenMenu,
  onNavigate,
  onPerfil,
  onLogout,
}: TopbarProps) {
  const [alertas, setAlertas] = useState<AlertaResponse[]>([])
  const [abierto, setAbierto] = useState(false)
  // Ids marcados como leidos, por dispositivo: mientras la causa no cambie, dejan de insistir.
  const [leidas, setLeidas] = useState<Record<string, number>>(() => alertasLeidas())
  // Las leidas no desaparecen del todo: se pueden volver a ver, para no perder el rastro de que existieron.
  const [verLeidas, setVerLeidas] = useState(false)
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
  // 'permisos' está porque un acceso pedido desde el móvil es una alerta más:
  // sin él, el admin no se enteraba hasta recargar la página.
  useRealtime(['stock', 'compras', 'recepciones', 'notasventa', 'pedidos', 'permisos'], cargar)

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

  const sinLeer = alertas.filter((a) => !leidas[a.id])
  const criticas = sinLeer.filter((a) => a.severidad === 'CRITICA').length
  const advertencias = sinLeer.filter((a) => a.severidad === 'ADVERTENCIA').length
  const colorContador = criticas > 0 ? 'bg-red-600' : advertencias > 0 ? 'bg-amber-500' : 'bg-emerald-600'
  const visibles = verLeidas ? alertas : sinLeer

  const marcar = (id: string) => {
    marcarLeida(id)
    setLeidas((prev) => ({ ...prev, [id]: Date.now() }))
  }

  const marcarTodas = () => {
    const ids = sinLeer.map((a) => a.id)
    marcarTodasLeidas(ids)
    setLeidas((prev) => {
      const ahora = Date.now()
      const siguiente = { ...prev }
      for (const id of ids) siguiente[id] = ahora
      return siguiente
    })
  }

  /*
    El acceso pedido llega con los ids del backend —"fact.precios · ver"—,
    que es lo unico que el servidor conoce: los nombres de las pantallas viven
    en el menu, aqui. Se traducen al leerlos y no antes.
  */
  const detalleDe = (a: AlertaResponse) => {
    if (a.tipo !== 'SOLICITUD_ACCESO') return a.detalle

    const [submodulo, accion, ...resto] = a.detalle.split(' · ')
    const pantalla = resolveNav(submodulo).item?.label ?? submodulo
    return [pantalla, ACCION_PEDIDA[accion] ?? accion, ...resto].join(' · ')
  }

  const irA = (a: AlertaResponse) => {
    setAbierto(false)
    if (!a.ruta) return

    onNavigate(a.ruta)

    /*
      Accesos abre por la matriz de roles, y el acceso pedido no vive ahi sino
      en la bandeja: sin esto la alerta dejaba al admin en la pantalla correcta
      pero en la pestaña equivocada, buscando lo que acababa de tocar.

      Por el hash y no por la ruta porque la pestaña no es una vista del menu:
      no tiene id ni permiso propio, es un detalle de esta pantalla.
    */
    if (a.tipo === 'SOLICITUD_ACCESO') window.location.hash = 'solicitudes'
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
          {sinLeer.length > 0 && (
            <span
              className={cn(
                'absolute top-0.5 right-0.5 flex size-4 items-center justify-center rounded-full text-[9px] font-bold text-white ring-2 ring-white',
                colorContador,
              )}
            >
              {sinLeer.length > 9 ? '9+' : sinLeer.length}
            </span>
          )}
        </button>

        {abierto && (
          /*
            En el movil se sale de la pantalla.
            El panel colgaba de la campana con un ancho fijo, y la campana no
            esta pegada al borde —tiene el perfil y el salir a su derecha—,
            asi que a 375px arrancaba en -72 y se comia el inicio de cada
            alerta. Ahi va suelto de la campana, pegado a los dos bordes;
            desde sm vuelve a colgar de ella.
          */
          <div className="fixed inset-x-3 top-16 z-30 rounded-panel border border-line bg-white shadow-panel sm:absolute sm:inset-x-auto sm:top-full sm:right-0 sm:mt-2 sm:w-96">
            <div className="flex items-start justify-between gap-3 border-b border-line px-4 py-3">
              <div>
                <h3 className="text-sm font-bold text-ink">Alertas</h3>
                <p className="text-xs text-ink-soft">
                  {alertas.length === 0
                    ? 'Todo en orden'
                    : sinLeer.length === 0
                      ? 'Ya revisaste todo'
                      : criticas > 0 || advertencias > 0
                        ? `${sinLeer.length} cosas para revisar`
                        : `${sinLeer.length} novedades`}
                </p>
              </div>
              {sinLeer.length > 0 && (
                <button
                  type="button"
                  onClick={marcarTodas}
                  title="Marcar todas como leídas"
                  className="flex shrink-0 cursor-pointer items-center gap-1 rounded-md px-2 py-1 text-[11px] font-semibold text-ink-muted transition-colors hover:bg-surface-alt hover:text-ink"
                >
                  <CheckCheck size={13} />
                  Marcar todas
                </button>
              )}
            </div>

            <div className="max-h-96 overflow-y-auto">
              {visibles.length === 0 ? (
                <p className="px-4 py-6 text-center text-sm text-ink-soft">
                  {alertas.length === 0 ? 'No hay nada pendiente.' : 'No queda nada sin leer.'}
                </p>
              ) : (
                visibles.map((a) => {
                  const leida = Boolean(leidas[a.id])
                  return (
                    <div
                      key={a.id}
                      className={cn(
                        'flex w-full items-start gap-2 border-b border-line px-4 py-3 last:border-0',
                        leida && 'opacity-60',
                      )}
                    >
                      <button
                        type="button"
                        onClick={() => irA(a)}
                        disabled={!a.ruta}
                        className={cn(
                          'flex min-w-0 flex-1 items-start gap-3 text-left',
                          a.ruta ? 'cursor-pointer' : 'cursor-default',
                        )}
                      >
                        <span
                          className={cn(
                            'mt-0.5 shrink-0 rounded-full p-1.5',
                            a.severidad === 'CRITICA'
                              ? 'bg-red-50 text-red-600'
                              : a.severidad === 'ADVERTENCIA'
                                ? 'bg-amber-50 text-amber-600'
                                : 'bg-emerald-50 text-emerald-600',
                          )}
                        >
                          {a.tipo === 'STOCK_REPUESTO' ? (
                            <PackageCheck size={14} />
                          ) : a.tipo === 'LOTE_POR_VENCER' ? (
                            <PackageX size={14} />
                          ) : a.tipo === 'SOLICITUD_ACCESO' ? (
                            <LockKeyhole size={14} />
                          ) : (
                            <AlertTriangle size={14} />
                          )}
                        </span>
                        <span className="min-w-0">
                          <span className="block truncate text-sm font-semibold text-ink">{a.titulo}</span>
                          <span className="block truncate text-xs text-ink-soft">{detalleDe(a)}</span>
                        </span>
                      </button>
                      {/* Marcar como leída sin navegar: por eso va fuera del boton que abre la alerta. */}
                      {!leida && (
                        <button
                          type="button"
                          onClick={() => marcar(a.id)}
                          title="Marcar como leída"
                          className="shrink-0 cursor-pointer rounded-md p-1.5 text-ink-soft transition-colors hover:bg-surface-alt hover:text-ink"
                        >
                          <Check size={14} />
                        </button>
                      )}
                    </div>
                  )
                })
              )}
            </div>

            {alertas.length > 0 && alertas.length !== sinLeer.length && (
              <button
                type="button"
                onClick={() => setVerLeidas((v) => !v)}
                className="w-full cursor-pointer border-t border-line px-4 py-2 text-center text-xs font-semibold text-ink-muted transition-colors hover:bg-surface-alt hover:text-ink"
              >
                {verLeidas ? 'Ocultar las leídas' : `Ver también las leídas (${alertas.length - sinLeer.length})`}
              </button>
            )}
          </div>
        )}
      </div>

      <div className="flex items-center gap-1 border-l border-line pl-3">
        <button
          type="button"
          onClick={onPerfil}
          title="Mi perfil"
          className="flex cursor-pointer items-center gap-2 rounded-lg p-1 pr-2 transition-colors hover:bg-surface-alt"
        >
          <span className="hidden text-right sm:block">
            <span className="block text-sm leading-tight font-semibold text-ink">{userName}</span>
            <span className="block text-[11px] text-ink-muted">{userEmail}</span>
          </span>
          <span className="inline-flex size-9 shrink-0 items-center justify-center overflow-hidden rounded-full bg-[rgb(var(--sys-rgb))] text-sm font-bold text-[var(--sys-on)]">
            {userFoto ? (
              <img src={urlImagen(userFoto)} alt={userName} className="size-full object-cover" />
            ) : (
              userName.charAt(0).toUpperCase()
            )}
          </span>
        </button>
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
