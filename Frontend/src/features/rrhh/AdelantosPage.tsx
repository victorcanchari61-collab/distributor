import { useCallback, useEffect, useState } from 'react'
import type { ReactNode } from 'react'
import { Ban, CalendarClock, Eye, HandCoins, Plus, Users, Wallet } from 'lucide-react'
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
import { fechaCorta, fechaHora, hoyLocal } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { adelantoApi, comoSeDescuenta, lunesDe, sumarDias } from './adelantoApi'
import type { AdelantoFila, AdelantoResponse, EmpleadoAdelanto, EstadoAdelanto, ResumenAdelantos } from './adelantoApi'
import type { CuentaPagoOpcion } from './planillaApi'
import { tipoDeCuenta } from '../finanzas/cuentaFinancieraApi'

const soles = (n: number) => `S/ ${n.toFixed(2)}`
const numero = (texto: string) => (texto.trim() ? Number(texto.replace(',', '.')) : NaN)
const redondear = (n: number) => Math.round(n * 100) / 100

/** "del 06/10 al 12/10". */
const semana = (lunes: string) => `del ${fechaCorta(lunes).slice(0, 5)} al ${fechaCorta(sumarDias(lunes, 6)).slice(0, 5)}`

const ESTADOS: Record<EstadoAdelanto, { label: string; tono: BadgeTone }> = {
  PENDIENTE: { label: 'Por descontar', tono: 'warning' },
  DESCONTADO: { label: 'Descontado', tono: 'success' },
  ANULADO: { label: 'Anulado', tono: 'neutral' },
}

/**
 * Plata que se le da a un trabajador a cuenta de su sueldo. Sale de una cuenta al dársela y se le
 * descuenta en la planilla: todo de una vez o en partes, desde la semana que se elija. En cada
 * planilla se puede ajustar cuánto se le descuenta esa semana; lo que no, queda para la siguiente.
 */
