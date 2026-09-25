import { useCallback, useEffect, useState } from 'react'
import { Ban, HandCoins, List, PiggyBank, Plus } from 'lucide-react'
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
import { fechaCorta, hoyLocal } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { financiamientoApi } from './financiamientoApi'
import type { CuentaOpcion, EstadoFinanciamiento, FinanciamientoResponse } from './financiamientoApi'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

const ESTADOS: Record<EstadoFinanciamiento, { label: string; tono: BadgeTone }> = {
  VIGENTE: { label: 'Vigente', tono: 'warning' },
  CANCELADO: { label: 'Pagado', tono: 'success' },
  ANULADO: { label: 'Anulado', tono: 'neutral' },
}

const NATURALEZA: Record<string, string> = { CAJA: 'Caja', BANCO: 'Banco', PASARELA: 'Pasarela' }

const numero = (texto: string) => (texto.trim() ? Number(texto.replace(',', '.')) : NaN)

/**
 * Préstamos que recibe el negocio. La plata entra a una cuenta como
 * movimiento no operativo (no es ganancia) y queda como deuda, que baja con
 * cada pago hasta quedar pagada.
 */
export function PrestamosRecibidosPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()
  const [prestamos, setPrestamos] = useState<FinanciamientoResponse[]>([])
  const [cuentas, setCuentas] = useState<CuentaOpcion[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [nuevoAbierto, setNuevoAbierto] = useState(false)
  const [pagando, setPagando] = useState<FinanciamientoResponse | null>(null)
  // Por id: al recargar la lista, el modal de pagos muestra lo nuevo.
  const [viendoPagosId, setViendoPagosId] = useState<number | null>(null)
  const viendoPagos = prestamos.find((p) => p.id === viendoPagosId) ?? null

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [p, c] = await Promise.all([financiamientoApi.listar(), financiamientoApi.cuentas()])
      setPrestamos(p)
      setCuentas(c)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los préstamos.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('financiamientos', cargar)

  const anular = (p: FinanciamientoResponse) =>
    confirmar({
      titulo: `Anular el préstamo de ${p.acreedor}`,
      mensaje: `Sale ${soles(p.montoRecibido)} de ${p.cuentaFinanciera}, como si nunca hubiera entrado. No se puede deshacer.`,
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        try {
          await financiamientoApi.anular(p.id)
          await cargar()
          toast.exito('Préstamo anulado')
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos anular el préstamo.')
        }
      },
    })

  const vigentes = prestamos.filter((p) => p.estado === 'VIGENTE')
  const deuda = vigentes.reduce((s, p) => s + p.saldo, 0)

  const columns: DataTableColumn<FinanciamientoResponse>[] = [
    { key: 'fecha', label: 'Fecha', filterable: false, render: (row) => fechaCorta(row.fecha) },
    {
      key: 'acreedor',
      label: 'Quién prestó',
      filterable: false,
      render: (row) => (
        <div>
          <p className="font-medium text-ink">{row.acreedor}</p>
          {row.descripcion && <p className="text-xs text-ink-soft">{row.descripcion}</p>}
        </div>
      ),
    },
    { key: 'montoRecibido', label: 'Recibido', align: 'right', filterable: false, render: (row) => soles(row.montoRecibido) },
    { key: 'totalADevolver', label: 'A devolver', align: 'right', filterable: false, render: (row) => soles(row.totalADevolver) },
    { key: 'pagado', label: 'Pagado', align: 'right', filterable: false, render: (row) => soles(row.pagado) },
    {
      key: 'saldo',
      label: 'Falta pagar',
      align: 'right',
      filterable: false,
      render: (row) => <span className="font-semibold">{soles(row.saldo)}</span>,
    },
    { key: 'cuentaFinanciera', label: 'Entró a', filterable: false },
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
      icon={<PiggyBank size={20} />}
      title="Préstamos recibidos"
      description="La plata que te prestan entra a una cuenta como no operativa (no es ganancia) y queda como deuda hasta que la terminas de pagar."
      actions={
        puede('finanzas.financiamiento', 'crear') ? (
          <Button size="sm" onClick={() => setNuevoAbierto(true)} iconRight={<Plus size={15} />}>
            Nuevo préstamo
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Deuda pendiente" value={soles(deuda)} icon={<PiggyBank size={18} />} tono="danger" />
          <StatCard label="Préstamos vigentes" value={String(vigentes.length)} icon={<HandCoins size={18} />} tono="sys" />
        </>
      }
      columns={columns}
      rows={prestamos}
      cardIcon={PiggyBank}
      searchPlaceholder="Buscar por quién prestó..."
      empty={cargando ? 'Cargando préstamos...' : 'Todavía no hay préstamos registrados.'}
      rowActions={(row) => (
        <>
          <RowAction label={`Pagos de ${row.acreedor}`} tone="view" onClick={() => setViendoPagosId(row.id)}>
            <List size={15} />
          </RowAction>
          {row.estado === 'VIGENTE' && puede('finanzas.financiamiento', 'crear') && (
            <RowAction label={`Registrar pago a ${row.acreedor}`} tone="success" onClick={() => setPagando(row)}>
              <HandCoins size={15} />
            </RowAction>
          )}
          {row.estado !== 'ANULADO' && puede('finanzas.financiamiento', 'anular') && (
            <RowAction
              label={`Anular préstamo de ${row.acreedor}`}
              tone="danger"
              disabled={row.pagos.some((p) => !p.anulado)}
              disabledReason="Tiene pagos: anúlalos primero"
              onClick={() => anular(row)}
            >
              <Ban size={15} />
            </RowAction>
          )}
        </>
      )}
    >
      {nuevoAbierto && (
        <NuevoPrestamoModal
          cuentas={cuentas}
          onClose={() => setNuevoAbierto(false)}
          onGuardado={async () => {
            setNuevoAbierto(false)
            await cargar()
            toast.exito('Préstamo registrado')
          }}
        />
      )}
      {pagando && (
        <PagoModal
          prestamo={pagando}
          cuentas={cuentas}
          onClose={() => setPagando(null)}
          onGuardado={async () => {
            setPagando(null)
            await cargar()
            toast.exito('Pago registrado')
          }}
        />
      )}
      {viendoPagos && (
        <PagosModal
          prestamo={viendoPagos}
          puedeAnular={puede('finanzas.financiamiento', 'anular')}
          onClose={() => setViendoPagosId(null)}
          onCambio={cargar}
        />
      )}
      {dialogo}
    </ListPage>
  )
}

