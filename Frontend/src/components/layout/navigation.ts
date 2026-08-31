import type { LucideIcon } from 'lucide-react'
import {
  Boxes,
  ClipboardList,
  FileText,
  Landmark,
  MapPinned,
  Package,
  ReceiptText,
  Route,
  Settings,
  ShieldCheck,
  Store,
  Truck,
  UserCog,
  Users,
  Warehouse,
} from 'lucide-react'

/** Clave de color: coincide con los `data-sys` de styles/systems.css. */
export type SysKey = 'brand' | 'fact' | 'inv' | 'tms' | 'dms' | 'rrhh' | 'config'

export interface NavItem {
  id: string
  label: string
  icon: LucideIcon
  badge?: string
}

export interface NavGroup {
  id: string
  label: string
  sys: SysKey
  icon: LucideIcon
  items: NavItem[]
}

export const NAV_GROUPS: NavGroup[] = [
  {
    id: 'fact',
    label: 'Facturación',
    sys: 'fact',
    icon: ReceiptText,
    items: [
      { id: 'fact.comprobantes', label: 'Comprobantes', icon: FileText, badge: '12' },
      { id: 'fact.clientes', label: 'Clientes', icon: Users },
      { id: 'fact.caja', label: 'Caja y cobranza', icon: Landmark },
    ],
  },
  {
    id: 'inv',
    label: 'Inventario',
    sys: 'inv',
    icon: Boxes,
    items: [
      { id: 'inv.stock', label: 'Stock por almacén', icon: Warehouse },
      { id: 'inv.movimientos', label: 'Movimientos', icon: Package },
      { id: 'inv.conteos', label: 'Conteos cíclicos', icon: ClipboardList },
    ],
  },
  {
    id: 'tms',
    label: 'TMS',
    sys: 'tms',
    icon: Truck,
    items: [
      { id: 'tms.rutas', label: 'Rutas', icon: Route, badge: '3' },
      { id: 'tms.flota', label: 'Flota', icon: Truck },
      { id: 'tms.tracking', label: 'Tracking', icon: MapPinned },
    ],
  },
  {
    id: 'dms',
    label: 'DMS',
    sys: 'dms',
    icon: Store,
    items: [
      { id: 'dms.visitas', label: 'Visitas', icon: Store },
      { id: 'dms.devoluciones', label: 'Devoluciones', icon: Package },
    ],
  },
  {
    id: 'rrhh',
    label: 'RR. HH.',
    sys: 'rrhh',
    icon: Users,
    items: [
      { id: 'rrhh.empleados', label: 'Empleados', icon: Users },
      { id: 'rrhh.asistencia', label: 'Asistencia', icon: ClipboardList },
      { id: 'rrhh.nomina', label: 'Nómina', icon: Landmark },
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
