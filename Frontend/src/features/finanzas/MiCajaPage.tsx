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
import { desplazarDias, fechaHora, hoyLocal } from '../../lib/fechas'
import { useRealtime } from '../../lib/realtime'
import { miCajaApi } from './miCajaApi'
import type { CuentaDestino } from './miCajaApi'
import type { CuentaFinancieraResponse, MovimientoCuentaResponse } from './cuentaFinancieraApi'
import { gastoOperativoApi, origenLabel } from './gastoOperativoApi'
import type { CategoriaOpcion, TipoMovimientoOperativo } from './gastoOperativoApi'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

const BILLETES = [200, 100, 50, 20, 10]
const MONEDAS = [5, 2, 1, 0.5, 0.2, 0.1]

const DOCUMENTOS: Record<string, string> = {
  PAGO_VENTA: 'Cobro de venta',
  MOVIMIENTO_OPERATIVO: 'Ingreso o egreso',
  CIERRE_CAJA: 'Cierre de caja',
  FALTANTE_CAJA: 'Faltante de cierre',
  SOBRANTE_CAJA: 'Sobrante de cierre',
  REVERSION: 'Anulación',
  SALDO_INICIAL: 'Saldo inicial',
  TRANSFERENCIA_INTERNA: 'Transferencia',
  FINANCIAMIENTO: 'Préstamo recibido',
  PAGO_FINANCIAMIENTO: 'Pago de préstamo',
  RECUPERO_FALTANTE: 'Recupero de faltante',
}

const NATURALEZA_LABEL: Record<string, string> = { CAJA: 'Caja', BANCO: 'Banco', PASARELA: 'Pasarela' }

/**
 * La Caja de quien está logueado: su propio dinero en la ruta. Las ventas al
 * contado que cobra entran solas; acá se registra cualquier otro ingreso o
 * egreso a mano, y se cierra la caja (cuenta lo físico y lo entrega a otra
 * cuenta).
 */
export function MiCajaPage() {
  const toast = useToast()
  const [caja, setCaja] = useState<CuentaFinancieraResponse | null>(null)
  const [movimientos, setMovimientos] = useState<MovimientoCuentaResponse[]>([])
  const [categorias, setCategorias] = useState<CategoriaOpcion[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  // El historial de una caja crece todos los días: se pide por rango, el
  // último mes por defecto, y se cambia desde el filtro de fecha de la tabla.
  const [desde, setDesde] = useState(desplazarDias(-30))
  const [hasta, setHasta] = useState(hoyLocal())

  const [movimientoAbierto, setMovimientoAbierto] = useState<TipoMovimientoOperativo | null>(null)
  const [cerrarAbierto, setCerrarAbierto] = useState(false)

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [c, cat] = await Promise.all([miCajaApi.mia(), gastoOperativoApi.categoriasOpciones()])
      setCaja(c)
      setCategorias(cat)
      setMovimientos(await miCajaApi.movimientos(desde, hasta))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar tu caja.')
    } finally {
      setCargando(false)
    }
  }, [desde, hasta])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('cuentasfinancieras', cargar)
  useRealtime('gastosoperativos', cargar)

  const totalIngresos = movimientos.filter((m) => m.tipo === 'INGRESO').reduce((s, m) => s + m.monto, 0)
  const totalEgresos = movimientos.filter((m) => m.tipo === 'EGRESO').reduce((s, m) => s + m.monto, 0)

  const columns: DataTableColumn<MovimientoCuentaResponse>[] = [
    { key: 'fecha', label: 'Fecha', filterType: 'date', render: (row) => fechaHora(row.fecha) },
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
    {
      key: 'documentoOrigen',
      label: 'Concepto',
      filterType: 'select',
      filterOptions: Object.entries(DOCUMENTOS).map(([value, label]) => ({ value, label })),
      render: (row) => DOCUMENTOS[row.documentoOrigen] ?? row.documentoOrigen,
    },
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
        <StatCard label="Ingresos" value={soles(totalIngresos)} icon={<TrendingUp size={18} />} tono="success" hint="En las fechas de la tabla" />
        <StatCard label="Egresos" value={soles(totalEgresos)} icon={<TrendingDown size={18} />} tono="danger" hint="En las fechas de la tabla" />
      </div>

      <SysDataTable
        columns={columns}
        rows={movimientos}
        onConsulta={(q) => {
          const fecha = q.filtros.find((f) => f.columna === 'fecha')
          setDesde(fecha?.valor || desplazarDias(-30))
          setHasta(fecha?.valorHasta || fecha?.valor || hoyLocal())
        }}
        cardIcon={Wallet}
        searchPlaceholder="Buscar por detalle..."
        empty={cargando ? 'Cargando movimientos...' : 'No hay movimientos en tu caja en estas fechas.'}
      />

      {movimientoAbierto && caja && (
        <MovimientoLibreModal
          tipo={movimientoAbierto}
          categorias={categorias.filter((c) => c.tipo === movimientoAbierto)}
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
            toast.exito('Caja cerrada')
          }}
        />
      )}
    </div>
  )
}

function MovimientoLibreModal({
  tipo,
  categorias,
  onClose,
  onGuardado,
}: {
  tipo: TipoMovimientoOperativo
  categorias: CategoriaOpcion[]
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
          options={categorias.map((c) => ({ value: c.id, label: c.nombre, detalle: origenLabel(c.origen) }))}
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
  const [destinos, setDestinos] = useState<CuentaDestino[]>([])
  const [cuentaDestinoId, setCuentaDestinoId] = useState(0)
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

  useEffect(() => {
    miCajaApi
      .destinos()
      .then(setDestinos)
      .catch((e) => setError(e instanceof ApiError ? e.message : 'No pudimos cargar las cuentas.'))
  }, [])

  const guardar = async () => {
    if (!cuentaDestinoId) return setError('Elige a quién le entregas lo contado.')

    setGuardando(true)
    setError('')
    try {
      await miCajaApi.cerrar({
        billetes: Math.round(totalBilletes * 100) / 100,
        monedas: Math.round(totalMonedas * 100) / 100,
        cuentaDestinoId,
        observacion: observacion.trim() || null,
      })
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
      description="Cuenta billete por billete y moneda por moneda, y elige a quién se lo entregas."
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            Cerrar y entregar
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

        <Desplegable
          label="Entregar a"
          value={cuentaDestinoId}
          onChange={(v) => setCuentaDestinoId(Number(v))}
          placeholder="Elige la caja o el banco"
          options={destinos.map((d) => ({ value: d.id, label: d.nombre, detalle: NATURALEZA_LABEL[d.naturaleza] ?? d.naturaleza }))}
        />

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
