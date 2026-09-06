import { useState } from 'react'
import { ShieldOff } from 'lucide-react'
import { Navigate, Route, Routes, useLocation, useNavigate } from 'react-router-dom'
import { DashboardLayout, NAV_DEFAULT, navIdFromPath, navPath, resolveNav } from './components/layout'
import { LoginPage } from './features/auth/LoginPage'
import type { UsuarioResponse } from './features/auth/authApi'
import { AccesosPage, AuditoriaPage, EmpresaPage, RolesPage, UsuariosPage } from './features/config'
import { SolicitudPermisoModal } from './features/config/SolicitudPermisoModal'
import { ListasPreciosPage, PedidosPage, NotasVentaPage } from './features/facturacion'
import { ArqueoDiarioPage, CuentasPorCobrarPage, CuentasPorPagarPage, MetodosPagoPage, MisCobrosPage } from './features/finanzas'
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
import { MercadosPage, RutasPage } from './features/tms'
import { PendingPage } from './features/PendingPage'
import { clearSession, getUsuario } from './lib/authStorage'
import { PermisosProvider, usePermisos } from './lib/permisos'

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
  'tms.mercados': MercadosPage,
  'tms.rutas': RutasPage,
  'finanzas.metodospago': MetodosPagoPage,
  'finanzas.cobrar': CuentasPorCobrarPage,
  'finanzas.pagar': CuentasPorPagarPage,
  'finanzas.miscobros': MisCobrosPage,
  'finanzas.arqueo': ArqueoDiarioPage,
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
    // Se remonta al cambiar de usuario: si no, quien entrara despues heredaria
    // los permisos que quedaron cargados de la sesion anterior.
    <PermisosProvider key={usuario.id}>
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

      {/*
        Se monta una vez, fuera de las vistas: cualquier 403 del filtro de
        permisos lo abre, venga de donde venga, sin que cada pantalla tenga que
        acordarse de manejarlo.
      */}
      <SolicitudPermisoModal />
    </DashboardLayout>
    </PermisosProvider>
  )
}

/** Resuelve la vista que corresponde a la ruta actual. */
function Vista() {
  const { pathname } = useLocation()
  const id = navIdFromPath(pathname)
  const { puedeVer, cargando } = usePermisos()

  // El menu ya esconde lo que no se puede abrir, pero la URL se escribe a mano
  // y se comparte por chat: sin esto, pegar un enlace saltaria el filtro.
  if (cargando) return null
  if (!puedeVer(id)) return <SinAcceso />

  const View = VIEWS[id]
  if (View) return <View />

  const { group, item } = resolveNav(id)
  return <PendingPage title={item?.label ?? 'Vista'} group={group?.label} />
}

/** Se llego a una pantalla que el rol no tiene concedida. */
function SinAcceso() {
  return (
    <div className="flex flex-col items-center justify-center gap-2 py-24 text-center">
      <ShieldOff size={32} className="text-ink-soft" />
      <p className="text-base font-semibold text-ink">No tienes acceso a esta pantalla</p>
      <p className="max-w-sm text-sm text-ink-muted">
        Tu rol no la incluye. Si necesitas entrar, pídeselo a un administrador.
      </p>
    </div>
  )
}

export default App
