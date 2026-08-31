import { MapPin, Pencil, Plus, Trash2 } from 'lucide-react'
import { Badge, Button, PageSection, SysDataTable } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'

interface Sucursal {
  id: number
  codigo: string
  nombre: string
  direccion: string
  telefono: string
  tipo: 'Oficina' | 'Almacén' | 'Punto de venta'
  activa: boolean
}

/** Datos de muestra: la API de sucursales todavia no existe. */
const SUCURSALES: Sucursal[] = [
  { id: 1, codigo: 'S001', nombre: 'Sede Central', direccion: 'Av. Argentina 1420, Lima', telefono: '(01) 555-1200', tipo: 'Oficina', activa: true },
  { id: 2, codigo: 'S002', nombre: 'Almacén Callao', direccion: 'Jr. Los Cedros 240, Callao', telefono: '(01) 555-1233', tipo: 'Almacén', activa: true },
  { id: 3, codigo: 'S003', nombre: 'Almacén Central', direccion: 'Av. Argentina 1420, Lima', telefono: '(01) 555-1201', tipo: 'Almacén', activa: true },
  { id: 4, codigo: 'S004', nombre: 'Punto Lima Norte', direccion: 'Av. Túpac Amaru 890, Comas', telefono: '(01) 555-4410', tipo: 'Punto de venta', activa: false },
]

const COLUMNS: DataTableColumn<Sucursal>[] = [
  { key: 'codigo', label: 'Código' },
  { key: 'nombre', label: 'Nombre' },
  { key: 'direccion', label: 'Dirección' },
  { key: 'telefono', label: 'Teléfono' },
  { key: 'tipo', label: 'Tipo', render: (row) => <Badge tone="sys">{row.tipo}</Badge> },
  {
    key: 'activa',
    label: 'Estado',
    value: (row) => (row.activa ? 'Activa' : 'Inactiva'),
    render: (row) => (
      <Badge tone={row.activa ? 'success' : 'neutral'}>{row.activa ? 'Activa' : 'Inactiva'}</Badge>
    ),
  },
]

export function SucursalesPage() {
  return (
    <PageSection
      title="Sucursales"
      description="Oficinas, almacenes y puntos de venta donde opera la empresa activa."
      icon={<MapPin size={18} />}
      actions={
        <Button size="sm" iconRight={<Plus size={15} />}>
          Nueva sucursal
        </Button>
      }
    >
      <SysDataTable
        columns={COLUMNS}
        rows={SUCURSALES}
        cardIcon={MapPin}
        searchPlaceholder="Buscar sucursal por nombre o dirección..."
        empty="Todavía no hay sucursales registradas."
        actions={(row) => (
          <>
            <RowAction label={`Editar ${row.nombre}`}>
              <Pencil size={15} />
            </RowAction>
            <RowAction label={`Eliminar ${row.nombre}`}>
              <Trash2 size={15} />
            </RowAction>
          </>
        )}
      />
    </PageSection>
  )
}

function RowAction({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <button
      type="button"
      title={label}
      aria-label={label}
      className="cursor-pointer rounded-md p-1.5 text-zinc-500 transition-colors hover:bg-[rgb(var(--sys-rgb)/0.12)] hover:text-[rgb(var(--sys-ink-rgb))]"
    >
      {children}
    </button>
  )
}
