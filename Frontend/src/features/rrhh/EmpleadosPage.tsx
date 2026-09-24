import { useCallback, useEffect, useState } from 'react'
import { fechaCorta } from '../../lib/fechas'
import { BadgeCheck, IdCard, Pencil, Plus, ShieldCheck, ShieldOff, Trash2, UserRound, Users } from 'lucide-react'
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
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { DataTableColumn, TipoDocumento } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { consultaApi } from '../../lib/consultaApi'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { empleadoApi } from './empleadoApi'
import type { EmpleadoRequest, EmpleadoResponse } from './empleadoApi'

const VACIO: EmpleadoRequest = {
  documento: '',
  tipoDoc: 'DNI',
  nombres: '',
  apellidos: '',
  telefono: '',
  email: '',
  direccion: '',
  cargo: '',
  area: '',
  fechaIngreso: '',
  fechaCese: '',
  observacion: '',
}

/** Una fecha del servidor, como la espera un <input type="date">. */
const paraCampo = (iso: string | null) => (iso ? iso.slice(0, 10) : '')

/**
 * Empleados: quién trabaja en el negocio.
 *
 * Es un maestro y no una cuenta de acceso. Se registra a todos —el estibador que nunca entra al
 * sistema también— y al crear un usuario se elige, opcionalmente, a quién pertenece esa cuenta.
 * Al que se va se le pone fecha de cese y se desactiva: su ficha queda, porque los documentos que
 * registró siguen apuntando a él.
 */
