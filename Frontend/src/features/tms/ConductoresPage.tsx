import { useCallback, useEffect, useState } from 'react'
import { AlertTriangle, CalendarClock, IdCard, Pencil, Plus, ShieldCheck, Trash2 } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Input,
  ListPage,
  Modal,
  RowAction,
  StatCard,
  useConfirmacion,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { BadgeEstadoDocumentos, CampoFoto } from './CampoFoto'
import { conductorApi } from './flotaApi'
import type { ConductorResponse, ResumenConductoresResponse } from './flotaApi'

interface FormConductor {
  nombre: string
  documento: string
  telefono: string
  direccion: string
  licenciaNumero: string
  licenciaCategoria: string
  licenciaVence: string
  foto: string | null
  fechaIngreso: string
  observacion: string
  activo: boolean
}

const VACIO: FormConductor = {
  nombre: '',
  documento: '',
  telefono: '',
  direccion: '',
  licenciaNumero: '',
  licenciaCategoria: '',
  licenciaVence: '',
  foto: null,
  fechaIngreso: '',
  observacion: '',
  activo: true,
}

/** El backend manda ISO completo; el <input type="date"> solo quiere yyyy-mm-dd. */
const soloFecha = (iso: string | null) => (iso ? iso.slice(0, 10) : '')

const textoOpcional = (texto: string) => texto.trim() || null

