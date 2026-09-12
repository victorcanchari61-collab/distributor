import { useCallback, useEffect, useState } from 'react'
import {
  AlertTriangle,
  CalendarClock,
  Eye,
  Pencil,
  Plus,
  ShieldCheck,
  ShieldOff,
  Truck,
  Wrench,
} from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Desplegable,
  Input,
  ListPage,
  Modal,
  RowAction,
  StatCard,
  Tabs,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { BadgeEstadoDocumentos, CampoFoto } from './CampoFoto'
import { conductorApi, tipoVehiculoApi, urlImagen, vehiculoApi } from './flotaApi'
import type {
  ConductorResponse,
  ResumenFlotaResponse,
  TipoVehiculoResponse,
  VehiculoResponse,
} from './flotaApi'

type Pestana = 'vehiculos' | 'tipos'

/** Lo que el formulario mantiene como texto: los <input> devuelven strings. */
interface FormVehiculo {
  placa: string
  tipoVehiculoId: number
  marca: string
  modelo: string
  anio: string
  color: string
  capacidadKg: string
  soatNumero: string
  soatVence: string
  revisionTecnicaVence: string
  permisoCirculacionVence: string
  foto: string | null
  conductorId: number
  observacion: string
  activo: boolean
}

const VACIO: FormVehiculo = {
  placa: '',
  tipoVehiculoId: 0,
  marca: '',
  modelo: '',
  anio: '',
  color: '',
  capacidadKg: '',
  soatNumero: '',
  soatVence: '',
  revisionTecnicaVence: '',
  permisoCirculacionVence: '',
  foto: null,
  conductorId: 0,
  observacion: '',
  activo: true,
}

/** El backend manda ISO completo; el <input type="date"> solo quiere yyyy-mm-dd. */
const soloFecha = (iso: string | null) => (iso ? iso.slice(0, 10) : '')

const textoOpcional = (texto: string) => texto.trim() || null
const numeroOpcional = (texto: string) => (texto.trim() ? Number(texto) : null)
const fechaOpcional = (texto: string) => texto.trim() || null