function NuevoPrestamoModal({
  cuentas,
  onClose,
  onGuardado,
}: {
  cuentas: CuentaOpcion[]
  onClose: () => void
  onGuardado: () => void | Promise<void>
}) {
  const [acreedor, setAcreedor] = useState('')
  const [descripcion, setDescripcion] = useState('')
  const [fecha, setFecha] = useState(hoyLocal())
  const [recibido, setRecibido] = useState('')
  const [devolver, setDevolver] = useState('')
  const [cuentaId, setCuentaId] = useState(0)
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  const guardar = async () => {
    const monto = numero(recibido)
    const total = devolver.trim() ? numero(devolver) : null
    if (!acreedor.trim()) return setError('Indica quién te prestó.')
    if (!Number.isFinite(monto) || monto <= 0) return setError('Ingresa cuánto recibiste.')
    if (total !== null && (!Number.isFinite(total) || total < monto)) {
      return setError('Lo que se devuelve no puede ser menos de lo que recibiste.')
    }
    if (!cuentaId) return setError('Elige a qué cuenta entró la plata.')

    setGuardando(true)
    setError('')
    try {
      await financiamientoApi.crear({
        acreedor: acreedor.trim(),
        descripcion: descripcion.trim() || null,
        fecha,
        montoRecibido: Math.round(monto * 100) / 100,
        totalADevolver: total === null ? null : Math.round(total * 100) / 100,
        cuentaFinancieraId: cuentaId,
      })
      await onGuardado()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos registrar el préstamo.')
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal
      open
      size="sm"
      title="Nuevo préstamo"
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
        <Input label="Quién te prestó" placeholder="BCP, Juan Pérez..." value={acreedor} onChange={(e) => setAcreedor(e.target.value)} />
        <Input label="Para qué" optional placeholder="Capital de trabajo, compra de mercadería..." value={descripcion} onChange={(e) => setDescripcion(e.target.value)} />
        <div className="grid grid-cols-2 gap-3">
          <Input label="Recibido" type="number" step="0.01" placeholder="0.00" value={recibido} onChange={(e) => setRecibido(e.target.value)} />
          <Input
            label="A devolver"
            type="number"
            step="0.01"
            optional
            placeholder={recibido || '0.00'}
            value={devolver}
            onChange={(e) => setDevolver(e.target.value)}
          />
        </div>
        <p className="-mt-2 text-xs text-ink-soft">"A devolver" es el total con intereses. Si lo dejas vacío, es lo mismo que recibiste.</p>
        <Input label="Fecha" type="date" value={fecha} onChange={(e) => setFecha(e.target.value)} />
        <Desplegable
          label="Entró a"
          value={cuentaId}
          onChange={(v) => setCuentaId(Number(v))}
          placeholder="Elige la caja o el banco"
          options={cuentas.map((c) => ({ value: c.id, label: c.nombre, detalle: NATURALEZA[c.naturaleza] ?? c.naturaleza }))}
        />
      </div>
    </Modal>
  )
}

function PagoModal({
  prestamo,
  cuentas,
  onClose,
  onGuardado,
}: {
  prestamo: FinanciamientoResponse
  cuentas: CuentaOpcion[]
  onClose: () => void
  onGuardado: () => void | Promise<void>
}) {
  const [monto, setMonto] = useState('')
  const [fecha, setFecha] = useState(hoyLocal())
  const [cuentaId, setCuentaId] = useState(prestamo.cuentaFinancieraId)
  const [observacion, setObservacion] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  const guardar = async () => {
    const valor = numero(monto)
    if (!Number.isFinite(valor) || valor <= 0) return setError('Ingresa cuánto pagas.')
    if (valor > prestamo.saldo) return setError(`Solo falta pagar ${soles(prestamo.saldo)}.`)
    if (!cuentaId) return setError('Elige de qué cuenta sale el pago.')

    setGuardando(true)
    setError('')
    try {
      await financiamientoApi.pagar(prestamo.id, {
        monto: Math.round(valor * 100) / 100,
        fecha,
        cuentaFinancieraId: cuentaId,
        observacion: observacion.trim() || null,
      })
      await onGuardado()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos registrar el pago.')
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal
      open
      size="sm"
      title={`Pago a ${prestamo.acreedor}`}
      description={`Falta pagar ${soles(prestamo.saldo)}.`}
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            Registrar pago
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        {error && <Alert>{error}</Alert>}
        <Input
          label="Monto"
          type="number"
          step="0.01"
          placeholder="0.00"
          value={monto}
          onChange={(e) => setMonto(e.target.value)}
          hint={
            <button type="button" className="text-xs text-ink-soft underline" onClick={() => setMonto(String(prestamo.saldo))}>
              Pagar todo
            </button>
          }
        />
        <Input label="Fecha" type="date" value={fecha} onChange={(e) => setFecha(e.target.value)} />
        <Desplegable
          label="Sale de"
          value={cuentaId}
          onChange={(v) => setCuentaId(Number(v))}
          placeholder="Elige la caja o el banco"
          options={cuentas.map((c) => ({ value: c.id, label: c.nombre, detalle: NATURALEZA[c.naturaleza] ?? c.naturaleza }))}
        />
        <Input label="Observación" optional placeholder="Cuota 3 de 12..." value={observacion} onChange={(e) => setObservacion(e.target.value)} />
      </div>
    </Modal>
  )
}

function PagosModal({
  prestamo,
  puedeAnular,
  onClose,
  onCambio,
}: {
  prestamo: FinanciamientoResponse
  puedeAnular: boolean
  onClose: () => void
  onCambio: () => Promise<void>
}) {
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()

  const anularPago = (pagoId: number, monto: number) =>
    confirmar({
      titulo: 'Anular el pago',
      mensaje: `Vuelve ${soles(monto)} a la cuenta de la que salió, y a la deuda. No se puede deshacer.`,
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        try {
          await financiamientoApi.anularPago(prestamo.id, pagoId)
          await onCambio()
          toast.exito('Pago anulado')
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos anular el pago.')
        }
      },
    })

  return (
    <Modal
      open
      size="md"
      title={`Pagos a ${prestamo.acreedor}`}
      description={`Recibido ${soles(prestamo.montoRecibido)} · a devolver ${soles(prestamo.totalADevolver)} · falta ${soles(prestamo.saldo)}`}
      onClose={onClose}
    >
      <div className="overflow-hidden rounded-panel border border-line">
        {prestamo.pagos.length === 0 ? (
          <p className="p-4 text-center text-sm text-ink-soft">Todavía no hay pagos.</p>
        ) : (
          prestamo.pagos.map((p) => (
            <div key={p.id} className="flex items-center justify-between gap-3 border-b border-line px-3 py-2.5 last:border-b-0">
              <div className="min-w-0">
                <p className={`text-sm font-semibold ${p.anulado ? 'text-ink-soft line-through' : 'text-ink'}`}>{soles(p.monto)}</p>
                <p className="truncate text-xs text-ink-soft">
                  {fechaCorta(p.fecha)} · desde {p.cuentaFinanciera}
                  {p.observacion ? ` · ${p.observacion}` : ''}
                </p>
              </div>
              {p.anulado ? (
                <Badge tone="neutral">Anulado</Badge>
              ) : (
                puedeAnular &&
                prestamo.estado !== 'ANULADO' && (
                  <RowAction label="Anular pago" tone="danger" onClick={() => anularPago(p.id, p.monto)}>
                    <Ban size={15} />
                  </RowAction>
                )
              )}
            </div>
          ))
        )}
      </div>
      {dialogo}
    </Modal>
  )
}
