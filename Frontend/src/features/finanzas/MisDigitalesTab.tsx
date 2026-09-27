import { useEffect, useState } from 'react'
import { ArrowLeftRight, Smartphone, Wallet } from 'lucide-react'
import { Badge, StatCard, SysDataTable, useToast } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { desplazarDias, fechaHora, hoyLocal } from '../../lib/fechas'
import { useRealtime } from '../../lib/realtime'
import { miCajaApi } from './miCajaApi'
import type { MovimientoDigital } from './miCajaApi'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

const METODOS: Record<string, string> = {
  BILLETERA_DIGITAL: 'Billetera digital',
  TRANSFERENCIA: 'Transferencia',
}

/**
 * Lo que la persona cobró o pagó por Yape, Plin o transferencia. No está en su
 * caja —esa plata va directo al banco del método— y por eso no cuenta para el
 * cierre, pero es suyo: tiene que poder ver qué cobró y a qué cuenta entró.
 */
export function MisDigitalesTab() {
  const toast = useToast()
  const [movimientos, setMovimientos] = useState<MovimientoDigital[]>([])
  const [cargando, setCargando] = useState(true)
  const [desde, setDesde] = useState(desplazarDias(-30))
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

  const cobros = movimientos.filter((m) => m.tipo === 'COBRO' && !m.anulado)
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
        <span className={row.anulado ? 'text-ink-soft line-through' : ''}>
          {row.tipo === 'COBRO' ? '+' : '-'}
          {soles(row.monto)}
        </span>
      ),
    },
    { key: 'cuenta', label: 'Cuenta', filterable: false, render: (row) => row.cuenta ?? '—' },
    {
      key: 'anulado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'Vigente', label: 'Vigente' },
        { value: 'Anulado', label: 'Anulado' },
      ],
      value: (row) => (row.anulado ? 'Anulado' : 'Vigente'),
      render: (row) => (row.anulado ? <Badge tone="neutral">Anulado</Badge> : <Badge tone="success">Vigente</Badge>),
    },
  ]

  return (
    <div className="space-y-5">
      <p className="text-sm text-ink-soft">
        Lo que cobraste o pagaste por Yape, Plin o transferencia. No está en tu caja —esa plata entra directo a la cuenta del
        banco— y por eso no cuenta para tu cierre.
      </p>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <StatCard
          label="Cobrado digital"
          value={soles(suma(cobros))}
          icon={<Wallet size={18} />}
          tono="sys"
          hint={`${cobros.length} ${cobros.length === 1 ? 'cobro' : 'cobros'} en estas fechas`}
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
      </div>

      <SysDataTable
        columns={columns}
        rows={movimientos}
        onConsulta={(q) => {
          const fecha = q.filtros.find((f) => f.columna === 'fecha')
          setDesde(fecha?.valor || desplazarDias(-30))
          setHasta(fecha?.valorHasta || fecha?.valor || hoyLocal())
        }}
        cardIcon={Smartphone}
        searchPlaceholder="Buscar por documento o cliente..."
        empty={cargando ? 'Cargando...' : 'No hiciste cobros ni pagos digitales en estas fechas.'}
      />
    </div>
  )
}
