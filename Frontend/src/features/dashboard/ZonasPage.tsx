import { useCallback, useEffect, useMemo, useState } from 'react'
import { MapPinned, TrendingDown, TriangleAlert, Users, Wallet } from 'lucide-react'
import { BarChart, HBarChart, Marco, PALETA, moneda } from '../../components/charts'
import { Alert, ListPage, StatCard, Tabs } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { useRealtime } from '../../lib/realtime'
import { hoyLocal } from '../../lib/fechas'
import { FiltroFechas, inicioDeAnio } from '../crm/filtros'
import { colorCambio, porcentaje, soles, solesConSigno } from '../crm/formato'
import { sinVentasApi } from './sinVentasApi'
import type { AgruparZonas, ZonaCrm, ZonasCrm } from './sinVentasApi'

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
  const [desde, setDesde] = useState(inicioDeAnio())
  const [hasta, setHasta] = useState(hoyLocal())
  const [datos, setDatos] = useState<ZonasCrm | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setDatos(await sinVentasApi.zonas(desde, hasta, agrupar))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las zonas.')
    } finally {
      setCargando(false)
    }
  }, [desde, hasta, agrupar])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['notasventa', 'pedidos', 'clientes', 'devoluciones', 'mercados', 'rutas'], cargar)

  const singular = AGRUPAR.find((a) => a.id === agrupar)?.singular ?? 'Zona'

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
        key: 'enRiesgo',
        label: 'En riesgo',
        align: 'right',
        filterable: false,
        value: (row) => row.enRiesgo,
        render: (row) => (row.enRiesgo > 0 ? <span className="font-semibold text-orange-600">{row.enRiesgo}</span> : '—'),
      },
      {
        key: 'enSeguimiento',
        label: 'En seguimiento',
        align: 'right',
        filterable: false,
        value: (row) => row.enSeguimiento,
        render: (row) => (row.enSeguimiento > 0 ? <span className="font-semibold text-blue-600">{row.enSeguimiento}</span> : '—'),
      },
      {
        key: 'anterior',
        label: 'Venta anterior',
        align: 'right',
        filterable: false,
        value: (row) => row.ventaAnterior,
        render: (row) => <span className="text-ink-soft">{soles(row.ventaAnterior)}</span>,
      },
      {
        key: 'actual',
        label: 'Venta actual',
        align: 'right',
        filterable: false,
        value: (row) => row.ventaActual,
        render: (row) => soles(row.ventaActual),
      },
      {
        key: 'variacion',
        label: 'Variación',
        align: 'right',
        filterable: false,
        value: (row) => row.variacion,
        render: (row) => (
          <span className={`flex flex-col items-end ${colorCambio(row.variacion)}`}>
            <span className="font-semibold">{solesConSigno(row.variacion)}</span>
            <span className="text-xs">{row.caidaPct === null ? '—' : porcentaje(-row.caidaPct)}</span>
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
  // Para los gráficos: las zonas que más venden (hasta 8) y las que más pierden (hasta 6).
  const masVendidas = [...items].sort((a, b) => b.ventaActual + b.ventaAnterior - (a.ventaActual + a.ventaAnterior)).slice(0, 8)
  const conPerdida = items.filter((z) => z.ventaPerdida > 0).sort((a, b) => b.ventaPerdida - a.ventaPerdida).slice(0, 6)
  const peor = items.find((z) => z.ventaPerdida > 0)
  const totalPerdida = items.reduce((s, z) => s + z.ventaPerdida, 0)
  const enRiesgo = items.reduce((s, z) => s + z.criticos + z.enRiesgo, 0)
  const clientes = items.reduce((s, z) => s + z.clientes, 0)
  const actual = items.reduce((s, z) => s + z.ventaActual, 0)
  const anterior = items.reduce((s, z) => s + z.ventaAnterior, 0)

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
          <div className="flex flex-wrap items-end gap-x-6 gap-y-2">
            <Tabs
              items={AGRUPAR.map((a) => ({ id: a.id, label: a.label }))}
              active={agrupar}
              onChange={(id) => setAgrupar(id as AgruparZonas)}
            />
            <FiltroFechas desde={desde} hasta={hasta} onChange={(d, h) => { setDesde(d); setHasta(h) }} />
          </div>
          {datos && (
            <p className="text-xs text-ink-soft">
              Del {datos.periodo.etiqueta} frente al {datos.periodo.etiquetaAnterior}. Ventas con IGV, sin
              anuladas ni recojos.
            </p>
          )}

          {/* Cómo le va a cada zona, de un vistazo: lo vendido ahora contra antes, y dónde se pierde. */}
          <div className="grid gap-4 pt-2 lg:grid-cols-2">
            <Marco
              titulo={`Ventas por ${singular.toLowerCase()}`}
              subtitulo="Lo vendido ahora frente al periodo anterior, en las zonas que más venden"
              cargando={cargando && !datos}
              vacio={masVendidas.length === 0}
              mensajeVacio="No hay ventas en estos periodos"
              alto={220}
              derecha={
                <span className="flex items-center gap-3 text-[11px] text-ink-muted">
                  <span className="flex items-center gap-1.5">
                    <span className="size-2 rounded-sm" style={{ backgroundColor: PALETA[0] }} /> Ahora
                  </span>
                  <span className="flex items-center gap-1.5">
                    <span className="size-2 rounded-sm bg-slate-300" /> Antes
                  </span>
                </span>
              }
            >
              <BarChart
                etiquetas={masVendidas.map((z) => z.nombre)}
                series={[
                  { id: 'antes', nombre: 'Antes', color: '#cbd5e1', valores: masVendidas.map((z) => z.ventaAnterior) },
                  { id: 'ahora', nombre: 'Ahora', color: PALETA[0], valores: masVendidas.map((z) => z.ventaActual) },
                ]}
                formato={(n) => moneda(n)}
                alto={220}
              />
            </Marco>

            <Marco
              titulo={`Dónde se pierde más`}
              subtitulo={`Venta perdida por ${singular.toLowerCase()}, de los clientes que bajaron`}
              cargando={cargando && !datos}
              vacio={conPerdida.length === 0}
              mensajeVacio="Ninguna zona perdió ventas"
              alto={220}
            >
              <HBarChart
                items={conPerdida.map((z) => ({
                  nombre: z.nombre,
                  valor: z.ventaPerdida,
                  detalle: `${z.criticos + z.enRiesgo} en riesgo`,
                }))}
                formato={(n) => moneda(n)}
                unColor="#dc2626"
              />
            </Marco>
          </div>
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
            hint="críticos y en riesgo"
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
