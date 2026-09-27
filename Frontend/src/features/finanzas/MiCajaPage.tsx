import { useCallback, useEffect, useState } from 'react'
import { ArrowDownCircle, ArrowUpCircle, Landmark, Smartphone, TrendingDown, TrendingUp, Wallet } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Desplegable,
  FilaStats,
  Input,
  Modal,
  PageHeader,
  StatCard,
  SysDataTable,
  Tabs,
  useToast,
} from '../../components/ui'
import type { BadgeTone, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaHora, hoyLocal } from '../../lib/fechas'
import { useRealtime } from '../../lib/realtime'
import { miCajaApi } from './miCajaApi'
import type { CuentaDestino, MovimientoDigital } from './miCajaApi'
import type { CuentaFinancieraResponse, MovimientoCuentaResponse } from './cuentaFinancieraApi'
import { gastoOperativoApi, origenLabel } from './gastoOperativoApi'
import type { CategoriaOpcion, TipoMovimientoOperativo } from './gastoOperativoApi'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

const BILLETES = [200, 100, 50, 20, 10]
const MONEDAS = [5, 2, 1, 0.5, 0.2, 0.1]

const DOCUMENTOS: Record<string, string> = {
  PAGO_VENTA: 'Cobro de venta',
  PAGO_COMPRA: 'Pago a proveedor',
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

type Medio = 'EFECTIVO' | 'BILLETERA_DIGITAL' | 'TRANSFERENCIA'

const MEDIOS: Record<Medio, string> = {
  EFECTIVO: 'Efectivo',
  BILLETERA_DIGITAL: 'Billetera digital',
  TRANSFERENCIA: 'Transferencia',
}

type Estado = 'VIGENTE' | 'ANULADO' | 'REVERSA' | 'PENDIENTE' | 'VERIFICADO' | 'RECHAZADO'

/*
 * El efectivo solo vale o se anuló. Lo digital, además, se busca en el banco
 * por su número de operación: queda por verificar hasta que alguien lo
 * encuentra, y si no aparece se rechaza y se descuenta en planilla.
 */
const ESTADOS: Record<Estado, { label: string; tono: BadgeTone }> = {
  VIGENTE: { label: 'Vigente', tono: 'success' },
  PENDIENTE: { label: 'Por verificar', tono: 'warning' },
  VERIFICADO: { label: 'Verificado', tono: 'success' },
  RECHAZADO: { label: 'Rechazado', tono: 'danger' },
  ANULADO: { label: 'Anulado', tono: 'neutral' },
  REVERSA: { label: 'Reversa', tono: 'neutral' },
}

/**
 * Una fila de Mi Caja: un movimiento de la caja (efectivo) o un cobro o pago
 * por Yape o transferencia, que no pasa por la caja pero también es suyo.
 */
interface FilaMiCaja {
  clave: string
  fecha: string
  medio: Medio
  /** "Efectivo", o el método: "Yape-Victor". */
  metodo: string
  tipo: 'INGRESO' | 'EGRESO'
  monto: number
  /** Solo en efectivo: cómo quedó la caja. Lo digital no la toca. */
  saldo: number | null
  /** La clave de DOCUMENTOS, para filtrar por concepto. */
  concepto: string
  /** Lo que va debajo del concepto: el documento y el cliente, o lo escrito a mano. */
  detalle: string | null
  numeroOperacion: string | null
  estado: Estado
}

/** Movió plata de verdad: ni lo anulado, ni su reversa, ni lo que no llegó al banco. */
const cuenta = (f: FilaMiCaja) => f.estado !== 'ANULADO' && f.estado !== 'REVERSA' && f.estado !== 'RECHAZADO'

const deEfectivo = (m: MovimientoCuentaResponse): FilaMiCaja => ({
  clave: `E-${m.id}`,
  fecha: m.fecha,
  medio: 'EFECTIVO',
  metodo: 'Efectivo',
  tipo: m.tipo,
  monto: m.monto,
  saldo: m.saldoResultante,
  concepto: m.documentoOrigen,
  detalle: m.observacion ?? null,
  numeroOperacion: null,
  estado: m.esReversa ? 'REVERSA' : m.anulado ? 'ANULADO' : 'VIGENTE',
})

const deDigital = (m: MovimientoDigital): FilaMiCaja => ({
  clave: `D-${m.tipo}-${m.id}`,
  fecha: m.fecha,
  medio: m.metodoTipo,
  metodo: m.metodoPago,
  tipo: m.tipo === 'COBRO' ? 'INGRESO' : 'EGRESO',
  monto: m.monto,
  saldo: null,
  concepto: m.tipo === 'COBRO' ? 'PAGO_VENTA' : 'PAGO_COMPRA',
  detalle: [m.documento, m.contraparte, m.cuenta && `${m.tipo === 'COBRO' ? 'entró a' : 'salió de'} ${m.cuenta}`]
    .filter(Boolean)
    .join(' · '),
  numeroOperacion: m.numeroOperacion,
  estado: m.anulado ? 'ANULADO' : (m.estadoVerificacion ?? 'VIGENTE'),
})

/**
 * La Caja de quien está logueado: su propio dinero en la ruta, y lo que cobró
 * o pagó por Yape o transferencia.
 *
 * Todo va en una sola lista, pero las tarjetas separan lo que tiene en la mano
 * —el efectivo, lo único que se cuenta al cerrar caja— de lo que entró directo
 * al banco. Un solo total haría creer que el Yape también se entrega, y el
 * cierre saldría con faltante sin faltar nada.
 */
export function MiCajaPage() {
  const toast = useToast()
  const [caja, setCaja] = useState<CuentaFinancieraResponse | null>(null)
  const [filas, setFilas] = useState<FilaMiCaja[]>([])
  const [categorias, setCategorias] = useState<CategoriaOpcion[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  // El historial crece todos los días: se pide por rango, hoy por defecto, y
  // se cambia desde el filtro de fecha de la tabla.
  const [desde, setDesde] = useState(hoyLocal())
  const [hasta, setHasta] = useState(hoyLocal())

  const [movimientoAbierto, setMovimientoAbierto] = useState<TipoMovimientoOperativo | null>(null)
  const [cerrarAbierto, setCerrarAbierto] = useState(false)

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [c, cat, efectivo, digitales] = await Promise.all([
        miCajaApi.mia(),
        gastoOperativoApi.categoriasOpciones(),
        miCajaApi.movimientos(desde, hasta),
        miCajaApi.digitales(desde, hasta),
      ])
      setCaja(c)
      setCategorias(cat)
      setFilas(
        [...efectivo.map(deEfectivo), ...digitales.map(deDigital)].sort(
          (a, b) => b.fecha.localeCompare(a.fecha) || b.clave.localeCompare(a.clave),
        ),
      )
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

  // Un cobro, un gasto, un cierre o una verificación en el banco cambian la lista.
  useRealtime(['cuentasfinancieras', 'gastosoperativos', 'notasventa', 'compras', 'cierrescaja'], cargar)

  const suma = (lista: FilaMiCaja[]) => lista.reduce((s, f) => s + f.monto, 0)
  const efectivo = filas.filter((f) => f.medio === 'EFECTIVO' && cuenta(f))
  const ingresos = efectivo.filter((f) => f.tipo === 'INGRESO')
  const egresos = efectivo.filter((f) => f.tipo === 'EGRESO')
  const cobrosDigitales = filas.filter((f) => f.medio !== 'EFECTIVO' && f.tipo === 'INGRESO' && cuenta(f))
  const porVerificar = cobrosDigitales.filter((f) => f.estado === 'PENDIENTE').length
  const rechazados = filas.filter((f) => f.estado === 'RECHAZADO')

  const columns: DataTableColumn<FilaMiCaja>[] = [
    { key: 'fecha', label: 'Fecha', filterType: 'date', render: (row) => fechaHora(row.fecha) },
    {
      key: 'medio',
      label: 'Medio',
      filterType: 'select',
      filterOptions: Object.entries(MEDIOS).map(([value, label]) => ({ value, label })),
      render: (row) => (
        <Badge tone={row.medio === 'EFECTIVO' ? 'sys' : 'neutral'}>
          {row.medio === 'EFECTIVO' ? <Wallet size={12} /> : <Smartphone size={12} />}
          {row.metodo}
        </Badge>
      ),
    },
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
      key: 'concepto',
      label: 'Concepto',
      filterType: 'select',
      filterOptions: Object.entries(DOCUMENTOS).map(([value, label]) => ({ value, label })),
      render: (row) => (
        <div>
          <p>{DOCUMENTOS[row.concepto] ?? row.concepto}</p>
          {row.detalle && <p className="text-xs text-ink-soft">{row.detalle}</p>}
        </div>
      ),
    },
    {
      key: 'monto',
      label: 'Monto',
      align: 'right',
      filterable: false,
      render: (row) => (
        <span className={cuenta(row) ? '' : 'text-ink-soft line-through'}>
          {row.tipo === 'INGRESO' ? '+' : '-'}
          {soles(row.monto)}
        </span>
      ),
    },
    {
      key: 'saldo',
      label: 'Saldo en caja',
      align: 'right',
      filterable: false,
      render: (row) => (row.saldo === null ? <span className="text-ink-soft">—</span> : soles(row.saldo)),
    },
    {
      key: 'numeroOperacion',
      label: 'N° operación',
      filterable: false,
      render: (row) =>
        row.numeroOperacion ? <span className="font-mono">{row.numeroOperacion}</span> : <span className="text-ink-soft">—</span>,
    },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: Object.entries(ESTADOS).map(([value, e]) => ({ value, label: e.label })),
      render: (row) => <Badge tone={ESTADOS[row.estado].tono}>{ESTADOS[row.estado].label}</Badge>,
    },
  ]

  return (
    <div className="space-y-5">
      <PageHeader
        icon={<Wallet size={20} />}
        title="Mi Caja"
        description="Lo que cobras al contado entra a tu caja; lo de Yape o transferencia va directo al banco. Aquí registras cualquier otro ingreso o egreso, y cierras el día."
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
      {rechazados.length > 0 && (
        <Alert tone="warning">
          {rechazados.length === 1 ? 'Un cobro no apareció' : `${rechazados.length} cobros no aparecieron`} en el banco:{' '}
          {soles(suma(rechazados))} se te descuentan en tu planilla.
        </Alert>
      )}

      <FilaStats>
        <StatCard
          label="Efectivo en tu mano"
          value={caja ? soles(caja.saldoActual) : '—'}
          icon={<Wallet size={18} />}
          tono={caja && caja.saldoActual < 0 ? 'danger' : 'sys'}
          hint="Lo que se cuenta al cerrar caja"
        />
        <StatCard
          label="Ingresos en efectivo"
          value={soles(suma(ingresos))}
          icon={<TrendingUp size={18} />}
          tono="success"
          hint="En las fechas de la tabla"
        />
        <StatCard
          label="Egresos en efectivo"
          value={soles(suma(egresos))}
          icon={<TrendingDown size={18} />}
          tono="danger"
          hint="En las fechas de la tabla"
        />
        <StatCard
          label="Cobrado digital"
          value={soles(suma(cobrosDigitales))}
          icon={<Smartphone size={18} />}
          tono="warning"
          hint={porVerificar > 0 ? `Va al banco · ${porVerificar} por verificar` : 'Va directo al banco, no a tu caja'}
        />
      </FilaStats>

      <SysDataTable
        columns={columns}
        rows={filas}
        rowKey="clave"
        onConsulta={(q) => {
          const fecha = q.filtros.find((f) => f.columna === 'fecha')
          setDesde(fecha?.valor || hoyLocal())
          setHasta(fecha?.valorHasta || fecha?.valor || hoyLocal())
        }}
        filtrosIniciales={[{ column: 'fecha', operator: 'between', value: hoyLocal(), valueTo: hoyLocal() }]}
        cardIcon={Wallet}
        searchPlaceholder="Buscar por operación, monto o estado..."
        empty={cargando ? 'Cargando movimientos...' : 'No hay movimientos en estas fechas.'}
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
