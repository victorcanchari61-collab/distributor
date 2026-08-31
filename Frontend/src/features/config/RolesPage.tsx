import { useState } from 'react'
import { IdCard, Pencil, Plus, Trash2, Users } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Input,
  Modal,
  PageHeader,
  PageSection,
  StatCard,
  SysDataTable,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { NAV_GROUPS } from '../../components/layout'
import { ACCESOS_INICIALES, ROLES_LIST } from './roles'
import type { Rol } from './roles'

interface RolFila {
  id: number
  label: string
  description: string
  usuarios: number
  modulos: number
  /** Los tres del enum del backend no se pueden eliminar. */
  delSistema: boolean
}

/** Cuantos usuarios tiene cada rol. Sale del listado de usuarios de muestra. */
const USUARIOS_POR_ROL: Record<Rol, number> = { 1: 1, 2: 2, 3: 2 }

const FILAS_INICIALES: RolFila[] = ROLES_LIST.map((r) => ({
  id: r.id,
  label: r.label,
  description: r.description,
  usuarios: USUARIOS_POR_ROL[r.id],
  modulos: NAV_GROUPS.filter((g) => (ACCESOS_INICIALES[r.id][g.id] ?? []).length > 0).length,
  delSistema: true,
}))

export function RolesPage() {
  const [filas, setFilas] = useState<RolFila[]>(FILAS_INICIALES)

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<RolFila | null>(null)
  const [form, setForm] = useState({ label: '', description: '' })
  const [errorForm, setErrorForm] = useState('')

  const abrirNuevo = () => {
    setEditando(null)
    setForm({ label: '', description: '' })
    setErrorForm('')
    setAbierto(true)
  }

  const abrirEdicion = (fila: RolFila) => {
    setEditando(fila)
    setForm({ label: fila.label, description: fila.description })
    setErrorForm('')
    setAbierto(true)
  }

  const guardar = () => {
    const label = form.label.trim()
    if (!label) {
      setErrorForm('Ponle un nombre al rol.')
      return
    }
    if (filas.some((f) => f.label.toLowerCase() === label.toLowerCase() && f.id !== editando?.id)) {
      setErrorForm('Ya existe un rol con ese nombre.')
      return
    }

    if (editando) {
      setFilas((prev) =>
        prev.map((f) =>
          f.id === editando.id ? { ...f, label, description: form.description.trim() } : f,
        ),
      )
    } else {
      setFilas((prev) => [
        ...prev,
        {
          id: Math.max(0, ...prev.map((f) => f.id)) + 1,
          label,
          description: form.description.trim(),
          usuarios: 0,
          modulos: 0,
          delSistema: false,
        },
      ])
    }

    setAbierto(false)
  }

  const eliminar = (fila: RolFila) => setFilas((prev) => prev.filter((f) => f.id !== fila.id))

  const columns: DataTableColumn<RolFila>[] = [
    {
      key: 'label',
      label: 'Rol',
      render: (row) => (
        <span className="flex items-center gap-2">
          <span className="font-semibold text-ink">{row.label}</span>
          {row.delSistema && <Badge>del sistema</Badge>}
        </span>
      ),
    },
    { key: 'description', label: 'Qué puede hacer' },
    { key: 'usuarios', label: 'Usuarios', align: 'right', value: (row) => row.usuarios },
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
      <PageHeader
        icon={<IdCard size={20} />}
        title="Roles"
        description="Define los perfiles de trabajo. Lo que cada rol puede tocar se configura en Accesos."
        actions={
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nuevo rol
          </Button>
        }
      />

      <section className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <StatCard label="Roles definidos" value={String(filas.length)} icon={<IdCard size={18} />} />
        <StatCard
          label="Usuarios asignados"
          value={String(filas.reduce((total, f) => total + f.usuarios, 0))}
          icon={<Users size={18} />}
        />
        <StatCard label="Módulos del sistema" value={String(NAV_GROUPS.length)} />
      </section>

      <PageSection>
        <SysDataTable
          columns={columns}
          rows={filas}
          cardIcon={IdCard}
          searchPlaceholder="Buscar rol..."
          empty="Todavía no hay roles definidos."
          actions={(row) => (
            <>
              <RowAction label={`Editar ${row.label}`} onClick={() => abrirEdicion(row)}>
                <Pencil size={15} />
              </RowAction>
              {!row.delSistema && (
                <RowAction label={`Eliminar ${row.label}`} onClick={() => eliminar(row)}>
                  <Trash2 size={15} />
                </RowAction>
              )}
            </>
          )}
        />

        <p className="mt-3 text-xs text-ink-soft">
          Los tres roles marcados <b>del sistema</b> vienen del enum <code>Role</code> del backend y
          no se pueden eliminar. Los que crees aquí viven solo en pantalla hasta que ese enum pase a
          ser tabla.
        </p>
      </PageSection>

      <Modal
        open={abierto}
        title={editando ? `Editar ${editando.label}` : 'Nuevo rol'}
        description="El nombre y la descripción ayudan a saber para quién es este perfil."
        onClose={() => setAbierto(false)}
        size="sm"
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" onClick={guardar}>
              {editando ? 'Guardar cambios' : 'Crear rol'}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {errorForm && <Alert>{errorForm}</Alert>}

          <Input
            label="Nombre del rol"
            placeholder="Ej. Supervisor de almacén"
            value={form.label}
            onChange={(e) => setForm({ ...form, label: e.target.value })}
          />

          <label className="block">
            <span className="ui-label mb-2">Qué puede hacer</span>
            <textarea
              rows={3}
              placeholder="Describe en una línea el alcance de este perfil."
              value={form.description}
              onChange={(e) => setForm({ ...form, description: e.target.value })}
              className="w-full rounded-field border border-line bg-surface px-3 py-2 text-sm text-ink outline-none transition-colors placeholder:text-ink-soft focus:border-brand focus:ring-4 focus:ring-brand-ring"
            />
          </label>

          <p className="text-xs text-ink-soft">
            Después de crearlo, define sus permisos en <b>Accesos</b>.
          </p>
        </div>
      </Modal>
    </div>
  )
}

function RowAction({
  label,
  onClick,
  children,
}: {
  label: string
  onClick: () => void
  children: React.ReactNode
}) {
  return (
    <button
      type="button"
      title={label}
      aria-label={label}
      onClick={onClick}
      className="cursor-pointer rounded-md p-1.5 text-zinc-500 transition-colors hover:bg-[rgb(var(--sys-rgb)/0.12)] hover:text-[rgb(var(--sys-ink-rgb))]"
    >
      {children}
    </button>
  )
}
