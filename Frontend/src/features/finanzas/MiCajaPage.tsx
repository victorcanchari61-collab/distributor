import { useCallback, useEffect, useState } from 'react'
import { ArrowDownCircle, ArrowUpCircle, Landmark, Wallet } from 'lucide-react'
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

      <StatCard
        label="Saldo de tu caja"
        value={caja ? soles(caja.saldoActual) : '—'}
        icon={<Wallet size={18} />}
        tono={caja && caja.saldoActual < 0 ? 'danger' : 'sys'}
        hint="Lo que deberías tener ahora en la mano"
      />

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
          caja={caja}
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
  caja,
  onClose,
  onGuardado,
}: {
  caja: CuentaFinancieraResponse
  onClose: () => void
  onGuardado: () => void | Promise<void>
}) {
  const [billetes, setBilletes] = useState('')
  const [monedas, setMonedas] = useState('')
  const [observacion, setObservacion] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  const numero = (texto: string) => {
    const n = Number(texto.replace(',', '.'))
    return Number.isFinite(n) ? n : 0
  }

  const total = numero(billetes) + numero(monedas)
  const diferencia = total - caja.saldoActual

  const guardar = async () => {
    if (numero(billetes) < 0 || numero(monedas) < 0) return setError('El efectivo no puede ser negativo.')

    setGuardando(true)
    setError('')
    try {
      const cuerpo: CerrarMiCajaRequest = {
        fecha: hoyLocal(),
        billetes: numero(billetes),
        monedas: numero(monedas),
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
      description="Cuenta lo que tienes de verdad. Se compara contra el saldo de tu caja y se liquida a la Caja General."
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

        <div className="grid grid-cols-2 gap-3">
          <Input label="Billetes" type="number" step="0.01" placeholder="0.00" value={billetes} onChange={(e) => setBilletes(e.target.value)} />
          <Input label="Monedas" type="number" step="0.01" placeholder="0.00" value={monedas} onChange={(e) => setMonedas(e.target.value)} />
        </div>

        <div className="grid grid-cols-3 gap-px overflow-hidden rounded-panel border border-line bg-line text-center">
          <div className="bg-white px-2 py-2">
            <p className="text-[11px] font-semibold uppercase text-ink-soft">Contado</p>
            <p className="text-base font-bold text-ink">{soles(total)}</p>
          </div>
          <div className="bg-white px-2 py-2">
            <p className="text-[11px] font-semibold uppercase text-ink-soft">Debe traer</p>
            <p className="text-base font-bold text-ink-muted">{soles(caja.saldoActual)}</p>
          </div>
          <div className="bg-white px-2 py-2">
            <p className="text-[11px] font-semibold uppercase text-ink-soft">Diferencia</p>
            <p className={`text-base font-bold ${diferencia === 0 ? 'text-emerald-600' : diferencia > 0 ? 'text-ink-muted' : 'text-red-600'}`}>
              {diferencia > 0 ? '+' : ''}
              {soles(diferencia)}
            </p>
          </div>
        </div>

        <Input label="Observación" optional placeholder="Alguna razón de la diferencia..." value={observacion} onChange={(e) => setObservacion(e.target.value)} />
      </div>
    </Modal>
  )
}
