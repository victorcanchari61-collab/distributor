import type { LucideIcon } from 'lucide-react'
import {
  Banknote,
  Boxes,
  Building2,
  CalendarCheck,
  CalendarDays,
  ClipboardCheck,
  ClipboardList,
  Contact,
  CreditCard,
  FileMinus,
  FileText,
  Gauge,
  Hash,
  IdCard,
  Landmark,
  LayoutGrid,
  MapPin,
  MapPinned,
  Package,
  PackageCheck,
  PackagePlus,
  ReceiptText,
  Route,
  Ruler,
  Settings,
  ShieldCheck,
  ShoppingCart,
  Sliders,
  Store,
  Tags,
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
      { id: 'maestros.productos', label: 'Productos', icon: Package, pending: true },
      { id: 'maestros.categorias', label: 'Categorías y marcas', icon: Tags, pending: true },
      { id: 'maestros.almacenes', label: 'Almacenes', icon: Warehouse, pending: true },
      { id: 'maestros.unidades', label: 'Unidades de medida', icon: Ruler, pending: true },
      { id: 'maestros.precios', label: 'Listas de precios', icon: Banknote, pending: true },
    ],
  },
  {
    id: 'compras',
    label: 'Compras',
    sys: 'compras',
    icon: ShoppingCart,
    items: [
      { id: 'compras.ordenes', label: 'Órdenes de compra', icon: ClipboardList, pending: true },
      { id: 'compras.recepciones', label: 'Recepciones', icon: PackageCheck, pending: true },
      { id: 'compras.pagar', label: 'Cuentas por pagar', icon: CreditCard, pending: true },
    ],
  },
  {
    id: 'inv',
    label: 'Inventario',
    sys: 'inv',
    icon: Boxes,
    items: [
      { id: 'inv.stock', label: 'Stock por almacén', icon: Warehouse, pending: true },
      { id: 'inv.movimientos', label: 'Movimientos', icon: PackagePlus, pending: true },
      { id: 'inv.transferencias', label: 'Transferencias', icon: Truck, pending: true },
      { id: 'inv.conteos', label: 'Conteos cíclicos', icon: ClipboardCheck, pending: true },
      { id: 'inv.lotes', label: 'Lotes y vencimientos', icon: CalendarDays, pending: true },
    ],
  },
  {
    id: 'fact',
    label: 'Facturación',
    sys: 'fact',
    icon: ReceiptText,
    items: [
      { id: 'fact.pedidos', label: 'Pedidos', icon: ClipboardList, pending: true },
      { id: 'fact.comprobantes', label: 'Comprobantes', icon: FileText, pending: true },
      { id: 'fact.notas', label: 'Notas de crédito y débito', icon: FileMinus, pending: true },
      { id: 'fact.cobrar', label: 'Cuentas por cobrar', icon: Wallet, pending: true },
      { id: 'fact.caja', label: 'Caja', icon: Landmark, pending: true },
    ],
  },
  {
    id: 'tms',
    label: 'TMS',
    sys: 'tms',
    icon: Truck,
    items: [
      { id: 'tms.rutas', label: 'Rutas', icon: Route, pending: true },
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
      { id: 'config.accesos', label: 'Roles y accesos', icon: ShieldCheck },
      { id: 'config.empresa', label: 'Empresa', icon: Building2 },
      { id: 'config.sucursales', label: 'Sucursales', icon: MapPin },
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
