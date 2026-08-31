import { IdCard, Pencil, Plus, Users } from 'lucide-react'
import { Badge, Button, PageSection, StatCard, SysDataTable } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { NAV_GROUPS } from '../../components/layout'
import { ACCESOS_INICIALES, ROLES_LIST } from './roles'
import type { Rol } from './roles'

interface RolFila {
  id: Rol
  label: string
  description: string
  usuarios: number
  modulos: number
}

/** Cuantos usuarios tiene cada rol. Sale del listado de usuarios de muestra. */
const USUARIOS_POR_ROL: Record<Rol, number> = { 1: 1, 2: 2, 3: 2 }

export function RolesPage() {
  const filas: RolFila[] = ROLES_LIST.map((r) => ({
    id: r.id,
    label: r.label,
    description: r.description,
    usuarios: USUARIOS_POR_ROL[r.id],
    modulos: NAV_GROUPS.filter((g) => (ACCESOS_INICIALES[r.id][g.id] ?? []).length > 0).length,
  }))

  const columns: DataTableColumn<RolFila>[] = [
    {
      key: 'label',
      label: 'Rol',
      render: (row) => <span className="font-semibold text-ink">{row.label}</span>,
    },
    { key: 'description', label: 'Qué puede hacer' },
    {
      key: 'usuarios',
      label: 'Usuarios',
      align: 'right',
      value: (row) => row.usuarios,
    },
    {
      key: 'modulos',
      label: 'Módulos',
      align: 'right',
      value: (row) => row.modulos,
      render: (row) => (
        <Badge tone="sys">
          {row.modulos} de {NAV_GROUPS.length}
        </Badge>
      ),
    },
  ]

  return (
    <div className="space-y-5">
      <section className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <StatCard label="Roles definidos" value={String(filas.length)} icon={<IdCard size={18} />} />
        <StatCard
          label="Usuarios asignados"
          value={String(filas.reduce((total, f) => total + f.usuarios, 0))}
          icon={<Users size={18} />}
        />
        <StatCard label="Módulos del sistema" value={String(NAV_GROUPS.length)} />
      </section>

      <PageSection
        title="Roles"
        description="Define los perfiles de trabajo. Lo que cada rol puede tocar se configura en Accesos."
        icon={<IdCard size={18} />}
        actions={
          <Button size="sm" iconRight={<Plus size={15} />}>
            Nuevo rol
          </Button>
        }
      >
        <SysDataTable
          columns={columns}
          rows={filas}
          cardIcon={IdCard}
          searchPlaceholder="Buscar rol..."
          empty="Todavía no hay roles definidos."
          actions={(row) => (
            <button
              type="button"
              title={`Editar ${row.label}`}
              aria-label={`Editar ${row.label}`}
              className="cursor-pointer rounded-md p-1.5 text-zinc-500 transition-colors hover:bg-[rgb(var(--sys-rgb)/0.12)] hover:text-[rgb(var(--sys-ink-rgb))]"
            >
              <Pencil size={15} />
            </button>
          )}
        />

        <p className="mt-3 text-xs text-ink-soft">
          Los tres roles actuales vienen del enum <code>Role</code> del backend. Crear roles nuevos
          requiere convertirlos en tabla.
        </p>
      </PageSection>
    </div>
  )
}
