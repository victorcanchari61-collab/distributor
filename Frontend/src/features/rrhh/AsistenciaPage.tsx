import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  CalendarCheck,
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  Clock,
  Flag,
  Pencil,
  Plus,
  Table2,
  Undo2,
  UserCheck,
  UserX,
} from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Desplegable,
  Input,
  Modal,
  PageHeader,
  RowAction,
  StatCard,
  SysDataTable,
  Tabs,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { BadgeTone, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta, fechaLocal, hoyLocal } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { empleadoApi, trabajaba } from './empleadoApi'
import type { EmpleadoResponse } from './empleadoApi'
import { asistenciaApi } from './asistenciaApi'
import type { AsistenciaResponse, EstadoAsistencia, ResumenAsistencia } from './asistenciaApi'
import { feriadoApi } from './feriadoApi'
import type { FeriadoResponse } from './feriadoApi'
import { FeriadosModal } from './FeriadosModal'
import { PaseListaModal } from './PaseListaModal'

const DIAS = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
const MESES = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
]

const ESTADOS: { value: EstadoAsistencia; label: string }[] = [
  { value: 'PRESENTE', label: 'Presente' },
  { value: 'TARDANZA', label: 'Tardanza' },
  { value: 'FALTA', label: 'Falta' },
  { value: 'PERMISO', label: 'Permiso' },
]

// Apagados a propósito: PRESENTE (lo esperable, la mayoría de los días) va en
// gris neutro y no compite por atención. El color se reserva para lo que de
// verdad hay que mirar: una tardanza, una falta, un permiso.
const TONO_ESTADO: Record<EstadoAsistencia, BadgeTone> = {
  PRESENTE: 'neutral',
  TARDANZA: 'warning',
  FALTA: 'danger',
  PERMISO: 'sys',
}

const ABREVIA: Record<EstadoAsistencia, string> = {
  PRESENTE: 'P',
  TARDANZA: 'T',
  FALTA: 'F',
  PERMISO: 'PM',
}

type Pestana = 'calendario' | 'registro'

/** El mes de `cursor` en semanas de lunes a domingo, con huecos como `null`. */
function semanasDe(cursor: Date): (string | null)[][] {
  const anio = cursor.getFullYear()
  const mes = cursor.getMonth()
  const primerDia = new Date(anio, mes, 1)
  const offset = (primerDia.getDay() + 6) % 7
  const diasEnMes = new Date(anio, mes + 1, 0).getDate()

  const celdas: (string | null)[] = [
    ...Array<null>(offset).fill(null),
    ...Array.from({ length: diasEnMes }, (_, i) => fechaLocal(new Date(anio, mes, i + 1))),
  ]
  while (celdas.length % 7 !== 0) celdas.push(null)

  const semanas: (string | null)[][] = []
  for (let i = 0; i < celdas.length; i += 7) semanas.push(celdas.slice(i, i + 7))
  return semanas
}

interface FormAsistencia {
  empleadoId: number
  fecha: string
  estado: EstadoAsistencia
  observacion: string
}

const formVacio = (): FormAsistencia => ({
  empleadoId: 0,
  fecha: hoyLocal(),
  estado: 'PRESENTE',
  observacion: '',
})

/**
 * Quién vino, quién faltó, quién llegó tarde. Se marca a mano, uno por uno —
 * no hay reloj biométrico detrás. Una pestaña para verlo en calendario, otra
 * para el registro tal cual —filtrable, con acciones para corregir o anular
 * una marca hecha por error.
 */
