import { Eye, FileText, Package, Pencil, Receipt, Truck, Users } from 'lucide-react'
import { StatCard, SysDataTable } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'

interface Comprobante {
  id: number
  numero: string
  cliente: string
  fecha: string
  estado: 'Aceptada' | 'Enviada' | 'Pendiente' | 'Anulada'
  total: number
}

/** Datos de muestra hasta que existan los endpoints del listado. */
const COMPROBANTES: Comprobante[] = [
  { id: 1, numero: 'F001-2280', cliente: 'Minimarket Lucero', fecha: '2026-08-31', estado: 'Aceptada', total: 3420 },
  { id: 2, numero: 'B001-9114', cliente: 'Bodega San Martín', fecha: '2026-08-31', estado: 'Enviada', total: 486 },
  { id: 3, numero: 'F001-2279', cliente: 'Distribuidora El Sol', fecha: '2026-08-30', estado: 'Aceptada', total: 12750 },
  { id: 4, numero: 'NC-042', cliente: 'Minimarket Lucero', fecha: '2026-08-30', estado: 'Pendiente', total: -320 },
  { id: 5, numero: 'F001-2278', cliente: 'Comercial Andina', fecha: '2026-08-29', estado: 'Aceptada', total: 8940 },
  { id: 6, numero: 'B001-9113', cliente: 'Bodega Los Pinos', fecha: '2026-08-29', estado: 'Anulada', total: 220 },
  { id: 7, numero: 'F001-2277', cliente: 'Market Express', fecha: '2026-08-28', estado: 'Aceptada', total: 5610 },
]

const ESTADO_COLOR: Record<Comprobante['estado'], string> = {
  Aceptada: 'bg-emerald-50 text-emerald-700 ring-emerald-200',
  Enviada: 'bg-blue-50 text-blue-700 ring-blue-200',
  Pendiente: 'bg-amber-50 text-amber-700 ring-amber-200',
  Anulada: 'bg-red-50 text-red-700 ring-red-200',
}

const money = (n: number) =>
  `S/ ${n.toLocaleString('es-PE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`

const COLUMNS: DataTableColumn<Comprobante>[] = [
  { key: 'numero', label: 'Comprobante' },
  { key: 'cliente', label: 'Cliente' },
  { key: 'fecha', label: 'Fecha' },
  {
    key: 'estado',
    label: 'Estado',
    render: (row) => (
      <span
        className={`inline-flex rounded-full px-2 py-0.5 text-[11px] font-semibold ring-1 ${ESTADO_COLOR[row.estado]}`}
      >
        {row.estado}
      </span>
    ),
  },
  {
    key: 'total',
    label: 'Total',
    align: 'right',
    value: (row) => row.total,
    render: (row) => money(row.total),
  },
]

export function DashboardPage() {
  return (
    <div className="space-y-6">
      <section className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Facturado hoy"
          value="S/ 62,480"
          trend={12.4}
          hint="vs. ayer"
          icon={<Receipt size={18} />}
        />
        <StatCard
          label="Órdenes por despachar"
          value="38"
          trend={-4.2}
          hint="7 con retraso"
          icon={<Package size={18} />}
        />
        <StatCard
          label="Entregas en ruta"
          value="11"
          trend={3.1}
          hint="94% a tiempo"
          icon={<Truck size={18} />}
        />
        <StatCard
          label="Personal activo"
          value="32"
          hint="3 con tardanza"
          icon={<Users size={18} />}
        />
      </section>

      <section className="rounded-panel border border-line bg-white p-4 sm:p-5">
        <div className="mb-4 flex items-center gap-2">
          <FileText size={18} className="text-[rgb(var(--sys-rgb))]" />
          <h2 className="text-base font-bold text-ink">Últimos comprobantes</h2>
        </div>

        <SysDataTable
          columns={COLUMNS}
          rows={COMPROBANTES}
          cardIcon={FileText}
          searchPlaceholder="Buscar comprobante o cliente..."
          pageSize={30}
          actions={(row) => (
            <>
              <button
                type="button"
                title={`Ver ${row.numero}`}
                aria-label={`Ver ${row.numero}`}
                className="cursor-pointer rounded-md p-1.5 text-zinc-500 transition-colors hover:bg-[rgb(var(--sys-rgb)/0.12)] hover:text-[rgb(var(--sys-ink-rgb))]"
              >
                <Eye size={15} />
              </button>
              <button
                type="button"
                title={`Editar ${row.numero}`}
                aria-label={`Editar ${row.numero}`}
                className="cursor-pointer rounded-md p-1.5 text-zinc-500 transition-colors hover:bg-[rgb(var(--sys-rgb)/0.12)] hover:text-[rgb(var(--sys-ink-rgb))]"
              >
                <Pencil size={15} />
              </button>
            </>
          )}
        />
      </section>
    </div>
  )
}