export function EmpleadosPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const [empleados, setEmpleados] = useState<EmpleadoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<EmpleadoResponse | null>(null)
  const [form, setForm] = useState<EmpleadoRequest>(VACIO)
  const [guardando, setGuardando] = useState(false)
  const [consultando, setConsultando] = useState(false)
  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    setError('')
    try {
      setEmpleados(await empleadoApi.getAll())
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los empleados.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  // Enlazar una ficha a una cuenta cambia la columna "Usuario" de esta lista.
  useRealtime(['empleados', 'usuarios'], cargar)

  const abrirNuevo = () => {
    setEditando(null)
    setForm(VACIO)
    setAbierto(true)
  }

  const abrirEdicion = (empleado: EmpleadoResponse) => {
    setEditando(empleado)
    setForm({
      documento: empleado.documento,
      tipoDoc: empleado.tipoDoc,
      nombres: empleado.nombres,
      apellidos: empleado.apellidos,
      telefono: empleado.telefono ?? '',
      email: empleado.email ?? '',
      direccion: empleado.direccion ?? '',
      cargo: empleado.cargo ?? '',
      area: empleado.area ?? '',
      fechaIngreso: paraCampo(empleado.fechaIngreso),
      fechaCese: paraCampo(empleado.fechaCese),
      observacion: empleado.observacion ?? '',
    })
    setAbierto(true)
  }

  /** Trae de RENIEC los nombres y apellidos, para no teclearlos. */
  const consultarDni = async (dni: string) => {
    setConsultando(true)
    try {
      const datos = await consultaApi.dni(dni)
      setForm((prev) => ({
        ...prev,
        documento: datos.dni,
        tipoDoc: 'DNI',
        nombres: datos.nombres.trim(),
        apellidos: `${datos.apellidoPaterno} ${datos.apellidoMaterno}`.replace(/\s+/g, ' ').trim(),
      }))
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos consultar el DNI.')
    } finally {
      setConsultando(false)
    }
  }

  const guardar = async () => {
    if (!form.documento.trim()) return toast.error('Ingresa el documento.')
    if (form.tipoDoc === 'DNI' && !/^[0-9]{8}$/.test(form.documento)) {
      return toast.error('El DNI debe tener 8 dígitos.')
    }
    if (!form.nombres.trim()) return toast.error('Ingresa los nombres.')
    if (!form.apellidos.trim()) return toast.error('Ingresa los apellidos.')
    if (form.fechaIngreso && form.fechaCese && form.fechaCese < form.fechaIngreso) {
      return toast.error('La fecha de cese no puede ser anterior a la de ingreso.')
    }

    // Las fechas vacías viajan como null: "" no es una fecha para el servidor.
    const cuerpo: EmpleadoRequest = {
      ...form,
      fechaIngreso: form.fechaIngreso || null,
      fechaCese: form.fechaCese || null,
    }

    setGuardando(true)
    try {
      if (editando) await empleadoApi.update(editando.id, { ...cuerpo, activo: editando.activo })
      else await empleadoApi.create(cuerpo)
      setAbierto(false)
      await cargar()
      toast.exito(editando ? 'Empleado actualizado' : 'Empleado registrado')
    } catch (e) {
      toast.error(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos guardar el empleado.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const eliminar = (empleado: EmpleadoResponse) =>
    confirmar({
      titulo: `Eliminar a ${empleado.nombreCompleto}`,
      mensaje:
        'Se borra definitivamente y no se puede deshacer. Si la persona dejó de trabajar, ponle fecha de cese y desactívala en vez de eliminarla.',
      confirmar: 'Eliminar',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await empleadoApi.remove(empleado.id)
          await cargar()
          toast.exito(`${empleado.nombreCompleto} eliminado`)
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos eliminar al empleado.')
        }
      },
    })

  const cambiarEstado = (empleado: EmpleadoResponse) =>
    confirmar({
      titulo: `${empleado.activo ? 'Desactivar' : 'Activar'} a ${empleado.nombreCompleto}`,
      mensaje: empleado.activo
        ? 'Deja de poder elegirse al crear un usuario, pero conserva su ficha y su historial.'
        : 'Vuelve a estar disponible para usarse.',
      confirmar: empleado.activo ? 'Desactivar' : 'Activar',
      tono: empleado.activo ? 'warning' : 'pregunta',
      accion: async () => {
        setError('')
        try {
          await (empleado.activo ? empleadoApi.desactivar(empleado.id) : empleadoApi.activar(empleado.id))
          await cargar()
          toast.exito(`${empleado.nombreCompleto} ${empleado.activo ? 'desactivado' : 'activado'}`)
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  // La lista trae activos e inactivos: los contadores tienen que separarlos.
  const activos = empleados.filter((e) => e.activo)
  const desactivados = empleados.length - activos.length
  const conUsuario = activos.filter((e) => e.usuarioId != null).length

  /** Los valores que de verdad hay en esa columna, para elegir y no teclear. */
  const distintos = (campo: 'cargo' | 'area') =>
    [...new Set(empleados.map((e) => e[campo]?.trim()).filter((v): v is string => !!v))]
      .sort((a, b) => a.localeCompare(b, 'es'))
      .map((v) => ({ value: v, label: v }))

  const columns: DataTableColumn<EmpleadoResponse>[] = [
    // Documento y nombre se encuentran con el buscador de arriba, no en el panel.
    { key: 'documento', label: 'Documento', filterable: false },
    {
      key: 'nombreCompleto',
      label: 'Empleado',
      filterable: false,
      render: (row) => <span className="font-medium text-ink">{row.nombreCompleto}</span>,
    },
    { key: 'cargo', label: 'Cargo', filterType: 'select', filterOptions: distintos('cargo') },
    { key: 'area', label: 'Área', filterType: 'select', filterOptions: distintos('area') },
    { key: 'telefono', label: 'Teléfono', filterable: false },
    {
      key: 'fechaIngreso',
      label: 'Ingreso',
      filterType: 'date',
      render: (row) => (row.fechaIngreso ? fechaCorta(row.fechaIngreso) : '—'),
    },
    {
      key: 'usuario',
      label: 'Usuario',
      filterType: 'select',
      filterOptions: [
        { value: 'Con usuario', label: 'Con usuario' },
        { value: 'Sin usuario', label: 'Sin usuario' },
      ],
      value: (row) => (row.usuarioId ? 'Con usuario' : 'Sin usuario'),
      render: (row) =>
        row.usuarioId ? (
          <Badge tone="sys">{row.usuario}</Badge>
        ) : (
          <span className="text-ink-soft">No entra al sistema</span>
        ),
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
        <Badge tone={row.activo ? 'success' : 'neutral'}>{row.activo ? 'Activo' : 'Cesado'}</Badge>
      ),
    },
  ]

  return (
    <ListPage
      icon={<Users size={20} />}
      title="Empleados"
      description="Quién trabaja en el negocio. Al crear un usuario se elige a quién pertenece esa cuenta."
      actions={
        puede('rrhh.empleados', 'crear') ? (
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nuevo empleado
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Empleados activos" value={String(activos.length)} icon={<Users size={18} />} />
          <StatCard
            label="Con usuario"
            value={String(conUsuario)}
            icon={<BadgeCheck size={18} />}
            tono="success"
            hint={`${activos.length - conUsuario} sin cuenta en el sistema`}
          />
          <StatCard
            label="Cesados"
            value={String(desactivados)}
            icon={<ShieldOff size={18} />}
            tono={desactivados > 0 ? 'warning' : 'neutral'}
            hint={desactivados > 0 ? 'conservan su historial' : 'ninguno'}
          />
        </>
      }
      columns={columns}
      rows={empleados}
      cardIcon={UserRound}
      searchPlaceholder="Buscar por nombre, documento o cargo..."
      empty={cargando ? 'Cargando empleados...' : 'Todavía no hay empleados registrados.'}
      rowActions={(row) => (
        <>
          {puede('rrhh.empleados', 'editar') && (
            <RowAction label={`Editar a ${row.nombreCompleto}`} onClick={() => abrirEdicion(row)}>
              <Pencil size={15} />
            </RowAction>
          )}
          {puede('rrhh.empleados', 'editar') && (
            <RowAction
              label={`${row.activo ? 'Desactivar' : 'Activar'} a ${row.nombreCompleto}`}
              tone={row.activo ? 'warning' : 'success'}
              onClick={() => cambiarEstado(row)}
            >
              {row.activo ? <ShieldOff size={15} /> : <ShieldCheck size={15} />}
            </RowAction>
          )}
          {puede('rrhh.empleados', 'eliminar') && (
            <RowAction
              label={`Eliminar a ${row.nombreCompleto}`}
              tone="danger"
              // Con cuenta enlazada el servidor lo rechaza: se dice aquí en vez de dejar intentarlo.
              disabled={row.usuarioId != null}
              disabledReason="Tiene un usuario enlazado"
              onClick={() => eliminar(row)}
            >
              <Trash2 size={15} />
            </RowAction>
          )}
        </>
      )}
    >
      <Modal
        open={abierto}
        size="lg"
        title={editando ? `Editar a ${editando.nombreCompleto}` : 'Nuevo empleado'}
        description="El documento identifica a la persona y no se puede repetir."
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Registrar empleado'}
            </Button>
          </>
        }
      >
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {/* Un empleado es una persona: DNI, o un código interno si es extranjero sin DNI. */}
          <DocumentoInput
            className="sm:col-span-2"
            tipo={(form.tipoDoc as TipoDocumento) ?? 'DNI'}
            onTipoChange={(tipoDoc) => setForm((prev) => ({ ...prev, tipoDoc }))}
            tipos={['DNI', 'CODIGO']}
            value={form.documento}
            onChange={(documento) => setForm((prev) => ({ ...prev, documento }))}
            onBuscar={consultarDni}
            buscando={consultando}
          />

          <Input
            label="Nombres"
            placeholder="Ej. Juan Carlos"
            value={form.nombres}
            onChange={(e) => setForm({ ...form, nombres: e.target.value })}
          />

          <Input
            label="Apellidos"
            placeholder="Ej. Quispe Mamani"
            value={form.apellidos}
            onChange={(e) => setForm({ ...form, apellidos: e.target.value })}
          />

          <Input
            label="Cargo"
            optional
            placeholder="Ej. Repartidor"
            value={form.cargo ?? ''}
            onChange={(e) => setForm({ ...form, cargo: e.target.value })}
          />

          <Input
            label="Área"
            optional
            placeholder="Ej. Reparto"
            value={form.area ?? ''}
            onChange={(e) => setForm({ ...form, area: e.target.value })}
          />

          <Input
            label="Teléfono"
            optional
            value={form.telefono ?? ''}
            onChange={(e) => setForm({ ...form, telefono: e.target.value })}
          />

          <Input
            label="Correo"
            type="email"
            optional
            value={form.email ?? ''}
            onChange={(e) => setForm({ ...form, email: e.target.value })}
          />

          <Input
            label="Dirección"
            className="sm:col-span-2"
            optional
            value={form.direccion ?? ''}
            onChange={(e) => setForm({ ...form, direccion: e.target.value })}
          />

          <Input
            label="Fecha de ingreso"
            type="date"
            optional
            value={form.fechaIngreso ?? ''}
            onChange={(e) => setForm({ ...form, fechaIngreso: e.target.value })}
          />

          <Input
            label="Fecha de cese"
            type="date"
            optional
            hint={<span className="text-xs text-ink-soft">solo si ya dejó de trabajar</span>}
            value={form.fechaCese ?? ''}
            onChange={(e) => setForm({ ...form, fechaCese: e.target.value })}
          />

          <Input
            label="Observación"
            className="sm:col-span-2"
            optional
            placeholder="Referencia, contacto de emergencia..."
            value={form.observacion ?? ''}
            onChange={(e) => setForm({ ...form, observacion: e.target.value })}
          />

          {editando?.usuarioId && (
            <p className="flex items-center gap-2 text-xs text-ink-soft sm:col-span-2">
              <IdCard size={14} />
              Esta ficha la usa la cuenta de <strong className="text-ink">{editando.usuario}</strong>. El
              enlace se cambia desde Configuración → Usuarios.
            </p>
          )}
        </div>
      </Modal>

      {dialogo}
    </ListPage>
  )
}
