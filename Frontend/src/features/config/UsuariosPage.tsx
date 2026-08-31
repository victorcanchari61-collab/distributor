import { useState } from 'react'
import { Pencil, Plus, ShieldOff, UserCog } from 'lucide-react'
import { Badge, Button, PageSection, StatCard, SysDataTable } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ROLES, type Rol } from './roles'

export interface Usuario {
  id: number
  nombre: string
  email: string
  role: Rol
  activo: boolean
  ultimoAcceso: string
}

/** Datos de muestra: la API todavia no expone el listado de usuarios. */
const USUARIOS: Usuario[] = [
  { id: 1, nombre: 'Admin', email: 'admin@distributor.com', role: 1, activo: true, ultimoAcceso: '2026-08-31 09:14' },
  { id: 2, nombre: 'Lucía Torres', email: 'ltorres@distributor.com', role: 3, activo: true, ultimoAcceso: '2026-08-31 07:58' },
  { id: 3, nombre: 'Pedro Ramos', email: 'pramos@distributor.com', role: 2, activo: true, ultimoAcceso: '2026-08-30 18:02' },
  { id: 4, nombre: 'Carlos Mendoza', email: 'cmendoza@distributor.com', role: 2, activo: true, ultimoAcceso: '2026-08-30 16:41' },
  { id: 5, nombre: 'Rosa Díaz', email: 'rdiaz@distributor.com', role: 3, activo: false, ultimoAcceso: '2026-07-12 11:20' },
]

export function UsuariosPage() {
  const [usuarios] = useState(USUARIOS)

  const activos = usuarios.filter((u) => u.activo).length
  const admins = usuarios.filter((u) => u.role === 1).length

  const columns: DataTableColumn<Usuario>[] = [
    { key: 'nombre', label: 'Nombre' },
    { key: 'email', label: 'Correo' },
    {
      key: 'role',
      label: 'Rol',
      value: (row) => ROLES[row.role].label,
      render: (row) => <Badge tone="sys">{ROLES[row.role].label}</Badge>,
    },
    { key: 'ultimoAcceso', label: 'Último acceso' },
    {
      key: 'activo',
      label: 'Estado',
      value: (row) => (row.activo ? 'Activo' : 'Inactivo'),
      render: (row) => (
        <Badge tone={row.activo ? 'success' : 'neutral'}>{row.activo ? 'Activo' : 'Inactivo'}</Badge>
      ),
    },
  ]

  return (
    <div className="space-y-5">
      <section className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <StatCard label="Usuarios registrados" value={String(usuarios.length)} icon={<UserCog size={18} />} />
        <StatCard label="Activos" value={String(activos)} hint={`${usuarios.length - activos} deshabilitados`} />
        <StatCard label="Administradores" value={String(admins)} hint="con acceso total" />
      </section>

      <PageSection
        title="Usuarios del sistema"
        description="Quién entra a la plataforma, con qué rol y en qué sucursal."
        icon={<UserCog size={18} />}
        actions={
          <Button size="sm" iconRight={<Plus size={15} />}>
            Nuevo usuario
          </Button>
        }
      >
        <SysDataTable
          columns={columns}
          rows={usuarios}
          cardIcon={UserCog}
          searchPlaceholder="Buscar por nombre, correo o rol..."
          empty="Todavía no hay usuarios registrados."
          actions={(row) => (
            <>
              <RowAction label={`Editar ${row.nombre}`}>
                <Pencil size={15} />
              </RowAction>
              <RowAction label={`Deshabilitar ${row.nombre}`}>
                <ShieldOff size={15} />
              </RowAction>
            </>
          )}
        />
      </PageSection>
    </div>
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