export function AdelantosPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()
  const [adelantos, setAdelantos] = useState<AdelantoFila[]>([])
  const [resumen, setResumen] = useState<ResumenAdelantos | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [nuevoAbierto, setNuevoAbierto] = useState(false)
  const [viendoId, setViendoId] = useState<number | null>(null)
  const [cambiandoPlan, setCambiandoPlan] = useState<AdelantoFila | null>(null)

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [lista, r] = await Promise.all([adelantoApi.listar(), adelantoApi.resumen()])
      setAdelantos(lista)
      setResumen(r)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los adelantos.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  // Al pagar o anular una planilla cambia lo descontado.
  useRealtime(['adelantos', 'planillas'], cargar)

  const anular = (a: AdelantoFila) =>
    confirmar({
      titulo: `Anular el adelanto de ${a.empleado}`,
      mensaje: `Los ${soles(a.monto)} vuelven a ${a.cuentaFinanciera ?? 'la cuenta de donde salieron'}, como si no se le hubieran dado. No se puede deshacer.`,
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        try {
          await adelantoApi.anular(a.id)
          await cargar()
          toast.exito('Adelanto anulado')
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos anular el adelanto.')
        }
      },
    })

  const empleados = [...new Set(adelantos.map((a) => a.empleado))].sort((x, y) => x.localeCompare(y, 'es'))

  const columns: DataTableColumn<AdelantoFila>[] = [
    { key: 'fecha', label: 'Fecha', filterable: false, render: (row) => fechaCorta(row.fecha) },
    {
      key: 'empleado',
      label: 'Empleado',
      filterType: 'select',
      filterOptions: empleados.map((e) => ({ value: e, label: e })),
    },
    { key: 'monto', label: 'Monto', align: 'right', filterable: false, render: (row) => soles(row.monto) },
    {
      key: 'descontado',
      label: 'Descontado',
      align: 'right',
      filterable: false,
      render: (row) => (row.descontado > 0 ? soles(row.descontado) : '—'),
    },
    {
      key: 'saldo',
      label: 'Falta',
      align: 'right',
      filterable: false,
      render: (row) => <span className="font-semibold">{row.saldo > 0 ? soles(row.saldo) : '—'}</span>,
    },
    {
      key: 'cuotaSemanal',
      label: 'Cómo se descuenta',
      filterable: false,
      render: (row) => (
        <div>
          <p>{comoSeDescuenta(row)}</p>
          <p className="text-xs text-ink-soft">Desde la semana {semana(row.descontarDesde)}</p>
        </div>
      ),
    },
    { key: 'cuentaFinanciera', label: 'Salió de', filterable: false },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: Object.entries(ESTADOS).map(([value, e]) => ({ value, label: e.label })),
      value: (row) => row.estado,
      render: (row) => <Badge tone={ESTADOS[row.estado].tono}>{ESTADOS[row.estado].label}</Badge>,
    },
  ]

  return (
    <ListPage
      icon={<HandCoins size={20} />}
      title="Adelantos"
      description="Plata a cuenta del sueldo. Sale de una cuenta al darla y se descuenta en la planilla: todo de una vez o en partes, desde la semana que elijas."
      actions={
        puede('rrhh.adelantos', 'crear') ? (
          <Button size="sm" onClick={() => setNuevoAbierto(true)} iconRight={<Plus size={15} />}>
            Nuevo adelanto
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Por descontar" value={soles(resumen?.saldoPendiente ?? 0)} icon={<HandCoins size={18} />} tono="warning" />
          <StatCard label="Adelantos vigentes" value={String(resumen?.vigentes ?? 0)} icon={<CalendarClock size={18} />} tono="sys" />
          <StatCard label="Trabajadores que deben" value={String(resumen?.empleados ?? 0)} icon={<Users size={18} />} tono="neutral" />
          <StatCard label="Entregado este mes" value={soles(resumen?.entregadoMes ?? 0)} icon={<Wallet size={18} />} tono="danger" />
        </>
      }
      columns={columns}
      rows={adelantos}
      cardIcon={HandCoins}
      searchPlaceholder="Buscar por empleado..."
      empty={cargando ? 'Cargando adelantos...' : 'Todavía no se dio ningún adelanto.'}
      rowActions={(row) => (
        <>
          <RowAction label={`Ver el adelanto de ${row.empleado}`} tone="view" onClick={() => setViendoId(row.id)}>
            <Eye size={15} />
          </RowAction>
          {row.estado === 'PENDIENTE' && puede('rrhh.adelantos', 'editar') && (
            <RowAction label={`Cambiar cómo se le descuenta a ${row.empleado}`} onClick={() => setCambiandoPlan(row)}>
              <CalendarClock size={15} />
            </RowAction>
          )}
          {row.estado !== 'ANULADO' && puede('rrhh.adelantos', 'anular') && (
            <RowAction
              label={`Anular el adelanto de ${row.empleado}`}
              tone="danger"
              disabled={row.descontado > 0}
              disabledReason="Ya se le descontó algo en planilla"
              onClick={() => anular(row)}
            >
              <Ban size={15} />
            </RowAction>
          )}
        </>
      )}
    >
      {nuevoAbierto && (
        <NuevoAdelantoModal
          onClose={() => setNuevoAbierto(false)}
          onGuardado={async () => {
            setNuevoAbierto(false)
            await cargar()
            toast.exito('Adelanto registrado')
          }}
        />
      )}
      {cambiandoPlan && (
        <PlanModal
          adelanto={cambiandoPlan}
          onClose={() => setCambiandoPlan(null)}
          onGuardado={async () => {
            setCambiandoPlan(null)
            await cargar()
            toast.exito('Plan actualizado')
          }}
        />
      )}
      {viendoId !== null && <DetalleModal id={viendoId} onClose={() => setViendoId(null)} />}
      {dialogo}
    </ListPage>
  )
}

type Cuando = 'esta' | 'proxima' | 'elegir'
type Como = 'todo' | 'partes'

/**
 * Desde cuándo y cómo se descuenta. Lo usan el alta y el cambio de plan: la misma pregunta con
 * las mismas palabras.
 */
