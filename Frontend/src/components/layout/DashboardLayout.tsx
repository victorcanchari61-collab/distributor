import { useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { Menu, PanelLeftOpen, PanelRightOpen } from 'lucide-react'
import { CabeceraGlobalContext, cn } from '../ui'
import type { CabeceraGlobal } from '../ui'
import { BarraNavegacion } from './BarraNavegacion'
import { CampanaAlertas, MenuCuenta } from './CuentaUsuario'
import type { FormatoNavegacion, LadoNavegacion } from './formatoNavegacion'
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
  /** Menú lateral, barra fija abajo o barra arriba: lo elige cada persona en su menú de cuenta. */
  formato: FormatoNavegacion
  onFormato: (formato: FormatoNavegacion) => void
  /** De qué lado va el menú lateral (solo aplica con `formato: 'lateral'`). */
  lado: LadoNavegacion
  onLado: (lado: LadoNavegacion) => void
  children: ReactNode
}

// Las cabeceras de las vistas ya no llevan la cuenta ni la campana: están en la franja de arriba, junto a las pestañas.
const SIN_CABECERA_GLOBAL: CabeceraGlobal = {}

/**
 * Estructura de la aplicación: arriba, una franja con las pestañas de trabajo, la cuenta y la campana; a la
 * izquierda el menú lateral (o, si la persona lo eligió, una barra abajo o arriba); y el área de trabajo gris.
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
  lado,
  onLado,
  children,
}: DashboardLayoutProps) {
  const [collapsed, setCollapsed] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)
  const [oculto, setOculto] = useState(false)
  const barra = formato === 'barra'
  const superior = formato === 'superior'
  const lateral = formato === 'lateral'
  const derecha = lado === 'derecha'

  const { sys } = resolveNav(active)
  const cabecera = useMemo(() => SIN_CABECERA_GLOBAL, [])

  return (
    <div data-sys={sys} className="min-h-screen bg-surface-alt">
      {lateral && (
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
          lado={lado}
          onLado={onLado}
        />
      )}

      {barra && <BarraNavegacion active={active} onSelect={onSelect} colocacion="inferior" />}

      <div
        className={cn(
          'flex min-h-screen flex-col transition-[padding] duration-200',
          lateral
            ? derecha
              ? cn(
                  'lg:pl-0',
                  oculto ? 'lg:pr-0' : collapsed ? 'lg:pr-[72px]' : 'lg:pr-56',
                )
              : cn(
                  'lg:pr-0',
                  oculto ? 'lg:pl-0' : collapsed ? 'lg:pl-[72px]' : 'lg:pl-56',
                )
            : '',
        )}
      >
        {/*
          Con la barra arriba, como en los sistemas de escritorio: una fila blanca a todo el ancho con los módulos y la
          cuenta; debajo las pestañas de trabajo, pegadas al contenido (la activa se funde con la página, así que entre
          ellas y la vista no puede ir nada).
        */}
        {superior ? (
          <header className="sticky top-0 z-30">
            <div className="flex h-14 items-center gap-3 border-b border-line bg-white px-3 sm:px-5">
              <BarraNavegacion active={active} onSelect={onSelect} colocacion="superior" />

              <div className="flex shrink-0 items-center gap-2">
                <MenuCuenta
                  nombre={userName}
                  email={userEmail}
                  foto={userFoto}
                  onPerfil={onPerfil}
                  onLogout={onLogout}
                  formato={formato}
                  onFormato={onFormato}
                  lado={lado}
                  onLado={onLado}
                />
                <CampanaAlertas onNavigate={onSelect} />
              </div>
            </div>
            <div className="bg-slate-200/80 pt-1.5 pr-3 pl-1 backdrop-blur sm:pr-5">{pestanas}</div>
          </header>
        ) : (
          /* La franja de arriba: las pestañas abiertas a la izquierda; la cuenta y la campana a la derecha. */
        <header className="sticky top-0 z-30 bg-slate-200/80 pt-1.5 pr-3 pl-1 backdrop-blur sm:pr-5">
          <div className="flex items-end gap-2">
            {lateral && (
              <div className="mb-1 flex shrink-0 items-center">
                <button
                  type="button"
                  onClick={() => setMobileOpen(true)}
                  aria-label="Abrir menú"
                  className="cursor-pointer rounded-lg p-2 text-ink-muted transition-colors hover:bg-white lg:hidden"
                >
                  <Menu size={20} />
                </button>
                {/* Solo con el sider oculto: es la única forma de recuperarlo. Sale del lado donde estaba. */}
                {oculto && !derecha && (
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

            <div className="mb-1 flex shrink-0 items-center gap-2">
              {lateral && oculto && derecha && (
                <button
                  type="button"
                  onClick={() => setOculto(false)}
                  aria-label="Mostrar menú"
                  title="Mostrar menú"
                  className="hidden cursor-pointer rounded-lg p-2 text-ink-muted transition-colors hover:bg-white hover:text-ink lg:block"
                >
                  <PanelRightOpen size={20} />
                </button>
              )}
              <MenuCuenta
                nombre={userName}
                email={userEmail}
                foto={userFoto}
                onPerfil={onPerfil}
                onLogout={onLogout}
                formato={formato}
                onFormato={onFormato}
                lado={lado}
                onLado={onLado}
              />
              <CampanaAlertas onNavigate={onSelect} />
            </div>
          </div>

        </header>
        )}

        {/*
          Con la barra de abajo se le deja todo su alto debajo, en cualquier ancho, para que nada quede tapado. Las
          tablas que llenan la pantalla bajan su paginación al costado de la barra cuando entra (lo miden ellas, ver
          SysDataTable): ahí no se pierde ese alto.
        */}
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
