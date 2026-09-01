import { useCallback, useEffect, useState } from 'react'
import {
  Building2,
  CheckCircle2,
  Circle,
  Pencil,
  Plus,
  ShieldCheck,
  ShieldOff,
  Trash2,
} from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  DocumentoInput,
  Input,
  ListPage,
  Modal,
  RowAction,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { consultaApi } from '../../lib/consultaApi'
import { empresaApi } from './empresaApi'
import type { EmpresaRequest, EmpresaResponse } from './empresaApi'

const VACIA: EmpresaRequest = {
  razonSocial: '',
  nombreComercial: '',
  ruc: '',
  direccion: '',
  departamento: '',
  provincia: '',
  distrito: '',
  telefono: '',
  email: '',
  sitioWeb: '',
  representanteLegal: '',
  activa: false,
}

export function EmpresaPage() {
  const [empresas, setEmpresas] = useState<EmpresaResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [editando, setEditando] = useState<EmpresaResponse | null>(null)
  const [abierto, setAbierto] = useState(false)
  const [form, setForm] = useState<EmpresaRequest>(VACIA)
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')
  const [consultando, setConsultando] = useState(false)
  const [avisoSunat, setAvisoSunat] = useState('')

  const cargar = useCallback(async () => {
    setCargando(true)
    setError('')
    try {
      setEmpresas(await empresaApi.getAll())
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las empresas.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  const abrirNueva = () => {
    setEditando(null)
    setForm({ ...VACIA, activa: empresas.length === 0 })
    setErrorForm('')
    setAvisoSunat('')
    setAbierto(true)
  }

  /** Trae de SUNAT los datos de la empresa y llena el formulario. */
  const consultarRuc = async (ruc: string) => {
    setConsultando(true)
    setErrorForm('')
    setAvisoSunat('')
    try {
      const datos = await consultaApi.ruc(ruc)
      setForm((prev) => ({
        ...prev,
        ruc: datos.ruc,
        razonSocial: datos.razonSocial,
        // SUNAT suele no traer nombre comercial: se deja la razon social.
        nombreComercial: datos.nombreComercial || prev.nombreComercial || datos.razonSocial,
        direccion: datos.direccion ?? prev.direccion,
        departamento: datos.departamento ?? prev.departamento,
        provincia: datos.provincia ?? prev.provincia,
        distrito: datos.distrito ?? prev.distrito,
      }))

      // Un contribuyente de baja o no habido se puede registrar, pero conviene avisarlo.
      const partes = [datos.estado, datos.condicion].filter(Boolean)
      setAvisoSunat(partes.length ? `SUNAT: ${partes.join(' · ')}` : '')
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos consultar el RUC.')
    } finally {
      setConsultando(false)
    }
  }

  const abrirEdicion = (empresa: EmpresaResponse) => {
    setEditando(empresa)
    setForm({
      razonSocial: empresa.razonSocial,
      nombreComercial: empresa.nombreComercial,
      ruc: empresa.ruc,
      direccion: empresa.direccion ?? '',
      departamento: empresa.departamento ?? '',
      provincia: empresa.provincia ?? '',
      distrito: empresa.distrito ?? '',
      telefono: empresa.telefono ?? '',
      email: empresa.email ?? '',
      sitioWeb: empresa.sitioWeb ?? '',
      representanteLegal: empresa.representanteLegal ?? '',
      activa: empresa.activa,
    })
    setErrorForm('')
    setAvisoSunat('')
    setAbierto(true)
  }

  const guardar = async () => {
    setGuardando(true)
    setErrorForm('')
    try {
      if (editando) await empresaApi.update(editando.id, form)
      else await empresaApi.create(form)
      setAbierto(false)
      await cargar()
    } catch (e) {
      setErrorForm(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos guardar la empresa.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const activar = async (empresa: EmpresaResponse) => {
    setError('')
    try {
      await empresaApi.activar(empresa.id)
      await cargar()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos activar la empresa.')
    }
  }

  const cambiarHabilitacion = async (empresa: EmpresaResponse) => {
    setError('')
    try {
      await (empresa.habilitada
        ? empresaApi.deshabilitar(empresa.id)
        : empresaApi.habilitar(empresa.id))
      await cargar()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado de la empresa.')
    }
  }

  const eliminar = async (empresa: EmpresaResponse) => {
    setError('')
    try {
      await empresaApi.remove(empresa.id)
      await cargar()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos eliminar la empresa.')
    }
  }

  const activa = empresas.find((e) => e.activa)

  const columns: DataTableColumn<EmpresaResponse>[] = [
    { key: 'razonSocial', label: 'Razón social' },
    { key: 'nombreComercial', label: 'Nombre comercial' },
    { key: 'ruc', label: 'RUC' },
    { key: 'telefono', label: 'Teléfono' },
    {
      key: 'sitioWeb',
      label: 'Sitio web',
      render: (row) =>
        row.sitioWeb ? (
          <a
            href={row.sitioWeb}
            target="_blank"
            rel="noreferrer"
            onClick={(e) => e.stopPropagation()}
            className="text-blue-600 hover:underline"
          >
            {row.sitioWeb.replace(/^https?:\/\//, '')}
          </a>
        ) : (
          <span className="text-ink-soft">—</span>
        ),
    },
    {
      key: 'activa',
      label: 'Estado',
      value: (row) => (row.activa ? 'Activa' : row.habilitada ? 'Disponible' : 'Deshabilitada'),
      render: (row) =>
        row.activa ? (
          <Badge tone="success">Activa</Badge>
        ) : row.habilitada ? (
          <Badge tone="sys">Disponible</Badge>
        ) : (
          <Badge>Deshabilitada</Badge>
        ),
    },
  ]

  return (
    <ListPage
      icon={<Building2 size={20} />}
      title="Empresas"
      description="Puedes registrar varias, pero solo una opera el sistema a la vez."
      actions={
        <Button size="sm" onClick={abrirNueva} iconRight={<Plus size={15} />}>
          Nueva empresa
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      banner={
        activa ? (
          <div className="flex flex-wrap items-center gap-3 rounded-panel border border-[rgb(var(--sys-rgb)/0.3)] bg-[rgb(var(--sys-rgb)/0.06)] p-4">
            <CheckCircle2 size={20} className="shrink-0 text-[rgb(var(--sys-ink-rgb))]" />
            <div className="min-w-0">
              <p className="text-sm font-semibold text-ink">Operando como {activa.nombreComercial}</p>
              <p className="truncate text-xs text-ink-muted">
                {activa.razonSocial} · RUC {activa.ruc}
              </p>
            </div>
          </div>
        ) : undefined
      }
      columns={columns}
      rows={empresas}
      cardIcon={Building2}
      searchPlaceholder="Buscar por razón social o RUC..."
      empty={cargando ? 'Cargando empresas...' : 'Todavía no hay empresas registradas.'}
      rowActions={(row) => (
        <>
          {!row.activa && (
            <RowAction
              label={`Activar ${row.nombreComercial}`}
              tone="success"
              disabled={!row.habilitada}
              disabledReason="Está deshabilitada: habilítala antes de activarla"
              onClick={() => void activar(row)}
            >
              <Circle size={15} />
            </RowAction>
          )}

          <RowAction label={`Editar ${row.nombreComercial}`} onClick={() => abrirEdicion(row)}>
            <Pencil size={15} />
          </RowAction>

          {/* La empresa activa no se deshabilita: primero se activa otra. */}
          <RowAction
            label={`${row.habilitada ? 'Deshabilitar' : 'Habilitar'} ${row.nombreComercial}`}
            tone={row.habilitada ? 'warning' : 'success'}
            disabled={row.activa}
            disabledReason="Es la empresa activa: activa otra antes de deshabilitarla"
            onClick={() => void cambiarHabilitacion(row)}
          >
            {row.habilitada ? <ShieldOff size={15} /> : <ShieldCheck size={15} />}
          </RowAction>

          <RowAction
            label={`Eliminar ${row.nombreComercial}`}
            tone="danger"
            disabled={row.activa}
            disabledReason="Es la empresa activa: no se puede eliminar"
            onClick={() => void eliminar(row)}
          >
            <Trash2 size={15} />
          </RowAction>
        </>
      )}
      note="Activa es la empresa con la que opera el sistema; deshabilitada se retira sin borrarla y no se puede activar. La empresa activa no se elimina ni se deshabilita: primero activa otra."
    >
      <Modal
        open={abierto}
        title={editando ? 'Editar empresa' : 'Nueva empresa'}
        description="Estos datos aparecen en documentos y reportes."
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Crear empresa'}
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

          {avisoSunat && (
            <p className="rounded-field border border-blue-200 bg-blue-50 px-3 py-2 text-xs text-blue-700 sm:col-span-2">
              {avisoSunat}
            </p>
          )}

          <Input
            label="Razón social"
            className="sm:col-span-2"
            value={form.razonSocial}
            onChange={(e) => setForm({ ...form, razonSocial: e.target.value })}
          />
          <Input
            label="Nombre comercial"
            value={form.nombreComercial}
            onChange={(e) => setForm({ ...form, nombreComercial: e.target.value })}
          />
          <DocumentoInput
            tipo="ruc"
            label="RUC"
            placeholder="20512345678"
            value={form.ruc}
            onChange={(ruc) => setForm({ ...form, ruc })}
            onBuscar={consultarRuc}
            buscando={consultando}
          />
          <Input
            label="Dirección fiscal"
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
            label="Provincia"
            value={form.provincia ?? ''}
            onChange={(e) => setForm({ ...form, provincia: e.target.value })}
          />
          <Input
            label="Distrito"
            value={form.distrito ?? ''}
            onChange={(e) => setForm({ ...form, distrito: e.target.value })}
          />
          <Input
            label="Representante legal"
            value={form.representanteLegal ?? ''}
            onChange={(e) => setForm({ ...form, representanteLegal: e.target.value })}
          />
          <Input
            label="Teléfono"
            value={form.telefono ?? ''}
            onChange={(e) => setForm({ ...form, telefono: e.target.value })}
          />
          <Input
            label="Correo"
            type="email"
            value={form.email ?? ''}
            onChange={(e) => setForm({ ...form, email: e.target.value })}
          />
          <Input
            label="Sitio web"
            placeholder="titanicd.pe"
            value={form.sitioWeb ?? ''}
            onChange={(e) => setForm({ ...form, sitioWeb: e.target.value })}
          />

          {/* Desactivar desde aqui no se permite: el backend obliga a activar otra. */}
          {!form.activa && (
            <label className="flex cursor-pointer items-center gap-2 text-sm text-ink-muted sm:col-span-2">
              <input
                type="checkbox"
                checked={form.activa}
                onChange={(e) => setForm({ ...form, activa: e.target.checked })}
                className="size-4 cursor-pointer rounded border-line-strong accent-[rgb(var(--sys-rgb))]"
              />
              Dejar esta empresa como la activa del sistema
            </label>
          )}
        </div>
      </Modal>
    </ListPage>
  )
}