export function AsistenciaPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()

  const [pestana, setPestana] = useState<Pestana>('calendario')

  const [cursor, setCursor] = useState(() => {
    const hoy = new Date()
    return new Date(hoy.getFullYear(), hoy.getMonth(), 1)
  })
  const [empleadoFiltro, setEmpleadoFiltro] = useState<number | ''>('')
  const [empleados, setEmpleados] = useState<EmpleadoResponse[]>([])
  const [marcas, setMarcas] = useState<AsistenciaResponse[]>([])
  const [resumen, setResumen] = useState<ResumenAsistencia | null>(null)
  const [feriados, setFeriados] = useState<FeriadoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<AsistenciaResponse | null>(null)
  const [form, setForm] = useState<FormAsistencia>(formVacio())
  const [guardando, setGuardando] = useState(false)
  const [feriadosAbierto, setFeriadosAbierto] = useState(false)
  const [paseFecha, setPaseFecha] = useState<string | null>(null)

  const desde = fechaLocal(new Date(cursor.getFullYear(), cursor.getMonth(), 1))
  const hasta = fechaLocal(new Date(cursor.getFullYear(), cursor.getMonth() + 1, 0))

  const cargar = useCallback(async () => {
    setCargando(true)
    setError('')
    try {
      const id = empleadoFiltro || undefined
      const [m, r] = await Promise.all([
        asistenciaApi.listar(desde, hasta, id),
        asistenciaApi.resumen(desde, hasta, id),
      ])
      setMarcas(m)
      setResumen(r)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar la asistencia.')
    } finally {
      setCargando(false)
    }
  }, [desde, hasta, empleadoFiltro])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('asistencia', cargar)

  useEffect(() => {
    void empleadoApi.getAll().then((todos) => setEmpleados(todos.filter((e) => e.activo)))
  }, [])

  const cargarFeriados = useCallback(() => {
    void feriadoApi.getAll().then(setFeriados)
  }, [])

  useEffect(() => {
    cargarFeriados()
  }, [cargarFeriados])

  useRealtime('feriados', cargarFeriados)

  // Solo las activas: una anulada no debería tapar el día en el calendario.
  const marcasPorDia = useMemo(() => {
    const mapa = new Map<string, AsistenciaResponse>()
    for (const m of marcas) {
      if (!m.anulado) mapa.set(m.fecha.slice(0, 10), m)
    }
    return mapa
  }, [marcas])

  // Con "Todos los empleados": todas las marcas activas de cada día, para el pase de lista.
  const marcasDelDia = useMemo(() => {
    const mapa = new Map<string, AsistenciaResponse[]>()
    for (const m of marcas) {
      if (m.anulado) continue
      const dia = m.fecha.slice(0, 10)
      mapa.set(dia, [...(mapa.get(dia) ?? []), m])
    }
    return mapa
  }, [marcas])

  const feriadosPorDia = useMemo(
    () => new Map(feriados.map((f) => [f.fecha.slice(0, 10), f])),
    [feriados],
  )

  const abrirNuevo = (preset?: { empleadoId?: number; fecha?: string }) => {
    setEditando(null)
    setForm({ ...formVacio(), empleadoId: preset?.empleadoId ?? (Number(empleadoFiltro) || 0), fecha: preset?.fecha ?? hoyLocal() })
    setAbierto(true)
  }

  const abrirEdicion = (marca: AsistenciaResponse) => {
    setEditando(marca)
    setForm({
      empleadoId: marca.empleadoId,
      fecha: marca.fecha.slice(0, 10),
      estado: marca.estado,
      observacion: marca.observacion ?? '',
    })
    setAbierto(true)
  }

  // Con un empleado elegido, el día del calendario se puede tocar: si ya
  // tiene marca la abre para corregirla, si no propone una nueva. Sin
  // empleado elegido, abre el pase de lista de todos.
  const alClickDia = (fecha: string | null) => {
    if (!fecha) return
    if (!empleadoFiltro) {
      if (fecha <= hoyLocal() && puede('rrhh.asistencia', 'crear')) setPaseFecha(fecha)
      return
    }
    const marca = marcasPorDia.get(fecha)
    if (marca) {
      if (puede('rrhh.asistencia', 'editar')) abrirEdicion(marca)
    } else if (fecha <= hoyLocal() && puede('rrhh.asistencia', 'crear')) {
      abrirNuevo({ empleadoId: Number(empleadoFiltro), fecha })
    }
  }

  const guardar = async () => {
    if (!editando && !form.empleadoId) return toast.error('Elige el empleado.')
    if (!form.fecha) return toast.error('Elige la fecha.')

    setGuardando(true)
    try {
      if (editando) {
        await asistenciaApi.editar(editando.id, { estado: form.estado, observacion: form.observacion.trim() || null })
      } else {
        await asistenciaApi.crear({
          empleadoId: form.empleadoId,
          fecha: form.fecha,
          estado: form.estado,
          observacion: form.observacion.trim() || null,
        })
      }
      setAbierto(false)
      await cargar()
      toast.exito(editando ? 'Marca actualizada' : 'Asistencia registrada')
    } catch (e) {
      toast.error(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos guardar la marca.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const anular = (marca: AsistenciaResponse) =>
    confirmar({
      titulo: `Anular la marca de ${marca.empleado}`,
      mensaje: `Deja sin efecto el "${ESTADOS.find((e) => e.value === marca.estado)?.label}" del ${fechaCorta(marca.fecha)}. Se puede volver a marcar ese día después.`,
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        try {
          await asistenciaApi.anular(marca.id)
          await cargar()
          toast.exito('Marca anulada')
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos anular la marca.')
        }
      },
    })

  const empleadosEnLista = [...new Set(marcas.map((m) => m.empleado))]
    .sort((a, b) => a.localeCompare(b, 'es'))
    .map((v) => ({ value: v, label: v }))

  const columns: DataTableColumn<AsistenciaResponse>[] = [
    { key: 'fecha', label: 'Fecha', filterType: 'date', render: (row) => fechaCorta(row.fecha) },
    { key: 'empleado', label: 'Empleado', filterType: 'select', filterOptions: empleadosEnLista },
    { key: 'cargo', label: 'Cargo', filterable: false, render: (row) => row.cargo ?? '—' },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: ESTADOS,
      render: (row) => <Badge tone={TONO_ESTADO[row.estado]}>{ESTADOS.find((e) => e.value === row.estado)?.label}</Badge>,
    },
    { key: 'observacion', label: 'Observación', filterable: false, render: (row) => row.observacion ?? '—' },
    { key: 'usuario', label: 'Registrada por', filterable: false, render: (row) => row.usuario ?? '—' },
    {
      key: 'registro',
      label: 'Registro',
      filterType: 'select',
      filterOptions: [
        { value: 'Activa', label: 'Activa' },
        { value: 'Anulada', label: 'Anulada' },
      ],
      value: (row) => (row.anulado ? 'Anulada' : 'Activa'),
      render: (row) => <Badge tone={row.anulado ? 'danger' : 'neutral'}>{row.anulado ? 'Anulada' : 'Activa'}</Badge>,
    },
  ]

  const semanas = semanasDe(cursor)

  return (
    <div className="space-y-5">
      <PageHeader
        icon={<CalendarCheck size={20} />}
        title="Asistencia"
        description="Quién vino, quién faltó, quién llegó tarde. El registro es manual, uno por empleado y por día."
        actions={
          puede('rrhh.asistencia', 'crear') ? (
            <Button size="sm" onClick={() => abrirNuevo()} iconRight={<Plus size={15} />}>
              Nueva marca
            </Button>
          ) : undefined
        }
      />

      {error && <Alert>{error}</Alert>}

      {resumen && (
        <section className="-mx-4 flex snap-x snap-mandatory gap-3 overflow-x-auto px-4 pb-1 sm:mx-0 sm:grid sm:grid-cols-[repeat(auto-fit,minmax(13rem,1fr))] sm:gap-4 sm:overflow-visible sm:px-0 sm:pb-0 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          <StatCard label="Presentes" value={String(resumen.presentes)} icon={<UserCheck size={18} />} tono="sys" />
          <StatCard label="Tardanzas" value={String(resumen.tardanzas)} icon={<Clock size={18} />} tono="warning" />
          <StatCard label="Faltas" value={String(resumen.faltas)} icon={<UserX size={18} />} tono="danger" />
          <StatCard label="Permisos" value={String(resumen.permisos)} icon={<CalendarDays size={18} />} tono="neutral" />
        </section>
      )}

      <Tabs
        active={pestana}
        onChange={(id) => setPestana(id as Pestana)}
        items={[
          { id: 'calendario', label: 'Calendario', icon: <CalendarDays size={15} /> },
          { id: 'registro', label: 'Registro', icon: <Table2 size={15} />, badge: marcas.length },
        ]}
      />

      {pestana === 'calendario' ? (
        <div className="rounded-panel border border-line bg-white p-4">
          <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => setCursor((c) => new Date(c.getFullYear(), c.getMonth() - 1, 1))}
                className="rounded-field border border-line p-1.5 text-ink-soft hover:bg-surface-alt"
                aria-label="Mes anterior"
              >
                <ChevronLeft size={16} />
              </button>
              <span className="w-36 text-center text-sm font-bold text-ink">
                {MESES[cursor.getMonth()]} {cursor.getFullYear()}
              </span>
              <button
                type="button"
                onClick={() => setCursor((c) => new Date(c.getFullYear(), c.getMonth() + 1, 1))}
                className="rounded-field border border-line p-1.5 text-ink-soft hover:bg-surface-alt"
                aria-label="Mes siguiente"
              >
                <ChevronRight size={16} />
              </button>
            </div>

            <div className="flex flex-1 flex-wrap items-center justify-end gap-2">
              <div className="w-full sm:w-64">
                <Desplegable
                  value={empleadoFiltro}
                  onChange={(v) => setEmpleadoFiltro(v === '' ? '' : Number(v))}
                  placeholder="Todos los empleados"
                  optional
                  options={empleados.map((e) => ({ value: e.id, label: e.nombreCompleto, detalle: e.cargo ?? undefined }))}
                />
              </div>
              {puede('rrhh.asistencia', 'ver') && (
                <Button size="sm" variant="secondary" onClick={() => setFeriadosAbierto(true)} iconRight={<Flag size={15} />}>
                  Feriados
                </Button>
              )}
            </div>
          </div>

          <div className="grid grid-cols-7 gap-1 text-center text-[11px] font-semibold uppercase text-ink-soft">
            {DIAS.map((d) => (
              <div key={d} className="py-1">
                {d}
              </div>
            ))}
          </div>

          <div className="grid grid-cols-7 gap-1">
            {semanas.flatMap((semana, si) =>
              semana.map((fecha, di) => {
                const marca = fecha && empleadoFiltro ? marcasPorDia.get(fecha) : undefined
                const feriado = fecha ? feriadosPorDia.get(fecha) : undefined
                const futuro = fecha ? fecha > hoyLocal() : false
                const clicable = !!fecha && !futuro && (!!empleadoFiltro || puede('rrhh.asistencia', 'crear'))
                const marcadosDia = fecha && !empleadoFiltro ? (marcasDelDia.get(fecha)?.length ?? 0) : 0
                const esperadosDia =
                  fecha && !empleadoFiltro && !futuro ? empleados.filter((e) => trabajaba(e, fecha)).length : 0
                return (
                  <button
                    key={`${si}-${di}`}
                    type="button"
                    disabled={!clicable}
                    title={feriado?.nombre}
                    onClick={() => alClickDia(fecha)}
                    className={`flex h-16 flex-col items-center justify-center gap-0.5 rounded-field border px-1 text-xs ${
                      fecha ? (feriado ? 'border-amber-200 bg-amber-50' : 'border-line bg-white') : 'border-transparent'
                    } ${clicable ? 'cursor-pointer hover:border-sys' : ''} ${futuro ? 'opacity-40' : ''}`}
                  >
                    {fecha && <span className="text-ink-soft">{Number(fecha.slice(8, 10))}</span>}
                    {feriado && (
                      <span className="w-full truncate text-center text-[10px] font-semibold text-amber-700">
                        {feriado.nombre}
                      </span>
                    )}
                    {marca && (
                      <Badge tone={TONO_ESTADO[marca.estado]} className="px-1.5 py-0">
                        {ABREVIA[marca.estado]}
                      </Badge>
                    )}
                    {(marcadosDia > 0 || esperadosDia > 0) && (
                      <Badge
                        tone={marcadosDia >= esperadosDia ? 'neutral' : 'warning'}
                        className="px-1.5 py-0"
                      >
                        {marcadosDia}/{esperadosDia}
                      </Badge>
                    )}
                  </button>
                )
              }),
            )}
          </div>

          <p className="mt-2 text-xs text-ink-soft">
            {empleadoFiltro
              ? 'Toca un día para marcar o corregir a este empleado.'
              : 'Toca un día para pasar lista a todos: marcados / los que trabajaban ese día. Elige un empleado para ver solo sus marcas.'}
          </p>
        </div>
      ) : (
        <SysDataTable
          columns={columns}
          rows={marcas}
          cardIcon={CalendarCheck}
          searchPlaceholder="Buscar por empleado..."
          empty={cargando ? 'Cargando asistencia...' : 'No hay marcas registradas este mes.'}
          actions={(row) => (
            <>
              {!row.anulado && puede('rrhh.asistencia', 'editar') && (
                <RowAction label={`Editar la marca de ${row.empleado}`} onClick={() => abrirEdicion(row)}>
                  <Pencil size={15} />
                </RowAction>
              )}
              {!row.anulado && puede('rrhh.asistencia', 'anular') && (
                <RowAction label={`Anular la marca de ${row.empleado}`} tone="danger" onClick={() => anular(row)}>
                  <Undo2 size={15} />
                </RowAction>
              )}
            </>
          )}
        />
      )}

      <Modal
        open={abierto}
        title={editando ? `Editar marca de ${editando.empleado}` : 'Nueva marca de asistencia'}
        description={editando ? undefined : 'Un empleado, un día: si ya tiene una marca activa, anúlala antes de registrar otra.'}
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Registrar'}
            </Button>
          </>
        }
      >
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {editando ? (
            <>
              <div className="sm:col-span-2">
                <p className="text-xs font-semibold uppercase tracking-wide text-ink-soft">Empleado</p>
                <p className="text-sm font-medium text-ink">{editando.empleado}</p>
              </div>
              <div>
                <p className="text-xs font-semibold uppercase tracking-wide text-ink-soft">Fecha</p>
                <p className="text-sm font-medium text-ink">{fechaCorta(editando.fecha)}</p>
              </div>
            </>
          ) : (
            <>
              <Desplegable
                label="Empleado"
                className="sm:col-span-2"
                value={form.empleadoId}
                onChange={(v) => setForm({ ...form, empleadoId: Number(v) })}
                placeholder="Elige un empleado"
                options={empleados.map((e) => ({ value: e.id, label: e.nombreCompleto, detalle: e.cargo ?? undefined }))}
              />
              <Input
                label="Fecha"
                type="date"
                max={hoyLocal()}
                value={form.fecha}
                onChange={(e) => setForm({ ...form, fecha: e.target.value })}
              />
            </>
          )}

          <Desplegable
            label="Estado"
            value={form.estado}
            onChange={(v) => setForm({ ...form, estado: v as EstadoAsistencia })}
            options={ESTADOS}
          />

          <Input
            label="Observación"
            className="sm:col-span-2"
            optional
            placeholder="Motivo del permiso, minutos de tardanza..."
            value={form.observacion}
            onChange={(e) => setForm({ ...form, observacion: e.target.value })}
          />
        </div>
      </Modal>

      <FeriadosModal open={feriadosAbierto} onClose={() => setFeriadosAbierto(false)} />

      {paseFecha && (
        <PaseListaModal
          fecha={paseFecha}
          feriado={feriadosPorDia.get(paseFecha)?.nombre}
          empleados={empleados}
          marcas={marcasDelDia.get(paseFecha) ?? []}
          puedeCorregir={puede('rrhh.asistencia', 'editar')}
          onClose={() => setPaseFecha(null)}
          onGuardado={async (mensaje) => {
            setPaseFecha(null)
            await cargar()
            toast.exito(mensaje)
          }}
        />
      )}

      {dialogo}
    </div>
  )
}
