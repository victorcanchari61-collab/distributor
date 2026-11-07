import { lazy, Suspense, useEffect, useState } from 'react'
import type { ComponentType } from 'react'
import { ShieldOff } from 'lucide-react'
import { Route, Routes, useLocation, useNavigate } from 'react-router-dom'
import { DashboardLayout, navIdFromPath, navPath, puedeAbrir, resolveNav } from './components/layout'
import { LoginPage } from './features/auth/LoginPage'
import type { UsuarioResponse } from './features/auth/authApi'
import { SolicitudPermisoModal } from './features/config/SolicitudPermisoModal'
import { solicitudApi } from './features/config/solicitudApi'
import { Button } from './components/ui'
import { PendingPage } from './features/PendingPage'
import { clearSession, getUsuario } from './lib/authStorage'
import { PermisosProvider, usePermisos } from './lib/permisos'

/**
 * Una pantalla que se descarga SOLO cuando se abre.
 *
 * Antes todas las pantallas viajaban juntas en un mismo archivo de 1.7 MB: quien solo entraba a Pedidos bajaba también
 * la planilla, los dashboards y el CRM, y el login esperaba a que todo eso llegara. Ahora cada módulo es su propio
 * archivo y se pide al abrir su primera pantalla; el navegador lo guarda para las siguientes.
 */
const pantalla = (cargar: () => Promise<Record<string, unknown>>, nombre: string) =>
  lazy(() => cargar().then((modulo) => ({ default: modulo[nombre] as ComponentType })))

const InicioPage = pantalla(() => import('./features/inicio'), 'InicioPage')
const MiPerfilPage = pantalla(() => import('./features/perfil'), 'MiPerfilPage')
const CatalogoPublicoPage = pantalla(() => import('./features/maestros'), 'CatalogoPublicoPage')

/** Mientras llega el archivo de la pantalla: algo discreto, sin saltos. */
function Cargando() {
  return <p className="py-10 text-center text-sm text-ink-soft">Cargando...</p>
}

