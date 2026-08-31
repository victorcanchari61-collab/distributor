import type { ModuleIconKey } from '../../components/ui/ModuleIcon'

export interface SystemEntry {
  key: ModuleIconKey
  title: string
  subtitle: string
  description: string
  modules: number
  /** Degradado de la tarjeta: parte del acento del carrusel del login. */
  from: string
  to: string
}

export const SYSTEMS: SystemEntry[] = [
  {
    key: 'FACT',
    title: 'Facturación',
    subtitle: 'Comprobantes y cobranza',
    description: 'Facturas, boletas, notas de crédito, series e impuestos sobre la misma base.',
    modules: 59,
    from: '#2563eb',
    to: '#1e40af',
  },
  {
    key: 'INV',
    title: 'Inventario',
    subtitle: 'Almacenes y existencias',
    description: 'Ingresos, salidas, transferencias, lotes, vencimientos y conteos cíclicos.',
    modules: 83,
    from: '#0e9f6e',
    to: '#046c4e',
  },
  {
    key: 'TMS',
    title: 'TMS',
    subtitle: 'Sistema de Gestión de Transporte',
    description: 'Flota, rutas, tracking y liquidación de reparto.',
    modules: 72,
    from: '#0891b2',
    to: '#155e75',
  },
  {
    key: 'DMS',
    title: 'DMS',
    subtitle: 'Distribución y Despacho',
    description: 'Entregas, devoluciones y rechazos confirmados en el punto de venta.',
    modules: 54,
    from: '#db2777',
    to: '#9d174d',
  },
  {
    key: 'RRHH',
    title: 'RRHH',
    subtitle: 'Recursos Humanos (RR. HH.)',
    description: 'Empleados, asistencia, nómina y evaluación de desempeño.',
    modules: 116,
    from: '#d97706',
    to: '#92400e',
  },
  {
    key: 'CONFIG',
    title: 'Configuración',
    subtitle: 'Configuración del sistema',
    description: 'Usuarios, accesos y parámetros de todos los sistemas.',
    modules: 64,
    from: '#475569',
    to: '#1e293b',
  },
]