function CamposPlan({
  fecha,
  saldo,
  cuando,
  setCuando,
  semanaElegida,
  setSemanaElegida,
  como,
  setComo,
  cuota,
  setCuota,
}: {
  /** El día en que se le dio: "esta semana" es la de esa fecha. */
  fecha: string
  /** Lo que hay que descontar, para decir en cuántas semanas. */
  saldo: number
  cuando: Cuando
  setCuando: (c: Cuando) => void
  semanaElegida: string
  setSemanaElegida: (s: string) => void
  como: Como
  setComo: (c: Como) => void
  cuota: string
  setCuota: (c: string) => void
}) {
  const valorCuota = numero(cuota)
  const semanas = Number.isFinite(valorCuota) && valorCuota > 0 && saldo > 0 ? Math.ceil(saldo / valorCuota) : 0
  const lunes = lunesDe(fecha)

  return (
    <>
      <Desplegable
        label="Se descuenta desde"
        value={cuando}
        onChange={(v) => setCuando(v as Cuando)}
        options={[
          { value: 'esta', label: 'Esta semana', detalle: semana(lunes) },
          { value: 'proxima', label: 'La próxima semana', detalle: semana(sumarDias(lunes, 7)) },
          { value: 'elegir', label: 'Elegir la semana' },
        ]}
      />
      {cuando === 'elegir' && (
        <Input
          label="Cualquier día de esa semana"
          type="date"
          min={lunes}
          value={semanaElegida}
          onChange={(e) => setSemanaElegida(e.target.value)}
          hint={semanaElegida ? `Semana ${semana(lunesDe(semanaElegida))}` : undefined}
        />
      )}
      <Desplegable
        label="Cómo"
        value={como}
        onChange={(v) => setComo(v as Como)}
        options={[
          { value: 'todo', label: 'Todo de una vez', detalle: 'En una sola planilla' },
          { value: 'partes', label: 'En partes', detalle: 'Un monto fijo por semana' },
        ]}
      />
      {como === 'partes' && (
        <Input
          label="Por semana"
          type="number"
          step="0.01"
          placeholder="0.00"
          value={cuota}
          onChange={(e) => setCuota(e.target.value)}
          hint={semanas > 0 ? `En ${semanas} ${semanas === 1 ? 'semana' : 'semanas'}` : undefined}
        />
      )}
      <p className="-mt-2 text-xs text-ink-soft">
        En cada planilla puedes ajustar cuánto se le descuenta esa semana; lo que no se descuente queda para la siguiente.
      </p>
    </>
  )
}

/** La semana elegida como fecha a mandar, o un error para mostrar. */
function semanaDelPlan(fecha: string, cuando: Cuando, elegida: string): string | { error: string } {
  if (cuando === 'esta') return lunesDe(fecha)
  if (cuando === 'proxima') return sumarDias(lunesDe(fecha), 7)
  if (!elegida) return { error: 'Elige desde qué semana se descuenta.' }
  return lunesDe(elegida)
}

/** La cuota por semana: null es todo de una vez. */
function cuotaDelPlan(como: Como, cuota: string): number | null | { error: string } {
  if (como === 'todo') return null
  const valor = numero(cuota)
  if (!Number.isFinite(valor) || valor <= 0) return { error: 'Indica cuánto se le descuenta por semana.' }
  return redondear(valor)
}

