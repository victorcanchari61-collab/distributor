import { useCallback, useEffect, useState } from 'react'
import { Ban, Calculator, Coins, Eye, FileText, HandCoins, History, Pencil, RefreshCw, Wallet } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Checkbox,
  Desplegable,
  Input,
  ListPage,
  Modal,
  RowAction,
  StatCard,
  Tabs,
  useConfirmacion,
  useToast,
  VisorReportePdf,
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
import { tipoDeCuenta } from '../finanzas/cuentaFinancieraApi'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

/** "mar 07/10": el día de la semana ayuda a ubicar cuál falta. */
const diaCorto = (fecha: string) => {
  const [a, m, d] = fecha.slice(0, 10).split('-').map(Number)
  const dia = new Date(a, m - 1, d).toLocaleDateString('es-PE', { weekday: 'short' }).replace('.', '')
  return `${dia} ${String(d).padStart(2, '0')}/${String(m).padStart(2, '0')}`
}
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
  // Las boletas en PDF: de todos, o de un empleado.
  const [boletas, setBoletas] = useState<{ ruta: string; titulo: string; nombre: string } | null>(null)

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

  // La asistencia y los feriados recalculan el borrador en el servidor, que avisa por 'planillas'.
  useRealtime(['planillas', 'empleados', 'asistencia', 'feriados'], cargar)

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
  // Días de la semana en que a alguien le falta su marca: se pagarían como trabajados.
  const sinMarcar = borrador ? (planilla?.fechasSinMarcar ?? []) : []

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
      render: (row) => (
        <div>
          <p>{row.diasNoPagados > 0 ? `${menos(row.descuentoInasistencias)} (${row.diasNoPagados} d)` : '—'}</p>
          {borrador && row.diasSinMarcar > 0 && (
            <p className="text-xs text-amber-700">
              {row.diasSinMarcar} {row.diasSinMarcar === 1 ? 'día' : 'días'} sin marcar
            </p>
          )}
        </div>
      ),
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
      key: 'descuentoAdelantos',
      label: 'Adelantos',
      align: 'right',
      filterable: false,
      render: (row) => (
        <div>
          <p>{menos(row.descuentoAdelantos)}</p>
          {borrador && row.adelantosSaldo > row.descuentoAdelantos && (
            <p className="text-xs text-ink-soft">Debe {soles(row.adelantosSaldo)}</p>
          )}
          {borrador && row.adelantosManual !== null && <p className="text-xs text-amber-700">Ajustado a mano</p>}
        </div>
      ),
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
            {/* Hasta hoy: una semana que no empezó no tiene asistencia y se pagaría completa. */}
            <Input
              size="sm"
              type="date"
              aria-label="Semana"
              max={hoyLocal()}
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
            {planilla && planilla.detalle.length > 0 && puede('rrhh.planilla', 'exportar') && (
              <Button
                size="sm"
                variant="secondary"
                onClick={() =>
                  setBoletas({
                    ruta: planillaApi.rutaBoletas(planilla.id),
                    titulo: `Boletas del ${fechaCorta(planilla.desde)} al ${fechaCorta(planilla.hasta)}`,
                    nombre: `boletas-${planilla.desde.slice(0, 10)}.pdf`,
                  })
                }
                iconRight={<FileText size={15} />}
              >
                Boletas
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
            <div className="flex flex-col gap-2">
              <Alert tone="info">
                Semana del {fechaCorta(planilla.desde)} al {fechaCorta(planilla.hasta)} ·{' '}
                <strong>{ESTADOS[planilla.estado].label}</strong>
                {planilla.estado === 'PAGADA' && planilla.cuentaFinanciera
                  ? ` desde ${planilla.cuentaFinanciera}${planilla.fechaPago ? ` el ${fechaHora(planilla.fechaPago)}` : ''}`
                  : ''}
              </Alert>
              {sinMarcar.length > 0 && (
                <Alert tone="warning">
                  Falta pasar lista el {sinMarcar.map(diaCorto).join(', ')}. Esos días se pagan como trabajados: márcalos
                  en Asistencia antes de pagar (la planilla se recalcula sola).
                </Alert>
              )}
            </div>
          ) : undefined
        }
        stats={
          <>
            <StatCard label="Costo de planilla" value={soles(planilla?.totalCostoLaboral ?? 0)} icon={<Calculator size={18} />} tono="sys" />
            <StatCard label="Faltantes descontados" value={soles(planilla?.totalFaltantes ?? 0)} icon={<Ban size={18} />} tono="danger" />
            <StatCard label="Adelantos descontados" value={soles(planilla?.totalAdelantos ?? 0)} icon={<Coins size={18} />} tono="warning" />
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
        rowActions={(row) => (
          <>
            {planilla && puede('rrhh.planilla', 'exportar') && (
              <RowAction
                label={`Boleta de ${row.empleado}`}
                tone="neutral"
                onClick={() =>
                  setBoletas({
                    ruta: planillaApi.rutaBoletas(planilla.id, row.empleadoId),
                    titulo: `Boleta de ${row.empleado}`,
                    nombre: `boleta-${planilla.desde.slice(0, 10)}.pdf`,
                  })
                }
              >
                <FileText size={15} />
              </RowAction>
            )}
            {borrador && puede('rrhh.planilla', 'editar') && (
              <RowAction label={`Ajustar ${row.empleado}`} onClick={() => setAjustando(row)}>
                <Pencil size={15} />
              </RowAction>
            )}
          </>
        )}
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
            // Si el servidor la recalculó (cambió la asistencia, un sueldo...), se ven los montos nuevos.
            onRefrescar={cargar}
          />
        )}
        {boletas && (
          <VisorReportePdf
            ruta={boletas.ruta}
            titulo={boletas.titulo}
            nombreArchivo={boletas.nombre}
            onCerrar={() => setBoletas(null)}
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
  // Vacío: lo que le toca según sus adelantos.
  const [adelantos, setAdelantos] = useState(detalle.adelantosManual !== null ? String(detalle.adelantosManual) : '')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  const numero = (texto: string) => (texto.trim() ? Number(texto.replace(',', '.')) : 0)

  const guardar = async () => {
    const b = numero(bonos)
    const d = numero(descuentos)
    if (!Number.isFinite(b) || b < 0 || !Number.isFinite(d) || d < 0) return setError('Los montos no pueden ser negativos.')
    const ad = adelantos.trim() ? numero(adelantos) : null
    if (ad !== null && (!Number.isFinite(ad) || ad < 0)) return setError('El descuento de adelantos no puede ser negativo.')
    if (ad !== null && ad > detalle.adelantosSaldo) return setError(`Solo debe ${soles(detalle.adelantosSaldo)} de adelantos.`)

    setGuardando(true)
    setError('')
    try {
      onGuardado(
        await planillaApi.ajustar(detalle.id, {
          bonos: Math.round(b * 100) / 100,
          otrosDescuentos: Math.round(d * 100) / 100,
          nota: nota.trim() || null,
          adelantos: ad === null ? null : Math.round(ad * 100) / 100,
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
      description="Un bono suma a lo que cobra; otro descuento resta. Los adelantos se dan en RR. HH. → Adelantos."
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
        <Input label="Nota" optional placeholder="Horas extra, uniforme..." value={nota} onChange={(e) => setNota(e.target.value)} />
        {detalle.adelantosSaldo > 0 && (
          <>
            <Input
              label="Adelantos a descontar esta semana"
              type="number"
              step="0.01"
              optional
              placeholder={detalle.adelantosSugerido.toFixed(2)}
              value={adelantos}
              onChange={(e) => setAdelantos(e.target.value)}
            />
            <p className="-mt-2 text-xs text-ink-soft">
              Debe {soles(detalle.adelantosSaldo)}; esta semana le toca {soles(detalle.adelantosSugerido)}. Vacío es lo que le
              toca, 0 es nada. Lo que no se descuente queda para la semana siguiente.
            </p>
          </>
        )}
      </div>
    </Modal>
  )
}


function PagarModal({
  planilla,
  onClose,
  onPagado,
  onRefrescar,
}: {
  planilla: PlanillaResponse
  onClose: () => void
  onPagado: () => void | Promise<void>
  onRefrescar: () => void | Promise<void>
}) {
  const [cuentas, setCuentas] = useState<CuentaPagoOpcion[]>([])
  const [cuentaId, setCuentaId] = useState(0)
  const [pagarIgual, setPagarIgual] = useState(false)
  const [pagando, setPagando] = useState(false)
  const [error, setError] = useState('')
  const sinMarcar = planilla.fechasSinMarcar ?? []

  useEffect(() => {
    planillaApi
      .cuentas()
      .then(setCuentas)
      .catch((e) => setError(e instanceof ApiError ? e.message : 'No pudimos cargar las cuentas.'))
  }, [])

  const pagar = async () => {
    if (!cuentaId) return setError('Elige de qué cuenta sale el pago.')
    if (sinMarcar.length > 0 && !pagarIgual) return setError('Marca la asistencia que falta, o confirma que quieres pagar igual.')
    setPagando(true)
    setError('')
    try {
      await planillaApi.pagar(planilla.id, cuentaId, pagarIgual)
      await onPagado()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos pagar la planilla.')
      await onRefrescar()
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
          <Button size="sm" loading={pagando} disabled={sinMarcar.length > 0 && !pagarIgual} onClick={() => void pagar()}>
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
          options={cuentas.map((c) => ({ value: c.id, label: c.nombre, detalle: tipoDeCuenta(c) }))}
        />
        {sinMarcar.length > 0 && (
          <>
            <Alert tone="warning">
              Falta pasar lista el {sinMarcar.map(diaCorto).join(', ')}. Si pagas ahora, esos días se pagan como
              trabajados.
            </Alert>
            <Checkbox
              label="Pagar igual, sin esas marcas"
              checked={pagarIgual}
              onChange={(e) => setPagarIgual(e.target.checked)}
            />
          </>
        )}
      </div>
    </Modal>
  )
}