/** Vistas ya construidas, por id del menu. El resto cae en PendingPage. */
const VIEWS: Record<string, ComponentType> = {
  'dashboard.ventas': pantalla(() => import('./features/dashboard'), 'VentasDashboard'),
  'dashboard.rentabilidad': pantalla(() => import('./features/dashboard'), 'RentabilidadDashboard'),
  'dashboard.cobranza': pantalla(() => import('./features/dashboard'), 'CobranzaDashboard'),
  'dashboard.compras': pantalla(() => import('./features/dashboard'), 'ComprasDashboard'),
  'dashboard.inventario': pantalla(() => import('./features/dashboard'), 'InventarioDashboard'),
  'dashboard.reparto': pantalla(() => import('./features/dashboard'), 'RepartoDashboard'),
  'fact.facturas': pantalla(() => import('./features/facturacion'), 'FacturasPage'),
  'fact.boletas': pantalla(() => import('./features/facturacion'), 'BoletasPage'),
  'fact.notascredito': pantalla(() => import('./features/facturacion'), 'NotasCreditoPage'),
  'fact.notasdebito': pantalla(() => import('./features/facturacion'), 'NotasDebitoPage'),
  'dashboard.sinventas': pantalla(() => import('./features/dashboard'), 'ProductosSinVentasPage'),
  'dashboard.zonas': pantalla(() => import('./features/dashboard'), 'ZonasPage'),
  'maestros.clientes': pantalla(() => import('./features/maestros'), 'ClientesPage'),
  'maestros.proveedores': pantalla(() => import('./features/maestros'), 'ProveedoresPage'),
  'maestros.productos': pantalla(() => import('./features/maestros'), 'ProductosPage'),
  'maestros.catalogo': pantalla(() => import('./features/maestros'), 'CatalogoPage'),
  'rrhh.empleados': pantalla(() => import('./features/rrhh'), 'EmpleadosPage'),
  'rrhh.asistencia': pantalla(() => import('./features/rrhh'), 'AsistenciaPage'),
  'rrhh.planilla': pantalla(() => import('./features/rrhh'), 'PlanillaPage'),
  'rrhh.adelantos': pantalla(() => import('./features/rrhh'), 'AdelantosPage'),
  'fact.pedidos': pantalla(() => import('./features/facturacion'), 'PedidosPage'),
  'fact.notaventa': pantalla(() => import('./features/facturacion'), 'NotasVentaPage'),
  'fact.precios': pantalla(() => import('./features/facturacion'), 'ListasPreciosPage'),
  'inv.almacenes': pantalla(() => import('./features/inventario'), 'AlmacenesPage'),
  'inv.ubicaciones': pantalla(() => import('./features/inventario'), 'UbicacionProductosPage'),
  'inv.stock': pantalla(() => import('./features/inventario'), 'StockPage'),
  'inv.kardex': pantalla(() => import('./features/inventario'), 'KardexPage'),
  'inv.ajustes': pantalla(() => import('./features/inventario'), 'AjustesPage'),
  'inv.transferencias': pantalla(() => import('./features/inventario'), 'TransferenciasPage'),
  'inv.prestamos': pantalla(() => import('./features/inventario'), 'PrestamosPage'),
  'inv.lotes': pantalla(() => import('./features/inventario'), 'LotesVencimientosPage'),
  'inv.conteos': pantalla(() => import('./features/inventario'), 'ConteosPage'),
  'compras.solicitudes': pantalla(() => import('./features/compras'), 'SolicitudesCompraPage'),
  'compras.ordenes': pantalla(() => import('./features/compras'), 'OrdenesCompraPage'),
  'compras.compras': pantalla(() => import('./features/compras'), 'MisComprasPage'),
  'compras.recepciones': pantalla(() => import('./features/compras'), 'RecepcionesPage'),
  'tms.mercados': pantalla(() => import('./features/tms'), 'MercadosPage'),
  'tms.rutas': pantalla(() => import('./features/tms'), 'RutasPage'),
  'tms.flota': pantalla(() => import('./features/tms'), 'FlotaPage'),
  'tms.conductores': pantalla(() => import('./features/tms'), 'ConductoresPage'),
  'tms.despachos': pantalla(() => import('./features/tms'), 'DespachosPage'),
  'tms.novedades': pantalla(() => import('./features/tms'), 'NovedadesPage'),
  'tms.motivos': pantalla(() => import('./features/tms'), 'MotivosNovedadPage'),
  'crm.seguimiento': pantalla(() => import('./features/crm'), 'SeguimientoPage'),
  'crm.caida': pantalla(() => import('./features/crm'), 'CaidaPage'),
  'crm.vendedores': pantalla(() => import('./features/crm'), 'VendedoresCaidaPage'),
  'dms.visitas': pantalla(() => import('./features/dms'), 'VisitasPage'),
  'dms.devoluciones': pantalla(() => import('./features/dms'), 'DevolucionesPage'),
  'finanzas.caja': pantalla(() => import('./features/finanzas'), 'MiCajaPage'),
  'finanzas.cajas': pantalla(() => import('./features/finanzas'), 'CajasPage'),
  'finanzas.cierres': pantalla(() => import('./features/finanzas'), 'CierresCajaPage'),
  'finanzas.bancos': pantalla(() => import('./features/finanzas'), 'CuentasFinancierasPage'),
  // Es una pestaña de Bancos: el enlace viejo lleva ahí, ya abierta.
  'finanzas.metodospago': pantalla(() => import('./features/finanzas'), 'MetodosPagoEnBancos'),
  'finanzas.cobrar': pantalla(() => import('./features/finanzas'), 'CuentasPorCobrarPage'),
  'finanzas.pagar': pantalla(() => import('./features/finanzas'), 'CuentasPorPagarPage'),
  'finanzas.ganancias': pantalla(() => import('./features/finanzas'), 'MisGananciasPage'),
  'finanzas.movimientos': pantalla(() => import('./features/finanzas'), 'MovimientosDineroPage'),
  'finanzas.operativos': pantalla(() => import('./features/finanzas'), 'GastosOperativosPage'),
  'finanzas.financiamiento': pantalla(() => import('./features/finanzas'), 'PrestamosRecibidosPage'),
  'finanzas.resultados': pantalla(() => import('./features/finanzas'), 'EstadoResultadosPage'),
  'config.usuarios': pantalla(() => import('./features/config'), 'UsuariosPage'),
  'config.accesos': pantalla(() => import('./features/config'), 'AccesosPage'),
  'config.roles': pantalla(() => import('./features/config'), 'RolesPage'),
  'config.empresa': pantalla(() => import('./features/config'), 'EmpresaPage'),
  'config.auditoria': pantalla(() => import('./features/config'), 'AuditoriaPage'),
}

