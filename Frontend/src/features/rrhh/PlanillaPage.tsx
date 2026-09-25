import { useCallback, useEffect, useState } from 'react'
import { Ban, Calculator, Eye, HandCoins, History, Pencil, RefreshCw, Wallet } from 'lucide-react'
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
import type { BadgeTone, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta, fechaHora, hoyLocal } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { planillaApi } from './planillaApi'
import type {
  CuentaPagoOpcion,
  EstadoPlanilla,
  PlanillaDetalleResponse,
  PlanillaResponse,
  PlanillaResumenResponse,
} from './planillaApi'

const soles = (n: number) => `S/ ${n.toFixed(2)}`
const menos = (n: number) => (n > 0 ? `-${soles(n)}` : '—')
const mas = (n: number) => (n > 0 ? `+${soles(n)}` : '—')

const ESTADOS: Record<EstadoPlanilla, { label: string; tono: BadgeTone }> = {
  BORRADOR: { label: 'Borrador', tono: 'warning' },
  PAGADA: { label: 'Pagada', tono: 'success' },
  ANULADA: { label: 'Anulada', tono: 'neutral' },
}

type Pestana = 'semana' | 'historial'

/**
 * El pago semanal: sueldo menos las faltas y permisos, más los feriados
 * trabajados, con bonos y descuentos a mano, y el descuento de los faltantes
 * de caja pendientes del trabajador.
 */
