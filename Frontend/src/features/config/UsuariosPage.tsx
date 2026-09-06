import { useCallback, useEffect, useState } from 'react'
import { Pencil, Plus, ShieldCheck, ShieldOff, UserCheck, UserCog, UserPlus } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  DocumentoInput,
  Input,
  ListPage,
  Modal,
  RowAction,
  StatCard,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { consultaApi } from '../../lib/consultaApi'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { rolApi } from './rolApi'
import type { RolResponse } from './rolApi'
import { usuarioApi } from './usuarioApi'
import type { UsuarioResponse } from './usuarioApi'

/** Un usuario, tal como lo devuelve el API. */
export type Usuario = UsuarioResponse

const VACIO = { nombre: '', email: '', password: '', dni: '', rolId: 0 }

export function UsuariosPage() {
  const { puede } = usePermisos()
  const [usuarios, setUsuarios] = useState<Usuario[]>([])
  const [cargando, setCargando] = useState(true)
  const [roles, setRoles] = useState<RolResponse[]>([])

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<Usuario | null>(null)
  const [form, setForm] = useState(VACIO)
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')
  const [error, setError] = useState('')
  const [consultando, setConsultando] = useState(false)

  // Los roles del selector salen de la tabla Roles, no de una lista fija.
  const cargarRoles = useCallback(async () => {
    try {
      setRoles((await rolApi.getAll()).filter((r) => r.activo))
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los roles.')
    }
  }, [])

  // El listado sale de la tabla Usuarios: antes eran datos de muestra porque
  // el API no lo exponia, y lo que se veia aqui no coincidia con la base.
  const cargarUsuarios = useCallback(async () => {
    setCargando(true)
    try {
      setUsuarios(await usuarioApi.getAll())
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los usuarios.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargarRoles()
    void cargarUsuarios()
  }, [cargarRoles, cargarUsuarios])

  useRealtime('roles', cargarRoles)
  useRealtime('usuarios', cargarUsuarios)

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
    setForm({
      nombre: usuario.nombre,
      email: usuario.email,
      password: '',
      dni: usuario.dni ?? '',
      rolId: usuario.rolId,
    })
    setErrorForm('')
    setAbierto(true)
  }

  /** Trae de RENIEC el nombre de la persona y llena el campo Nombre. */
  const consultarDni = async (dni: string) => {
    setConsultando(true)
    setErrorForm('')
    try {
      const datos = await consultaApi.dni(dni)
      setForm((prev) => ({
        ...prev,
        dni: datos.dni,
        nombre: `${datos.apellidoPaterno} ${datos.apellidoMaterno} ${datos.nombres}`
          .replace(/\s+/g, ' ')
          .trim(),
      }))
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos consultar el DNI.')
    } finally {
      setConsultando(false)
    }
  }

  const guardar = async () => {
    setErrorForm('')

    if (!form.nombre.trim()) return setErrorForm('Ingresa el nombre del usuario.')
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) return setErrorForm('El correo no es válido.')
    if (!form.rolId) return setErrorForm('Selecciona un rol.')
    if (!editando && form.password.length < 6) {
      return setErrorForm('La contraseña debe tener al menos 6 caracteres.')
    }

    setGuardando(true)
    try {
      if (editando) {
        await usuarioApi.update(editando.id, {
          nombre: form.nombre.trim(),
          email: form.email.trim(),
          dni: form.dni || null,
          rolId: form.rolId,
          activo: editando.activo,
          // Vacio: el backend deja la contraseña que ya tenia.
          password: form.password || null,
        })
      } else {
        await usuarioApi.create({
          nombre: form.nombre.trim(),
          email: form.email.trim(),
          password: form.password,
          dni: form.dni || null,
          rolId: form.rolId,
        })
      }

      setAbierto(false)
      await cargarUsuarios()
      await cargarRoles()
    } catch (e) {
      setErrorForm(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : editando
            ? 'No pudimos guardar los cambios.'
            : 'No pudimos crear el usuario.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const alternarEstado = async (usuario: Usuario) => {
    setError('')
    try {
      await usuarioApi.update(usuario.id, {
        nombre: usuario.nombre,
        email: usuario.email,
        dni: usuario.dni,
        rolId: usuario.rolId,
        activo: !usuario.activo,
      })
      await cargarUsuarios()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
    }
  }

  const columns: DataTableColumn<Usuario>[] = [
    { key: 'nombre', label: 'Nombre' },
    { key: 'email', label: 'Correo' },
    {
      key: 'dni',
      label: 'DNI',
      render: (row) => row.dni ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'rol',
      label: 'Rol',
      render: (row) => <Badge tone="sys">{row.rol}</Badge>,
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

  const rolElegido = roles.find((r) => r.id === form.rolId)

  return (
    <ListPage
      icon={<UserCog size={20} />}
      title="Usuarios del sistema"
      description="Quién entra a la plataforma y con qué rol."
      actions={
        puede('config.usuarios', 'crear') ? (
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nuevo usuario
          </Button>
        ) : undefined
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
            icon={<UserCheck size={18} />}
            tono="success"
            hint={`${usuarios.length - activos} deshabilitados`}
          />
          <StatCard
            label="Administradores"
            value={String(admins)}
            icon={<UserPlus size={18} />}
            tono="warning"
            hint="con acceso total"
          />
        </>
      }
      columns={columns}
      rows={usuarios}
      cardIcon={UserCog}
      searchPlaceholder="Buscar por nombre, correo o rol..."
      empty={cargando ? 'Cargando usuarios...' : 'Todavía no hay usuarios registrados.'}
      rowActions={(row) => (
        <>
          {puede('config.usuarios', 'editar') && (
            <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)}>
              <Pencil size={15} />
            </RowAction>
          )}
          {puede('config.usuarios', 'editar') && (
            <RowAction
              label={`${row.activo ? 'Deshabilitar' : 'Habilitar'} ${row.nombre}`}
              tone={row.activo ? 'warning' : 'success'}
              onClick={() => void alternarEstado(row)}
            >
              {row.activo ? <ShieldOff size={15} /> : <ShieldCheck size={15} />}
            </RowAction>
          )}
        </>
      )}
    >
      <Modal
        open={abierto}
        title={editando ? `Editar ${editando.nombre}` : 'Nuevo usuario'}
        description={
          editando
            ? 'Deja la contraseña vacía para no cambiarla.'
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

          {/* Un usuario es una persona: siempre DNI. */}
          <DocumentoInput
            tipo="DNI"
            tipoFijo
            label="DNI"
            placeholder="45871203"
            value={form.dni}
            onChange={(dni) => setForm({ ...form, dni })}
            onBuscar={consultarDni}
            buscando={consultando}
            optional
          />

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

          {/* Al editar se puede dejar vacia: cambiar el nombre de alguien no
              deberia obligar a reescribir su clave. */}
          <Input
            label={editando ? 'Nueva contraseña' : 'Contraseña'}
            type="password"
            revealable
            optional={!!editando}
            autoComplete="new-password"
            placeholder={editando ? 'Dejar vacío para no cambiarla' : 'Mínimo 6 caracteres'}
            value={form.password}
            onChange={(e) => setForm({ ...form, password: e.target.value })}
          />

          <label className="block">
            <span className="ui-label mb-1.5">Rol</span>
            <select
              value={form.rolId}
              onChange={(e) => setForm({ ...form, rolId: Number(e.target.value) })}
              className="h-[var(--height-field-md)] w-full cursor-pointer rounded-field border border-line bg-surface px-3 text-sm text-ink outline-none focus:border-ink-soft"
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
