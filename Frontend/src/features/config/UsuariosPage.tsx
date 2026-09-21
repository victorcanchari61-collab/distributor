import { useCallback, useEffect, useState } from 'react'
import { Pencil, Plus, ShieldCheck, ShieldOff, UserCheck, UserCog, UserPlus } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  DocumentoInput,
  Desplegable,
  Input,
  ListPage,
  Modal,
  RowAction,
  StatCard,
  useToast,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { empleadoApi } from '../maestros'
import { rutaApi } from '../tms'
import type { RutaResponse } from '../tms'
import type { EmpleadoOpcion } from '../maestros'
import { consultaApi } from '../../lib/consultaApi'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { rolApi } from './rolApi'
import type { RolResponse } from './rolApi'
import { usuarioApi } from './usuarioApi'
import type { UsuarioResponse } from './usuarioApi'

/** Un usuario, tal como lo devuelve el API. */
export type Usuario = UsuarioResponse

const VACIO = { nombre: '', email: '', password: '', dni: '', rolId: 0, empleadoId: 0, rutaId: 0 }

export function UsuariosPage() {
  const { puede } = usePermisos()
  const [usuarios, setUsuarios] = useState<Usuario[]>([])
  const [cargando, setCargando] = useState(true)
  const [roles, setRoles] = useState<RolResponse[]>([])
  const [empleados, setEmpleados] = useState<EmpleadoOpcion[]>([])
  const [rutas, setRutas] = useState<RutaResponse[]>([])

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<Usuario | null>(null)
  const [form, setForm] = useState(VACIO)
  const [guardando, setGuardando] = useState(false)
  const toast = useToast()
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

  /*
   * Los empleados para enlazar la cuenta con su ficha.
   *
   * Si falla se sigue: el enlace es opcional, y quedarse sin poder crear un usuario porque el
   * padrón no cargó sería peor que crearlo sin ficha.
   */
  // Igual que los empleados: sin rutas se sigue, la ruta es opcional.
  const cargarRutas = useCallback(async () => {
    try {
      setRutas(await rutaApi.getAll())
    } catch {
      setRutas([])
    }
  }, [])

  const cargarEmpleados = useCallback(async () => {
    try {
      setEmpleados(await empleadoApi.opciones())
    } catch {
      setEmpleados([])
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
    void cargarEmpleados()
    void cargarRutas()
  }, [cargarRoles, cargarUsuarios, cargarEmpleados, cargarRutas])

  useRealtime('roles', cargarRoles)
  useRealtime('usuarios', cargarUsuarios)
  useRealtime('empleados', cargarEmpleados)

  const activos = usuarios.filter((u) => u.activo).length
  const admins = usuarios.filter((u) => u.rol === 'Administrador').length

  const abrirNuevo = () => {
    setEditando(null)
    setForm({ ...VACIO, rolId: roles[0]?.id ?? 0 })
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
      empleadoId: usuario.empleadoId ?? 0,
      rutaId: usuario.rutaId ?? 0,
    })
    setAbierto(true)
  }

  /*
   * Elegir empleado llena los datos de la cuenta con los de su ficha.
   *
   * Se pisa lo que haya, no solo lo vacío: elegir a alguien es decir "esta cuenta es de esta
   * persona", y al cambiar de empleado los datos del anterior tienen que irse con él. Lo que la
   * ficha no tiene se deja como está, en vez de borrarlo: un empleado sin correo cargado no debería
   * vaciar el que se acaba de escribir. "Sin empleado" tampoco borra nada — lo escrito sigue
   * sirviendo aunque la cuenta no sea de nadie del padrón.
   */
  const elegirEmpleado = (empleadoId: number) => {
    const empleado = empleados.find((e) => e.id === empleadoId)

    setForm((prev) => ({
      ...prev,
      empleadoId,
      ...(empleado
        ? {
            nombre: empleado.nombreCompleto,
            // El código interno de un extranjero no es un DNI: ese campo solo acepta 8 dígitos.
            dni: empleado.tipoDoc === 'DNI' ? empleado.documento : prev.dni,
            email: empleado.email ?? prev.email,
          }
        : {}),
    }))
  }

  /** Trae de RENIEC el nombre de la persona y llena el campo Nombre. */
  const consultarDni = async (dni: string) => {
    setConsultando(true)
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
      toast.error(e instanceof ApiError ? e.message : 'No pudimos consultar el DNI.')
    } finally {
      setConsultando(false)
    }
  }

  const guardar = async () => {

    if (!form.nombre.trim()) return toast.error('Ingresa el nombre del usuario.')
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) return toast.error('El correo no es válido.')
    if (!form.rolId) return toast.error('Selecciona un rol.')
    if (!editando && form.password.length < 6) {
      return toast.error('La contraseña debe tener al menos 6 caracteres.')
    }

    setGuardando(true)
    try {
      if (editando) {
        await usuarioApi.update(editando.id, {
          nombre: form.nombre.trim(),
          email: form.email.trim(),
          dni: form.dni || null,
          rolId: form.rolId,
          // 0 es "sin empleado": desenlaza la ficha.
          empleadoId: form.empleadoId || null,
          // 0 es "sin ruta": la quita.
          rutaId: form.rutaId || null,
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
          empleadoId: form.empleadoId || null,
          rutaId: form.rutaId || null,
        })
      }

      setAbierto(false)
      await cargarUsuarios()
      await cargarRoles()
    } catch (e) {
      toast.error(
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
    // Nombre, correo y DNI son datos únicos por persona: se buscan arriba,
    // no en el panel.
    { key: 'nombre', label: 'Nombre', filterable: false },
    { key: 'email', label: 'Correo', filterable: false },
    {
      key: 'dni',
      label: 'DNI',
      filterable: false,
      render: (row) => row.dni ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'empleado',
      label: 'Empleado',
      filterType: 'select',
      filterOptions: [
        { value: 'Con empleado', label: 'Con empleado' },
        { value: 'Sin empleado', label: 'Sin empleado' },
      ],
      value: (row) => (row.empleadoId ? 'Con empleado' : 'Sin empleado'),
      render: (row) =>
        row.empleado ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'ruta',
      label: 'Ruta',
      filterType: 'select',
      filterOptions: [
        { value: 'Sin ruta', label: 'Sin ruta' },
        ...rutas.map((r) => ({ value: r.nombre, label: `Ruta ${r.nombre}` })),
      ],
      value: (row) => row.ruta ?? 'Sin ruta',
      render: (row) => (row.ruta ? <Badge tone="neutral">Ruta {row.ruta}</Badge> : <span className="text-ink-soft">—</span>),
    },
    {
      key: 'rol',
      label: 'Rol',
      // Sale del catalogo de roles ya cargado, no de una lista fija.
      filterType: 'select',
      filterOptions: roles.map((r) => ({ value: r.nombre, label: r.nombre })),
      render: (row) => <Badge tone="sys">{row.rol}</Badge>,
    },
    {
      key: 'activo',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'Activo', label: 'Activo' },
        { value: 'Inactivo', label: 'Inactivo' },
      ],
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
          {/*
            De quién es esta cuenta, lo primero que se elige.

            Es OPCIONAL: hay cuentas que no son de nadie del padrón —soporte, la del dueño— y
            empleados que nunca entran al sistema. Va arriba porque al elegir a alguien se llenan
            solos su DNI, su nombre y su correo, y lo de abajo queda para corregir, no para teclear.

            El que ya tiene cuenta sale en la lista pero no se puede elegir: esconderlo dejaría
            pensando por qué no aparece, y al editar su propio usuario el selector saldría vacío.
          */}
          <label className="block">
            <span className="ui-label mb-1.5">
              Empleado <span className="font-normal text-ink-soft">(opcional)</span>
            </span>
            <select
              value={form.empleadoId}
              onChange={(e) => elegirEmpleado(Number(e.target.value))}
              className="h-[var(--height-field-md)] w-full cursor-pointer rounded-field border border-line bg-surface px-3 text-sm text-ink outline-none focus:border-ink-soft"
            >
              <option value={0}>Sin empleado</option>
              {empleados.map((e) => {
                const ocupado = e.usuarioId != null && e.usuarioId !== editando?.id
                return (
                  <option key={e.id} value={e.id} disabled={ocupado}>
                    {e.nombreCompleto}
                    {e.cargo ? ` — ${e.cargo}` : ''}
                    {ocupado ? ' (ya tiene usuario)' : ''}
                  </option>
                )
              })}
            </select>
            <span className="mt-1.5 block text-xs text-ink-soft">
              {empleados.length === 0
                ? 'Todavía no hay empleados registrados. Se dan de alta en Maestros → Empleados.'
                : 'Al elegirlo se llenan el DNI, el nombre y el correo de su ficha.'}
            </span>
          </label>

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

          {/*
            La cartera de clientes que atiende, para cualquier usuario y sin depender del rol: el dueño
            también vende y tiene la suya. Sola no restringe nada; lo que limita a "mis clientes" es el
            alcance del rol. Con ese alcance, sin ruta no ve ningún cliente.
          */}
          <Desplegable
            label="Ruta"
            optional
            placeholder="Sin ruta"
            value={form.rutaId}
            onChange={(v) => setForm({ ...form, rutaId: Number(v) })}
            options={[
              { value: 0, label: 'Sin ruta' },
              ...rutas
                // Una ruta desactivada no se asigna, pero se sigue mostrando a quien ya la tiene.
                .filter((r) => r.activo || r.id === form.rutaId)
                .map((r) => ({
                  value: r.id,
                  label: `Ruta ${r.nombre}`,
                  detalle: r.vendedores.length ? r.vendedores.join(', ') : 'sin vendedor',
                })),
            ]}
          />

        </div>
      </Modal>
    </ListPage>
  )
}
