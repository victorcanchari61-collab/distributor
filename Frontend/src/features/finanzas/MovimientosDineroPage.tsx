import { useCallback, useEffect, useState } from 'react'
import { ArrowLeftRight, Ban, Download, Landmark, Plus, Scale, TrendingDown, TrendingUp } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  ListPage,
  RowAction,
  StatCard,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { BadgeTone, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { exportarExcel } from '../../lib/excel'
import { desplazarDias, fechaHora, hoyLocal } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { gastoOperativoApi } from './gastoOperativoApi'
import type { CategoriaOpcion } from './gastoOperativoApi'
import { movimientoDineroApi } from './movimientoDineroApi'
import type { CuentaMovimiento, MovimientoDineroResponse, OrigenDinero } from './movimientoDineroApi'
import { NuevoMovimientoModal } from './NuevoMovimientoModal'

const soles = (n: number) => `S/ ${n.toFixed(2)}`
const redondear = (n: number) => Math.round(n * 100) / 100

const ORIGENES: { value: OrigenDinero; label: string; tono: BadgeTone }[] = [
  { value: 'OPERATIVO', label: 'Operativo', tono: 'sys' },
  { value: 'NO_OPERATIVO', label: 'No operativo', tono: 'warning' },
  { value: 'INTERNO', label: 'Interno', tono: 'neutral' },
]

type Estado = 'VIGENTE' | 'ANULADO' | 'ANULACION'
const estadoDe = (m: MovimientoDineroResponse): Estado => (m.esReversa ? 'ANULACION' : m.anulado ? 'ANULADO' : 'VIGENTE')
const ESTADOS: Record<Estado, { label: string; tono: BadgeTone }> = {
  VIGENTE: { label: 'Vigente', tono: 'success' },
  ANULADO: { label: 'Anulado', tono: 'neutral' },
  ANULACION: { label: 'Anulación', tono: 'neutral' },
}

const opcionesDe = (valores: (string | null)[]) =>
  [...new Set(valores.filter((v): v is string => !!v))]
    .sort((a, b) => a.localeCompare(b, 'es'))
    .map((v) => ({ value: v, label: v }))

/**
 * El kardex del dinero: todo lo que entra y sale de las cajas y los bancos,
 * venga de donde venga — cobros de venta, ingresos y egresos a mano, cierres,
 * préstamos, planilla —, con el saldo de la cuenta después de cada uno.
 */
export function MovimientosDineroPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()
  const [movimientos, setMovimientos] = useState<MovimientoDineroResponse[]>([])
  const [cuentas, setCuentas] = useState<CuentaMovimiento[]>([])
  const [categorias, setCategorias] = useState<CategoriaOpcion[]>([])
  const [desde, setDesde] = useState(desplazarDias(-30))
  const [hasta, setHasta] = useState(hoyLocal())
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [nuevoAbierto, setNuevoAbierto] = useState(false)

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setMovimientos(await movimientoDineroApi.listar(desde, hasta))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los movimientos.')
    } finally {
      setCargando(false)
    }
  }, [desde, hasta])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['cuentasfinancieras', 'gastosoperativos', 'financiamientos', 'cierrescaja', 'planillas'], cargar)

  const abrirNuevo = async () => {
    try {
      const [c, cat] = await Promise.all([movimientoDineroApi.cuentas(), gastoOperativoApi.categoriasOpciones()])
      setCuentas(c)
      setCategorias(cat)
      setNuevoAbierto(true)
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos cargar las cuentas y categorías.')
    }
  }

  const anular = (m: MovimientoDineroResponse) =>
    confirmar({
      titulo: 'Anular movimiento',
      mensaje: `${m.concepto}: revierte ${soles(m.monto)} en ${m.cuenta}. No se puede deshacer.`,
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        try {
          await gastoOperativoApi.anular(m.movimientoOperativoId!)
          await cargar()
          toast.exito('Movimiento anulado')
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos anular el movimiento.')
        }
      },
    })

  // Lo interno (transferencias, saldos iniciales) no es ingreso ni egreso del
  // negocio. Una anulación resta de lo que anuló: la reversa de un ingreso sale
  // de la cuenta, pero baja los ingresos — no sube los egresos.
  const totales = { ingresosOp: 0, egresosOp: 0, ingresosNo: 0, egresosNo: 0 }
  for (const m of movimientos) {
    if (m.origen === 'INTERNO') continue
    const tipo = m.esReversa ? (m.tipo === 'INGRESO' ? 'EGRESO' : 'INGRESO') : m.tipo
    const monto = m.esReversa ? -m.monto : m.monto
    if (m.origen === 'OPERATIVO') {
      if (tipo === 'INGRESO') totales.ingresosOp += monto
      else totales.egresosOp += monto
    } else if (tipo === 'INGRESO') totales.ingresosNo += monto
    else totales.egresosNo += monto
  }
  const resultado = redondear(totales.ingresosOp - totales.egresosOp)
  const netoNoOperativo = redondear(totales.ingresosNo - totales.egresosNo)

  const exportar = () =>
    exportarExcel(
      `movimientos_${desde}_${hasta}`,
      movimientos.map((m) => ({
        Fecha: fechaHora(m.fecha),
        Cuenta: m.cuenta,
        Tipo: m.tipo === 'INGRESO' ? 'Ingreso' : 'Egreso',
        Concepto: m.concepto,
        Categoría: m.categoria ?? '',
        Origen: ORIGENES.find((o) => o.value === m.origen)?.label ?? m.origen,
        Monto: m.tipo === 'INGRESO' ? m.monto : -m.monto,
        Saldo: m.saldoResultante,
        Estado: ESTADOS[estadoDe(m)].label,
        Detalle: m.observacion ?? '',
        Usuario: m.usuario ?? '',
      })),
    )

  const columns: DataTableColumn<MovimientoDineroResponse>[] = [
    { key: 'fecha', label: 'Fecha', filterType: 'date', render: (row) => fechaHora(row.fecha) },
    { key: 'cuenta', label: 'Cuenta', filterType: 'select', filterOptions: opcionesDe(movimientos.map((m) => m.cuenta)) },
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
      filterable: false,
      render: (row) => (
        <div className="min-w-0">
          <p className={`text-ink ${row.anulado ? 'line-through opacity-60' : ''}`}>{row.concepto}</p>
          {row.observacion && !row.esReversa && <p className="text-xs text-ink-soft">{row.observacion}</p>}
        </div>
      ),
    },
    {
      key: 'categoria',
      label: 'Categoría',
      filterType: 'select',
      filterOptions: opcionesDe(movimientos.map((m) => m.categoria)),
      render: (row) => row.categoria ?? '—',
    },
    {
      key: 'origen',
      label: 'Origen',
      filterType: 'select',
      filterOptions: ORIGENES.map(({ value, label }) => ({ value, label })),
      render: (row) => {
        const o = ORIGENES.find((x) => x.value === row.origen)
        return <Badge tone={o?.tono ?? 'neutral'}>{o?.label ?? row.origen}</Badge>
      },
    },
    {
      key: 'monto',
      label: 'Monto',
      align: 'right',
      filterable: false,
      render: (row) => (
        <span className={row.tipo === 'INGRESO' ? 'text-emerald-700' : 'text-red-700'}>
          {row.tipo === 'INGRESO' ? '+' : '-'}
          {soles(row.monto)}
        </span>
      ),
    },
    { key: 'saldoResultante', label: 'Saldo', align: 'right', filterable: false, render: (row) => soles(row.saldoResultante) },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: Object.entries(ESTADOS).map(([value, e]) => ({ value, label: e.label })),
      value: (row) => estadoDe(row),
      render: (row) => {
        const e = ESTADOS[estadoDe(row)]
        return <Badge tone={e.tono}>{e.label}</Badge>
      },
    },
  ]

  return (
    <ListPage
      icon={<ArrowLeftRight size={20} />}
      title="Movimientos"
      description="Todo lo que entra y sale de las cajas y los bancos, venga de donde venga, con el saldo de la cuenta después de cada movimiento."
      actions={
        <>
          {puede('finanzas.movimientos', 'exportar') && (
            <Button size="sm" variant="secondary" onClick={exportar} disabled={movimientos.length === 0} iconRight={<Download size={15} />}>
              Exportar
            </Button>
          )}
          {puede('finanzas.movimientos', 'crear') && (
            <Button size="sm" onClick={() => void abrirNuevo()} iconRight={<Plus size={15} />}>
              Nuevo movimiento
            </Button>
          )}
        </>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Ingresos operativos" value={soles(redondear(totales.ingresosOp))} icon={<TrendingUp size={18} />} tono="success" />
          <StatCard label="Egresos operativos" value={soles(redondear(totales.egresosOp))} icon={<TrendingDown size={18} />} tono="danger" />
          <StatCard
            label="Resultado operativo"
            value={soles(resultado)}
            icon={<Scale size={18} />}
            tono={resultado < 0 ? 'danger' : 'sys'}
            hint="Ingresos menos egresos operativos"
          />
          <StatCard
            label="Neto no operativo"
            value={soles(netoNoOperativo)}
            icon={<Landmark size={18} />}
            tono="warning"
            hint="Préstamos, aportes, retiros, activos"
          />
        </>
      }
      columns={columns}
      rows={movimientos}
      onConsulta={(q) => {
        const fecha = q.filtros.find((f) => f.columna === 'fecha')
        setDesde(fecha?.valor || desplazarDias(-30))
        setHasta(fecha?.valorHasta || fecha?.valor || hoyLocal())
      }}
      cardIcon={ArrowLeftRight}
      searchPlaceholder="Buscar por concepto..."
      empty={cargando ? 'Cargando movimientos...' : 'No hay movimientos en este período.'}
      rowActions={(row) =>
        row.anulable && puede('finanzas.movimientos', 'anular') ? (
          <RowAction label="Anular" tone="danger" onClick={() => anular(row)}>
            <Ban size={15} />
          </RowAction>
        ) : null
      }
    >
      {nuevoAbierto && (
        <NuevoMovimientoModal
          cuentas={cuentas}
          categorias={categorias}
          onClose={() => setNuevoAbierto(false)}
          onGuardado={async () => {
            setNuevoAbierto(false)
            await cargar()
            toast.exito('Movimiento registrado')
          }}
        />
      )}
      {dialogo}
    </ListPage>
  )
}
