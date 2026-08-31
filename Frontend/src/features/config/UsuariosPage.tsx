import { useState } from 'react'
import { Pencil, Plus, ShieldOff, UserCog } from 'lucide-react'
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
import { ApiError } from '../../lib/apiClient'
import { register } from '../auth/authApi'
import { ROLES, ROLES_LIST, type Rol } from './roles'

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

const VACIO = { nombre: '', email: '', password: '', role: 2 as Rol }

export function UsuariosPage() {
  const [usuarios, setUsuarios] = useState(USUARIOS)

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<Usuario | null>(null)
  const [form, setForm] = useState(VACIO)
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const activos = usuarios.filter((u) => u.activo).length
  const admins = usuarios.filter((u) => u.role === 1).length

  const abrirNuevo = () => {
    setEditando(null)
    setForm(VACIO)
    setErrorForm('')
    setAbierto(true)
  }

  const abrirEdicion = (usuario: Usuario) => {
    setEditando(usuario)
    setForm({ nombre: usuario.nombre, email: usuario.email, password: '', role: usuario.role })
    setErrorForm('')
    setAbierto(true)
  }

  const guardar = async () => {
    setErrorForm('')

    if (!form.nombre.trim()) return setErrorForm('Ingresa el nombre del usuario.')
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) return setErrorForm('El correo no es válido.')
    if (!editando && form.password.length < 6) {
      return setErrorForm('La contraseña debe tener al menos 6 caracteres.')
    }

    // Editar todavia no tiene endpoint: se ajusta solo en pantalla.
    if (editando) {
      setUsuarios((prev) =>
        prev.map((u) =>
          u.id === editando.id
            ? { ...u, nombre: form.nombre.trim(), email: form.email.trim(), role: form.role }
            : u,
        ),
      )
      setAbierto(false)
      return
    }

    setGuardando(true)
    try {
      const creado = await register({
        nombre: form.nombre.trim(),
        email: form.email.trim(),
        password: form.password,
        role: form.role,
      })

      setUsuarios((prev) => [
        ...prev,
        {
          id: creado.id,
          nombre: creado.nombre,
          email: creado.email,
          role: creado.role as Rol,
          activo: creado.activo,
          ultimoAcceso: '—',
        },
      ])
      setAbierto(false)
    } catch (e) {
      setErrorForm(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos crear el usuario.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const alternarEstado = (usuario: Usuario) =>
    setUsuarios((prev) =>
      prev.map((u) => (u.id === usuario.id ? { ...u, activo: !u.activo } : u)),
    )

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
    <ListPage
      icon={<UserCog size={20} />}
      title="Usuarios del sistema"
      description="Quién entra a la plataforma y con qué rol."
      actions={
        <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
          Nuevo usuario
        </Button>
      }
      stats={
        <>
          <StatCard
            label="Usuarios registrados"
            value={String(usuarios.length)}
            icon={<UserCog size={18} />}
          />
          <StatCard
            label="Activos"
            value={String(activos)}
            hint={`${usuarios.length - activos} deshabilitados`}
          />
          <StatCard label="Administradores" value={String(admins)} hint="con acceso total" />
        </>
      }
      columns={columns}
      rows={usuarios}
      cardIcon={UserCog}
      searchPlaceholder="Buscar por nombre, correo o rol..."
      empty="Todavía no hay usuarios registrados."
      rowActions={(row) => (
        <>
          <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)}>
            <Pencil size={15} />
          </RowAction>
          <RowAction
            label={`${row.activo ? 'Deshabilitar' : 'Habilitar'} ${row.nombre}`}
            tone={row.activo ? 'warning' : 'success'}
            onClick={() => alternarEstado(row)}
          >
            <ShieldOff size={15} />
          </RowAction>
        </>
      )}
    >
      <Modal
        open={abierto}
        title={editando ? `Editar ${editando.nombre}` : 'Nuevo usuario'}
        description={
          editando
            ? 'La contraseña se cambia desde el propio usuario.'
            : 'Se crea con acceso inmediato a la plataforma.'
        }
        onClose={() => setAbierto(false)}
        size="sm"
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Crear usuario'}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {errorForm && <Alert>{errorForm}</Alert>}

          <Input
            label="Nombre"
            placeholder="Ej. Lucía Torres"
            value={form.nombre}
            onChange={(e) => setForm({ ...form, nombre: e.target.value })}
          />

          <Input
            label="Correo electrónico"
            type="email"
            autoComplete="off"
            placeholder="usuario@distributor.com"
            value={form.email}
            onChange={(e) => setForm({ ...form, email: e.target.value })}
          />

          {!editando && (
            <Input
              label="Contraseña"
              type="password"
              revealable
              autoComplete="new-password"
              placeholder="Mínimo 6 caracteres"
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
            />
          )}

          <label className="block">
            <span className="ui-label mb-2">Rol</span>
            <select
              value={form.role}
              onChange={(e) => setForm({ ...form, role: Number(e.target.value) as Rol })}
              className="min-h-control w-full cursor-pointer rounded-field border border-line bg-surface px-3 text-sm text-ink outline-none transition-colors focus:border-brand focus:ring-4 focus:ring-brand-ring"
            >
              {ROLES_LIST.map((r) => (
                <option key={r.id} value={r.id}>
                  {r.label}
                </option>
              ))}
            </select>
            <span className="mt-1.5 block text-xs text-ink-soft">
              {ROLES[form.role].description}
            </span>
          </label>
        </div>
      </Modal>
    </ListPage>
  )
}