function NuevoAdelantoModal({ onClose, onGuardado }: { onClose: () => void; onGuardado: () => void | Promise<void> }) {
  const [empleados, setEmpleados] = useState<EmpleadoAdelanto[]>([])
  const [cuentas, setCuentas] = useState<CuentaPagoOpcion[]>([])
  const [empleadoId, setEmpleadoId] = useState(0)
  const [monto, setMonto] = useState('')
  const [fecha, setFecha] = useState(hoyLocal())
  const [cuentaId, setCuentaId] = useState(0)
  const [cuando, setCuando] = useState<Cuando>('esta')
  const [semanaElegida, setSemanaElegida] = useState('')
  const [como, setComo] = useState<Como>('todo')
  const [cuota, setCuota] = useState('')
  const [observacion, setObservacion] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    Promise.all([adelantoApi.empleados(), adelantoApi.cuentas()])
      .then(([e, c]) => {
        setEmpleados(e)
        setCuentas(c)
      })
      .catch((e) => setError(e instanceof ApiError ? e.message : 'No pudimos cargar los empleados y las cuentas.'))
  }, [])

  const elegido = empleados.find((e) => e.id === empleadoId)
  const valor = numero(monto)

  const guardar = async () => {
    if (!empleadoId) return setError('Elige a quién se le da el adelanto.')
    if (!Number.isFinite(valor) || valor <= 0) return setError('Ingresa el monto.')
    if (!cuentaId) return setError('Elige de qué cuenta sale la plata.')
    const desde = semanaDelPlan(fecha, cuando, semanaElegida)
    if (typeof desde !== 'string') return setError(desde.error)
    const cuotaSemanal = cuotaDelPlan(como, cuota)
    if (cuotaSemanal !== null && typeof cuotaSemanal !== 'number') return setError(cuotaSemanal.error)

    setGuardando(true)
    setError('')
    try {
      await adelantoApi.crear({
        empleadoId,
        monto: redondear(valor),
        fecha,
        cuentaFinancieraId: cuentaId,
        descontarDesde: desde,
        cuotaSemanal,
        observacion: observacion.trim() || null,
      })
      await onGuardado()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos registrar el adelanto.')
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal
      open
      size="sm"
      title="Nuevo adelanto"
      description="La plata sale ahora de la cuenta que elijas y se le descuenta en la planilla."
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            Registrar
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        {error && <Alert>{error}</Alert>}
        <Desplegable
          label="Empleado"
          value={empleadoId}
          onChange={(v) => setEmpleadoId(Number(v))}
          placeholder="Elige a quién"
          options={empleados.map((e) => ({
            value: e.id,
            label: e.nombreCompleto,
            detalle: [
              e.sueldoSemanal ? `Sueldo ${soles(e.sueldoSemanal)}` : 'Sin sueldo semanal',
              e.saldoAdelantos > 0 ? `debe ${soles(e.saldoAdelantos)}` : null,
            ]
              .filter(Boolean)
              .join(' · '),
          }))}
        />
        {elegido && !elegido.sueldoSemanal && (
          <Alert tone="warning">No tiene sueldo semanal: no entra en la planilla y no se le podrá descontar.</Alert>
        )}
        <div className="grid grid-cols-2 gap-3">
          <Input label="Monto" type="number" step="0.01" placeholder="0.00" value={monto} onChange={(e) => setMonto(e.target.value)} />
          <Input label="Fecha" type="date" max={hoyLocal()} value={fecha} onChange={(e) => e.target.value && setFecha(e.target.value)} />
        </div>
        <Desplegable
          label="Sale de"
          value={cuentaId}
          onChange={(v) => setCuentaId(Number(v))}
          placeholder="Elige la caja o el banco"
          options={cuentas.map((c) => ({ value: c.id, label: c.nombre, detalle: tipoDeCuenta(c) }))}
        />
        <CamposPlan
          fecha={fecha}
          saldo={Number.isFinite(valor) ? valor : 0}
          cuando={cuando}
          setCuando={setCuando}
          semanaElegida={semanaElegida}
          setSemanaElegida={setSemanaElegida}
          como={como}
          setComo={setComo}
          cuota={cuota}
          setCuota={setCuota}
        />
        <Input label="Observación" optional maxLength={250} value={observacion} onChange={(e) => setObservacion(e.target.value)} />
      </div>
    </Modal>
  )
}

