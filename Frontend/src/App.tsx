import { useState } from 'react'
import { Navigate, Route, Routes, useLocation, useNavigate } from 'react-router-dom'
import { DashboardLayout, NAV_DEFAULT, navIdFromPath, navPath, resolveNav } from './components/layout'
import { LoginPage } from './features/auth/LoginPage'
import type { UsuarioResponse } from './features/auth/authApi'
import { AccesosPage, AuditoriaPage, EmpresaPage, RolesPage, UsuariosPage } from './features/config'
import { ListasPreciosPage, PedidosPage, NotasVentaPage } from './features/facturacion'
import { CuentasPorCobrarPage, CuentasPorPagarPage, MetodosPagoPage, MisCobrosPage } from './features/finanzas'
import {
  AlmacenesPage,
  AjustesPage,
  KardexPage,
  StockPage,
  TransferenciasPage,
  PrestamosPage,
  LotesVencimientosPage,
  ConteosPage,
} from './features/inventario'
import { OrdenesCompraPage, MisComprasPage, RecepcionesPage } from './features/compras'
import { ClientesPage, ProductosPage, ProveedoresPage } from './features/maestros'
import { PendingPage } from './features/PendingPage'
import { clearSession, getUsuario } from './lib/authStorage'

/** Vistas ya construidas, por id del menu. El resto cae en PendingPage. */
const VIEWS: Record<string, () => React.ReactElement> = {
  'maestros.clientes': ClientesPage,
  'maestros.proveedores': ProveedoresPage,
  'maestros.productos': ProductosPage,
  'fact.pedidos': PedidosPage,
  'fact.notaventa': NotasVentaPage,
  'fact.precios': ListasPreciosPage,
  'inv.almacenes': AlmacenesPage,
  'inv.stock': StockPage,
  'inv.kardex': KardexPage,
  'inv.ajustes': AjustesPage,
  'inv.transferencias': TransferenciasPage,
  'inv.prestamos': PrestamosPage,
  'inv.lotes': LotesVencimientosPage,
  'inv.conteos': ConteosPage,
  'compras.ordenes': OrdenesCompraPage,
  'compras.compras': MisComprasPage,
  'compras.recepciones': RecepcionesPage,
  'finanzas.metodospago': MetodosPagoPage,
  'finanzas.cobrar': CuentasPorCobrarPage,
  'finanzas.pagar': CuentasPorPagarPage,
  'finanzas.miscobros': MisCobrosPage,
  'config.usuarios': UsuariosPage,
  'config.accesos': AccesosPage,
  'config.roles': RolesPage,
  'config.empresa': EmpresaPage,
  'config.auditoria': AuditoriaPage,
}

function App() {
  const [usuario, setUsuario] = useState<UsuarioResponse | null>(() =>
    getUsuario<UsuarioResponse>(),
  )
  const navigate = useNavigate()
  const location = useLocation()

  if (!usuario) {
    return (
      <LoginPage
        onSuccess={(u) => {
          setUsuario(u)
          navigate(navPath(NAV_DEFAULT), { replace: true })
        }}
      />
    )
  }

  const active = navIdFromPath(location.pathname)

  return (
    <DashboardLayout
      active={active}
      onSelect={(id) => navigate(navPath(id))}
      userName={usuario.nombre}
      userEmail={usuario.email}
      onLogout={() => {
        clearSession()
        setUsuario(null)
        navigate('/', { replace: true })
      }}
    >
      <Routes>
        <Route path="/" element={<Navigate to={navPath(NAV_DEFAULT)} replace />} />
        <Route path="/:modulo/:vista" element={<Vista />} />
        <Route path="*" element={<Navigate to={navPath(NAV_DEFAULT)} replace />} />
      </Routes>
    </DashboardLayout>
  )
}

/** Resuelve la vista que corresponde a la ruta actual. */
function Vista() {
  const { pathname } = useLocation()
  const id = navIdFromPath(pathname)
  const View = VIEWS[id]
  if (View) return <View />

  const { group, item } = resolveNav(id)
  return <PendingPage title={item?.label ?? 'Vista'} group={group?.label} />
}

export default App
