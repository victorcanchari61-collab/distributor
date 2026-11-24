import { useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { Menu, PanelLeftOpen } from 'lucide-react'
import { CabeceraGlobalContext, cn } from '../ui'
import type { CabeceraGlobal } from '../ui'
import { BarraInferior } from './BarraInferior'
import { CampanaAlertas, MenuCuenta } from './CuentaUsuario'
import type { FormatoNavegacion } from './formatoNavegacion'
import { Sidebar } from './Sidebar'
import { resolveNav } from './navigation'

export interface DashboardLayoutProps {
  active: string
  onSelect: (id: string) => void
  userName: string
  userEmail: string
  userFoto: string | null
  onPerfil: () => void
  onLogout: () => void
  /** La barra de pestañas de trabajo: va arriba, a la izquierda de la cuenta y la campana. */
  pestanas?: ReactNode
  /** Menú lateral o barra fija abajo: lo elige cada persona en su menú de cuenta. */
  formato: FormatoNavegacion
  onFormato: (formato: FormatoNavegacion) => void
  children: ReactNode
}

// Las cabeceras de las vistas ya no llevan la cuenta ni la campana: están en la franja de arriba, junto a las pestañas.
const SIN_CABECERA_GLOBAL: CabeceraGlobal = {}

/**
 * Estructura de la aplicación: arriba, una franja con las pestañas de trabajo, la cuenta y la campana; a la
 * izquierda el menú lateral (o, si la persona lo eligió, una barra fija abajo); y el área de trabajo gris.
 *
 * El `data-sys` del contenedor lleva el color del sistema al que pertenece la vista abierta, así que cabeceras,
 * tablas y tarjetas se tiñen solas.
 */
export function DashboardLayout({
  active,
  onSelect,
  userName,
  userEmail,
  userFoto,
  onPerfil,
  onLogout,
  pestanas,
  formato,
  onFormato,
  children,
}: DashboardLayoutProps) {
  const [collapsed, setCollapsed] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)
  const [oculto, setOculto] = useState(false)
  const barra = formato === 'barra'

  const { sys } = resolveNav(active)
  const cabecera = useMemo(() => SIN_CABECERA_GLOBAL, [])

  return (
    <div data-sys={sys} className="min-h-screen bg-surface-alt">
      {barra ? (
        <BarraInferior active={active} onSelect={onSelect} />
      ) : (
        <Sidebar
          active={active}
          onSelect={(id) => {
            onSelect(id)
            setMobileOpen(false)
          }}
          collapsed={collapsed}
          onToggleCollapsed={() => setCollapsed((c) => !c)}
          mobileOpen={mobileOpen}
          onCloseMobile={() => setMobileOpen(false)}
          oculto={oculto}
          onOcultar={() => setOculto(true)}
        />
      )}

      <div
        className={cn(
          'flex min-h-screen flex-col transition-[padding] duration-200',
          barra ? '' : oculto ? 'lg:pl-0' : collapsed ? 'lg:pl-[72px]' : 'lg:pl-56',
        )}
      >
        {/* La franja de arriba: las pestañas abiertas a la izquierda; la cuenta y la campana a la derecha. */}
        <header className="sticky top-0 z-30 flex items-end gap-2 bg-slate-200/80 pt-2 pr-3 pl-1 backdrop-blur sm:pr-5">
          {!barra && (
            <div className="mb-1 flex shrink-0 items-center">
              <button
                type="button"
                onClick={() => setMobileOpen(true)}
                aria-label="Abrir menú"
                className="cursor-pointer rounded-lg p-2 text-ink-muted transition-colors hover:bg-white lg:hidden"
              >
                <Menu size={20} />
              </button>
              {/* Solo con el sider oculto: es la única forma de recuperarlo. */}
              {oculto && (
                <button
                  type="button"
                  onClick={() => setOculto(false)}
                  aria-label="Mostrar menú"
                  title="Mostrar menú"
                  className="hidden cursor-pointer rounded-lg p-2 text-ink-muted transition-colors hover:bg-white hover:text-ink lg:block"
                >
                  <PanelLeftOpen size={20} />
                </button>
              )}
            </div>
          )}

          <div className="min-w-0 flex-1">{pestanas}</div>

          <div className="mb-1.5 flex shrink-0 items-center gap-2">
            <MenuCuenta
              nombre={userName}
              email={userEmail}
              foto={userFoto}
              onPerfil={onPerfil}
              onLogout={onLogout}
              formato={formato}
              onFormato={onFormato}
            />
            <CampanaAlertas onNavigate={onSelect} />
          </div>
        </header>

        {/* Con la barra de abajo, el contenido deja su lugar para que no lo tape. */}
        <main className={cn('flex-1 px-4 pt-4 sm:px-6', barra ? 'pb-24' : 'pb-4 sm:pb-6')}>
          <CabeceraGlobalContext.Provider value={cabecera}>{children}</CabeceraGlobalContext.Provider>
        </main>
      </div>

      {/*
        Ancla para los modales: Modal se pinta con createPortal (ver su
        comentario) para no heredar el space-y de ListPage, pero si el
        destino fuera document.body quedaria fuera de este data-sys y
        saldria siempre en azul, sin importar el modulo abierto. Aqui
        adentro hereda el color correcto sin que Modal necesite saber cual
        es.
      */}
      <div id="modal-root" />
    </div>
  )
}
