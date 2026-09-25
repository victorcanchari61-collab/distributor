import { useCallback, useEffect, useState } from 'react'
import { ArrowDownCircle, ArrowUpCircle, Landmark, TrendingDown, TrendingUp, Wallet } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Desplegable,
  Input,
  Modal,
  PageHeader,
  StatCard,
  SysDataTable,
  Tabs,
  useToast,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaHora, hoyLocal } from '../../lib/fechas'
import { useRealtime } from '../../lib/realtime'
import { motivoGastoApi } from './arqueoApi'
import type { MotivoGastoResponse } from './arqueoApi'
import { miCajaApi } from './miCajaApi'
import type { CerrarMiCajaRequest } from './miCajaApi'
import type { CuentaFinancieraResponse, MovimientoCuentaResponse } from './cuentaFinancieraApi'
import type { TipoMovimientoOperativo } from './gastoOperativoApi'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

const BILLETES = [200, 100, 50, 20, 10]
const MONEDAS = [5, 2, 1, 0.5, 0.2, 0.1]

/**
 * La Caja de quien está logueado: su propio dinero en la ruta. Las ventas al
 * contado que cobra entran solas; acá se registra cualquier otro ingreso o
 * egreso a mano, y se cierra el día (cuenta lo físico y liquida a la Caja
 * General).
 */
export function MiCajaPage() {
  const toast = useToast()
  const [caja, setCaja] = useState<CuentaFinancieraResponse | null>(null)
  const [movimientos, setMovimientos] = useState<MovimientoCuentaResponse[]>([])
  const [motivos, setMotivos] = useState<MotivoGastoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [movimientoAbierto, setMovimientoAbierto] = useState<TipoMovimientoOperativo | null>(null)
  const [cerrarAbierto, setCerrarAbierto] = useState(false)

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [c, mot] = await Promise.all([miCajaApi.mia(), motivoGastoApi.getAll()])
      setCaja(c)
      setMotivos(mot)
      setMovimientos(await miCajaApi.movimientos())
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar tu caja.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('cuentasfinancieras', cargar)
  useRealtime('arqueo', cargar)
  useRealtime('gastosoperativos', cargar)

  const totalIngresos = movimientos.filter((m) => m.tipo === 'INGRESO').reduce((s, m) => s + m.monto, 0)
  const totalEgresos = movimientos.filter((m) => m.tipo === 'EGRESO').reduce((s, m) => s + m.monto, 0)

  const columns: DataTableColumn<MovimientoCuentaResponse>[] = [
    { key: 'fecha', label: 'Fecha', filterable: false, render: (row) => fechaHora(row.fecha) },
    {
      key: 'tipo',
      label: 'Tipo',
      filterType: 'select',
      filterOptions: [
        { value: 'INGRESO', label: 'Ingreso' },
        { value: 'EGRESO', label: 'Egreso' },
      ],
      render: (row) => <Badge tone={row.tipo === 'INGRESO' ? 'success' : 'danger'}>{row.tipo === 'INGRESO' ? 'Ingreso' : 'Egreso'}</Badge>,
    },
    {
      key: 'monto',
      label: 'Monto',
      align: 'right',
      filterable: false,
      render: (row) => (row.tipo === 'INGRESO' ? `+${soles(row.monto)}` : `-${soles(row.monto)}`),
    },
    { key: 'saldoResultante', label: 'Saldo', align: 'right', filterable: false, render: (row) => soles(row.saldoResultante) },
    { key: 'documentoOrigen', label: 'Origen', filterable: false },
    { key: 'observacion', label: 'Detalle', filterable: false, render: (row) => row.observacion ?? '—' },
  ]

  return (
    <div className="space-y-5">
      <PageHeader
        icon={<Wallet size={20} />}
        title="Mi Caja"
        description="Lo que cobras al contado entra solo. Aquí registras cualquier otro ingreso o egreso, y cierras el día."
        actions={
          <>
            <Button size="sm" variant="secondary" onClick={() => setMovimientoAbierto('INGRESO')} iconRight={<ArrowUpCircle size={15} />}>
              Ingreso
            </Button>
            <Button size="sm" variant="secondary" onClick={() => setMovimientoAbierto('EGRESO')} iconRight={<ArrowDownCircle size={15} />}>
              Egreso
            </Button>
            <Button size="sm" onClick={() => setCerrarAbierto(true)} iconRight={<Landmark size={15} />}>
              Cerrar caja
            </Button>
          </>
        }
      />

      {error && <Alert>{error}</Alert>}

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <StatCard
          label="Saldo de tu caja"
          value={caja ? soles(caja.saldoActual) : '—'}
          icon={<Wallet size={18} />}
          tono={caja && caja.saldoActual < 0 ? 'danger' : 'sys'}
          hint="Lo que deberías tener ahora en la mano"
        />
        <StatCard label="Ingresos" value={soles(totalIngresos)} icon={<TrendingUp size={18} />} tono="success" />
        <StatCard label="Egresos" value={soles(totalEgresos)} icon={<TrendingDown size={18} />} tono="danger" />
      </div>

      <SysDataTable
        columns={columns}
        rows={movimientos}
        cardIcon={Wallet}
        searchPlaceholder="Buscar por origen..."
        empty={cargando ? 'Cargando movimientos...' : 'Todavía no hay movimientos en tu caja.'}
      />

      {movimientoAbierto && caja && (
        <MovimientoLibreModal
          tipo={movimientoAbierto}
          motivos={motivos}
          onClose={() => setMovimientoAbierto(null)}
          onGuardado={async () => {
            setMovimientoAbierto(null)
            await cargar()
            toast.exito('Movimiento registrado')
          }}
        />
      )}

      {cerrarAbierto && caja && (
        <CerrarCajaModal
          onClose={() => setCerrarAbierto(false)}
          onGuardado={async () => {
            setCerrarAbierto(false)
            await cargar()
            toast.exito('Caja cerrada y liquidada')
          }}
        />
      )}
    </div>
  )
}

