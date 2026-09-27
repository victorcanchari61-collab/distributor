import { useEffect, useState } from 'react'
import { ArrowLeftRight, Smartphone, Wallet } from 'lucide-react'
import { Alert, Badge, FilaStats, StatCard, SysDataTable, useToast } from '../../components/ui'
import type { BadgeTone, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaHora, hoyLocal } from '../../lib/fechas'
import { useRealtime } from '../../lib/realtime'
import { miCajaApi } from './miCajaApi'
import type { MovimientoDigital } from './miCajaApi'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

const METODOS: Record<string, string> = {
  BILLETERA_DIGITAL: 'Billetera digital',
  TRANSFERENCIA: 'Transferencia',
}

/*
 * Un cobro digital se busca en el banco por su número de operación: queda por
 * verificar hasta que alguien lo encuentra, y si no aparece se rechaza y se
 * descuenta en la planilla de quien lo cobró. Un pago a proveedor no se
 * verifica: solo está vigente o anulado.
 */
const ESTADOS: { value: string; label: string; tono: BadgeTone }[] = [
  { value: 'PENDIENTE', label: 'Por verificar', tono: 'warning' },
  { value: 'VERIFICADO', label: 'Verificado', tono: 'success' },
  { value: 'RECHAZADO', label: 'Rechazado', tono: 'danger' },
  { value: 'VIGENTE', label: 'Vigente', tono: 'success' },
  { value: 'ANULADO', label: 'Anulado', tono: 'neutral' },
]

const estadoDe = (m: MovimientoDigital) => (m.anulado ? 'ANULADO' : (m.estadoVerificacion ?? 'VIGENTE'))

/**
 * Lo que la persona cobró o pagó por Yape, Plin o transferencia. No está en su
 * caja —esa plata va directo al banco del método— y por eso no cuenta para el
 * cierre, pero es suyo: tiene que poder ver qué cobró y a qué cuenta entró.
 */