export function FlotaPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const [pestana, setPestana] = useState<Pestana>('vehiculos')

  const [vehiculos, setVehiculos] = useState<VehiculoResponse[]>([])
  const [tipos, setTipos] = useState<TipoVehiculoResponse[]>([])
  const [conductores, setConductores] = useState<ConductorResponse[]>([])
  const [resumen, setResumen] = useState<ResumenFlotaResponse | null>(null)

  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [detalle, setDetalle] = useState<VehiculoResponse | null>(null)
  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<VehiculoResponse | null>(null)
  const [form, setForm] = useState<FormVehiculo>(VACIO)
  const [guardando, setGuardando] = useState(false)
  const [subiendoFoto, setSubiendoFoto] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      // Los conductores hacen falta para el desplegable del formulario y para
      // decir de quién es cada vehículo.
      const [v, t, c, r] = await Promise.all([
        vehiculoApi.getAll(),
        tipoVehiculoApi.getAll(),
        conductorApi.getAll(),
        vehiculoApi.resumen(),
      ])
      setVehiculos(v)
      setTipos(t)
      setConductores(c)
      setResumen(r)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar la flota.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['flota', 'conductores'], cargar)

  const tiposActivos = tipos.filter((t) => t.activo)

  const abrirNuevo = () => {
    setEditando(null)
    setForm({ ...VACIO, tipoVehiculoId: tiposActivos[0]?.id ?? 0 })
    setErrorForm('')
    setAbierto(true)
  }

  const abrirEdicion = (v: VehiculoResponse) => {
    setEditando(v)
    setForm({
      placa: v.placa,
      tipoVehiculoId: v.tipoVehiculoId,
      marca: v.marca ?? '',
      modelo: v.modelo ?? '',
      anio: v.anio ? String(v.anio) : '',
      color: v.color ?? '',
      capacidadKg: v.capacidadKg != null ? String(v.capacidadKg) : '',
      soatNumero: v.soatNumero ?? '',
      soatVence: soloFecha(v.soatVence),
      revisionTecnicaVence: soloFecha(v.revisionTecnicaVence),
      permisoCirculacionVence: soloFecha(v.permisoCirculacionVence),
      foto: v.foto,
      conductorId: v.conductorId ?? 0,
      observacion: v.observacion ?? '',
      activo: v.activo,
    })
    setErrorForm('')
    setAbierto(true)
  }

  const guardar = async () => {
    if (!form.placa.trim()) return setErrorForm('Ingresa la placa.')
    if (!form.tipoVehiculoId) return setErrorForm('Elige el tipo de vehículo.')

    setGuardando(true)
    setErrorForm('')
    try {
      const cuerpo = {
        placa: form.placa.trim().toUpperCase(),
        tipoVehiculoId: form.tipoVehiculoId,
        marca: textoOpcional(form.marca),
        modelo: textoOpcional(form.modelo),
        anio: numeroOpcional(form.anio),
        color: textoOpcional(form.color),
        capacidadKg: numeroOpcional(form.capacidadKg),
        soatNumero: textoOpcional(form.soatNumero),
        soatVence: fechaOpcional(form.soatVence),
        revisionTecnicaVence: fechaOpcional(form.revisionTecnicaVence),
        permisoCirculacionVence: fechaOpcional(form.permisoCirculacionVence),
        foto: form.foto,
        conductorId: form.conductorId || null,
        observacion: textoOpcional(form.observacion),
        activo: form.activo,
      }

      if (editando) await vehiculoApi.update(editando.id, cuerpo)
      else await vehiculoApi.create(cuerpo)

      setAbierto(false)
      await cargar()
      toast.exito(editando ? 'Vehículo actualizado' : 'Vehículo creado')
    } catch (e) {
      setErrorForm(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos guardar el vehículo.',
      )
    } finally {
      setGuardando(false)
    }
  }

  /*
   * Un vehiculo no se borra: se da de baja.
   *
   * Detras de una placa hay reparto, kardex y documentos; borrar la fila
   * dejaria todo eso apuntando a un vehiculo que ya no existe. Ademas la baja
   * casi siempre es temporal — el camion esta en el taller — y un borrado no
   * se deshace.
   */
  const cambiarEstado = (v: VehiculoResponse) =>
    confirmar({
      titulo: `${v.activo ? 'Desactivar' : 'Activar'} ${v.placa}`,
      mensaje: v.activo
        ? 'Deja de ofrecerse para repartir y sale de las alertas de documentos. Su historial se conserva.'
        : 'Vuelve a estar disponible para el reparto.',
      confirmar: v.activo ? 'Desactivar' : 'Activar',
      tono: v.activo ? 'warning' : 'pregunta',
      accion: async () => {
        setError('')
        try {
          await vehiculoApi.update(v.id, {
            placa: v.placa,
            tipoVehiculoId: v.tipoVehiculoId,
            marca: v.marca,
            modelo: v.modelo,
            anio: v.anio,
            color: v.color,
            capacidadKg: v.capacidadKg,
            soatNumero: v.soatNumero,
            soatVence: v.soatVence,
            revisionTecnicaVence: v.revisionTecnicaVence,
            permisoCirculacionVence: v.permisoCirculacionVence,
            foto: v.foto,
            conductorId: v.conductorId,
            observacion: v.observacion,
            activo: !v.activo,
          })
          await cargar()
          toast.exito(`${v.placa} ${v.activo ? 'desactivado' : 'activado'}`)
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  const columns: DataTableColumn<VehiculoResponse>[] = [
    { key: 'placa', label: 'Placa', render: (row) => <Badge tone="sys">{row.placa}</Badge> },
    {
      key: 'tipoVehiculo',
      label: 'Tipo',
      // Sale del catalogo de la otra pestana, no de una lista fija.
      filterType: 'select',
      filterOptions: tipos.map((t) => ({ value: t.nombre, label: t.nombre })),
    },
    {
      key: 'marca',
      label: 'Marca / modelo',
      value: (row) => `${row.marca ?? ''} ${row.modelo ?? ''}`.trim(),
      render: (row) =>
        row.marca || row.modelo ? (
          [row.marca, row.modelo].filter(Boolean).join(' ')
        ) : (
          <span className="text-ink-soft">—</span>
        ),
    },
    {
      key: 'capacidadKg',
      label: 'Capacidad',
      align: 'right',
      // Una cantidad no se busca por texto: no hay control numerico en el panel.
      filterable: false,
      render: (row) =>
        row.capacidadKg == null ? (
          <span className="text-ink-soft">—</span>
        ) : (
          `${row.capacidadKg} kg`
        ),
    },
    {
      key: 'conductor',
      label: 'Conductor',
      render: (row) => row.conductor ?? <span className="text-ink-soft">Sin asignar</span>,
    },
    {
      key: 'estadoDocumentos',
      label: 'Documentos',
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

  const cabecera = (
    <Tabs
      className="mb-5"
      active={pestana}
      onChange={(id) => setPestana(id as Pestana)}
      items={[
        { id: 'vehiculos', label: 'Vehículos', icon: <Truck size={15} />, badge: vehiculos.length },
        { id: 'tipos', label: 'Tipos de vehículo', icon: <Wrench size={15} />, badge: tipos.length },
      ]}
    />
  )

  if (pestana === 'tipos') {
    return (
      <>
        {cabecera}
        <TiposVehiculoTabla tipos={tipos} onRecargar={cargar} />
      </>
    )
  }

  return (
    <>
      {cabecera}
      <ListPage
        icon={<Truck size={20} />}
        title="Flota"
        description="Los vehículos de reparto, con sus documentos al día y quién los conduce."
        actions={
          puede('tms.flota', 'crear') ? (
            <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
              Nuevo vehículo
            </Button>
          ) : undefined
        }
        alert={error ? <Alert>{error}</Alert> : undefined}
        stats={
          <>
            <StatCard
              label="Vehículos"
              value={String(resumen?.vehiculos ?? 0)}
              icon={<Truck size={18} />}
            />
            <StatCard
              label="Activos"
              value={String(resumen?.activos ?? 0)}
              icon={<ShieldCheck size={18} />}
              tono="success"
            />
            <StatCard
              label="Con documento vencido"
              value={String(resumen?.conDocumentoVencido ?? 0)}
              icon={<AlertTriangle size={18} />}
              tono={resumen?.conDocumentoVencido ? 'danger' : 'neutral'}
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
        rows={vehiculos}
        cardIcon={Truck}
        searchPlaceholder="Buscar por placa, marca, conductor..."
        empty={cargando ? 'Cargando flota...' : 'Todavía no hay vehículos registrados.'}
        rowActions={(row) => (
          <>
            <RowAction tone="view" label={`Ver ${row.placa}`} onClick={() => setDetalle(row)}>
              <Eye size={15} />
            </RowAction>
            {puede('tms.flota', 'editar') && (
              <RowAction label={`Editar ${row.placa}`} onClick={() => abrirEdicion(row)}>
                <Pencil size={15} />
              </RowAction>
            )}
            {puede('tms.flota', 'editar') && (
              <RowAction
                label={`${row.activo ? 'Desactivar' : 'Activar'} ${row.placa}`}
                tone={row.activo ? 'warning' : 'success'}
                onClick={() => cambiarEstado(row)}
              >
                {row.activo ? <ShieldOff size={15} /> : <ShieldCheck size={15} />}
              </RowAction>
            )}
          </>
        )}
      >
        {/*
          La ficha, en solo lectura. Antes lo unico que habia era Editar, asi
          que para mirar los vencimientos de un camion habia que abrir el
          formulario — con el riesgo de guardar algo sin querer.
        */}
        <Modal
          open={detalle !== null}
          size="lg"
          title={detalle ? `Vehículo ${detalle.placa}` : ''}
          onClose={() => setDetalle(null)}
          footer={
            <Button variant="secondary" size="sm" onClick={() => setDetalle(null)}>
              Cerrar
            </Button>
          }
        >
          {detalle && (
            <div className="flex flex-col gap-4">
              {detalle.foto && (
                <img
                  src={urlImagen(detalle.foto)}
                  alt={`Foto de ${detalle.placa}`}
                  className="max-h-56 w-full rounded-panel object-cover"
                />
              )}

              <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
                <Dato etiqueta="Tipo" valor={detalle.tipoVehiculo} />
                <Dato etiqueta="Marca" valor={detalle.marca} />
                <Dato etiqueta="Modelo" valor={detalle.modelo} />
                <Dato etiqueta="Año" valor={detalle.anio ? String(detalle.anio) : null} />
                <Dato etiqueta="Color" valor={detalle.color} />
                <Dato
                  etiqueta="Capacidad"
                  valor={detalle.capacidadKg ? `${detalle.capacidadKg} kg` : null}
                />
                <Dato etiqueta="Conductor" valor={detalle.conductor} />
                <Dato etiqueta="N° de SOAT" valor={detalle.soatNumero} />
                <Dato etiqueta="Estado" valor={detalle.activo ? 'Activo' : 'Inactivo'} />
              </div>

              <div>
                <p className="mb-2 text-xs font-semibold tracking-wide text-ink-soft uppercase">
                  Documentos
                </p>
                <div className="rounded-panel border border-line">
                  {detalle.vencimientos.map((v) => (
                    <div
                      key={v.nombre}
                      className="flex items-center justify-between gap-3 border-b border-line px-3 py-2 last:border-b-0"
                    >
                      <span className="text-sm text-ink">{v.nombre}</span>
                      <span className="flex items-center gap-2">
                        <span className="text-sm text-ink-muted tabular-nums">
                          {v.vence ? new Date(v.vence).toLocaleDateString('es-PE') : '—'}
                        </span>
                        <BadgeEstadoDocumentos estado={v.estado} />
                      </span>
                    </div>
                  ))}
                </div>
              </div>

              {detalle.observacion && (
                <p className="text-sm text-ink-soft">
                  <span className="font-semibold text-ink-muted">Observación: </span>
                  {detalle.observacion}
                </p>
              )}
            </div>
          )}
        </Modal>

        <Modal
          open={abierto}
          size="lg"
          title={editando ? `Editar ${editando.placa}` : 'Nuevo vehículo'}
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
                {editando ? 'Guardar cambios' : 'Crear vehículo'}
              </Button>
            </>
          }
        >
          <div className="flex flex-col gap-4">
            {errorForm && <Alert>{errorForm}</Alert>}

            <div className="grid gap-4 sm:grid-cols-[10rem_1fr]">
              <Input
                label="Placa"
                placeholder="ABC-123"
                value={form.placa}
                onChange={(e) => setForm({ ...form, placa: e.target.value.toUpperCase() })}
              />
              <Desplegable
                label="Tipo de vehículo"
                value={form.tipoVehiculoId}
                onChange={(v) => setForm({ ...form, tipoVehiculoId: Number(v) })}
                placeholder="Elegir tipo"
                options={tiposActivos.map((t) => ({
                  value: t.id,
                  label: t.nombre,
                  detalle: t.capacidadKgReferencia ? `${t.capacidadKgReferencia} kg` : undefined,
                }))}
              />
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <Input
                label="Marca"
                optional
                placeholder="Hyundai"
                value={form.marca}
                onChange={(e) => setForm({ ...form, marca: e.target.value })}
              />
              <Input
                label="Modelo"
                optional
                placeholder="HD65"
                value={form.modelo}
                onChange={(e) => setForm({ ...form, modelo: e.target.value })}
              />
            </div>

            <div className="grid gap-4 sm:grid-cols-3">
              <Input
                label="Año"
                optional
                type="number"
                placeholder="2020"
                value={form.anio}
                onChange={(e) => setForm({ ...form, anio: e.target.value })}
              />
              <Input
                label="Color"
                optional
                placeholder="Blanco"
                value={form.color}
                onChange={(e) => setForm({ ...form, color: e.target.value })}
              />
              <Input
                label="Capacidad (kg)"
                optional
                type="number"
                step="0.01"
                value={form.capacidadKg}
                onChange={(e) => setForm({ ...form, capacidadKg: e.target.value })}
              />
            </div>

            <Desplegable
              label="Conductor habitual"
              optional
              value={form.conductorId}
              onChange={(v) => setForm({ ...form, conductorId: Number(v) })}
              options={[
                { value: 0, label: 'Sin asignar' },
                ...conductores
                  .filter((c) => c.activo)
                  .map((c) => ({ value: c.id, label: c.nombre, detalle: c.documento })),
              ]}
            />

            <hr className="border-line" />

            <div className="grid gap-4 sm:grid-cols-2">
              <Input
                label="SOAT (número)"
                optional
                value={form.soatNumero}
                onChange={(e) => setForm({ ...form, soatNumero: e.target.value })}
              />
              <Input
                label="SOAT vence"
                optional
                type="date"
                value={form.soatVence}
                onChange={(e) => setForm({ ...form, soatVence: e.target.value })}
              />
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <Input
                label="Revisión técnica vence"
                optional
                type="date"
                value={form.revisionTecnicaVence}
                onChange={(e) => setForm({ ...form, revisionTecnicaVence: e.target.value })}
              />
              <Input
                label="Permiso de circulación vence"
                optional
                type="date"
                value={form.permisoCirculacionVence}
                onChange={(e) => setForm({ ...form, permisoCirculacionVence: e.target.value })}
              />
            </div>

            <hr className="border-line" />

            <CampoFoto
              label="Foto del vehículo"
              carpeta="vehiculos"
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
    </>
  )
}

/** Catálogo del que salen los vehículos: furgón, camioneta, moto. */
function TiposVehiculoTabla({
  tipos,
  onRecargar,
}: {
  tipos: TipoVehiculoResponse[]
  onRecargar: () => Promise<void>
}) {
  const { puede } = usePermisos()
  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<TipoVehiculoResponse | null>(null)
  const [form, setForm] = useState({
    nombre: '',
    descripcion: '',
    capacidadKgReferencia: '',
    activo: true,
  })
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')
  const [error, setError] = useState('')
  const { confirmar, dialogo } = useConfirmacion()

  const abrirNuevo = () => {
    setEditando(null)
    setForm({ nombre: '', descripcion: '', capacidadKgReferencia: '', activo: true })
    setErrorForm('')
    setAbierto(true)
  }

  const abrirEdicion = (t: TipoVehiculoResponse) => {
    setEditando(t)
    setForm({
      nombre: t.nombre,
      descripcion: t.descripcion ?? '',
      capacidadKgReferencia:
        t.capacidadKgReferencia != null ? String(t.capacidadKgReferencia) : '',
      activo: t.activo,
    })
    setErrorForm('')
    setAbierto(true)
  }

  const guardar = async () => {
    if (!form.nombre.trim()) return setErrorForm('Ingresa el nombre.')

    setGuardando(true)
    setErrorForm('')
    try {
      const cuerpo = {
        nombre: form.nombre.trim(),
        descripcion: textoOpcional(form.descripcion),
        capacidadKgReferencia: numeroOpcional(form.capacidadKgReferencia),
        activo: form.activo,
      }
      if (editando) await tipoVehiculoApi.update(editando.id, cuerpo)
      else await tipoVehiculoApi.create(cuerpo)
      setAbierto(false)
      await onRecargar()
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos guardar el tipo.')
    } finally {
      setGuardando(false)
    }
  }

  const cambiarEstado = (t: TipoVehiculoResponse) =>
    confirmar({
      titulo: `${t.activo ? 'Desactivar' : 'Activar'} ${t.nombre}`,
      mensaje: t.activo
        ? 'Deja de ofrecerse al dar de alta vehículos. Los que ya lo usan lo conservan.'
        : 'Vuelve a estar disponible para vehículos nuevos.',
      confirmar: t.activo ? 'Desactivar' : 'Activar',
      tono: t.activo ? 'warning' : 'pregunta',
      accion: async () => {
        setError('')
        try {
          await tipoVehiculoApi.update(t.id, {
            nombre: t.nombre,
            descripcion: t.descripcion,
            capacidadKgReferencia: t.capacidadKgReferencia,
            activo: !t.activo,
          })
          await onRecargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  const columns: DataTableColumn<TipoVehiculoResponse>[] = [
    { key: 'nombre', label: 'Nombre' },
    {
      key: 'descripcion',
      label: 'Descripción',
      render: (row) => row.descripcion ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'capacidadKgReferencia',
      label: 'Capacidad ref.',
      align: 'right',
      // Una cantidad no se busca por texto: no hay control numerico en el panel.
      filterable: false,
      render: (row) =>
        row.capacidadKgReferencia == null ? (
          <span className="text-ink-soft">—</span>
        ) : (
          `${row.capacidadKgReferencia} kg`
        ),
    },
    { key: 'vehiculos', label: 'Vehículos', align: 'right', filterable: false },
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

  return (
    <ListPage
      icon={<Wrench size={20} />}
      title="Tipos de vehículo"
      description="Furgón, camioneta, moto. De aquí sale el tipo que se elige en cada vehículo."
      actions={
        puede('tms.flota', 'crear') ? (
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nuevo tipo
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      columns={columns}
      rows={tipos}
      cardIcon={Wrench}
      searchPlaceholder="Buscar tipo..."
      empty="Todavía no hay tipos de vehículo."
      rowActions={(row) => (
        <>
          {puede('tms.flota', 'editar') && (
            <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)}>
              <Pencil size={15} />
            </RowAction>
          )}
          {puede('tms.flota', 'editar') && (
            <RowAction
              label={`${row.activo ? 'Desactivar' : 'Activar'} ${row.nombre}`}
              tone={row.activo ? 'warning' : 'success'}
              onClick={() => cambiarEstado(row)}
            >
              {row.activo ? <ShieldOff size={15} /> : <ShieldCheck size={15} />}
            </RowAction>
          )}
        </>
      )}
    >
      <Modal
        open={abierto}
        size="sm"
        title={editando ? `Editar ${editando.nombre}` : 'Nuevo tipo de vehículo'}
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Crear tipo'}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {errorForm && <Alert>{errorForm}</Alert>}

          <Input
            label="Nombre"
            placeholder="Furgón"
            value={form.nombre}
            onChange={(e) => setForm({ ...form, nombre: e.target.value })}
          />

          <Input
            label="Descripción"
            optional
            value={form.descripcion}
            onChange={(e) => setForm({ ...form, descripcion: e.target.value })}
          />

          <Input
            label="Capacidad de referencia (kg)"
            optional
            type="number"
            step="0.01"
            hint={<span className="text-xs text-ink-soft">orientativa</span>}
            value={form.capacidadKgReferencia}
            onChange={(e) => setForm({ ...form, capacidadKgReferencia: e.target.value })}
          />

          <label className="flex items-center gap-2 text-sm text-ink-muted">
            <input
              type="checkbox"
              checked={form.activo}
              onChange={(e) => setForm({ ...form, activo: e.target.checked })}
            />
            Activo (se ofrece al dar de alta vehículos)
          </label>
        </div>
      </Modal>

      {dialogo}
    </ListPage>
  )
}

/** Una etiqueta con su valor en la ficha; "—" cuando no hay dato. */
function Dato({ etiqueta, valor }: { etiqueta: string; valor?: string | null }) {
  return (
    <div className="flex flex-col gap-0.5">
      <span className="text-[11px] font-semibold tracking-wide text-ink-soft uppercase">
        {etiqueta}
      </span>
      <span className="text-sm text-ink">{valor || '—'}</span>
    </div>
  )
}
