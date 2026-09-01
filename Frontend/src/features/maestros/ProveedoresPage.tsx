import { useCallback, useEffect, useState } from 'react'
import {
  Building2,
  FileCheck2,
  Pencil,
  Plus,
  ShieldCheck,
  ShieldOff,
  Tags,
  Trash2,
  Upload,
} from 'lucide-react'
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
import { proveedorApi } from './proveedorApi'
import type { ProveedorRequest, ProveedorResponse } from './proveedorApi'

const VACIO: ProveedorRequest = {
  documento: '',
  tipoDoc: 'DNI',
  nombre: '',
  nombreComercial: '',
  direccion: '',
  departamento: '',
  distrito: '',
  telefono: '',
  telefono2: '',
  email: '',
  rubro: '',
}

export function ProveedoresPage() {
  const [proveedores, setProveedores] = useState<ProveedorResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [importando, setImportando] = useState(false)
  const [editando, setEditando] = useState<ProveedorResponse | null>(null)
  const [form, setForm] = useState<ProveedorRequest>(VACIO)
  const [guardando, setGuardando] = useState(false)
  const [consultando, setConsultando] = useState(false)
  const [errorForm, setErrorForm] = useState('')
  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    setError('')
    try {
      setProveedores(await proveedorApi.getAll())
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los proveedores.')
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

  const abrirEdicion = (proveedor: ProveedorResponse) => {
    setEditando(proveedor)
    setForm({
      documento: proveedor.documento,
      tipoDoc: proveedor.tipoDoc,
      nombre: proveedor.nombre,
      nombreComercial: proveedor.nombreComercial ?? '',
      direccion: proveedor.direccion ?? '',
      departamento: proveedor.departamento ?? '',
      distrito: proveedor.distrito ?? '',
      telefono: proveedor.telefono ?? '',
      telefono2: proveedor.telefono2 ?? '',
      email: proveedor.email ?? '',
      rubro: proveedor.rubro ?? '',
    })
    setErrorForm('')
    setAbierto(true)
  }

  const consultarDocumento = async (documento: string, tipo: TipoDocumento) => {
    setConsultando(true)
    setErrorForm('')
    try {
      if (tipo === 'RUC') {
        const datos = await consultaApi.ruc(documento)
        setForm((prev) => ({
          ...prev,
          nombre: datos.razonSocial,
          nombreComercial: datos.nombreComercial ?? prev.nombreComercial,
          direccion: datos.direccion ?? prev.direccion,
          departamento: datos.departamento ?? prev.departamento,
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
    if (!form.nombre.trim()) return setErrorForm('Ingresa la razón social.')

    setGuardando(true)
    try {
      if (editando) await proveedorApi.update(editando.id, { ...form, activo: editando.activo })
      else await proveedorApi.create(form)
      setAbierto(false)
      await cargar()
    } catch (e) {
      setErrorForm(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos guardar el proveedor.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const eliminar = (proveedor: ProveedorResponse) =>
    confirmar({
      titulo: `Eliminar ${proveedor.nombre}`,
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
          await proveedorApi.remove(proveedor.id)
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos eliminar el proveedor.')
        }
      },
    })

  const cambiarEstado = (proveedor: ProveedorResponse) =>
    confirmar({
      titulo: `${proveedor.activo ? 'Desactivar' : 'Activar'} ${proveedor.nombre}`,
      mensaje: proveedor.activo
        ? 'Deja de aparecer para nuevas operaciones, pero conserva su historial y puedes volver a activarlo.'
        : 'Vuelve a estar disponible para usarse.',
      confirmar: proveedor.activo ? 'Desactivar' : 'Activar',
      tono: proveedor.activo ? 'warning' : 'pregunta',
      accion: async () => {
        setError('')
        try {
          await (proveedor.activo ? proveedorApi.desactivar(proveedor.id) : proveedorApi.activar(proveedor.id))
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  const conRuc = proveedores.filter((p) => p.tipoDoc === 'RUC').length
  const rubros = new Set(proveedores.map((p) => p.rubro).filter(Boolean)).size

  const columns: DataTableColumn<ProveedorResponse>[] = [
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
    { key: 'nombre', label: 'Razón social' },
    { key: 'nombreComercial', label: 'Nombre comercial' },
    { key: 'rubro', label: 'Rubro' },
    { key: 'direccion', label: 'Dirección' },
    { key: 'telefono', label: 'Teléfono' },
    { key: 'distrito', label: 'Distrito' },

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
      icon={<Building2 size={20} />}
      title="Proveedores"
      description="A quién se le compra. El documento puede ser RUC, DNI o un código interno."
      actions={
        <>
          <Button variant="secondary" size="sm" onClick={() => setImportando(true)}>
            <Upload size={15} />
            Importar
          </Button>
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nuevo proveedor
          </Button>
        </>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard
            label="Proveedores activos"
            value={String(proveedores.length)}
            icon={<Building2 size={18} />}
          />
          <StatCard
            label="Con RUC"
            value={String(conRuc)}
            icon={<FileCheck2 size={18} />}
            tono="success"
            hint={`${proveedores.length - conRuc} con DNI o código`}
          />
          <StatCard
            label="Rubros"
            value={String(rubros)}
            icon={<Tags size={18} />}
            tono="neutral"
          />
        </>
      }
      columns={columns}
      rows={proveedores}
      cardIcon={Building2}
      searchPlaceholder="Buscar por razón social, documento o rubro..."
      empty={cargando ? 'Cargando proveedores...' : 'Todavía no hay proveedores registrados.'}
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
        title={editando ? `Editar ${editando.nombre}` : 'Nuevo proveedor'}
        description="El documento identifica al proveedor y no se puede repetir."
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Crear proveedor'}
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
            tipo={(form.tipoDoc as TipoDocumento) ?? 'RUC'}
            onTipoChange={(tipoDoc) => setForm((prev) => ({ ...prev, tipoDoc }))}
            value={form.documento}
            onChange={(documento) => setForm((prev) => ({ ...prev, documento }))}
            onBuscar={consultarDocumento}
            buscando={consultando}
          />

          <Input
            label="Nombre comercial"
            optional
            value={form.nombreComercial ?? ''}
            onChange={(e) => setForm({ ...form, nombreComercial: e.target.value })}
          />

          <Input
            label="Razón social"
            className="sm:col-span-2"
            value={form.nombre}
            onChange={(e) => setForm({ ...form, nombre: e.target.value })}
          />

          <Input
            label="Rubro"
            placeholder="Ej. Fideos y harinas"
            value={form.rubro ?? ''}
            onChange={(e) => setForm({ ...form, rubro: e.target.value })}
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
            value={form.direccion ?? ''}
            onChange={(e) => setForm({ ...form, direccion: e.target.value })}
          />

          <Input
            label="Departamento"
            value={form.departamento ?? ''}
            onChange={(e) => setForm({ ...form, departamento: e.target.value })}
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

          <Input
            label="Teléfono 2"
            optional
            value={form.telefono2 ?? ''}
            onChange={(e) => setForm({ ...form, telefono2: e.target.value })}
          />
        </div>
      </Modal>

      <ImportarModal<ProveedorRequest>
        open={importando}
        onClose={() => setImportando(false)}
        titulo="proveedores"
        columnasEsperadas={[
          'RUC',
          'Razón social',
          'Nombre comercial',
          'Dirección',
          'Teléfono',
          'Teléfono 2',
          'Email',
          'Departamento',
          'Distrito',
        ]}
        mapear={(fila) => ({
          documento: valorDe(fila, 'ruc', 'documento', 'dni'),
          nombre: valorDe(fila, 'razon social', 'nombre', 'proveedor'),
          nombreComercial: valorDe(fila, 'nombre comercial'),
          direccion: valorDe(fila, 'direccion'),
          telefono: valorDe(fila, 'telefono'),
          telefono2: valorDe(fila, 'telefono 2', 'telefono2'),
          // La hoja del negocio trae el rubro en la columna EMAIL: el backend
          // separa lo que es correo de lo que no.
          email: valorDe(fila, 'email', 'correo'),
          departamento: valorDe(fila, 'departamento'),
          distrito: valorDe(fila, 'distrito'),
        })}
        onImportar={proveedorApi.importar}
        onListo={() => void cargar()}
      />

      {dialogo}
    </ListPage>
  )
}