function MovimientoLibreModal({
  tipo,
  motivos,
  onClose,
  onGuardado,
}: {
  tipo: TipoMovimientoOperativo
  motivos: MotivoGastoResponse[]
  onClose: () => void
  onGuardado: () => void | Promise<void>
}) {
  const [motivoGastoId, setMotivoGastoId] = useState(0)
  const [monto, setMonto] = useState('')
  const [descripcion, setDescripcion] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  const guardar = async () => {
    const numero = Number(monto.replace(',', '.'))
    if (!motivoGastoId) return setError('Elige la categoría.')
    if (!Number.isFinite(numero) || numero <= 0) return setError('Ingresa un monto mayor a cero.')

    setGuardando(true)
    setError('')
    try {
      await miCajaApi.registrarMovimiento({
        tipo,
        motivoGastoId,
        monto: numero,
        descripcion: descripcion.trim() || null,
      })
      await onGuardado()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos registrar el movimiento.')
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal
      open
      size="sm"
      title={tipo === 'INGRESO' ? 'Registrar ingreso' : 'Registrar egreso'}
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
          label="Categoría"
          value={motivoGastoId}
          onChange={(v) => setMotivoGastoId(Number(v))}
          placeholder="Elige una categoría"
          options={motivos.filter((m) => m.activo).map((m) => ({ value: m.id, label: m.nombre }))}
        />
        <Input label="Monto" type="number" step="0.01" placeholder="0.00" value={monto} onChange={(e) => setMonto(e.target.value)} />
        <Input label="Detalle" optional value={descripcion} onChange={(e) => setDescripcion(e.target.value)} />
      </div>
    </Modal>
  )
}

function CerrarCajaModal({
  onClose,
  onGuardado,
}: {
  onClose: () => void
  onGuardado: () => void | Promise<void>
}) {
  const [cantBilletes, setCantBilletes] = useState<Record<number, string>>({})
  const [cantMonedas, setCantMonedas] = useState<Record<number, string>>({})
  const [pestana, setPestana] = useState<'billetes' | 'monedas'>('billetes')
  const [observacion, setObservacion] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  const cantidad = (texto: string | undefined) => {
    const n = Number(texto)
    return Number.isFinite(n) && n > 0 ? Math.floor(n) : 0
  }

  const sumar = (denominaciones: number[], cantidades: Record<number, string>) =>
    denominaciones.reduce((s, v) => s + v * cantidad(cantidades[v]), 0)

  const totalBilletes = sumar(BILLETES, cantBilletes)
  const totalMonedas = sumar(MONEDAS, cantMonedas)

  const guardar = async () => {
    setGuardando(true)
    setError('')
    try {
      const cuerpo: CerrarMiCajaRequest = {
        fecha: hoyLocal(),
        billetes: totalBilletes,
        monedas: totalMonedas,
        observacion: observacion.trim() || null,
      }
      await miCajaApi.cerrar(cuerpo)
      await onGuardado()
    } catch (e) {
      setError(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos cerrar la caja.',
      )
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal
      open
      size="sm"
      title="Cerrar caja"
      description="Cuenta billete por billete y moneda por moneda. Se compara contra el saldo de tu caja y se liquida a la Caja General."
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            Cerrar y liquidar
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        {error && <Alert>{error}</Alert>}

        <Tabs
          active={pestana}
          onChange={(id) => setPestana(id as 'billetes' | 'monedas')}
          items={[
            { id: 'billetes', label: 'Billetes' },
            { id: 'monedas', label: 'Monedas' },
          ]}
        />

        {pestana === 'billetes' ? (
          <div>
            <div className="flex flex-col gap-1.5">
              {BILLETES.map((v) => (
                <FilaDenominacion
                  key={v}
                  valor={v}
                  cantidad={cantBilletes[v] ?? ''}
                  onChange={(texto) => setCantBilletes({ ...cantBilletes, [v]: texto })}
                />
              ))}
            </div>
            <p className="mt-2 text-right text-sm font-semibold text-ink">Subtotal billetes {soles(totalBilletes)}</p>
          </div>
        ) : (
          <div>
            <div className="flex flex-col gap-1.5">
              {MONEDAS.map((v) => (
                <FilaDenominacion
                  key={v}
                  valor={v}
                  cantidad={cantMonedas[v] ?? ''}
                  onChange={(texto) => setCantMonedas({ ...cantMonedas, [v]: texto })}
                />
              ))}
            </div>
            <p className="mt-2 text-right text-sm font-semibold text-ink">Subtotal monedas {soles(totalMonedas)}</p>
          </div>
        )}

        <Input label="Observación" optional placeholder="Alguna razón de la diferencia..." value={observacion} onChange={(e) => setObservacion(e.target.value)} />
      </div>
    </Modal>
  )
}

/** Una fila de conteo: cuántos billetes/monedas de un valor, y cuánto suman. */
function FilaDenominacion({
  valor,
  cantidad,
  onChange,
}: {
  valor: number
  cantidad: string
  onChange: (texto: string) => void
}) {
  const subtotal = valor * (Number(cantidad) > 0 ? Math.floor(Number(cantidad)) : 0)

  return (
    <div className="flex items-center gap-2">
      <span className="w-16 shrink-0 text-sm text-ink">{soles(valor)}</span>
      <Input
        size="sm"
        type="number"
        min={0}
        step={1}
        placeholder="0"
        value={cantidad}
        onChange={(e) => onChange(e.target.value)}
        className="w-20"
      />
      <span className="ml-auto shrink-0 text-sm text-ink-soft">{soles(subtotal)}</span>
    </div>
  )
}
