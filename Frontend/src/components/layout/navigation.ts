import type { LucideIcon } from 'lucide-react'
import {
  Banknote,
  Boxes,
  Building2,
  Calculator,
  CalendarCheck,
  CalendarDays,
  ClipboardCheck,
  ClipboardList,
  Coins,
  Contact,
  CreditCard,
  FileMinus,
  FileText,
  Gauge,
  HandCoins,
  Hash,
  IdCard,
  Landmark,
  LayoutGrid,
  MapPinned,
  Package,
  PackageCheck,
  PackagePlus,
  PackageSearch,
  Receipt,
  ReceiptText,
  Route,
  ScrollText,
  Settings,
  ShieldCheck,
  ShoppingBag,
  ShoppingCart,
  Sliders,
  Store,
  Truck,
  Undo2,
  UserCog,
  Users,
  Warehouse,
  Wallet,
} from 'lucide-react'

/** Clave de color: coincide con los `data-sys` de styles/systems.css. */
export type SysKey =
  | 'brand'
  | 'maestros'
  | 'compras'
  | 'inv'
  | 'finanzas'
  | 'fact'
  | 'tms'
  | 'dms'
  | 'rrhh'
  | 'config'

export interface NavItem {
  id: string
  label: string
  icon: LucideIcon
  badge?: string
  /** Marca las vistas que todavia no existen. */
  pending?: boolean
  /** No se pinta en el sider (queda reservada para mas adelante). */
  hidden?: boolean
}

export interface NavGroup {
  id: string
  label: string
  sys: SysKey
  icon: LucideIcon
  items: NavItem[]
}

/**
 * Modulos y submodulos del sistema.
 *
 * Clientes y Proveedores viven en Maestros porque los consumen varios
 * sistemas: al cliente lo factura Facturacion, lo visita DMS y lo entrega TMS;
 * al proveedor le compra Compras y le recepciona Inventario. Un solo lugar
 * donde crearlos y editarlos, los demas modulos solo los seleccionan.
 */