export function ConductoresPage() {
  const { puede } = usePermisos()

  const [conductores, setConductores] = useState<ConductorResponse[]>([])
  const [resumen, setResumen] = useState<ResumenConductoresResponse | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<ConductorResponse | null>(null)
  const [form, setForm] = useState<FormConductor>(VACIO)
  const [guardando, setGuardando] = useState(false)
  const [subiendoFoto, setSubiendoFoto] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [c, r] = await Promise.all([conductorApi.getAll(), conductorApi.resumen()])
      setConductores(c)
      setResumen(r)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los conductores.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  // También "flota": asignar un vehículo cambia las placas que se listan aquí.
  useRealtime(['conductores', 'flota'], cargar)

  const abrirNuevo = () => {
    setEditando(null)
    setForm(VACIO)
    setErrorForm('')
    setAbierto(true)
  }

  const abrirEdicion = (c: ConductorResponse) => {
    setEditando(c)
    setForm({
      nombre: c.nombre,
      documento: c.documento,
      telefono: c.telefono ?? '',
      direccion: c.direccion ?? '',
      licenciaNumero: c.licenciaNumero ?? '',
      licenciaCategoria: c.licenciaCategoria ?? '',
      licenciaVence: soloFecha(c.licenciaVence),
      foto: c.foto,
      fechaIngreso: soloFecha(c.fechaIngreso),
      observacion: c.observacion ?? '',
      activo: c.activo,
    })
    setErrorForm('')
    setAbierto(true)
  }

  const guardar = async () => {
    if (!form.nombre.trim()) return setErrorForm('Ingresa el nombre.')
    if (!form.documento.trim()) return setErrorForm('Ingresa el documento.')

    setGuardando(true)
    setErrorForm('')
    try {
      const cuerpo = {
        nombre: form.nombre.trim(),
        documento: form.documento.trim(),
        telefono: textoOpcional(form.telefono),
        direccion: textoOpcional(form.direccion),
        licenciaNumero: textoOpcional(form.licenciaNumero),
        licenciaCategoria: textoOpcional(form.licenciaCategoria),
        licenciaVence: form.licenciaVence.trim() || null,
        foto: form.foto,
        fechaIngreso: form.fechaIngreso.trim() || null,
        observacion: textoOpcional(form.observacion),
        activo: form.activo,
      }

      if (editando) await conductorApi.update(editando.id, cuerpo)
      else await conductorApi.create(cuerpo)

      setAbierto(false)
      await cargar()
    } catch (e) {
      setErrorForm(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos guardar el conductor.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const eliminar = (c: ConductorResponse) =>
    confirmar({
      titulo: `Eliminar ${c.nombre}`,
      mensaje:
        c.vehiculos.length > 0
          ? `Conduce ${c.vehiculos.join(', ')}. Si ya no trabaja aquí, desactívalo en su lugar.`
          : 'Se borra definitivamente.',
      confirmar: 'Eliminar',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await conductorApi.remove(c.id)
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos eliminar el conductor.')
        }
      },
    })

  const columns: DataTableColumn<ConductorResponse>[] = [
    { key: 'nombre', label: 'Nombre' },
    { key: 'documento', label: 'Documento' },
    {
      key: 'telefono',
      label: 'Teléfono',
      render: (row) => row.telefono ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'licenciaNumero',
      label: 'Licencia',
      value: (row) => `${row.licenciaNumero ?? ''} ${row.licenciaCategoria ?? ''}`.trim(),
      render: (row) =>
        row.licenciaNumero || row.licenciaCategoria ? (
          <span className="flex items-center gap-1.5">
            {row.licenciaNumero ?? '—'}
            {row.licenciaCategoria && <Badge>{row.licenciaCategoria}</Badge>}
          </span>
        ) : (
          <span className="text-ink-soft">Sin licencia</span>
        ),
    },
    {
      key: 'estadoDocumentos',
      label: 'Estado licencia',
      filterType: 'select',
      filterOptions: [
        { value: 'Vencido', label: 'Vencido' },
        { value: 'Por vencer', label: 'Por vencer' },
        { value: 'Al día', label: 'Al día' },
        { value: 'Sin fecha', label: 'Sin fecha' },
      ],
      value: (row) =>
        row.estadoDocumentos === 'vencido'
          ? 'Vencido'
          : row.estadoDocumentos === 'porVencer'
            ? 'Por vencer'
            : row.estadoDocumentos === 'alDia'
              ? 'Al día'
              : 'Sin fecha',
      render: (row) => <BadgeEstadoDocumentos estado={row.estadoDocumentos} />,
    },
    {
      key: 'vehiculos',
      label: 'Vehículos',
      value: (row) => row.vehiculos.join(' '),
      render: (row) =>
        row.vehiculos.length ? (
          <span className="flex flex-wrap gap-1">
            {row.vehiculos.map((placa) => (
              <Badge key={placa} tone="sys">
                {placa}
              </Badge>
            ))}
          </span>
        ) : (
          <span className="text-ink-soft">Sin asignar</span>
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
      title="Conductores"
      description="Quiénes conducen, con su licencia y los vehículos que tienen asignados."
      actions={
        puede('tms.conductores', 'crear') ? (
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nuevo conductor
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard
            label="Conductores"
            value={String(resumen?.conductores ?? 0)}
            icon={<IdCard size={18} />}
          />
          <StatCard
            label="Activos"
            value={String(resumen?.activos ?? 0)}
            icon={<ShieldCheck size={18} />}
            tono="success"
          />
          <StatCard
            label="Con licencia vencida"
            value={String(resumen?.conLicenciaVencida ?? 0)}
            icon={<AlertTriangle size={18} />}
            tono={resumen?.conLicenciaVencida ? 'danger' : 'neutral'}
            hint="no deberían salir a repartir"
          />
          <StatCard
            label="Por vencer"
            value={String(resumen?.porVencer ?? 0)}
            icon={<CalendarClock size={18} />}
            tono={resumen?.porVencer ? 'warning' : 'neutral'}
          />
        </>
      }
      columns={columns}
      rows={conductores}
      cardIcon={IdCard}
      searchPlaceholder="Buscar por nombre, documento, licencia..."
      empty={cargando ? 'Cargando conductores...' : 'Todavía no hay conductores registrados.'}
      rowActions={(row) => (
        <>
          {puede('tms.conductores', 'editar') && (
            <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)}>
              <Pencil size={15} />
            </RowAction>
          )}
          {puede('tms.conductores', 'eliminar') && (
            <RowAction label={`Eliminar ${row.nombre}`} tone="danger" onClick={() => eliminar(row)}>
              <Trash2 size={15} />
            </RowAction>
          )}
        </>
      )}
    >
      <Modal
        open={abierto}
        size="lg"
        title={editando ? `Editar ${editando.nombre}` : 'Nuevo conductor'}
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button
              size="sm"
              loading={guardando}
              disabled={subiendoFoto}
              onClick={() => void guardar()}
            >
              {editando ? 'Guardar cambios' : 'Crear conductor'}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {errorForm && <Alert>{errorForm}</Alert>}

          <div className="grid gap-4 sm:grid-cols-[1fr_10rem]">
            <Input
              label="Nombre"
              placeholder="Juan Pérez"
              value={form.nombre}
              onChange={(e) => setForm({ ...form, nombre: e.target.value })}
            />
            <Input
              label="Documento"
              placeholder="12345678"
              value={form.documento}
              onChange={(e) => setForm({ ...form, documento: e.target.value })}
            />
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <Input
              label="Teléfono"
              optional
              value={form.telefono}
              onChange={(e) => setForm({ ...form, telefono: e.target.value })}
            />
            <Input
              label="Fecha de ingreso"
              optional
              type="date"
              value={form.fechaIngreso}
              onChange={(e) => setForm({ ...form, fechaIngreso: e.target.value })}
            />
          </div>

          <Input
            label="Dirección"
            optional
            value={form.direccion}
            onChange={(e) => setForm({ ...form, direccion: e.target.value })}
          />

          <hr className="border-line" />

          <div className="grid gap-4 sm:grid-cols-3">
            <Input
              label="Licencia (número)"
              optional
              value={form.licenciaNumero}
              onChange={(e) => setForm({ ...form, licenciaNumero: e.target.value })}
            />
            <Input
              label="Categoría"
              optional
              placeholder="A-IIb"
              value={form.licenciaCategoria}
              onChange={(e) => setForm({ ...form, licenciaCategoria: e.target.value })}
            />
            <Input
              label="Vence"
              optional
              type="date"
              value={form.licenciaVence}
              onChange={(e) => setForm({ ...form, licenciaVence: e.target.value })}
            />
          </div>

          <hr className="border-line" />

          <CampoFoto
            label="Foto del conductor"
            carpeta="conductores"
            valor={form.foto}
            onChange={(ruta) => setForm((f) => ({ ...f, foto: ruta }))}
            onSubiendo={setSubiendoFoto}
            disabled={guardando}
          />

          <Input
            label="Observación"
            optional
            value={form.observacion}
            onChange={(e) => setForm({ ...form, observacion: e.target.value })}
          />

          <label className="flex items-center gap-2 text-sm text-ink-muted">
            <input
              type="checkbox"
              checked={form.activo}
              onChange={(e) => setForm({ ...form, activo: e.target.checked })}
            />
            Activo (disponible para repartir)
          </label>
        </div>
      </Modal>

      {dialogo}
    </ListPage>
  )
}
