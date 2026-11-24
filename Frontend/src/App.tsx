import { lazy, Suspense, useEffect, useRef, useState } from 'react'
import type { ComponentType } from 'react'
import { Home, LayoutDashboard, ShieldOff, UserRound } from 'lucide-react'
import { useLocation, useNavigate } from 'react-router-dom'
import { DashboardLayout, navIdFromPath, navPath, puedeAbrir, resolveNav, useFormatoNavegacion } from './components/layout'
import { AccesoRapidoContexto } from './components/layout/AccesoRapidoContexto'
import { pulsarAccesoRapido } from './components/layout/accesosRapidos'
import type { AccesoRapido } from './components/layout/accesosRapidos'
import { BarraPestanas, ContenidoPestanas, usePestanasTrabajo } from './components/pestanas'
import type { OpcionMenu, PestanaTrabajo } from './components/pestanas'
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
  'inv.plano': pantalla(() => import('./features/inventario'), 'PlanoPage'),
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

  return (
    // Se remonta al cambiar de usuario: si no, quien entrara despues heredaria
    // los permisos que quedaron cargados de la sesion anterior.
    <PermisosProvider key={usuario.id}>
      <Panel
        usuario={usuario}
        onSalir={() => {
          clearSession()
          setUsuario(null)
          navigate('/', { replace: true })
        }}
      />
    </PermisosProvider>
  )
}

/** La pestaña de Mi perfil: no es del menú (es de todos), pero se abre como cualquier otra. */
const PERFIL = 'perfil'

/** La clave de pestaña de una ruta: "" es Inicio, "perfil" Mi perfil, y el resto el id del menú ("inv.plano"). */
const claveDeRuta = (pathname: string) =>
  pathname.replace(/^\/+|\/+$/g, '') === PERFIL ? PERFIL : navIdFromPath(pathname)
const rutaDeClave = (clave: string) => (clave === '' ? '/' : clave === PERFIL ? '/perfil' : navPath(clave))

/** Lo que puede ser una pestaña: Inicio, Mi perfil y las vistas del menú. Fuera del componente: tiene que ser estable. */
const esClaveValida = (clave: string) => clave === '' || clave === PERFIL || resolveNav(clave).item !== undefined

/** Cuántas vistas sin pestaña se guardan montadas en el fondo para los accesos rápidos (las más recientes). */
const MAXIMO_EN_FONDO = 4

/** Cuántas pestañas puede tener abiertas una persona a la vez. */
const MAXIMO_PESTANAS = 12

/**
 * El panel de quien entró: el menú, las pestañas de trabajo y lo que muestra cada una.
 *
 * Las vistas no se pintan por ruta sino en pestañas, como en un navegador: entrar a una vista desde el menú la abre
 * en una pestaña nueva (o enfoca la que ya la tiene) y cada pestaña conserva lo suyo al ir y volver. La URL solo dice
 * cuál está a la vista, así un enlace compartido sigue abriendo la pantalla correcta.
 */