export const NAV_GROUPS: NavGroup[] = [
  {
    id: 'maestros',
    label: 'Maestros',
    sys: 'maestros',
    icon: LayoutGrid,
    items: [
      { id: 'maestros.clientes', label: 'Clientes', icon: Contact },
      { id: 'maestros.proveedores', label: 'Proveedores', icon: Building2 },
      { id: 'maestros.productos', label: 'Productos', icon: Package },
    ],
  },
  {
    id: 'compras',
    label: 'Compras',
    sys: 'compras',
    icon: ShoppingCart,
    // El flujo manda el orden: se emite una orden al proveedor, cuando este
    // la confirma se convierte en compra, y al llegar la mercaderia se
    // registra la recepcion.
    items: [
      { id: 'compras.ordenes', label: 'Órdenes de compra', icon: ClipboardList },
      { id: 'compras.compras', label: 'Mis compras', icon: ShoppingBag },
      { id: 'compras.recepciones', label: 'Recepciones', icon: PackageCheck },
    ],
  },
  {
    id: 'inv',
    label: 'Inventario',
    sys: 'inv',
    icon: Boxes,
    items: [
      { id: 'inv.almacenes', label: 'Almacenes', icon: Warehouse },
      { id: 'inv.stock', label: 'Stock por almacén', icon: PackageSearch },
      { id: 'inv.kardex', label: 'Kardex', icon: PackagePlus },
      { id: 'inv.ajustes', label: 'Ajustes de inventario', icon: ClipboardCheck },
      { id: 'inv.transferencias', label: 'Transferencias', icon: Truck },
      { id: 'inv.prestamos', label: 'Préstamos', icon: HandCoins },
      { id: 'inv.lotes', label: 'Lotes y vencimientos', icon: CalendarDays },
      { id: 'inv.conteos', label: 'Conteos cíclicos', icon: ClipboardCheck },
    ],
  },
  {
    id: 'fact',
    label: 'Facturación',
    sys: 'fact',
    icon: ReceiptText,
    // Por ahora no se factura: se trabaja con pedido y nota de venta. Los
    // comprobantes electronicos quedan reservados, junto a Series y Parametros
    // en Configuracion, para cuando el cliente decida facturar.
    items: [
      { id: 'fact.pedidos', label: 'Pedidos', icon: ClipboardList, pending: true },
      { id: 'fact.notaventa', label: 'Notas de venta', icon: FileText, pending: true },
      { id: 'fact.precios', label: 'Listas de precios', icon: Banknote },
      { id: 'fact.comprobantes', label: 'Comprobantes', icon: Receipt, pending: true, hidden: true },
      {
        id: 'fact.notas',
        label: 'Notas de crédito y débito',
        icon: FileMinus,
        pending: true,
        hidden: true,
      },
    ],
  },
  {
    id: 'finanzas',
    label: 'Finanzas',
    sys: 'finanzas',
    icon: Landmark,
    items: [
      { id: 'finanzas.metodospago', label: 'Métodos de pago', icon: Coins },
      { id: 'finanzas.cobrar', label: 'Cuentas por cobrar', icon: Wallet },
      { id: 'finanzas.pagar', label: 'Cuentas por pagar', icon: CreditCard },
      { id: 'finanzas.miscobros', label: 'Mis cobros', icon: HandCoins },
      { id: 'finanzas.arqueo', label: 'Arqueo diario', icon: Calculator },
    ],
  },
  {
    id: 'tms',
    label: 'TMS',
    sys: 'tms',
    icon: Truck,
    items: [
      { id: 'tms.mercados', label: 'Mercados', icon: Store },
      { id: 'tms.rutas', label: 'Rutas', icon: Route },
      { id: 'tms.flota', label: 'Flota', icon: Truck, pending: true },
      { id: 'tms.conductores', label: 'Conductores', icon: IdCard, pending: true },
      { id: 'tms.tracking', label: 'Tracking', icon: MapPinned, pending: true },
      { id: 'tms.liquidacion', label: 'Liquidación de reparto', icon: Banknote, pending: true },
    ],
  },
  {
    id: 'dms',
    label: 'DMS',
    sys: 'dms',
    icon: Store,
    items: [
      { id: 'dms.visitas', label: 'Visitas', icon: Store, pending: true },
      { id: 'dms.cobranzas', label: 'Cobranzas', icon: Wallet, pending: true },
      { id: 'dms.devoluciones', label: 'Devoluciones', icon: Undo2, pending: true },
      { id: 'dms.evidencias', label: 'Evidencias', icon: ClipboardCheck, pending: true },
    ],
  },
  {
    id: 'rrhh',
    label: 'RR. HH.',
    sys: 'rrhh',
    icon: Users,
    items: [
      { id: 'rrhh.empleados', label: 'Empleados', icon: Users, pending: true },
      { id: 'rrhh.asistencia', label: 'Asistencia', icon: CalendarCheck, pending: true },
      { id: 'rrhh.vacaciones', label: 'Vacaciones', icon: CalendarDays, pending: true },
      { id: 'rrhh.nomina', label: 'Nómina', icon: Banknote, pending: true },
      { id: 'rrhh.desempeno', label: 'Desempeño', icon: Gauge, pending: true },
    ],
  },
  {
    id: 'config',
    label: 'Configuración',
    sys: 'config',
    icon: Settings,
    items: [
      { id: 'config.usuarios', label: 'Usuarios', icon: UserCog },
      { id: 'config.roles', label: 'Roles', icon: IdCard },
      { id: 'config.accesos', label: 'Accesos', icon: ShieldCheck },
      { id: 'config.empresa', label: 'Empresa', icon: Building2 },
      { id: 'config.auditoria', label: 'Auditoría', icon: ScrollText },
      // Reservados: se muestran cuando el cliente decida usar facturacion.
      { id: 'config.series', label: 'Series de comprobantes', icon: Hash, pending: true, hidden: true },
      { id: 'config.parametros', label: 'Parámetros', icon: Sliders, pending: true, hidden: true },
    ],
  },
]

/** Color de sistema y titulo de una entrada del menu. */
export function resolveNav(itemId: string): { sys: SysKey; group?: NavGroup; item?: NavItem } {
  const group = NAV_GROUPS.find((g) => g.items.some((i) => i.id === itemId))
  if (!group) return { sys: 'brand' }
  return { sys: group.sys, group, item: group.items.find((i) => i.id === itemId) }
}

/** Primera vista del menu: la que se abre al entrar. */
export const NAV_DEFAULT = NAV_GROUPS[0].items[0].id

/**
 * Ruta de una entrada del menu. El id ya tiene la forma modulo.vista, asi que
 * 'config.usuarios' se convierte en '/config/usuarios' sin declarar nada mas.
 */
export function navPath(itemId: string) {
  return `/${itemId.split('.').join('/')}`
}

/** Id del menu a partir de la ruta del navegador. */
export function navIdFromPath(pathname: string) {
  return pathname.replace(/^\/+|\/+$/g, '').split('/').join('.')
}
