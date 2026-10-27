import { useCallback, useEffect, useMemo, useState } from 'react'
import { MapPinned, TrendingDown, TriangleAlert, Users, Wallet } from 'lucide-react'
import { Alert, ListPage, StatCard, Tabs } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { useRealtime } from '../../lib/realtime'
import type { PeriodoCrm } from './crmApi'
import { crmReportesApi } from './crmReportesApi'
import type { AgruparZonas, ZonaCrm, ZonasCrm } from './crmReportesApi'
import { PERIODOS, colorCambio, porcentaje, rango, soles, solesConSigno } from './formato'

const AGRUPAR: { id: AgruparZonas; label: string; singular: string }[] = [
  { id: 'mercado', label: 'Por mercado', singular: 'Mercado' },
  { id: 'ruta', label: 'Por ruta', singular: 'Ruta' },
]

/**
 * Mercados y rutas: la misma caída de ventas de la cartera, pero juntando a los clientes por zona.
 *
 * Sirve para ver si el problema es de un cliente o de toda una zona: un mercado donde bajan varios
 * a la vez no se arregla llamando de a uno.
 */
export function ZonasPage() {
  const [agrupar, setAgrupar] = useState<AgruparZonas>('mercado')
  const [periodo, setPeriodo] = useState<PeriodoCrm>('mes')
  const [datos, setDatos] = useState<ZonasCrm | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setDatos(await crmReportesApi.zonas(periodo, agrupar))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las zonas.')
    } finally {
      setCargando(false)
    }
  }, [periodo, agrupar])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['notasventa', 'pedidos', 'clientes', 'devoluciones', 'mercados', 'rutas'], cargar)

  const singular = AGRUPAR.find((a) => a.id === agrupar)?.singular ?? 'Zona'
  const contra = PERIODOS.find((p) => p.id === periodo)?.contra

  const columns: DataTableColumn<ZonaCrm>[] = useMemo(
    () => [
      {
        key: 'nombre',
        label: singular,
        filterable: false,
        render: (row) => <span className="font-medium text-ink">{row.nombre}</span>,
      },
      {
        key: 'clientes',
        label: 'Clientes',
        align: 'right',
        filterable: false,
        value: (row) => row.clientes,
        render: (row) => (
          <span className="flex flex-col items-end">
            <span>{row.clientes}</span>
            <span className="text-xs text-ink-soft">{row.conVentas} compraron</span>
          </span>
        ),
      },
      {
        key: 'criticos',
        label: 'Críticos',
        align: 'right',
        filterable: false,
        value: (row) => row.criticos,
        render: (row) => (row.criticos > 0 ? <span className="font-semibold text-red-600">{row.criticos}</span> : '—'),
      },
      {
        key: 'altos',
        label: 'Altos',
        align: 'right',
        filterable: false,
        value: (row) => row.altos,
        render: (row) => (row.altos > 0 ? <span className="font-semibold text-amber-600">{row.altos}</span> : '—'),
      },
      {
        key: 'inactivos',
        label: 'Inactivos',
        align: 'right',
        filterable: false,
        value: (row) => row.inactivos,
        render: (row) => (row.inactivos > 0 ? row.inactivos : '—'),
      },
      {
        key: 'actual',
        label: 'Ahora',
        align: 'right',
        filterable: false,
        value: (row) => row.actual,
        render: (row) => soles(row.actual),
      },
      {
        key: 'anterior',
        label: 'Antes',
        align: 'right',
        filterable: false,
        value: (row) => row.anterior,
        render: (row) => <span className="text-ink-soft">{soles(row.anterior)}</span>,
      },
      {
        key: 'diferencia',
        label: 'Cambio',
        align: 'right',
        filterable: false,
        value: (row) => row.diferencia,
        render: (row) => (
          <span className={`flex flex-col items-end ${colorCambio(row.diferencia)}`}>
            <span className="font-semibold">{solesConSigno(row.diferencia)}</span>
            <span className="text-xs">{porcentaje(row.variacion)}</span>
          </span>
        ),
      },
      {
        key: 'ventaPerdida',
        label: 'Venta perdida',
        align: 'right',
        filterable: false,
        value: (row) => row.ventaPerdida,
        render: (row) =>
          row.ventaPerdida > 0 ? <span className="text-red-600">{soles(row.ventaPerdida)}</span> : '—',
      },
      {
        key: 'saldo',
        label: 'Debe',
        align: 'right',
        filterable: false,
        value: (row) => row.saldoPorCobrar,
        render: (row) => (row.saldoPorCobrar > 0 ? soles(row.saldoPorCobrar) : '—'),
      },
    ],
    [singular],
  )

  const items = datos?.items ?? []
  const peor = items.find((z) => z.ventaPerdida > 0)
  const totalPerdida = items.reduce((s, z) => s + z.ventaPerdida, 0)
  const enRiesgo = items.reduce((s, z) => s + z.criticos + z.altos, 0)
  const clientes = items.reduce((s, z) => s + z.clientes, 0)
  const actual = items.reduce((s, z) => s + z.actual, 0)
  const anterior = items.reduce((s, z) => s + z.anterior, 0)

  return (
    <ListPage
      icon={<MapPinned size={20} />}
      title="Mercados y rutas"
      description="Cómo van las ventas de cada zona frente al periodo anterior."
      alert={
        error ? (
          <Alert>{error}</Alert>
        ) : datos?.soloPropios ? (
          <Alert tone="info">Ves solo los clientes de tus rutas y los que tienes asignados.</Alert>
        ) : undefined
      }
      banner={
        <div className="space-y-2">
          <div className="flex flex-wrap items-center gap-x-6 gap-y-1">
            <Tabs
              items={AGRUPAR.map((a) => ({ id: a.id, label: a.label }))}
              active={agrupar}
              onChange={(id) => setAgrupar(id as AgruparZonas)}
            />
            <Tabs
              items={PERIODOS.map((p) => ({ id: p.id, label: p.label }))}
              active={periodo}
              onChange={(id) => setPeriodo(id as PeriodoCrm)}
            />
          </div>
          {datos && (
            <p className="text-xs text-ink-soft">
              Del {rango(datos.ventanas.actual)} frente a {contra} ({rango(datos.ventanas.anterior)}). Ventas con
              IGV, sin anuladas ni recojos.
            </p>
          )}
        </div>
      }
      stats={
        <>
          <StatCard
            label="Venta perdida"
            value={soles(totalPerdida)}
            hint={peor ? `la mayor, en ${peor.nombre}` : 'ninguna zona bajó'}
            icon={<TrendingDown size={18} />}
            tono="warning"
          />
          <StatCard
            label="Clientes en riesgo"
            value={String(enRiesgo)}
            hint="críticos y altos"
            icon={<TriangleAlert size={18} />}
            tono="danger"
          />
          <StatCard
            label="Vendido en el periodo"
            value={soles(actual)}
            hint={`antes ${soles(anterior)}`}
            trend={anterior > 0 ? Math.round(((actual - anterior) / anterior) * 1000) / 10 : undefined}
            icon={<Wallet size={18} />}
          />
          <StatCard
            label="Clientes activos"
            value={String(clientes)}
            hint={`en ${items.length} ${agrupar === 'mercado' ? 'mercados' : 'rutas'}`}
            icon={<Users size={18} />}
            tono="neutral"
          />
        </>
      }
      columns={columns}
      rows={items}
      rowKey="nombre"
      cardIcon={MapPinned}
      searchPlaceholder={`Buscar ${singular.toLowerCase()}...`}
      empty={cargando ? 'Cargando zonas...' : 'No hay clientes con ventas en estos periodos.'}
      note="Las zonas con más venta perdida salen primero. 'Sin mercado' o 'Sin ruta' junta a los clientes que no tienen una asignada."
    />
  )
}
