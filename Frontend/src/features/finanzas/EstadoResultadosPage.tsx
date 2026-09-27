import { useEffect, useState } from 'react'
import type { ReactNode } from 'react'
import { Calculator, Download, FileBarChart, Receipt, TrendingDown, TrendingUp } from 'lucide-react'
import { Alert, Button, FilaStats, StatCard, cn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { exportarExcel } from '../../lib/excel'
import { fechaCorta } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { Encabezado, useTablero } from '../dashboard/comun'
import { estadoResultadosApi } from './estadoResultadosApi'
import type { EstadoResultadosResponse, LineaResultado } from './estadoResultadosApi'

const soles = (n: number) =>
  `S/ ${n.toLocaleString('es-PE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`

const pct = (n: number | null) => (n === null ? '—' : `${n.toFixed(1)}%`)

/**
 * Si el negocio gana, en un rango de fechas.
 *
 * Arriba lo vendido menos lo que costó (la utilidad bruta, la misma de Mis
 * ganancias), después los demás ingresos y gastos de operar, y abajo la
 * utilidad operativa. Lo no operativo —préstamos, aportes, retiros— va en un
 * bloque aparte, solo para mirar: pedir un préstamo no es ganar plata.
 *
 * Es un reporte de gestión, no tributario: las ventas van sin IGV y los gastos
 * al monto pagado.
 */
export function EstadoResultadosPage() {
  const { puede } = usePermisos()
  const tablero = useTablero('mes')
  const [estado, setEstado] = useState<EstadoResultadosResponse | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [recarga, setRecarga] = useState(0)

  useEffect(() => {
    let vigente = true
    setCargando(true)
    estadoResultadosApi
      .calcular(tablero.desde, tablero.hasta)
      .then((e) => {
        if (!vigente) return
        setEstado(e)
        setError('')
      })
      .catch((e) => vigente && setError(e instanceof ApiError ? e.message : 'No pudimos calcular el estado de resultados.'))
      .finally(() => vigente && setCargando(false))
    return () => {
      vigente = false
    }
  }, [tablero.desde, tablero.hasta, tablero.version, recarga])

  // Una venta, un gasto o un pago cambian el resultado: se recalcula solo.
  useRealtime(['notasventa', 'cuentasfinancieras', 'gastosoperativos', 'planillas'], () => setRecarga((n) => n + 1))

  const exportar = () => {
    if (!estado) return
    const fila = (concepto: string, monto: number | string) => ({ Concepto: concepto, Monto: monto })
    const renglones = (lista: LineaResultado[], signo: number) =>
      lista.map((l) => fila(`   ${l.concepto}`, signo * l.monto))

    exportarExcel(`estado-resultados-${estado.desde.slice(0, 10)}-al-${estado.hasta.slice(0, 10)}`, [
      fila(`Estado de resultados del ${fechaCorta(estado.desde)} al ${fechaCorta(estado.hasta)}`, ''),
      fila('Ventas (con IGV)', estado.ventasBrutas),
      fila('(-) IGV', -estado.igv),
      fila('Ventas netas', estado.ventasNetas),
      fila('(-) Costo de lo vendido', -estado.costoVentas),
      fila('UTILIDAD BRUTA', estado.utilidadBruta),
      fila('(+) Otros ingresos operativos', estado.totalOtrosIngresos),
      ...renglones(estado.otrosIngresos, 1),
      fila('(-) Gastos operativos', -estado.totalGastosOperativos),
      ...renglones(estado.gastosOperativos, -1),
      fila('UTILIDAD OPERATIVA', estado.utilidadOperativa),
      fila('', ''),
      fila('No operativo (informativo, no suma a la utilidad)', ''),
      fila('(+) Ingresos no operativos', estado.totalIngresosNoOperativos),
      ...renglones(estado.ingresosNoOperativos, 1),
      fila('(-) Egresos no operativos', -estado.totalEgresosNoOperativos),
      ...renglones(estado.egresosNoOperativos, -1),
    ])
  }

  const e = estado

  return (
    <div className="space-y-5">
      <Encabezado
        icono={<FileBarChart size={20} />}
        titulo="Estado de resultados"
        descripcion="Si el negocio gana: lo vendido sin IGV, menos lo que costó, menos los gastos de operar. Préstamos, aportes y retiros van aparte y no suman."
        tablero={tablero}
        acciones={
          puede('finanzas.resultados', 'exportar') && (
            <Button size="sm" variant="secondary" onClick={exportar} disabled={!e} iconRight={<Download size={15} />}>
              Exportar
            </Button>
          )
        }
      />

      {error && <Alert>{error}</Alert>}
      {e && e.lineasSinCosto > 0 && (
        <Alert tone="warning">
          {e.lineasSinCosto} {e.lineasSinCosto === 1 ? 'línea vendida no tiene costo' : 'líneas vendidas no tienen costo'}: ahí
          el costo sale en cero y la utilidad queda inflada.
        </Alert>
      )}

      <FilaStats className={cn(cargando && !e && 'opacity-60')}>
        <StatCard
          label="Ventas netas"
          value={e ? soles(e.ventasNetas) : '—'}
          icon={<Receipt size={18} />}
          tono="sys"
          hint={e ? `${e.ventas} ${e.ventas === 1 ? 'venta' : 'ventas'}, sin IGV` : undefined}
        />
        <StatCard
          label="Utilidad bruta"
          value={e ? soles(e.utilidadBruta) : '—'}
          icon={<TrendingUp size={18} />}
          tono={e && e.utilidadBruta < 0 ? 'danger' : 'success'}
          hint={e ? `Margen ${pct(e.margenBruto)}` : undefined}
        />
        <StatCard
          label="Gastos operativos"
          value={e ? soles(e.totalGastosOperativos) : '—'}
          icon={<TrendingDown size={18} />}
          tono="warning"
          hint={e ? `Otros ingresos ${soles(e.totalOtrosIngresos)}` : undefined}
        />
        <StatCard
          label="Utilidad operativa"
          value={e ? soles(e.utilidadOperativa) : '—'}
          icon={<Calculator size={18} />}
          tono={e && e.utilidadOperativa < 0 ? 'danger' : 'success'}
          hint={e ? `Margen ${pct(e.margenOperativo)}` : undefined}
        />
      </FilaStats>

      {e && (
        <div className="grid gap-4 lg:grid-cols-3">
          <section className="rounded-panel border border-line bg-white lg:col-span-2">
            <h2 className="border-b border-line px-4 py-3 text-sm font-semibold text-ink">
              Del {fechaCorta(e.desde)} al {fechaCorta(e.hasta)}
            </h2>
            <div className="divide-y divide-line">
              <Renglon concepto="Ventas (con IGV)" monto={e.ventasBrutas} />
              <Renglon concepto="(−) IGV" monto={-e.igv} tenue />
              <Renglon concepto="Ventas netas" monto={e.ventasNetas} fuerte />
              <Renglon concepto="(−) Costo de lo vendido" monto={-e.costoVentas} />
              <Total concepto="Utilidad bruta" monto={e.utilidadBruta} margen={e.margenBruto} />
              <Bloque titulo="(+) Otros ingresos operativos" total={e.totalOtrosIngresos} lineas={e.otrosIngresos} signo={1} />
              <Bloque titulo="(−) Gastos operativos" total={e.totalGastosOperativos} lineas={e.gastosOperativos} signo={-1} />
              <Total concepto="Utilidad operativa" monto={e.utilidadOperativa} margen={e.margenOperativo} grande />
            </div>
          </section>

          <section className="self-start rounded-panel border border-line bg-white">
            <h2 className="border-b border-line px-4 py-3 text-sm font-semibold text-ink">No operativo</h2>
            <p className="px-4 pt-3 text-xs text-ink-soft">
              Préstamos, aportes, retiros y activos. Mueven plata, pero no son ganancia ni gasto del negocio: no suman a la
              utilidad.
            </p>
            <div className="divide-y divide-line">
              <Bloque titulo="(+) Ingresos" total={e.totalIngresosNoOperativos} lineas={e.ingresosNoOperativos} signo={1} />
              <Bloque titulo="(−) Egresos" total={e.totalEgresosNoOperativos} lineas={e.egresosNoOperativos} signo={-1} />
              <Renglon concepto="Neto no operativo" monto={e.totalIngresosNoOperativos - e.totalEgresosNoOperativos} fuerte />
            </div>
          </section>
        </div>
      )}
    </div>
  )
}

/** Un renglón con su monto a la derecha; los negativos en rojo. */
function Renglon({
  concepto,
  monto,
  fuerte,
  tenue,
  sangria,
  detalle,
}: {
  concepto: ReactNode
  monto: number
  fuerte?: boolean
  tenue?: boolean
  sangria?: boolean
  detalle?: string
}) {
  return (
    <div className={cn('flex items-baseline justify-between gap-3 px-4 py-2 text-sm', sangria && 'pl-8')}>
      <span className={cn(fuerte ? 'font-semibold text-ink' : tenue ? 'text-ink-soft' : 'text-ink')}>
        {concepto}
        {detalle && <span className="ml-1.5 text-xs text-ink-soft">{detalle}</span>}
      </span>
      <span className={cn('tabular-nums', fuerte && 'font-semibold', monto < 0 ? 'text-red-600' : tenue ? 'text-ink-soft' : 'text-ink')}>
        {soles(monto)}
      </span>
    </div>
  )
}

/** Una utilidad: el renglón que resume lo de arriba, con su margen. */
function Total({
  concepto,
  monto,
  margen,
  grande,
}: {
  concepto: string
  monto: number
  margen: number | null
  grande?: boolean
}) {
  return (
    <div className="flex items-baseline justify-between gap-3 bg-surface-alt px-4 py-3">
      <span className={cn('font-bold uppercase tracking-wide text-ink', grande ? 'text-sm' : 'text-xs')}>
        {concepto}
        <span className="ml-2 text-xs font-medium normal-case text-ink-soft">margen {pct(margen)}</span>
      </span>
      <span className={cn('font-bold tabular-nums', grande ? 'text-lg' : 'text-base', monto < 0 ? 'text-red-600' : 'text-emerald-700')}>
        {soles(monto)}
      </span>
    </div>
  )
}

/** Un grupo de categorías con su total arriba y cada una debajo. */
function Bloque({
  titulo,
  total,
  lineas,
  signo,
}: {
  titulo: string
  total: number
  lineas: LineaResultado[]
  signo: 1 | -1
}) {
  return (
    <div>
      <Renglon concepto={titulo} monto={signo * total} fuerte />
      {lineas.length === 0 ? (
        <p className="px-8 pb-2 text-xs text-ink-soft">Nada en este rango.</p>
      ) : (
        lineas.map((l) => (
          <Renglon
            key={l.concepto}
            concepto={l.concepto}
            monto={signo * l.monto}
            tenue
            sangria
            detalle={`${l.movimientos} ${l.movimientos === 1 ? 'mov.' : 'movs.'}`}
          />
        ))
      )}
    </div>
  )
}