export function PlanillaPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()
  const [pestana, setPestana] = useState<Pestana>('semana')
  const [fecha, setFecha] = useState(hoyLocal())
  const [planilla, setPlanilla] = useState<PlanillaResponse | null>(null)
  const [historial, setHistorial] = useState<PlanillaResumenResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [trabajando, setTrabajando] = useState(false)
  const [error, setError] = useState('')
  const [ajustando, setAjustando] = useState<PlanillaDetalleResponse | null>(null)
  const [pagarAbierto, setPagarAbierto] = useState(false)

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [p, h] = await Promise.all([planillaApi.semana(fecha), planillaApi.historial()])
      setPlanilla(p)
      setHistorial(h)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar la planilla.')
    } finally {
      setCargando(false)
    }
  }, [fecha])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['planillas', 'empleados'], cargar)

  const generar = async () => {
    setTrabajando(true)
    try {
      setPlanilla(await planillaApi.generar(fecha))
      toast.exito(planilla ? 'Planilla recalculada' : 'Planilla armada')
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos armar la planilla.')
    } finally {
      setTrabajando(false)
    }
  }

  const anular = (p: PlanillaResponse) =>
    confirmar({
      titulo: 'Anular la planilla',
      mensaje:
        p.estado === 'PAGADA'
          ? 'Se revierte el pago y los faltantes descontados vuelven a quedar pendientes. No se puede deshacer.'
          : 'Se descarta este borrador.',
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        try {
          await planillaApi.anular(p.id)
          await cargar()
          toast.exito('Planilla anulada')
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos anular la planilla.')
        }
      },
    })

  const cabecera = (
    <Tabs
      className="mb-5"
      active={pestana}
      onChange={(id) => setPestana(id as Pestana)}
      items={[
        { id: 'semana', label: 'Semana', icon: <Calculator size={15} /> },
        { id: 'historial', label: 'Historial', icon: <History size={15} />, badge: historial.length },
      ]}
    />
  )

  if (pestana === 'historial') {
    const columnasHistorial: DataTableColumn<PlanillaResumenResponse>[] = [
      {
        key: 'desde',
        label: 'Semana',
        filterable: false,
        render: (row) => `${fechaCorta(row.desde)} al ${fechaCorta(row.hasta)}`,
      },
      {
        key: 'estado',
        label: 'Estado',
        filterType: 'select',
        filterOptions: Object.entries(ESTADOS).map(([value, e]) => ({ value, label: e.label })),
        value: (row) => row.estado,
        render: (row) => <Badge tone={ESTADOS[row.estado].tono}>{ESTADOS[row.estado].label}</Badge>,
      },
      { key: 'empleados', label: 'Empleados', align: 'right', filterable: false },
      { key: 'totalNeto', label: 'Neto', align: 'right', filterable: false, render: (row) => soles(row.totalNeto) },
      { key: 'fechaPago', label: 'Pagada el', filterable: false, render: (row) => (row.fechaPago ? fechaHora(row.fechaPago) : '—') },
    ]

    return (
      <>
        {cabecera}
        <ListPage
          icon={<History size={20} />}
          title="Historial de planillas"
          description="Todas las semanas armadas, pagadas o anuladas."
          columns={columnasHistorial}
          rows={historial}
          cardIcon={History}
          searchPlaceholder="Buscar..."
          empty={cargando ? 'Cargando...' : 'Todavía no se armó ninguna planilla.'}
          rowActions={(row) => (
            <RowAction
              label="Ver semana"
              tone="view"
              onClick={() => {
                setFecha(row.desde.slice(0, 10))
                setPestana('semana')
              }}
            >
              <Eye size={15} />
            </RowAction>
          )}
        />
      </>
    )
  }

  const borrador = planilla?.estado === 'BORRADOR'

  const columns: DataTableColumn<PlanillaDetalleResponse>[] = [
    {
      key: 'empleado',
      label: 'Empleado',
      filterable: false,
      render: (row) => (
        <div>
          <p className="font-medium text-ink">{row.empleado}</p>
          {row.cargo && <p className="text-xs text-ink-soft">{row.cargo}</p>}
        </div>
      ),
    },
    { key: 'sueldoSemanal', label: 'Sueldo', align: 'right', filterable: false, render: (row) => soles(row.sueldoSemanal) },
    {
      key: 'descuentoInasistencias',
      label: 'Faltas y permisos',
      align: 'right',
      filterable: false,
      render: (row) => (row.diasNoPagados > 0 ? `${menos(row.descuentoInasistencias)} (${row.diasNoPagados} d)` : '—'),
    },
    { key: 'extraFeriados', label: 'Feriados', align: 'right', filterable: false, render: (row) => mas(row.extraFeriados) },
    { key: 'bonos', label: 'Bonos', align: 'right', filterable: false, render: (row) => mas(row.bonos) },
    {
      key: 'otrosDescuentos',
      label: 'Otros desc.',
      align: 'right',
      filterable: false,
      render: (row) => (
        <span title={row.notaAjuste ?? undefined}>{menos(row.otrosDescuentos)}</span>
      ),
    },
    {
      key: 'descuentoFaltantes',
      label: 'Faltantes de caja',
      align: 'right',
      filterable: false,
      render: (row) => (row.descuentoFaltantes > 0 ? <span className="text-red-600">{menos(row.descuentoFaltantes)}</span> : '—'),
    },
    {
      key: 'neto',
      label: 'A pagar',
      align: 'right',
      filterable: false,
      render: (row) => <span className="font-semibold">{soles(row.neto)}</span>,
    },
  ]

  return (
    <>
      {cabecera}
      <ListPage
        icon={<Wallet size={20} />}
        title="Planilla semanal"
        description="Sueldo semanal menos faltas y permisos (un día = sueldo ÷ 6), más feriados trabajados (se pagan doble), bonos, descuentos y faltantes de caja."
        actions={
          <div className="flex flex-wrap items-end gap-2">
            <Input
              size="sm"
              type="date"
              aria-label="Semana"
              value={fecha}
              onChange={(e) => e.target.value && setFecha(e.target.value)}
              className="w-40"
            />
            {(!planilla || borrador) && puede('rrhh.planilla', 'crear') && (
              <Button size="sm" variant="secondary" loading={trabajando} onClick={() => void generar()} iconRight={<RefreshCw size={15} />}>
                {planilla ? 'Recalcular' : 'Armar planilla'}
              </Button>
            )}
            {borrador && puede('rrhh.planilla', 'crear') && (
              <Button size="sm" onClick={() => setPagarAbierto(true)} iconRight={<HandCoins size={15} />}>
                Pagar
              </Button>
            )}
            {planilla && puede('rrhh.planilla', 'anular') && (
              <Button size="sm" variant="secondary" onClick={() => anular(planilla)} iconRight={<Ban size={15} />}>
                Anular
              </Button>
            )}
          </div>
        }
        alert={
          error ? (
            <Alert>{error}</Alert>
          ) : planilla ? (
            <Alert tone="info">
              Semana del {fechaCorta(planilla.desde)} al {fechaCorta(planilla.hasta)} ·{' '}
              <strong>{ESTADOS[planilla.estado].label}</strong>
              {planilla.estado === 'PAGADA' && planilla.cuentaFinanciera
                ? ` desde ${planilla.cuentaFinanciera}${planilla.fechaPago ? ` el ${fechaHora(planilla.fechaPago)}` : ''}`
                : ''}
            </Alert>
          ) : undefined
        }
        stats={
          <>
            <StatCard label="Costo de planilla" value={soles(planilla?.totalCostoLaboral ?? 0)} icon={<Calculator size={18} />} tono="sys" />
            <StatCard label="Faltantes descontados" value={soles(planilla?.totalFaltantes ?? 0)} icon={<Ban size={18} />} tono="danger" />
            <StatCard label="Neto a pagar" value={soles(planilla?.totalNeto ?? 0)} icon={<Wallet size={18} />} tono="success" />
          </>
        }
        columns={columns}
        rows={planilla?.detalle ?? []}
        cardIcon={Wallet}
        searchPlaceholder="Buscar empleado..."
        empty={
          cargando
            ? 'Cargando planilla...'
            : planilla
              ? 'Ningún empleado activo tiene sueldo semanal.'
              : 'Esta semana todavía no tiene planilla: usa "Armar planilla".'
        }
        rowActions={(row) =>
          borrador && puede('rrhh.planilla', 'editar') ? (
            <RowAction label={`Ajustar ${row.empleado}`} onClick={() => setAjustando(row)}>
              <Pencil size={15} />
            </RowAction>
          ) : null
        }
      >
        {ajustando && (
          <AjusteModal
            detalle={ajustando}
            onClose={() => setAjustando(null)}
            onGuardado={(p) => {
              setAjustando(null)
              setPlanilla(p)
              toast.exito('Ajuste guardado')
            }}
          />
        )}
        {pagarAbierto && planilla && (
          <PagarModal
            planilla={planilla}
            onClose={() => setPagarAbierto(false)}
            onPagado={async () => {
              setPagarAbierto(false)
              await cargar()
              toast.exito('Planilla pagada')
            }}
          />
        )}
        {dialogo}
      </ListPage>
    </>
  )
}

