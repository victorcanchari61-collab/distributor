import { useCallback, useEffect, useState } from 'react'
import { Pencil, Plus, ShieldCheck, ShieldOff, UserCog } from 'lucide-react'
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
import { rolApi } from './rolApi'
import type { RolResponse } from './rolApi'

export interface Usuario {
  id: number
  nombre: string
  email: string
  rolId: number
  rol: string
  activo: boolean
  ultimoAcceso: string
}

/** Datos de muestra: la API todavia no expone el listado de usuarios. */
const USUARIOS: Usuario[] = [
  { id: 1, nombre: 'Admin', email: 'admin@distributor.com', rolId: 1, rol: 'Administrador', activo: true, ultimoAcceso: '2026-08-31 09:14' },
  { id: 2, nombre: 'Lucía Torres', email: 'ltorres@distributor.com', rolId: 3, rol: 'Almacenero', activo: true, ultimoAcceso: '2026-08-31 07:58' },
  { id: 3, nombre: 'Pedro Ramos', email: 'pramos@distributor.com', rolId: 2, rol: 'Vendedor', activo: true, ultimoAcceso: '2026-08-30 18:02' },
  { id: 4, nombre: 'Carlos Mendoza', email: 'cmendoza@distributor.com', rolId: 2, rol: 'Vendedor', activo: true, ultimoAcceso: '2026-08-30 16:41' },
  { id: 5, nombre: 'Rosa Díaz', email: 'rdiaz@distributor.com', rolId: 3, rol: 'Almacenero', activo: false, ultimoAcceso: '2026-07-12 11:20' },
]

const VACIO = { nombre: '', email: '', password: '', rolId: 0 }

export function UsuariosPage() {
  const [usuarios, setUsuarios] = useState(USUARIOS)
  const [roles, setRoles] = useState<RolResponse[]>([])

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<Usuario | null>(null)
  const [form, setForm] = useState(VACIO)
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')
  const [error, setError] = useState('')

  // Los roles del selector salen de la tabla Roles, no de una lista fija.
  const cargarRoles = useCallback(async () => {
    try {
      setRoles((await rolApi.getAll()).filter((r) => r.activo))
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los roles.')
    }
  }, [])

  useEffect(() => {
    void cargarRoles()
  }, [cargarRoles])

  const activos = usuarios.filter((u) => u.activo).length
  const admins = usuarios.filter((u) => u.rol === 'Administrador').length

  const abrirNuevo = () => {
    setEditando(null)
    setForm({ ...VACIO, rolId: roles[0]?.id ?? 0 })
    setErrorForm('')
    setAbierto(true)
  }

  const abrirEdicion = (usuario: Usuario) => {
    setEditando(usuario)
    setForm({ nombre: usuario.nombre, email: usuario.email, password: '', rolId: usuario.rolId })
    setErrorForm('')
    setAbierto(true)
  }

  const guardar = async () => {
    setErrorForm('')

    if (!form.nombre.trim()) return setErrorForm('Ingresa el nombre del usuario.')
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) return setErrorForm('El correo no es válido.')
    if (!form.rolId) return setErrorForm('Selecciona un rol.')
    if (!editando && form.password.length < 6) {
      return setErrorForm('La contraseña debe tener al menos 6 caracteres.')
    }

    // Editar todavia no tiene endpoint: se ajusta solo en pantalla.
    if (editando) {
      const rol = roles.find((r) => r.id === form.rolId)
      setUsuarios((prev) =>
        prev.map((u) =>
          u.id === editando.id
            ? {
                ...u,
                nombre: form.nombre.trim(),
                email: form.email.trim(),
                rolId: form.rolId,
                rol: rol?.nombre ?? u.rol,
              }
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
        rolId: form.rolId,
      })

      setUsuarios((prev) => [
        ...prev,
        {
          id: creado.id,
          nombre: creado.nombre,
          email: creado.email,
          rolId: creado.rolId,
          rol: creado.rol,
          activo: creado.activo,
          ultimoAcceso: '—',
        },
      ])
      setAbierto(false)
      await cargarRoles()
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
    setUsuarios((prev) => prev.map((u) => (u.id === usuario.id ? { ...u, activo: !u.activo } : u)))

  const columns: DataTableColumn<Usuario>[] = [
    { key: 'nombre', label: 'Nombre' },
    { key: 'email', label: 'Correo' },
    {
      key: 'rol',
      label: 'Rol',
      render: (row) => <Badge tone="sys">{row.rol}</Badge>,
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

  const rolElegido = roles.find((r) => r.id === form.rolId)

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
      alert={error ? <Alert>{error}</Alert> : undefined}
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
            {row.activo ? <ShieldOff size={15} /> : <ShieldCheck size={15} />}
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
              value={form.rolId}
              onChange={(e) => setForm({ ...form, rolId: Number(e.target.value) })}
              className="min-h-control w-full cursor-pointer rounded-field border border-line bg-surface px-3 text-sm text-ink outline-none transition-colors focus:border-brand focus:ring-4 focus:ring-brand-ring"
            >
              <option value={0}>Selecciona un rol</option>
              {roles.map((r) => (
                <option key={r.id} value={r.id}>
                  {r.nombre}
                </option>
              ))}
            </select>
            {rolElegido?.descripcion && (
              <span className="mt-1.5 block text-xs text-ink-soft">{rolElegido.descripcion}</span>
            )}
          </label>
        </div>
      </Modal>
    </ListPage>
  )
}
