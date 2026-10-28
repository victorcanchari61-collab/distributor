import { useCallback, useEffect, useMemo, useState } from 'react'
import { UsersRound } from 'lucide-react'
import { BarChart, Marco, moneda } from '../../components/charts'
import { Alert, PageHeader, SysDataTable } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { hoyLocal } from '../../lib/fechas'
import { useRealtime } from '../../lib/realtime'
import { crmApi } from './crmApi'
import type { EstadoClave, FilaVendedor, VendedoresCaida } from './crmApi'
import { FiltroFechas, inicioDeAnio } from './filtros'
import { ESTADOS_UI, ORDEN_ESTADOS, colorCambio, nombreCorto, porcentaje, soles, solesConSigno } from './formato'
import { ICONO_ESTADO } from './iconosEstado'
import { EtiquetaEstado, TarjetaReporte } from './piezas'

/**
 * Vendedores con caída: lo que vendió cada vendedor frente al mismo tramo del año anterior, con la misma escala de
 * estados que los clientes. Además dice cuántos de sus clientes están bajando, que es de donde sale la caída.
 */
export function VendedoresCaidaPage() {
  const [desde, setDesde] = useState(inicioDeAnio())
  const [hasta, setHasta] = useState(hoyLocal())
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

  const resumen = datos?.estados ?? []
  const items = useMemo(() => (datos?.items ?? []).filter((f) => !estado || f.estado === estado), [datos, estado])

  return (
    <div className="space-y-5">
      <PageHeader
        icon={<UsersRound size={20} />}
        title="Vendedores con caída"
        description="Cuánto vendió cada vendedor frente al mismo tramo del año anterior, y cuántos de sus clientes están bajando."
      />

      {error && <Alert>{error}</Alert>}

      <section className="rounded-panel border border-line bg-white p-4">
        <FiltroFechas desde={desde} hasta={hasta} onChange={(d, h) => { setDesde(d); setHasta(h) }} />
        {datos && (
          <p className="mt-3 text-xs text-ink-soft">
            Del {datos.periodo.etiqueta} frente al {datos.periodo.etiquetaAnterior}. Ventas con IGV, sin anuladas ni recojos.
          </p>
        )}
      </section>

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

      <Marco
        titulo="Ventas por vendedor"
        subtitulo="El tramo actual frente al mismo tramo del año anterior"
        cargando={cargando && !datos}
        vacio={items.length === 0}
        mensajeVacio="Ningún vendedor vendió en este tramo"
        alto={240}
      >
        <BarChart
          etiquetas={items.map((f) => nombreCorto(f.vendedor))}
          etiquetasLargas={items.map((f) => f.vendedor)}
          series={[
            { id: 'anterior', nombre: datos?.periodo.etiquetaAnterior ?? 'Año anterior', color: '#cbd5e1', valores: items.map((f) => f.ventaAnterior) },
            { id: 'actual', nombre: datos?.periodo.etiqueta ?? 'Actual', color: '#7c3aed', valores: items.map((f) => f.ventaActual) },
          ]}
          formato={(n) => moneda(n)}
        />
      </Marco>

      <SysDataTable
        columns={columnas}
        rows={items}
        rowKey="usuarioId"
        toolbar={false}
        pageSize={15}
        cardIcon={UsersRound}
        empty={cargando ? 'Cargando vendedores...' : 'Ningún vendedor vendió en este tramo.'}
      />
    </div>
  )
}
