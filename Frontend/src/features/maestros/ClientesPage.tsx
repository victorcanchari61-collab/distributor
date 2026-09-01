import { useCallback, useEffect, useState } from 'react'
import { Contact, Pencil, Plus, ShieldCheck, ShieldOff, Trash2, Upload } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  DocumentoInput,
  ImportarModal,
  Input,
  ListPage,
  Modal,
  RowAction,
  StatCard,
  useConfirmacion,
} from '../../components/ui'
import type { DataTableColumn, TipoDocumento } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { consultaApi } from '../../lib/consultaApi'
import { valorDe } from '../../lib/excel'
import { clienteApi } from './clienteApi'
import type { ClienteRequest, ClienteResponse } from './clienteApi'

const VACIO: ClienteRequest = {
  documento: '',
  tipoDoc: 'DNI',
  nombre: '',
  direccion: '',
  distrito: '',
  telefono: '',
  email: '',
  diaVisita: '',
  ruta: '',
  mercado: '',
}

const DIAS = ['LUNES', 'MARTES', 'MIERCOLES', 'JUEVES', 'VIERNES', 'SABADO', 'DOMINGO']

export function ClientesPage() {
  const [clientes, setClientes] = useState<ClienteResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [importando, setImportando] = useState(false)
  const [editando, setEditando] = useState<ClienteResponse | null>(null)
  const [form, setForm] = useState<ClienteRequest>(VACIO)
  const [guardando, setGuardando] = useState(false)
  const [consultando, setConsultando] = useState(false)
  const [errorForm, setErrorForm] = useState('')
  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    setError('')
    try {
      setClientes(await clienteApi.getAll())
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los clientes.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  const abrirNuevo = () => {
    setEditando(null)
    setForm(VACIO)
    setErrorForm('')
    setAbierto(true)
  }

  const abrirEdicion = (cliente: ClienteResponse) => {
    setEditando(cliente)
    setForm({
      documento: cliente.documento,
      tipoDoc: cliente.tipoDoc,
      nombre: cliente.nombre,
      direccion: cliente.direccion ?? '',
      distrito: cliente.distrito ?? '',
      telefono: cliente.telefono ?? '',
      email: cliente.email ?? '',
      diaVisita: cliente.diaVisita ?? '',
      ruta: cliente.ruta ?? '',
      mercado: cliente.mercado ?? '',
    })
    setErrorForm('')
    setAbierto(true)
  }

  /** Con 8 u 11 dígitos se puede traer el nombre de RENIEC o SUNAT. */
  const consultarDocumento = async (documento: string, tipo: TipoDocumento) => {
    setConsultando(true)
    setErrorForm('')
    try {
      if (tipo === 'RUC') {
        const datos = await consultaApi.ruc(documento)
        setForm((prev) => ({
          ...prev,
          nombre: datos.razonSocial,
          direccion: datos.direccion ?? prev.direccion,
          distrito: datos.distrito ?? prev.distrito,
        }))
      } else if (tipo === 'DNI') {
        const datos = await consultaApi.dni(documento)
        setForm((prev) => ({
          ...prev,
          nombre: `${datos.apellidoPaterno} ${datos.apellidoMaterno} ${datos.nombres}`
            .replace(/\s+/g, ' ')
            .trim(),
        }))
      }
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos consultar el documento.')
    } finally {
      setConsultando(false)
    }
  }

  const guardar = async () => {
    setErrorForm('')
    if (!/^[0-9]{3,15}$/.test(form.documento)) {
      return setErrorForm('El documento debe tener entre 3 y 15 dígitos.')
    }
    if (!form.nombre.trim()) return setErrorForm('Ingresa el nombre del cliente.')

    setGuardando(true)
    try {
      if (editando) await clienteApi.update(editando.id, { ...form, activo: editando.activo })
      else await clienteApi.create(form)
      setAbierto(false)
      await cargar()
    } catch (e) {
      setErrorForm(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos guardar el cliente.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const eliminar = (cliente: ClienteResponse) =>
    confirmar({
      titulo: `Eliminar ${cliente.nombre}`,
      mensaje: (
        <>
          Se borra definitivamente y no se puede deshacer. Si solo quieres dejar de usarlo,
          desactívalo en vez de eliminarlo.
        </>
      ),
      confirmar: 'Eliminar',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await clienteApi.remove(cliente.id)
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos eliminar el cliente.')
        }
      },
    })

  const cambiarEstado = (cliente: ClienteResponse) =>
    confirmar({
      titulo: `${cliente.activo ? 'Desactivar' : 'Activar'} ${cliente.nombre}`,
      mensaje: cliente.activo
        ? 'Deja de aparecer para nuevas operaciones, pero conserva su historial y puedes volver a activarlo.'
        : 'Vuelve a estar disponible para usarse.',
      confirmar: cliente.activo ? 'Desactivar' : 'Activar',
      tono: cliente.activo ? 'warning' : 'pregunta',
      accion: async () => {
        setError('')
        try {
          await (cliente.activo ? clienteApi.desactivar(cliente.id) : clienteApi.activar(cliente.id))
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  const conRuta = clientes.filter((c) => c.ruta).length
  const mercados = new Set(clientes.map((c) => c.mercado).filter(Boolean)).size

  const columns: DataTableColumn<ClienteResponse>[] = [
    {
      key: 'documento',
      label: 'Documento',
      render: (row) => (
        <span className="flex items-center gap-2">
          <span className="font-medium text-ink">{row.documento}</span>
          <Badge>{row.tipoDoc}</Badge>
        </span>
      ),
    },
    { key: 'nombre', label: 'Nombre' },
    { key: 'direccion', label: 'Dirección' },
    { key: 'distrito', label: 'Distrito' },
    { key: 'telefono', label: 'Teléfono' },
    {
      key: 'diaVisita',
      label: 'Día visita',
      render: (row) => (row.diaVisita ? <Badge tone="sys">{row.diaVisita}</Badge> : '—'),
    },
    { key: 'ruta', label: 'Ruta', align: 'right' },
    { key: 'mercado', label: 'Mercado', align: 'right' },

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
      icon={<Contact size={20} />}
      title="Clientes"
      description="Bodegas y puestos a los que se vende. El documento puede ser DNI, RUC o un código interno."
      actions={
        <>
          <Button variant="secondary" size="sm" onClick={() => setImportando(true)}>
            <Upload size={15} />
            Importar
          </Button>
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nuevo cliente
          </Button>
        </>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard
            label="Clientes activos"
            value={String(clientes.length)}
            icon={<Contact size={18} />}
          />
          <StatCard
            label="Con ruta asignada"
            value={String(conRuta)}
            hint={`${clientes.length - conRuta} sin ruta`}
          />
          <StatCard label="Mercados" value={String(mercados)} />
        </>
      }
      columns={columns}
      rows={clientes}
      cardIcon={Contact}
      searchPlaceholder="Buscar por nombre, documento, mercado..."
      empty={cargando ? 'Cargando clientes...' : 'Todavía no hay clientes registrados.'}
      rowActions={(row) => (
        <>
          <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)}>
            <Pencil size={15} />
          </RowAction>
          <RowAction
            label={`${row.activo ? 'Desactivar' : 'Activar'} ${row.nombre}`}
            tone={row.activo ? 'warning' : 'success'}
            onClick={() => cambiarEstado(row)}
          >
            {row.activo ? <ShieldOff size={15} /> : <ShieldCheck size={15} />}
          </RowAction>
          <RowAction label={`Eliminar ${row.nombre}`} tone="danger" onClick={() => eliminar(row)}>
            <Trash2 size={15} />
          </RowAction>
        </>
      )}
    >
      <Modal
        open={abierto}
        title={editando ? `Editar ${editando.nombre}` : 'Nuevo cliente'}
        description="El documento identifica al cliente y no se puede repetir."
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Crear cliente'}
            </Button>
          </>
        }
      >
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {errorForm && (
            <div className="sm:col-span-2">
              <Alert>{errorForm}</Alert>
            </div>
          )}

          <DocumentoInput
            className="sm:col-span-2"
            tipo={(form.tipoDoc as TipoDocumento) ?? 'DNI'}
            onTipoChange={(tipoDoc) => setForm((prev) => ({ ...prev, tipoDoc }))}
            value={form.documento}
            onChange={(documento) => setForm((prev) => ({ ...prev, documento }))}
            onBuscar={consultarDocumento}
            buscando={consultando}
          />

          <Input
            label="Nombre"
            value={form.nombre}
            onChange={(e) => setForm({ ...form, nombre: e.target.value })}
          />

          <Input
            label="Dirección"
            className="sm:col-span-2"
            value={form.direccion ?? ''}
            onChange={(e) => setForm({ ...form, direccion: e.target.value })}
          />

          <Input
            label="Distrito"
            value={form.distrito ?? ''}
            onChange={(e) => setForm({ ...form, distrito: e.target.value })}
          />

          <Input
            label="Teléfono"
            value={form.telefono ?? ''}
            onChange={(e) => setForm({ ...form, telefono: e.target.value })}
          />

          <label className="block">
            <span className="ui-label mb-1.5">Día de visita</span>
            <select
              value={form.diaVisita ?? ''}
              onChange={(e) => setForm({ ...form, diaVisita: e.target.value })}
              className="h-[var(--height-field-md)] w-full cursor-pointer rounded-field border border-line bg-surface px-3 text-sm text-ink outline-none focus:border-ink-soft"
            >
              <option value="">Sin definir</option>
              {DIAS.map((d) => (
                <option key={d} value={d}>
                  {d}
                </option>
              ))}
            </select>
          </label>

          <Input
            label="Ruta"
            value={form.ruta ?? ''}
            onChange={(e) => setForm({ ...form, ruta: e.target.value })}
          />

          <Input
            label="Mercado"
            value={form.mercado ?? ''}
            onChange={(e) => setForm({ ...form, mercado: e.target.value })}
          />

          <Input
            label="Correo"
            type="email"
            optional
            value={form.email ?? ''}
            onChange={(e) => setForm({ ...form, email: e.target.value })}
          />
        </div>
      </Modal>

      <ImportarModal<ClienteRequest>
        open={importando}
        onClose={() => setImportando(false)}
        titulo="clientes"
        columnasEsperadas={[
          'Documento',
          'Nombre',
          'Direccion',
          'Distrito',
          'Telefono',
          'Dias Visita',
          'Rutas',
          'Mercado',
        ]}
        mapear={(fila) => ({
          documento: valorDe(fila, 'documento', 'dni', 'ruc', 'nro documento'),
          nombre: valorDe(fila, 'nombre', 'razon social', 'cliente'),
          direccion: valorDe(fila, 'direccion', 'dirección'),
          distrito: valorDe(fila, 'distrito'),
          telefono: valorDe(fila, 'telefono', 'teléfono', 'celular'),
          diaVisita: valorDe(fila, 'dias visita', 'dia visita', 'día de visita'),
          ruta: valorDe(fila, 'rutas', 'ruta'),
          mercado: valorDe(fila, 'mercado'),
        })}
        onImportar={clienteApi.importar}
        onListo={() => void cargar()}
      />

      {dialogo}
    </ListPage>
  )
}
