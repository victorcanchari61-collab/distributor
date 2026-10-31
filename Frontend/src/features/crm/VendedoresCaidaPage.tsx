import { useCallback, useEffect, useMemo, useState } from 'react'
import { FileSpreadsheet, UsersRound } from 'lucide-react'
import { BarChart, DonutChart, HBarChart, Marco, moneda } from '../../components/charts'
import { Alert, Button, ListPage } from '../../components/ui'
import type { ConsultaTabla, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { exportarExcel } from '../../lib/excel'
import { hoyLocal } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { crmApi } from './crmApi'
import type { EstadoClave, FilaVendedor, VendedoresCaida } from './crmApi'
import { inicioDeAnio } from './filtros'
import { ESTADOS_UI, ORDEN_ESTADOS, colorCambio, nombreCorto, porcentaje, soles, solesConSigno } from './formato'
import { ICONO_ESTADO } from './iconosEstado'
import { EtiquetaEstado, TarjetaReporte } from './piezas'

/**
 * Vendedores con caída: lo que vendió cada vendedor frente al mismo tramo del año anterior, con la misma escala de
 * estados que los clientes. Además dice cuántos de sus clientes están bajando, que es de donde sale la caída.
 */
export function VendedoresCaidaPage() {
  const { puede } = usePermisos()
  // El tramo lo elige el panel de filtros de la tabla, con los demás.
  const [desdeInicial] = useState(inicioDeAnio())
  const [hastaInicial] = useState(hoyLocal())
  const [desde, setDesde] = useState(desdeInicial)
  const [hasta, setHasta] = useState(hastaInicial)
  const [estado, setEstado] = useState<EstadoClave>()

  const [datos, setDatos] = useState<VendedoresCaida | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setDatos(await crmApi.vendedores({ desde, hasta }))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar el reporte.')
    } finally {
      setCargando(false)
    }
  }, [desde, hasta])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['notasventa', 'clientes'], cargar)

  const columnas: DataTableColumn<FilaVendedor>[] = useMemo(
    () => [
      // Solo existe en el panel de Filtros: decide qué se pide (ver SysDataTable).
      { key: 'fecha', label: 'Fechas', soloFiltro: true, filterType: 'date' },
      {
        key: 'estado', width: 120,
        label: 'Estado',
        filterable: false,
        value: (r) => ORDEN_ESTADOS.indexOf(r.estado),
        render: (r) => <EtiquetaEstado estado={r.estado} />,
      },
      { key: 'vendedor', width: 170, label: 'Vendedor', filterable: false, render: (r) => <span className="font-medium text-ink">{r.vendedor}</span> },
      { key: 'anterior', width: 120, label: 'Venta anterior', align: 'right', filterable: false, value: (r) => r.ventaAnterior, render: (r) => <span className="text-ink-soft">{soles(r.ventaAnterior)}</span> },
      { key: 'actual', width: 115, label: 'Venta actual', align: 'right', filterable: false, value: (r) => r.ventaActual, render: (r) => soles(r.ventaActual) },
      {
        key: 'variacion', width: 120,
        label: 'Variación',
        align: 'right',
        filterable: false,
        value: (r) => r.variacion,
        render: (r) => <span className={`font-semibold ${colorCambio(r.variacion)}`}>{solesConSigno(r.variacion)}</span>,
      },
      {
        key: 'caida', width: 100,
        label: '% Caída',
        align: 'right',
        filterable: false,
        value: (r) => r.caidaPct ?? -999,
        render: (r) =>
          r.caidaPct === null ? <span className="text-ink-soft">—</span> : <span className={colorCambio(-r.caidaPct)}>{porcentaje(-r.caidaPct)}</span>,
      },
      { key: 'clientes', width: 100, label: 'Clientes', align: 'right', filterable: false, value: (r) => r.clientes, render: (r) => r.clientes },
      {
        key: 'enCaida', width: 110,
        label: 'Con caída',
        align: 'right',
        filterable: false,
        value: (r) => r.clientesEnCaida,
        render: (r) => (
          <span className="flex flex-col items-end">
            <span className="font-medium">{r.clientesEnCaida}</span>
            {r.clientesCriticos > 0 && <span className="text-[11px] font-semibold text-red-600">{r.clientesCriticos} críticos</span>}
          </span>
        ),
      },
      {
        key: 'riesgo', width: 130,
        label: 'Monto en riesgo',
        align: 'right',
        filterable: false,
        value: (r) => r.montoRiesgo,
        render: (r) => (r.montoRiesgo > 0 ? <span className="font-semibold text-red-600">{soles(r.montoRiesgo)}</span> : '—'),
      },
    ],
    [],
  )

  /** Traduce el panel de filtros al tramo que se pide. */
  const aplicar = useCallback(
    (q: ConsultaTabla) => {
      const fecha = q.filtros.find((f) => f.columna === 'fecha')
      const d = fecha?.valor || desdeInicial
      const h = fecha?.valorHasta || fecha?.valor || hastaInicial
      // Cada tecla del buscador también llega aquí: sin esta comparación se volvería a pedir todo.
      setDesde((previo) => (previo === d ? previo : d))
      setHasta((previo) => (previo === h ? previo : h))
    },
    [desdeInicial, hastaInicial],
  )

  const resumen = datos?.estados ?? []
  const items = useMemo(() => (datos?.items ?? []).filter((f) => !estado || f.estado === estado), [datos, estado])
  const mayoresRiesgo = useMemo(
    () => [...items].filter((f) => f.montoRiesgo > 0).sort((a, b) => b.montoRiesgo - a.montoRiesgo).slice(0, 8),
    [items],
  )

  /** Lo que se ve en la tabla (con la tarjeta elegida), en un Excel. */
  const exportar = () =>
    exportarExcel(
      `vendedores-con-caida-${desde}_${hasta}`,
      items.map((f) => ({
        Estado: ESTADOS_UI[f.estado].etiqueta,
        Vendedor: f.vendedor,
        'Venta anterior': f.ventaAnterior,
        'Venta actual': f.ventaActual,
        Variación: f.variacion,
        '% Caída': f.caidaPct === null ? null : Math.round(f.caidaPct * 10) / 10,
        Clientes: f.clientes,
        'Clientes con caída': f.clientesEnCaida,
        'Clientes críticos': f.clientesCriticos,
        'Monto en riesgo': f.montoRiesgo,
      })),
    )

  return (
    <ListPage
      icon={<UsersRound size={20} />}
      title="Vendedores con caída"
      description="Cuánto vendió cada vendedor frente al mismo tramo del año anterior, y cuántos de sus clientes están bajando."
      actions={
        puede('crm.vendedores', 'exportar') ? (
          <Button variant="secondary" size="sm" disabled={items.length === 0} onClick={exportar} iconRight={<FileSpreadsheet size={15} />}>
            Exportar Excel
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      banner={
        <div className="space-y-4">
          {datos && (
            <p className="text-xs text-ink-soft">
              Del {datos.periodo.etiqueta} frente al {datos.periodo.etiquetaAnterior}. Ventas con IGV, sin anuladas ni recojos. Las fechas se
              eligen en el ícono de filtros de la tabla.
            </p>
          )}

          <section className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
            {ORDEN_ESTADOS.map((e) => {
              const ui = ESTADOS_UI[e]
              const fila = resumen.find((r) => r.estado === e)
              return (
                <TarjetaReporte
                  key={e}
                  titulo={ui.etiqueta}
                  nota={ui.rango}
                  valor={fila?.clientes ?? 0}
                  detalle={e === 'SIN_BASE' ? 'sin ventas el año anterior' : e === 'NORMAL' ? 'venden igual o casi' : `${soles(fila?.monto ?? 0)} en riesgo`}
                  icono={ICONO_ESTADO[e]}
                  color={ui.color}
                  activa={estado === e}
                  onClick={() => setEstado(estado === e ? undefined : e)}
                />
              )
            })}
          </section>

          <section className="grid gap-4 lg:grid-cols-3">
            <Marco
              titulo="Vendedores por estado"
              subtitulo={datos ? `${soles(items.reduce((s, f) => s + f.ventaActual, 0))} vendidos en el tramo` : undefined}
              cargando={cargando && !datos}
              vacio={resumen.every((r) => r.clientes === 0)}
              mensajeVacio="Ningún vendedor vendió en este tramo"
              alto={168}
            >
              <DonutChart
                porciones={ORDEN_ESTADOS.filter((e) => (resumen.find((r) => r.estado === e)?.clientes ?? 0) > 0).map((e) => ({
                  nombre: ESTADOS_UI[e].etiqueta,
                  valor: resumen.find((r) => r.estado === e)?.clientes ?? 0,
                  color: ESTADOS_UI[e].color,
                }))}
                formato={(n) => `${n} ${n === 1 ? 'vendedor' : 'vendedores'}`}
                centro={{ titulo: 'Vendedores', valor: String(resumen.reduce((s, r) => s + r.clientes, 0)) }}
              />
            </Marco>

            <Marco
              titulo="Dónde está el mayor monto en riesgo"
              subtitulo="Lo que dejaron de comprar los clientes de cada vendedor"
              cargando={cargando && !datos}
              vacio={mayoresRiesgo.length === 0}
              mensajeVacio="Ningún vendedor tiene clientes que hayan bajado"
              alto={168}
            >
              <HBarChart
                items={mayoresRiesgo.map((f) => ({
                  nombre: nombreCorto(f.vendedor),
                  valor: f.montoRiesgo,
                  color: ESTADOS_UI[f.estado].color,
                  detalle: `${f.clientesEnCaida} ${f.clientesEnCaida === 1 ? 'cliente' : 'clientes'}`,
                }))}
                formato={(n) => moneda(n)}
              />
            </Marco>

            <Marco
              titulo="Ventas por vendedor"
              subtitulo="El tramo actual frente al mismo tramo del año anterior"
              cargando={cargando && !datos}
              vacio={items.length === 0}
              mensajeVacio="Ningún vendedor vendió en este tramo"
              alto={200}
              derecha={
                <span className="flex items-center gap-3 text-[11px] text-ink-muted">
                  <span className="flex items-center gap-1.5">
                    <span className="size-2 rounded-sm bg-violet-600" /> Actual
                  </span>
                  <span className="flex items-center gap-1.5">
                    <span className="size-2 rounded-sm bg-slate-300" /> Anterior
                  </span>
                </span>
              }
            >
              <BarChart
                etiquetas={items.map((f) => nombreCorto(f.vendedor))}
                etiquetasLargas={items.map((f) => f.vendedor)}
                series={[
                  { id: 'anterior', nombre: datos?.periodo.etiquetaAnterior ?? 'Año anterior', color: '#cbd5e1', valores: items.map((f) => f.ventaAnterior) },
                  { id: 'actual', nombre: datos?.periodo.etiqueta ?? 'Actual', color: '#7c3aed', valores: items.map((f) => f.ventaActual) },
                ]}
                formato={(n) => moneda(n)}
                alto={200}
              />
            </Marco>
          </section>
        </div>
      }
      columns={columnas}
      rows={items}
      rowKey="usuarioId"
      onConsulta={aplicar}
      filtrosIniciales={[{ column: 'fecha', operator: 'between', value: desdeInicial, valueTo: hastaInicial }]}
      pageSize={15}
      cardIcon={UsersRound}
      searchPlaceholder="Buscar vendedor..."
      empty={cargando ? 'Cargando vendedores...' : 'Ningún vendedor vendió en este tramo.'}
    />
  )
}
