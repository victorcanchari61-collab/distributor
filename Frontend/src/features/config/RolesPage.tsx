import { useCallback, useEffect, useState } from 'react'
import { IdCard, Pencil, Plus, ShieldCheck, ShieldOff, Trash2, Users } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Input,
  ListPage,
  Modal,
  RowAction,
  StatCard,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { NAV_GROUPS } from '../../components/layout'
import { ApiError } from '../../lib/apiClient'
import { rolApi } from './rolApi'
import type { RolResponse } from './rolApi'

export function RolesPage() {
  const [roles, setRoles] = useState<RolResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<RolResponse | null>(null)
  const [form, setForm] = useState({ nombre: '', descripcion: '' })
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const cargar = useCallback(async () => {
    setCargando(true)
    setError('')
    try {
      setRoles(await rolApi.getAll())
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los roles.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  const abrirNuevo = () => {
    setEditando(null)
    setForm({ nombre: '', descripcion: '' })
    setErrorForm('')
    setAbierto(true)
  }

  const abrirEdicion = (rol: RolResponse) => {
    setEditando(rol)
    setForm({ nombre: rol.nombre, descripcion: rol.descripcion ?? '' })
    setErrorForm('')
    setAbierto(true)
  }

  const guardar = async () => {
    setErrorForm('')
    if (!form.nombre.trim()) return setErrorForm('Ponle un nombre al rol.')

    setGuardando(true)
    try {
      if (editando) {
        await rolApi.update(editando.id, {
          nombre: form.nombre.trim(),
          descripcion: form.descripcion.trim(),
          activo: editando.activo,
        })
      } else {
        await rolApi.create({ nombre: form.nombre.trim(), descripcion: form.descripcion.trim() })
      }
      setAbierto(false)
      await cargar()
    } catch (e) {
      setErrorForm(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos guardar el rol.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const alternarEstado = async (rol: RolResponse) => {
    setError('')
    try {
      await rolApi.update(rol.id, {
        nombre: rol.nombre,
        descripcion: rol.descripcion,
        activo: !rol.activo,
      })
      await cargar()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado del rol.')
    }
  }

  const eliminar = async (rol: RolResponse) => {
    setError('')
    try {
      await rolApi.remove(rol.id)
      await cargar()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos eliminar el rol.')
    }
  }

  /** Modulos a los que el rol tiene acceso. */
  const modulosDe = (rol: RolResponse) => rol.permisos.filter((p) => p.ver).length

  const columns: DataTableColumn<RolResponse>[] = [
    {
      key: 'nombre',
      label: 'Rol',
      render: (row) => (
        <span className="flex items-center gap-2">
          <span className="font-semibold text-ink">{row.nombre}</span>
          {row.delSistema && <Badge>del sistema</Badge>}
        </span>
      ),
    },
    { key: 'descripcion', label: 'Qué puede hacer' },
    { key: 'usuarios', label: 'Usuarios', align: 'right', value: (row) => row.usuarios },
    {
      key: 'modulos',
      label: 'Módulos',
      align: 'right',
      value: (row) => modulosDe(row),
      render: (row) => (
        <Badge tone="sys">
          {modulosDe(row)} de {NAV_GROUPS.length}
        </Badge>
      ),
    },
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
    <ListPage
      icon={<IdCard size={20} />}
      title="Roles"
      description="Define los perfiles de trabajo. Lo que cada rol puede tocar se configura en Accesos."
      actions={
        <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
          Nuevo rol
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard
            label="Roles definidos"
            value={String(roles.length)}
            hint={`${roles.filter((r) => r.activo).length} activos`}
            icon={<IdCard size={18} />}
          />
          <StatCard
            label="Usuarios asignados"
            value={String(roles.reduce((total, r) => total + r.usuarios, 0))}
            icon={<Users size={18} />}
          />
          <StatCard label="Módulos del sistema" value={String(NAV_GROUPS.length)} />
        </>
      }
      columns={columns}
      rows={roles}
      cardIcon={IdCard}
      searchPlaceholder="Buscar rol..."
      empty={cargando ? 'Cargando roles...' : 'Todavía no hay roles definidos.'}
      rowActions={(row) => (
        <>
          <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)}>
            <Pencil size={15} />
          </RowAction>
          {!row.delSistema && (
            <>
              <RowAction
                label={`${row.activo ? 'Desactivar' : 'Activar'} ${row.nombre}`}
                tone={row.activo ? 'warning' : 'success'}
                onClick={() => void alternarEstado(row)}
              >
                {row.activo ? <ShieldOff size={15} /> : <ShieldCheck size={15} />}
              </RowAction>
              <RowAction
                label={`Eliminar ${row.nombre}`}
                tone="danger"
                onClick={() => void eliminar(row)}
              >
                <Trash2 size={15} />
              </RowAction>
            </>
          )}
        </>
      )}
      note="Los roles del sistema no se pueden eliminar ni desactivar, y un rol con usuarios asignados tampoco se elimina."
    >
      <Modal
        open={abierto}
        title={editando ? `Editar ${editando.nombre}` : 'Nuevo rol'}
        description="El nombre y la descripción ayudan a saber para quién es este perfil."
        onClose={() => setAbierto(false)}
        size="sm"
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
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
            value={form.nombre}
            onChange={(e) => setForm({ ...form, nombre: e.target.value })}
          />

          <label className="block">
            <span className="ui-label mb-2">Qué puede hacer</span>
            <textarea
              rows={3}
              placeholder="Describe en una línea el alcance de este perfil."
              value={form.descripcion}
              onChange={(e) => setForm({ ...form, descripcion: e.target.value })}
              className="w-full rounded-field border border-line bg-surface px-3 py-2 text-sm text-ink outline-none transition-colors placeholder:text-ink-soft focus:border-ink-soft"
            />
          </label>

          <p className="text-xs text-ink-soft">
            Después de crearlo, define sus permisos en <b>Accesos</b>.
          </p>
        </div>
      </Modal>
    </ListPage>
  )
}
