import { useState } from 'react'
import type { ReactNode } from 'react'
import { cn } from '../ui'
import { Sidebar } from './Sidebar'
import { Topbar } from './Topbar'
import { resolveNav } from './navigation'

export interface DashboardLayoutProps {
  active: string
  onSelect: (id: string) => void
  userName: string
  userEmail: string
  onLogout: () => void
  children: ReactNode
}

/**
 * Estructura de la aplicacion: sider blanco fijo a la izquierda y area de
 * trabajo gris a la derecha.
 *
 * El `data-sys` del contenedor lleva el color del sistema al que pertenece la
 * vista abierta, asi que topbar, tablas y tarjetas se tiñen solas.
 */
export function DashboardLayout({
  active,
  onSelect,
  userName,
  userEmail,
  onLogout,
  children,
}: DashboardLayoutProps) {
  const [collapsed, setCollapsed] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)
  const [oculto, setOculto] = useState(false)

  const { sys } = resolveNav(active)

  return (
    <div data-sys={sys} className="min-h-screen bg-surface-alt">
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

      <div
        className={cn(
          'flex min-h-screen flex-col transition-[padding] duration-200',
          oculto ? 'lg:pl-0' : collapsed ? 'lg:pl-[72px]' : 'lg:pl-64',
        )}
      >
        <Topbar
          siderOculto={oculto}
          onMostrarSider={() => setOculto(false)}
          userName={userName}
          userEmail={userEmail}
          onOpenMenu={() => setMobileOpen(true)}
          onLogout={onLogout}
        />

        <main className="flex-1 p-4 sm:p-6">{children}</main>
      </div>
    </div>
  )
}
