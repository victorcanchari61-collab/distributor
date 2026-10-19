import { useCallback, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import {
  CalendarCheck,
  CalendarDays,
  Check,
  ChevronLeft,
  ChevronRight,
  Clock,
  Flag,
  MessageSquare,
  FileText,
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
  FilaStats,
  Input,
  Modal,
  PageHeader,
  RowAction,
  StatCard,
  SysDataTable,
  Tabs,
  VisorReportePdf,
  cn,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta, fechaLocal, hoyLocal } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { trabajaba } from './empleadoApi'
import { asistenciaApi } from './asistenciaApi'
import type { AsistenciaResponse, EmpleadoAsistencia, EstadoAsistencia, ResumenAsistencia } from './asistenciaApi'
import { feriadoApi } from './feriadoApi'
import type { FeriadoResponse } from './feriadoApi'
import { FeriadosModal } from './FeriadosModal'
import { PaseListaModal } from './PaseListaModal'

const DIAS = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']

/** Su cargo, y si ya no está: cesado con su fecha, o desactivado. */
const detalleEmpleado = (e: EmpleadoAsistencia) =>
  e.activo
    ? (e.cargo ?? undefined)
    : e.fechaCese
      ? `Cesó el ${fechaCorta(e.fechaCese)}`
      : 'Desactivado'
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

/*
 * Un color por significado. PRESENTE va en gris a propósito: es lo esperable, la mayoría de los
 * días, y no compite por atención. El color se reserva para lo que hay que mirar.
 *
 * Permiso iba con el color del sistema, que en RR.HH. es ámbar: el mismo de la tardanza y del
 * feriado, tres cosas distintas en un solo tono. Ahora es celeste, y el feriado, violeta.
 */
const COLOR_ESTADO: Record<EstadoAsistencia, { chip: string; punto: string }> = {
  PRESENTE: { chip: 'bg-zinc-100 text-zinc-600 ring-zinc-200', punto: 'bg-zinc-400' },
  TARDANZA: { chip: 'bg-amber-50 text-amber-800 ring-amber-200', punto: 'bg-amber-500' },
  FALTA: { chip: 'bg-red-50 text-red-700 ring-red-200', punto: 'bg-red-500' },
  PERMISO: { chip: 'bg-sky-50 text-sky-700 ring-sky-200', punto: 'bg-sky-500' },
}

/** Lo que no es "presente", en el orden en que se mira: lo más grave primero. */
const INCIDENCIAS: EstadoAsistencia[] = ['FALTA', 'TARDANZA', 'PERMISO']

const etiquetaEstado = (estado: EstadoAsistencia) => ESTADOS.find((e) => e.value === estado)?.label ?? estado

/** El estado de una marca, con el mismo color en el calendario y en el registro. */
function EstadoChip({ estado, className }: { estado: EstadoAsistencia; className?: string }) {
  return (
    <span
      className={cn(
        'inline-flex items-center rounded-full px-2 py-0.5 text-[11px] font-semibold ring-1',
        COLOR_ESTADO[estado].chip,
        className,
      )}
    >
      {etiquetaEstado(estado)}
    </span>
  )
}

const ABREVIA: Record<EstadoAsistencia, string> = {
  PRESENTE: 'P',
  TARDANZA: 'T',
  FALTA: 'F',
  PERMISO: 'PM',
}

type Pestana = 'calendario' | 'registro'

/** El primer día del mes de una fecha YYYY-MM-DD. */
const mesDe = (fecha: string) => new Date(Number(fecha.slice(0, 4)), Number(fecha.slice(5, 7)) - 1, 1)

const DIAS_LARGOS = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado']

/**
 * Un día del calendario: el número arriba (hoy, en un círculo con el color del sistema), lo que
 * resume el día en la esquina y el detalle abajo. En el celular el detalle se vuelve puntos: siete
 * columnas en 375px no dejan sitio para texto.
 */
function DiaCalendario({
  fecha,
  hoy,
  apagado,
  feriado,
  sinMarcar = false,
  clicable,
  onClick,
  detalle,
  esquina,
  punto,
  children,
}: {
  fecha: string
  hoy: boolean
  /** Domingo, futuro o fuera de contrato: no se espera marca. */
  apagado: boolean
  feriado?: string
  /** Se esperaba marca y no la hay: borde punteado para que salte a la vista. */
  sinMarcar?: boolean
  clicable: boolean
  onClick: () => void
  /** Para el lector de pantalla y el tooltip: qué pasó ese día, en palabras. */
  detalle?: string
  esquina?: ReactNode
  /** En el celular, el estado del día como un punto junto al número. */
  punto?: string
  children?: ReactNode
}) {
  const [a, m, d] = fecha.split('-').map(Number)
  const dia = DIAS_LARGOS[new Date(a, m - 1, d).getDay()]
  const titulo = [`${dia} ${d}`, feriado && `Feriado: ${feriado}`, detalle].filter(Boolean).join(' · ')

  return (
    <button
      type="button"
      disabled={!clicable}
      onClick={onClick}
      title={titulo}
      aria-label={titulo}
      className={cn(
        'flex h-16 min-w-0 flex-col justify-between rounded-field border p-1 text-left sm:h-24 sm:p-2',
        'transition-[border-color,box-shadow] duration-150 ease-out',
        'focus-visible:ring-2 focus-visible:ring-[rgb(var(--sys-rgb)/0.45)] focus-visible:outline-none',
        feriado
          ? 'border-violet-200 bg-violet-50'
          : sinMarcar
            ? 'border-dashed border-amber-300 bg-white'
            : apagado
              ? 'border-line/70 bg-surface-alt'
              : 'border-line bg-white',
        clicable
          ? 'cursor-pointer hover:border-[rgb(var(--sys-rgb)/0.55)] hover:shadow-[0_3px_10px_-4px_rgb(15_23_42/0.18)]'
          : 'cursor-default',
      )}
    >
      <div className="flex items-start justify-between gap-1">
        <span
          className={cn(
            'inline-flex size-6 shrink-0 items-center justify-center rounded-full text-xs font-semibold tabular-nums sm:size-7 sm:text-[13px]',
            hoy ? 'bg-[rgb(var(--sys-rgb))] text-[var(--sys-on)]' : apagado && !feriado ? 'text-ink-soft' : 'text-ink',
          )}
        >
          {d}
        </span>
        {esquina && <span className="hidden sm:inline-flex">{esquina}</span>}
        {punto && <span className={cn('mt-1 size-1.5 shrink-0 rounded-full sm:hidden', punto)} />}
      </div>

      <div className="flex min-w-0 flex-col gap-1">
        {feriado && (
          <span className="flex min-w-0 items-center gap-1 text-[10px] font-semibold text-violet-700 sm:text-[11px]">
            <Flag size={11} className="shrink-0" aria-hidden="true" />
            <span className="hidden truncate sm:inline">{feriado}</span>
          </span>
        )}
        {children}
      </div>
    </button>
  )
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
  const [empleados, setEmpleados] = useState<EmpleadoAsistencia[]>([])
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
  const [reporte, setReporte] = useState(false)

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

  // Todos, también los desactivados: quien cesó se sigue marcando hasta su fecha de cese, y sus
  // marcas viejas se siguen pudiendo filtrar.
  const cargarEmpleados = useCallback(() => {
    asistenciaApi
      .empleados()
      .then(setEmpleados)
      .catch((e) => setError(e instanceof ApiError ? e.message : 'No pudimos cargar los empleados.'))
  }, [])

  useEffect(() => {
    cargarEmpleados()
  }, [cargarEmpleados])

  useRealtime('empleados', cargarEmpleados)

  const cargarFeriados = useCallback(() => {
    feriadoApi
      .getAll()
      .then(setFeriados)
      .catch((e) => setError(e instanceof ApiError ? e.message : 'No pudimos cargar los feriados.'))
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
    const elegido = empleados.find((e) => e.id === empleadoFiltro)
    if (marca) {
      if (puede('rrhh.asistencia', 'editar')) abrirEdicion(marca)
    } else if (fecha <= hoyLocal() && (!elegido || trabajaba(elegido, fecha)) && puede('rrhh.asistencia', 'crear')) {
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
      render: (row) => <EstadoChip estado={row.estado} />,
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
  const hoy = hoyLocal()
  const esMesActual = cursor.getFullYear() === Number(hoy.slice(0, 4)) && cursor.getMonth() === Number(hoy.slice(5, 7)) - 1
  const empleadoElegido = empleadoFiltro ? empleados.find((e) => e.id === empleadoFiltro) : undefined

  return (
    <div className="space-y-5">
      <PageHeader
        icon={<CalendarCheck size={20} />}
        title="Asistencia"
        description="Quién vino, quién faltó y quién llegó tarde."
        actions={
          <>
            {puede('rrhh.asistencia', 'exportar') && (
              <Button size="sm" variant="secondary" onClick={() => setReporte(true)} iconRight={<FileText size={15} />}>
                PDF del mes
              </Button>
            )}
            {puede('rrhh.asistencia', 'crear') && (
              <Button size="sm" onClick={() => abrirNuevo()} iconRight={<Plus size={15} />}>
                Nueva marca
              </Button>
            )}
          </>
        }
      />

      {error && <Alert>{error}</Alert>}

      {resumen && (
        <FilaStats>
          <StatCard label="Presentes" value={String(resumen.presentes)} icon={<UserCheck size={18} />} tono="sys" />
          <StatCard label="Tardanzas" value={String(resumen.tardanzas)} icon={<Clock size={18} />} tono="warning" />
          <StatCard label="Faltas" value={String(resumen.faltas)} icon={<UserX size={18} />} tono="danger" />
          <StatCard label="Permisos" value={String(resumen.permisos)} icon={<CalendarDays size={18} />} tono="neutral" />
        </FilaStats>
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
        <div className="rounded-panel border border-line bg-white p-3 sm:p-5">
          <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
            <div className="flex items-center gap-3">
              <div className="flex shrink-0 overflow-hidden rounded-field border border-line">
                <button
                  type="button"
                  onClick={() => setCursor((c) => new Date(c.getFullYear(), c.getMonth() - 1, 1))}
                  className="cursor-pointer border-r border-line p-1.5 text-ink-muted transition-colors hover:bg-surface-alt hover:text-ink"
                  aria-label="Mes anterior"
                >
                  <ChevronLeft size={16} />
                </button>
                <button
                  type="button"
                  onClick={() => setCursor((c) => new Date(c.getFullYear(), c.getMonth() + 1, 1))}
                  className="cursor-pointer p-1.5 text-ink-muted transition-colors hover:bg-surface-alt hover:text-ink"
                  aria-label="Mes siguiente"
                >
                  <ChevronRight size={16} />
                </button>
              </div>
              <h2 className="text-lg font-bold tracking-tight text-ink">
                {MESES[cursor.getMonth()]} <span className="font-medium text-ink-muted">{cursor.getFullYear()}</span>
              </h2>
              {!esMesActual && (
                <Button size="sm" variant="secondary" onClick={() => setCursor(mesDe(hoy))}>
                  Hoy
                </Button>
              )}
            </div>

            <div className="flex flex-1 flex-wrap items-center justify-end gap-2">
              <div className="w-full sm:w-64">
                <Desplegable
                  value={empleadoFiltro}
                  onChange={(v) => setEmpleadoFiltro(v === '' ? '' : Number(v))}
                  placeholder="Todos los empleados"
                  optional
                  options={empleados.map((e) => ({ value: e.id, label: e.nombreCompleto, detalle: detalleEmpleado(e) }))}
                />
              </div>
              {puede('rrhh.asistencia', 'ver') && (
                <Button size="sm" variant="secondary" onClick={() => setFeriadosAbierto(true)} iconRight={<Flag size={15} />}>
                  Feriados
                </Button>
              )}
            </div>
          </div>

          <div className="mb-1.5 grid grid-cols-7 gap-1.5 sm:gap-2">
            {DIAS.map((d, i) => (
              <div
                key={d}
                className={cn(
                  'px-1 text-[11px] font-semibold tracking-wide uppercase sm:px-2',
                  i === 6 ? 'text-ink-soft' : 'text-ink-muted',
                )}
              >
                {d}
              </div>
            ))}
          </div>

          <div className={cn('grid grid-cols-7 gap-1.5 transition-opacity duration-200 sm:gap-2', cargando && 'opacity-60')}>
            {semanas.flatMap((semana, si) =>
              semana.map((fecha, di) => {
                if (!fecha) return <div key={`${si}-${di}`} aria-hidden="true" />

                const feriado = feriadosPorDia.get(fecha)
                const futuro = fecha > hoy
                // Los domingos y feriados no se esperan (no se pagan ni se descuentan): no son "incompletos".
                const domingo = di === 6
                const seEspera = !domingo && !feriado && !futuro

                if (empleadoElegido) {
                  const marca = marcasPorDia.get(fecha)
                  const enContrato = trabajaba(empleadoElegido, fecha)
                  return (
                    <DiaCalendario
                      key={fecha}
                      fecha={fecha}
                      hoy={fecha === hoy}
                      apagado={futuro || domingo || !enContrato}
                      feriado={feriado?.nombre}
                      sinMarcar={seEspera && enContrato && !marca}
                      clicable={
                        marca ? puede('rrhh.asistencia', 'editar') : !futuro && enContrato && puede('rrhh.asistencia', 'crear')
                      }
                      onClick={() => alClickDia(fecha)}
                      detalle={
                        marca
                          ? `${etiquetaEstado(marca.estado)}${marca.observacion ? `: ${marca.observacion}` : ''}`
                          : !enContrato
                            ? 'No trabajaba aquí'
                            : seEspera
                              ? 'Sin marcar'
                              : undefined
                      }
                    >
                      {marca ? (
                        <div className="flex items-center gap-1">
                          <EstadoChip estado={marca.estado} className="hidden sm:inline-flex" />
                          <span
                            className={cn('inline-flex rounded-full px-1.5 text-[10px] font-bold ring-1 sm:hidden', COLOR_ESTADO[marca.estado].chip)}
                          >
                            {ABREVIA[marca.estado]}
                          </span>
                          {marca.observacion && <MessageSquare size={12} className="shrink-0 text-ink-soft" aria-hidden="true" />}
                        </div>
                      ) : seEspera && enContrato ? (
                        <span className="hidden text-[11px] font-medium text-amber-700 sm:inline">Sin marcar</span>
                      ) : null}
                    </DiaCalendario>
                  )
                }

                const delDia = marcasDelDia.get(fecha) ?? []
                const esperados = seEspera ? empleados.filter((e) => trabajaba(e, fecha)).length : 0
                const completo = delDia.length >= esperados
                const conteo = (estado: EstadoAsistencia) => delDia.filter((m) => m.estado === estado).length
                const incidencias = INCIDENCIAS.map((estado) => ({ estado, n: conteo(estado) })).filter((x) => x.n > 0)

                return (
                  <DiaCalendario
                    key={fecha}
                    fecha={fecha}
                    hoy={fecha === hoy}
                    apagado={futuro || domingo}
                    feriado={feriado?.nombre}
                    clicable={!futuro && puede('rrhh.asistencia', 'crear')}
                    onClick={() => alClickDia(fecha)}
                    detalle={[
                      esperados > 0 ? `${delDia.length} de ${esperados} con marca` : delDia.length > 0 ? `${delDia.length} con marca` : '',
                      ...incidencias.map((x) => `${x.n} ${etiquetaEstado(x.estado).toLowerCase()}`),
                    ]
                      .filter(Boolean)
                      .join(', ')}
                    esquina={
                      esperados > 0 ? (
                        <span
                          className={cn(
                            'inline-flex items-center gap-0.5 text-[11px] font-semibold tabular-nums',
                            completo ? 'text-emerald-700' : 'text-amber-700',
                          )}
                        >
                          {completo && <Check size={12} strokeWidth={3} aria-hidden="true" />}
                          {delDia.length}/{esperados}
                        </span>
                      ) : delDia.length > 0 ? (
                        <span className="text-[11px] font-semibold text-ink-muted tabular-nums">{delDia.length}</span>
                      ) : undefined
                    }
                    punto={esperados > 0 ? (completo ? 'bg-emerald-500' : 'bg-amber-500') : undefined}
                  >
                    {incidencias.length > 0 && (
                      <div className="flex flex-wrap items-center gap-1">
                        {incidencias.map((x) => (
                          <span key={x.estado} title={etiquetaEstado(x.estado)}>
                            <span
                              className={cn(
                                'hidden items-center rounded-full px-1.5 text-[10px] font-bold tabular-nums ring-1 sm:inline-flex',
                                COLOR_ESTADO[x.estado].chip,
                              )}
                            >
                              {x.n} {ABREVIA[x.estado]}
                            </span>
                            <span className={cn('inline-block size-1.5 rounded-full sm:hidden', COLOR_ESTADO[x.estado].punto)} />
                          </span>
                        ))}
                      </div>
                    )}
                  </DiaCalendario>
                )
              }),
            )}
          </div>

          <div className="mt-4 flex flex-wrap items-center justify-between gap-x-6 gap-y-2 border-t border-line pt-3">
            <ul className="flex flex-wrap items-center gap-x-4 gap-y-1.5 text-xs text-ink-muted">
              {empleadoElegido ? (
                <>
                  {ESTADOS.map((e) => (
                    <li key={e.value} className="flex items-center gap-1.5">
                      <span className={cn('size-2 rounded-full', COLOR_ESTADO[e.value].punto)} />
                      {e.label}
                    </li>
                  ))}
                  <li className="flex items-center gap-1.5">
                    <span className="size-2.5 rounded-sm border border-dashed border-amber-400" />
                    Sin marcar
                  </li>
                </>
              ) : (
                <>
                  <li className="flex items-center gap-1.5">
                    <Check size={12} strokeWidth={3} className="text-emerald-600" />
                    Lista completa
                  </li>
                  <li className="flex items-center gap-1.5">
                    <span className="size-2 rounded-full bg-amber-500" />
                    Falta pasar lista
                  </li>
                  {INCIDENCIAS.map((estado) => (
                    <li key={estado} className="flex items-center gap-1.5">
                      <span className={cn('size-2 rounded-full', COLOR_ESTADO[estado].punto)} />
                      {ABREVIA[estado]} {etiquetaEstado(estado).toLowerCase()}
                    </li>
                  ))}
                </>
              )}
              <li className="flex items-center gap-1.5">
                <Flag size={12} className="text-violet-600" />
                Feriado
              </li>
            </ul>
            <p className="text-xs text-ink-soft">
              {empleadoElegido ? 'Toca un día para marcar o corregir.' : 'Toca un día para pasar lista.'}
            </p>
          </div>
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
                options={empleados
                  .filter((e) => trabajaba(e, form.fecha))
                  .map((e) => ({ value: e.id, label: e.nombreCompleto, detalle: detalleEmpleado(e) }))}
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

      {/* El mes que muestra el calendario y, si hay uno elegido, solo ese empleado. */}
      {reporte && (
        <VisorReportePdf
          ruta={asistenciaApi.rutaPdf(desde, hasta, Number(empleadoFiltro) || undefined)}
          titulo={`Asistencia de ${MESES[cursor.getMonth()].toLowerCase()} ${cursor.getFullYear()}`}
          nombreArchivo={`asistencia-${desde.slice(0, 7)}.pdf`}
          onCerrar={() => setReporte(false)}
        />
      )}

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