function AjusteModal({
  detalle,
  onClose,
  onGuardado,
}: {
  detalle: PlanillaDetalleResponse
  onClose: () => void
  onGuardado: (p: PlanillaResponse) => void
}) {
  const [bonos, setBonos] = useState(detalle.bonos ? String(detalle.bonos) : '')
  const [descuentos, setDescuentos] = useState(detalle.otrosDescuentos ? String(detalle.otrosDescuentos) : '')
  const [nota, setNota] = useState(detalle.notaAjuste ?? '')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  const numero = (texto: string) => (texto.trim() ? Number(texto.replace(',', '.')) : 0)

  const guardar = async () => {
    const b = numero(bonos)
    const d = numero(descuentos)
    if (!Number.isFinite(b) || b < 0 || !Number.isFinite(d) || d < 0) return setError('Los montos no pueden ser negativos.')

    setGuardando(true)
    setError('')
    try {
      onGuardado(
        await planillaApi.ajustar(detalle.id, {
          bonos: Math.round(b * 100) / 100,
          otrosDescuentos: Math.round(d * 100) / 100,
          nota: nota.trim() || null,
        }),
      )
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos guardar el ajuste.')
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal
      open
      size="sm"
      title={`Ajustar a ${detalle.empleado}`}
      description="Un bono suma a lo que cobra; un descuento (adelanto, otro) resta."
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            Guardar
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        {error && <Alert>{error}</Alert>}
        <Input label="Bono" type="number" step="0.01" optional placeholder="0.00" value={bonos} onChange={(e) => setBonos(e.target.value)} />
        <Input
          label="Otros descuentos"
          type="number"
          step="0.01"
          optional
          placeholder="0.00"
          value={descuentos}
          onChange={(e) => setDescuentos(e.target.value)}
        />
        <Input label="Nota" optional placeholder="Adelanto del jueves, horas extra..." value={nota} onChange={(e) => setNota(e.target.value)} />
      </div>
    </Modal>
  )
}

const NATURALEZA: Record<string, string> = { CAJA: 'Caja', BANCO: 'Banco', PASARELA: 'Pasarela' }

function PagarModal({
  planilla,
  onClose,
  onPagado,
}: {
  planilla: PlanillaResponse
  onClose: () => void
  onPagado: () => void | Promise<void>
}) {
  const [cuentas, setCuentas] = useState<CuentaPagoOpcion[]>([])
  const [cuentaId, setCuentaId] = useState(0)
  const [pagando, setPagando] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    planillaApi
      .cuentas()
      .then(setCuentas)
      .catch((e) => setError(e instanceof ApiError ? e.message : 'No pudimos cargar las cuentas.'))
  }, [])

  const pagar = async () => {
    if (!cuentaId) return setError('Elige de qué cuenta sale el pago.')
    setPagando(true)
    setError('')
    try {
      await planillaApi.pagar(planilla.id, cuentaId)
      await onPagado()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos pagar la planilla.')
    } finally {
      setPagando(false)
    }
  }

  return (
    <Modal
      open
      size="sm"
      title="Pagar planilla"
      description={`Salen ${soles(planilla.totalNeto)} de la cuenta que elijas. Los faltantes descontados quedan saldados.`}
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={pagando} onClick={() => void pagar()}>
            Pagar {soles(planilla.totalNeto)}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        {error && <Alert>{error}</Alert>}
        <Desplegable
          label="Sale de"
          value={cuentaId}
          onChange={(v) => setCuentaId(Number(v))}
          placeholder="Elige la caja o el banco"
          options={cuentas.map((c) => ({ value: c.id, label: c.nombre, detalle: NATURALEZA[c.naturaleza] ?? c.naturaleza }))}
        />
      </div>
    </Modal>
  )
}
