export interface ModuleSlide {
  key: 'FACT' | 'INV' | 'TMS' | 'DMS' | 'RRHH'
  label: string
  accent: string
  title: string
  description: string
  rows: { title: string; subtitle: string; status: string }[]
  footer: string
}

export const MODULES: ModuleSlide[] = [
  {
    key: 'FACT',
    label: 'Facturación',
    accent: 'var(--color-fact)',
    title: 'Del pedido al comprobante, sin rehacer nada',
    description:
      'Facturas, boletas y notas de crédito con series, impuestos y envío electrónico. El pedido se registra una vez y sale como comprobante.',
    rows: [
      { title: 'Factura F001-2280', subtitle: 'Minimarket Lucero · S/ 3,420', status: 'Aceptada' },
      { title: 'Boleta B001-9114', subtitle: 'Bodega San Martín · S/ 486', status: 'Enviada' },
      { title: 'Nota de crédito NC-042', subtitle: 'Devolución DV-33', status: 'Pendiente' },
    ],
    footer: 'Facturado hoy: S/ 62,480 · 214 comprobantes',
  },
  {
    key: 'INV',
    label: 'Inventario',
    accent: 'var(--color-inv)',
    title: 'Stock real por almacén, lote y vencimiento',
    description:
      'Ingresos, salidas, transferencias y conteos cíclicos. Sabes qué tienes, dónde está y cuánto vale, al instante.',
    rows: [
      { title: 'Ingreso RC-155', subtitle: 'Andina S.A.C. · 6 pallets', status: 'Verificando' },
      { title: 'Transferencia TR-088', subtitle: 'Almacén Central → Callao', status: 'En tránsito' },
      { title: 'Conteo cíclico Zona A', subtitle: 'Diferencia 0.4%', status: 'Cerrado' },
    ],
    footer: 'Exactitud de inventario: 99.2% · 1,842 SKU',
  },
  {
    key: 'TMS',
    label: 'TMS',
    accent: 'var(--color-tms)',
    title: 'Rutas, unidades y entregas en un solo tablero',
    description:
      'Arma la ruta, asigna la unidad y sigue cada entrega en vivo, con evidencia de descarga y costos por viaje.',
    rows: [
      { title: 'Ruta 4 · Lima Norte', subtitle: 'Carlos Mendoza · 14 paradas', status: 'En ruta' },
      { title: 'Ruta 7 · Callao', subtitle: 'Unidad B2F-114', status: 'Cargando' },
      { title: 'Ruta 2 · Ate', subtitle: '12 de 12 entregas', status: 'Completada' },
    ],
    footer: 'Entregas a tiempo: 94% · 11 unidades activas',
  },
  {
    key: 'DMS',
    label: 'DMS',
    accent: 'var(--color-dms)',
    title: 'Lo que pasó en el cliente, registrado al instante',
    description:
      'Visitas, cobranzas, devoluciones y evidencias desde el celular del vendedor. Todo vuelve a inventario y caja.',
    rows: [
      { title: 'Visita · Bodega El Sol', subtitle: 'Pedido S/ 1,240', status: 'Cerrada' },
      { title: 'Cobranza · Minimarket Lucero', subtitle: 'S/ 860 en efectivo', status: 'Registrada' },
      { title: 'Devolución DV-33', subtitle: '3 cajas por vencimiento', status: 'En revisión' },
    ],
    footer: 'Cobertura del día: 128 de 140 clientes',
  },
  {
    key: 'RRHH',
    label: 'RRHH',
    accent: 'var(--color-rrhh)',
    title: 'Tu gente, del ingreso a la nómina',
    description:
      'Empleados, asistencia, vacaciones, nómina y desempeño. Un solo lugar para todo el equipo.',
    rows: [
      { title: 'Carlos Mendoza', subtitle: 'Repartidor · TMS', status: 'En ruta' },
      { title: 'Lucía Torres', subtitle: 'Almacenera · Inventario', status: 'Asistió' },
      { title: 'Pedro Ramos', subtitle: 'Vendedor · Ruta 4', status: 'Tardanza' },
    ],
    footer: 'Nómina del mes: S/ 48,200 · 32 empleados',
  },
]