export function MisDigitalesTab() {
  const toast = useToast()
  const [movimientos, setMovimientos] = useState<MovimientoDigital[]>([])
  const [cargando, setCargando] = useState(true)
  const [desde, setDesde] = useState(hoyLocal())
  const [hasta, setHasta] = useState(hoyLocal())
  const [recarga, setRecarga] = useState(0)

  useEffect(() => {
    let vigente = true
    setCargando(true)
    miCajaApi
      .digitales(desde, hasta)
      .then((m) => vigente && setMovimientos(m))
      .catch((e) => toast.error(e instanceof ApiError ? e.message : 'No pudimos cargar los cobros digitales.'))
      .finally(() => vigente && setCargando(false))
    return () => {
      vigente = false
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [desde, hasta, recarga])

  // Un cobro o pago nuevo, o uno anulado, cambia la lista.
  useRealtime(['notasventa', 'compras', 'cuentasfinancieras'], () => setRecarga((n) => n + 1))

  // Lo rechazado no llegó al banco: no cuenta como cobrado, se te descuenta.
  const cobros = movimientos.filter((m) => m.tipo === 'COBRO' && !m.anulado && m.estadoVerificacion !== 'RECHAZADO')
  const porVerificar = cobros.filter((m) => m.estadoVerificacion === 'PENDIENTE').length
  const rechazados = movimientos.filter((m) => !m.anulado && m.estadoVerificacion === 'RECHAZADO')
  const pagos = movimientos.filter((m) => m.tipo === 'PAGO' && !m.anulado)
  const suma = (lista: MovimientoDigital[]) => lista.reduce((s, m) => s + m.monto, 0)

  const columns: DataTableColumn<MovimientoDigital>[] = [
    { key: 'fecha', label: 'Fecha', filterType: 'date', render: (row) => fechaHora(row.fecha) },
    {
      key: 'tipo',
      label: 'Tipo',
      filterType: 'select',
      filterOptions: [
        { value: 'COBRO', label: 'Cobro' },
        { value: 'PAGO', label: 'Pago' },
      ],
      render: (row) => <Badge tone={row.tipo === 'COBRO' ? 'success' : 'warning'}>{row.tipo === 'COBRO' ? 'Cobro' : 'Pago'}</Badge>,
    },
    { key: 'documento', label: 'Documento', filterable: false },
    { key: 'contraparte', label: 'Cliente / proveedor', filterable: false, render: (row) => row.contraparte ?? '—' },
    {
      key: 'metodoTipo',
      label: 'Método',
      filterType: 'select',
      filterOptions: Object.entries(METODOS).map(([value, label]) => ({ value, label })),
      render: (row) => row.metodoPago,
    },
    {
      key: 'monto',
      label: 'Monto',
      align: 'right',
      filterable: false,
      render: (row) => (
        <span className={row.anulado || row.estadoVerificacion === 'RECHAZADO' ? 'text-ink-soft line-through' : ''}>
          {row.tipo === 'COBRO' ? '+' : '-'}
          {soles(row.monto)}
        </span>
      ),
    },
    { key: 'cuenta', label: 'Cuenta', filterable: false, render: (row) => row.cuenta ?? '—' },
    {
      key: 'numeroOperacion',
      label: 'N° operación',
      filterable: false,
      render: (row) => (row.numeroOperacion ? <span className="font-mono">{row.numeroOperacion}</span> : '—'),
    },
    {
      key: 'anulado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: ESTADOS.map(({ value, label }) => ({ value, label })),
      value: (row) => estadoDe(row),
      render: (row) => {
        const e = ESTADOS.find((x) => x.value === estadoDe(row))!
        return <Badge tone={e.tono}>{e.label}</Badge>
      },
    },
  ]

  return (
    <div className="space-y-5">
      <p className="text-sm text-ink-soft">
        Lo que cobraste o pagaste por Yape, Plin o transferencia. No está en tu caja —esa plata entra directo a la cuenta del
        banco— y por eso no cuenta para tu cierre. Cada cobro se busca en el banco por su número de operación.
      </p>

      {rechazados.length > 0 && (
        <Alert tone="warning">
          {rechazados.length === 1 ? 'Un cobro no apareció' : `${rechazados.length} cobros no aparecieron`} en el banco:{' '}
          {soles(suma(rechazados))} se te descuentan en tu planilla.
        </Alert>
      )}

      <FilaStats>
        <StatCard
          label="Cobrado digital"
          value={soles(suma(cobros))}
          icon={<Wallet size={18} />}
          tono="sys"
          hint={
            porVerificar > 0
              ? `${cobros.length} ${cobros.length === 1 ? 'cobro' : 'cobros'}, ${porVerificar} por verificar`
              : `${cobros.length} ${cobros.length === 1 ? 'cobro' : 'cobros'} en estas fechas`
          }
        />
        <StatCard
          label="Por billetera"
          value={soles(suma(cobros.filter((m) => m.metodoTipo === 'BILLETERA_DIGITAL')))}
          icon={<Smartphone size={18} />}
          tono="success"
          hint="Yape, Plin"
        />
        <StatCard
          label="Por transferencia"
          value={soles(suma(cobros.filter((m) => m.metodoTipo === 'TRANSFERENCIA')))}
          icon={<ArrowLeftRight size={18} />}
          tono="success"
          hint={pagos.length > 0 ? `Pagaste ${soles(suma(pagos))} a proveedores` : 'Directo al banco'}
        />
      </FilaStats>

      <SysDataTable
        columns={columns}
        rows={movimientos}
        onConsulta={(q) => {
          const fecha = q.filtros.find((f) => f.columna === 'fecha')
          setDesde(fecha?.valor || hoyLocal())
          setHasta(fecha?.valorHasta || fecha?.valor || hoyLocal())
        }}
        cardIcon={Smartphone}
        searchPlaceholder="Buscar por documento o cliente..."
        empty={cargando ? 'Cargando...' : 'No hiciste cobros ni pagos digitales en estas fechas.'}
      />
    </div>
  )
}
