import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  CalendarCheck,
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  Clock,
  Pencil,
  Plus,
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
  ListPage,
  Modal,
  RowAction,
  StatCard,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { BadgeTone, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta, fechaLocal, hoyLocal } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { empleadoApi } from './empleadoApi'
import type { EmpleadoResponse } from './empleadoApi'
import { asistenciaApi } from './asistenciaApi'
import type { AsistenciaResponse, EstadoAsistencia, ResumenAsistencia } from './asistenciaApi'

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

const TONO_ESTADO: Record<EstadoAsistencia, BadgeTone> = {
  PRESENTE: 'success',
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
 * no hay reloj biométrico detrás. El calendario es para ver el mes de un
 * vistazo; la tabla de abajo es el registro, con lo mismo filtrable y con
 * acciones para corregir o anular una marca hecha por error.
 */
export function AsistenciaPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()

  const [cursor, setCursor] = useState(() => {
    const hoy = new Date()
    return new Date(hoy.getFullYear(), hoy.getMonth(), 1)
  })
  const [empleadoFiltro, setEmpleadoFiltro] = useState<number | ''>('')
  const [empleados, setEmpleados] = useState<EmpleadoResponse[]>([])
  const [marcas, setMarcas] = useState<AsistenciaResponse[]>([])
  const [resumen, setResumen] = useState<ResumenAsistencia | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<AsistenciaResponse | null>(null)
  const [form, setForm] = useState<FormAsistencia>(formVacio())
  const [guardando, setGuardando] = useState(false)

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

  // Solo las activas: una anulada no debería tapar el día en el calendario.
  const marcasPorDia = useMemo(() => {
    const mapa = new Map<string, AsistenciaResponse>()
    for (const m of marcas) {
      if (!m.anulado) mapa.set(m.fecha.slice(0, 10), m)
    }
    return mapa
  }, [marcas])

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
  // tiene marca la abre para corregirla, si no propone una nueva.
  const alClickDia = (fecha: string | null) => {
    if (!fecha || !empleadoFiltro) return
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
    <ListPage
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
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        resumen && (
          <>
            <StatCard label="Presentes" value={String(resumen.presentes)} icon={<UserCheck size={18} />} tono="success" />
            <StatCard label="Tardanzas" value={String(resumen.tardanzas)} icon={<Clock size={18} />} tono="warning" />
            <StatCard label="Faltas" value={String(resumen.faltas)} icon={<UserX size={18} />} tono="danger" />
            <StatCard label="Permisos" value={String(resumen.permisos)} icon={<CalendarDays size={18} />} tono="sys" />
          </>
        )
      }
      banner={
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

            <div className="w-full sm:w-64">
              <Desplegable
                value={empleadoFiltro}
                onChange={(v) => setEmpleadoFiltro(v === '' ? '' : Number(v))}
                placeholder="Todos los empleados"
                optional
                options={empleados.map((e) => ({ value: e.id, label: e.nombreCompleto, detalle: e.cargo ?? undefined }))}
              />
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
                const marca = fecha ? marcasPorDia.get(fecha) : undefined
                const futuro = fecha ? fecha > hoyLocal() : false
                const clicable = !!fecha && !!empleadoFiltro && !futuro
                return (
                  <button
                    key={`${si}-${di}`}
                    type="button"
                    disabled={!clicable}
                    onClick={() => alClickDia(fecha)}
                    className={`flex h-14 flex-col items-center justify-center gap-0.5 rounded-field border text-xs ${
                      fecha ? 'border-line bg-white' : 'border-transparent'
                    } ${clicable ? 'cursor-pointer hover:border-sys' : ''} ${futuro ? 'opacity-40' : ''}`}
                  >
                    {fecha && <span className="text-ink-soft">{Number(fecha.slice(8, 10))}</span>}
                    {marca && (
                      <Badge tone={TONO_ESTADO[marca.estado]} className="px-1.5 py-0">
                        {ABREVIA[marca.estado]}
                      </Badge>
                    )}
                  </button>
                )
              }),
            )}
          </div>

          {!empleadoFiltro && (
            <p className="mt-2 text-xs text-ink-soft">Elige un empleado para marcar o corregir desde el calendario.</p>
          )}
        </div>
      }
      columns={columns}
      rows={marcas}
      cardIcon={CalendarCheck}
      searchPlaceholder="Buscar por empleado..."
      empty={cargando ? 'Cargando asistencia...' : 'No hay marcas registradas este mes.'}
      rowActions={(row) => (
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
    >
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

      {dialogo}
    </ListPage>
  )
}