function Panel({ usuario, onSalir }: { usuario: UsuarioResponse; onSalir: () => void }) {
  const navigate = useNavigate()
  const location = useLocation()

  // Las pestañas abiertas y el formato del menú se recuerdan por usuario: no se mezclan al cambiar de cuenta.
  const pestanas = usePestanasTrabajo({
    claveRuta: claveDeRuta(location.pathname),
    onNavegar: (clave) => navigate(rutaDeClave(clave), { replace: true }),
    claveGuardado: `distribuidora.pestanas.${usuario.id}`,
    esValida: esClaveValida,
    maximo: MAXIMO_PESTANAS,
  })
  const [formato, setFormato] = useFormatoNavegacion(`distribuidora.navegacion.${usuario.id}`)

  // Entrar a una vista desde el menú abre su pestaña (o enfoca la que ya la tiene). Con el máximo alcanzado no cabe
  // otra: la vista reemplaza a la de la pestaña activa.
  const abrir = (clave: string) => {
    if (pestanas.claves.includes(clave) || pestanas.caben) pestanas.abrir(clave)
    else navigate(rutaDeClave(clave))
  }

  // Accesos rápidos del menú (Nuevo cliente, Importar…): el modal sale encima de la vista en la que se está, sin
  // cambiar de pestaña. Si la vista del botón no está abierta, se monta oculta en el fondo para poder pulsarlo; solo se
  // va a ella si el botón no abre un modal sino que cambia la propia vista (un formulario de página completa).
  const [enFondo, setEnFondo] = useState<string[]>([])
  const abrirVista = useRef(abrir)
  useEffect(() => {
    abrirVista.current = abrir
  })
  const usarAcceso = (vista: string, acceso: AccesoRapido) => {
    if (!pestanas.claves.includes(vista)) {
      setEnFondo((f) => [...f.filter((c) => c !== vista), vista].slice(-MAXIMO_EN_FONDO))
    }
    pulsarAccesoRapido(vista, acceso, () => abrirVista.current(vista))
  }

  const cerrable = pestanas.claves.length > 1
  const lista: PestanaTrabajo[] = pestanas.claves.map((clave) => {
    if (clave === '') return { clave, etiqueta: 'Inicio', icono: Home, sys: 'brand', cerrable }
    if (clave === PERFIL) return { clave, etiqueta: 'Mi perfil', icono: UserRound, sys: 'brand', cerrable }
    const { group, item } = resolveNav(clave)
    return {
      clave,
      etiqueta: item?.label ?? clave,
      titulo: group ? `${group.label} › ${item?.label ?? ''}` : item?.label,
      icono: item?.icon ?? LayoutDashboard,
      sys: group?.sys ?? 'brand',
      cerrable,
    }
  })

  // Clic derecho sobre una pestaña.
  const opcionesDe = (clave: string): OpcionMenu[] => {
    const en = pestanas.claves.indexOf(clave)
    return [
      { etiqueta: 'Cerrar pestaña', onElegir: () => pestanas.cerrar(clave), desactivada: !cerrable },
      { etiqueta: 'Cerrar las demás', onElegir: () => pestanas.cerrarOtras(clave), desactivada: !cerrable },
      {
        etiqueta: 'Cerrar las de la derecha',
        onElegir: () => pestanas.cerrarDerecha(clave),
        desactivada: en === pestanas.claves.length - 1,
      },
    ]
  }

  return (
    <AccesoRapidoContexto.Provider value={usarAcceso}>
    <DashboardLayout
      active={pestanas.activa}
      onSelect={abrir}
      userName={usuario.nombre}
      userEmail={usuario.email}
      userFoto={usuario.foto}
      onPerfil={() => abrir(PERFIL)}
      onLogout={onSalir}
      formato={formato}
      onFormato={setFormato}
      pestanas={
        <BarraPestanas
          pestanas={lista}
          activa={pestanas.activa}
          onElegir={(clave) => navigate(rutaDeClave(clave), { replace: true })}
          onCerrar={pestanas.cerrar}
          opcionesDe={opcionesDe}
        />
      }
    >
      <ContenidoPestanas
        claves={pestanas.claves}
        activa={pestanas.activa}
        cargando={<Cargando />}
        enFondo={enFondo}
        pintar={(clave) => (clave === '' ? <Inicio /> : clave === PERFIL ? <MiPerfilPage /> : <Vista id={clave} />)}
      />

      {/*
        Se monta una vez, fuera de las vistas: cualquier 403 del filtro de
        permisos lo abre, venga de donde venga, sin que cada pantalla tenga que
        acordarse de manejarlo.
      */}
      <SolicitudPermisoModal />
    </DashboardLayout>
    </AccesoRapidoContexto.Provider>
  )
}

/** La vista de una pestaña. */
function Vista({ id }: { id: string }) {
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