function PlanModal({
  adelanto,
  onClose,
  onGuardado,
}: {
  adelanto: AdelantoFila
  onClose: () => void
  onGuardado: () => void | Promise<void>
}) {
  // Arranca en lo que tiene: su semana y su cuota.
  const [cuando, setCuando] = useState<Cuando>('elegir')
  const [semanaElegida, setSemanaElegida] = useState(adelanto.descontarDesde.slice(0, 10))
  const [como, setComo] = useState<Como>(adelanto.cuotaSemanal ? 'partes' : 'todo')
  const [cuota, setCuota] = useState(adelanto.cuotaSemanal ? String(adelanto.cuotaSemanal) : '')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  const guardar = async () => {
    const desde = semanaDelPlan(adelanto.fecha, cuando, semanaElegida)
    if (typeof desde !== 'string') return setError(desde.error)
    const cuotaSemanal = cuotaDelPlan(como, cuota)
    if (cuotaSemanal !== null && typeof cuotaSemanal !== 'number') return setError(cuotaSemanal.error)

    setGuardando(true)
    setError('')
    try {
      await adelantoApi.cambiarPlan(adelanto.id, { descontarDesde: desde, cuotaSemanal })
      await onGuardado()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el plan.')
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal
      open
      size="sm"
      title={`Cómo se le descuenta a ${adelanto.empleado}`}
      description={`Falta descontar ${soles(adelanto.saldo)} de ${soles(adelanto.monto)}.`}
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
        <CamposPlan
          fecha={adelanto.fecha}
          saldo={adelanto.saldo}
          cuando={cuando}
          setCuando={setCuando}
          semanaElegida={semanaElegida}
          setSemanaElegida={setSemanaElegida}
          como={como}
          setComo={setComo}
          cuota={cuota}
          setCuota={setCuota}
        />
      </div>
    </Modal>
  )
}

function DetalleModal({ id, onClose }: { id: number; onClose: () => void }) {
  const [adelanto, setAdelanto] = useState<AdelantoResponse | null>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    adelantoApi
      .get(id)
      .then(setAdelanto)
      .catch((e) => setError(e instanceof ApiError ? e.message : 'No pudimos cargar el adelanto.'))
  }, [id])

  const a = adelanto
  return (
    <Modal open size="md" title={a ? `Adelanto de ${a.empleado}` : 'Adelanto'} onClose={onClose}>
      {error && <Alert>{error}</Alert>}
      {!a && !error && <p className="text-sm text-ink-soft">Cargando...</p>}
      {a && (
        <div className="flex flex-col gap-4">
          <div className="grid grid-cols-3 gap-3">
            <StatCard label="Monto" value={soles(a.monto)} icon={<HandCoins size={18} />} tono="sys" />
            <StatCard label="Descontado" value={soles(a.descontado)} icon={<Wallet size={18} />} tono="success" />
            <StatCard label="Falta" value={soles(a.saldo)} icon={<CalendarClock size={18} />} tono="warning" />
          </div>
          <dl className="grid grid-cols-2 gap-x-4 gap-y-2 text-sm">
            <Dato etiqueta="Estado" valor={<Badge tone={ESTADOS[a.estado].tono}>{ESTADOS[a.estado].label}</Badge>} />
            <Dato etiqueta="Se le dio el" valor={fechaCorta(a.fecha)} />
            <Dato etiqueta="Cómo se descuenta" valor={comoSeDescuenta(a)} />
            <Dato etiqueta="Desde la semana" valor={semana(a.descontarDesde)} />
            <Dato etiqueta="Salió de" valor={a.cuentaFinanciera ?? '—'} />
            <Dato etiqueta="Registró" valor={a.usuario ? `${a.usuario} · ${fechaHora(a.fechaCreacion)}` : fechaHora(a.fechaCreacion)} />
            {a.observacion && <Dato etiqueta="Observación" valor={a.observacion} />}
          </dl>
          <div>
            <p className="mb-2 text-sm font-semibold text-ink">Descontado en planilla</p>
            {a.descuentos.length === 0 ? (
              <p className="text-sm text-ink-soft">Todavía no se le descontó nada.</p>
            ) : (
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-line text-left text-xs text-ink-soft">
                    <th className="py-1.5 font-medium">Semana</th>
                    <th className="py-1.5 font-medium">Pagada el</th>
                    <th className="py-1.5 text-right font-medium">Monto</th>
                  </tr>
                </thead>
                <tbody>
                  {a.descuentos.map((d) => (
                    <tr key={d.planillaId} className="border-b border-line/60">
                      <td className="py-1.5">{semana(d.desde)}</td>
                      <td className="py-1.5">{d.fechaPago ? fechaHora(d.fechaPago) : '—'}</td>
                      <td className="py-1.5 text-right">{soles(d.monto)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </div>
      )}
    </Modal>
  )
}

function Dato({ etiqueta, valor }: { etiqueta: string; valor: ReactNode }) {
  return (
    <div>
      <dt className="text-xs text-ink-soft">{etiqueta}</dt>
      <dd className="text-ink">{valor}</dd>
    </div>
  )
}