function App() {
  const [usuario, setUsuario] = useState<UsuarioResponse | null>(() =>
    getUsuario<UsuarioResponse>(),
  )
  const navigate = useNavigate()
  const location = useLocation()

  // Mi Perfil avisa por aqui cuando guarda: la barra superior tiene que mostrar
  // el nombre y la foto nuevos sin obligar a recargar la pagina.
  useEffect(() => {
    const alActualizar = (e: Event) => {
      setUsuario((e as CustomEvent<UsuarioResponse>).detail)
    }
    window.addEventListener('perfil:actualizado', alActualizar)
    return () => window.removeEventListener('perfil:actualizado', alActualizar)
  }, [])

  // El catálogo público se abre con un enlace, sin sesión: va ANTES del login y fuera del panel (sin menú, sin
  // permisos ni tiempo real). Es una sola palabra de ruta: el catálogo interno vive en /maestros/catalogo.
  if (location.pathname === '/catalogo' || location.pathname === '/catalogo/') {
    return (
      <Suspense fallback={<Cargando />}>
        <CatalogoPublicoPage />
      </Suspense>
    )
  }

  if (!usuario) {
    return (
      <LoginPage
        onSuccess={(u) => {
          setUsuario(u)
          // A la raiz y no a una vista fija: es Inicio quien sabe cual es la
          // primera pantalla que esta persona puede abrir.
          navigate('/', { replace: true })
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
      userFoto={usuario.foto}
      onPerfil={() => navigate('/perfil')}
      onLogout={() => {
        clearSession()
        setUsuario(null)
        navigate('/', { replace: true })
      }}
    >
      <Suspense fallback={<Cargando />}>
      <Routes>
        <Route path="/" element={<Inicio />} />
        {/* Ruta propia y fuera del filtro de permisos: es de todos, no de un modulo. */}
        <Route path="/perfil" element={<MiPerfilPage />} />
        <Route path="/:modulo/:vista" element={<Vista />} />
        <Route path="*" element={<Inicio />} />
      </Routes>
      </Suspense>

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
  // puedeAbrir y no puedeVer: Bancos se abre también con solo el permiso de Métodos de pago, que es su pestaña.
  if (!puedeAbrir(id, puedeVer)) return <SinAcceso submodulo={id} />

  const View = VIEWS[id]
  if (View) return <View />

  const { group, item } = resolveNav(id)
  return <PendingPage title={item?.label ?? 'Vista'} group={group?.label} />
}

/**
 * A dónde va alguien que entra sin pedir una vista concreta.
 *
 * Antes esto saltaba a la primera pantalla que la persona pudiera abrir, para
 * no recibir a un almacenero con un "no tienes acceso" nada mas entrar. Ahora
 * hay una pantalla propia que ademas resuelve lo otro: quien no ve un modulo
 * no sabe que existe, y quien lo necesita tenia que adivinar el nombre de la
 * pantalla para pedirla.
 */
function Inicio() {
  const { cargando } = usePermisos()

  if (cargando) return null

  return <InicioPage />
}

/**
 * Se llego a una pantalla que el rol no tiene concedida.
 *
 * Lleva el boton para pedirla porque entrar es lo unico que NO abre el modal
 * solo: las vistas cargan catalogos de otros modulos al abrirse y un modal por
 * cada uno seria ruido. Aqui, en cambio, se sabe con certeza que la persona
 * queria entrar.
 */
function SinAcceso({ submodulo }: { submodulo?: string }) {
  const [pedido, setPedido] = useState(false)
  const [enviando, setEnviando] = useState(false)

  const pedir = async () => {
    if (!submodulo) return
    setEnviando(true)
    try {
      await solicitudApi.solicitar({ submodulo, accion: 'ver' })
      setPedido(true)
    } catch {
      // Sin ruido: el boton se queda como estaba y se puede reintentar.
    } finally {
      setEnviando(false)
    }
  }

  return (
    <div className="flex flex-col items-center justify-center gap-2 py-24 text-center">
      <ShieldOff size={32} className="text-ink-soft" />
      <p className="text-base font-semibold text-ink">No tienes acceso a esta pantalla</p>
      <p className="max-w-sm text-sm text-ink-muted">
        Tu rol no la incluye. Si necesitas entrar, pídeselo a un administrador.
      </p>

      {submodulo &&
        (pedido ? (
          <p className="mt-2 text-sm font-medium text-emerald-700">
            Listo, un administrador lo verá en su bandeja.
          </p>
        ) : (
          <Button className="mt-3" loading={enviando} onClick={() => void pedir()}>
            Pedir acceso
          </Button>
        ))}
    </div>
  )
}

export default App
