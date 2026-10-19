import { CalendarClock, HandCoins, PackageOpen, ShoppingBag, TrendingDown, TrendingUp, Wallet } from 'lucide-react'
import {
  BarChart,
  DonutChart,
  HBarChart,
  Kpi,
  Marco,
  PALETA,
  SEMAFORO,
  compacto,
  diaCorto,
  diaLargo,
  moneda,
  pct,
  variacion,
} from '../../components/charts'
import { cn } from '../../components/ui'
import { dashboardApi } from './dashboardApi'
import type { DashCostoProducto } from './dashboardApi'
import { COLOR_DEUDA, ConReportes, Encabezado, FilaKpi, frase, rejilla, semaforoDias, useBloque, useTablero } from './comun'
import { ReporteTablero } from './ReporteTablero'

/**
 * El otro lado de Cobranza: lo que se le debe a los proveedores y hace cuánto, lo que se compra y
 * a quién, y qué productos están costando más — para saber a quién pagar primero y dónde negociar.
 */
/** Compras: los gráficos y, en su otra pestaña, el reporte detallado. */
export function ComprasDashboard() {
  return <ConReportes graficos={<GraficosCompras />} reportes={<ReporteTablero tablero="compras" />} />
}

function GraficosCompras() {
  const t = useTablero()
  const b = useBloque(() => dashboardApi.compras(t.desde, t.hasta), [t.desde, t.hasta, t.version])
  const c = b.datos

  const sinDeuda = !c || c.totalPorPagar === 0
  const vieja = c ? c.antiguedad[3].valor + c.antiguedad[4].valor : 0
  const masVieja = c?.antiguedad.filter((a) => a.valor > 0).at(-1)
  const serie = c?.serie ?? []
  const pagos = c?.pagos ?? []
  const subieron = c?.costos.filter((x) => x.variacion > 0).length ?? 0
  const bajaron = c?.costos.filter((x) => x.variacion < 0).length ?? 0
  const principal = c?.porProveedor[0]

  return (
    <div className="space-y-5">
      <Encabezado
        icono={<ShoppingBag size={20} />}
        titulo="Dashboard de compras"
        descripcion="Lo que se debe a proveedores, lo que se compra y cómo cambian los costos."
        tablero={t}
      />

      <FilaKpi cargando={b.cargando}>
        {c && (
          <>
            <Kpi
              titulo="Por pagar"
              valor={moneda(c.totalPorPagar)}
              bajarEsBueno
              color={PALETA[2]}
              icono={<Wallet size={15} />}
              nota={`${c.cuentas} ${c.cuentas === 1 ? 'compra' : 'compras'} · ${c.proveedores} ${c.proveedores === 1 ? 'proveedor' : 'proveedores'}`}
            />
            <Kpi
              titulo="Deuda de más de 30 días"
              valor={c.totalPorPagar > 0 ? pct((vieja / c.totalPorPagar) * 100, 0) : '0%'}
              bajarEsBueno
              color={SEMAFORO.mal}
              icono={<CalendarClock size={15} />}
              nota={vieja > 0 ? `${moneda(vieja)} sin pagar hace más de un mes` : 'Nada atrasado'}
            />
            <Kpi
              titulo="Comprado"
              valor={moneda(c.comprado)}
              cambio={variacion(c.comprado, c.compradoAnterior)}
              color={PALETA[4]}
              icono={<ShoppingBag size={15} />}
              nota={
                c.porRecibir > 0
                  ? `${c.compras} ${c.compras === 1 ? 'compra' : 'compras'} · ${moneda(c.porRecibir)} por recibir`
                  : `${c.compras} ${c.compras === 1 ? 'compra' : 'compras'} en el período`
              }
            />
            <Kpi titulo="Pagado" valor={moneda(c.pagadoPeriodo)} color={PALETA[1]} icono={<HandCoins size={15} />} nota="A proveedores en el período" />
          </>
        )}
      </FilaKpi>

      <div className={rejilla(3)}>
        <Marco
          titulo="Cuánto hace que se debe"
          subtitulo={c && (sinDeuda ? 'No se le debe a nadie' : <>{pct((vieja / c.totalPorPagar) * 100, 0)} de la deuda pasa de 30 días</>)}
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && sinDeuda}
          mensajeVacio="Sin cuentas por pagar"
          alto={240}
        >
          <BarChart
            alto={240}
            etiquetas={(c?.antiguedad ?? []).map((a) => a.nombre.replace(' días', ' d'))}
            etiquetasLargas={(c?.antiguedad ?? []).map((a) => `${a.nombre} · ${a.cantidad} ${a.cantidad === 1 ? 'compra' : 'compras'}`)}
            series={[{ id: 'deuda', nombre: 'Por pagar', color: SEMAFORO.alerta, valores: (c?.antiguedad ?? []).map((a) => a.valor) }]}
            colorDe={(_, i) => COLOR_DEUDA[i]}
            formato={(n) => moneda(n)}
          />
        </Marco>

        <Marco
          titulo="A quién se le debe más"
          subtitulo={masVieja && `La deuda más vieja tiene ${masVieja.nombre === 'Más de 60' ? 'más de 60 días' : masVieja.nombre}`}
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && !c?.acreedores.length}
          mensajeVacio="Sin deudas con proveedores"
          alto={240}
        >
          <HBarChart
            items={(c?.acreedores ?? []).map((a) => ({ nombre: a.proveedor, valor: a.saldo, color: semaforoDias(a.dias), detalle: `${a.dias} d` }))}
            formato={(n) => moneda(n)}
          />
        </Marco>

        <Marco
          titulo="Pagos por día"
          subtitulo={c && <>Por método de pago · a crédito se compró {moneda(c.compradoCredito)}</>}
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && !c?.metodos.length}
          mensajeVacio="Sin pagos en el período"
          alto={240}
        >
          <BarChart
            alto={240}
            apilado
            etiquetas={pagos.map((d) => diaCorto(d.fecha))}
            etiquetasLargas={pagos.map((d) => diaLargo(d.fecha))}
            series={(c?.metodos ?? []).map((m, i) => ({ id: m, nombre: m, color: PALETA[i % PALETA.length], valores: pagos.map((d) => d.valores[i] ?? 0) }))}
            formato={(n) => moneda(n)}
          />
        </Marco>
      </div>

      <div className={rejilla(2)}>
        <Marco
          titulo="Compras por día"
          subtitulo={c && frase(variacion(c.comprado, c.compradoAnterior), `los ${t.dias} días anteriores`)}
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && !c?.compras}
          mensajeVacio="Sin compras en el período"
          alto={240}
        >
          <BarChart
            alto={240}
            apilado
            etiquetas={serie.map((d) => diaCorto(d.fecha))}
            etiquetasLargas={serie.map((d) => diaLargo(d.fecha))}
            series={[
              { id: 'contado', nombre: 'Contado', color: SEMAFORO.bien, valores: serie.map((d) => d.contado) },
              { id: 'credito', nombre: 'Crédito', color: SEMAFORO.alerta, valores: serie.map((d) => d.credito) },
            ]}
            formato={(n) => moneda(n)}
          />
        </Marco>

        <Marco
          titulo="Cómo cambian los costos"
          subtitulo={
            c && c.costos.length > 0
              ? [subieron > 0 && `${subieron} ${subieron === 1 ? 'subió' : 'subieron'}`, bajaron > 0 && `${bajaron} ${bajaron === 1 ? 'bajó' : 'bajaron'}`]
                  .filter(Boolean)
                  .join(', ') + ' frente a su compra anterior'
              : 'La última compra de cada producto frente a la anterior'
          }
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && !c?.costos.length}
          mensajeVacio="Sin cambios de costo en el período"
          alto={240}
        >
          <ListaCostos costos={c?.costos ?? []} />
        </Marco>
      </div>

      <div className={rejilla(2)}>
        <Marco
          titulo="A quién se le compra"
          subtitulo={
            principal && c && c.comprado > 0
              ? `${principal.nombre} es el ${pct((principal.valor / c.comprado) * 100, 0)} de lo comprado`
              : 'Lo comprado por proveedor'
          }
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && !c?.porProveedor.length}
          alto={200}
        >
          <HBarChart
            items={(c?.porProveedor ?? []).map((i) => ({ nombre: i.nombre, valor: i.valor, detalle: `${i.cantidad}` }))}
            formato={(n) => moneda(n)}
            unColor={PALETA[4]}
          />
        </Marco>

        <Marco
          titulo="Qué se compra"
          subtitulo="Por categoría"
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && !c?.porCategoria.length}
          alto={200}
        >
          <DonutChart
            porciones={(c?.porCategoria ?? []).map((i) => ({ nombre: i.nombre, valor: i.valor, color: i.nombre.startsWith('Sin ') ? SEMAFORO.neutro : undefined }))}
            formato={compacto}
            centro={{ titulo: 'Comprado', valor: moneda(c?.comprado ?? 0) }}
          />
        </Marco>
      </div>

      {c && c.porRecibir > 0 && (
        <p className="flex items-center gap-1.5 text-xs text-ink-soft">
          <PackageOpen size={13} aria-hidden="true" />
          {moneda(c.porRecibir)} en mercadería comprada que todavía no llega: se ve en Compras → Recepciones.
        </p>
      )}
    </div>
  )
}

/**
 * Los productos cuyo costo más cambió. Una lista y no barras: lo que importa es el antes y el
 * ahora, y si subió o bajó, que una barra no dice.
 */
function ListaCostos({ costos }: { costos: DashCostoProducto[] }) {
  return (
    <ul className="divide-y divide-line">
      {costos.map((x) => {
        const sube = x.variacion > 0
        return (
          <li key={x.producto} className="flex items-center justify-between gap-3 py-2">
            <div className="min-w-0">
              <p className="truncate text-sm font-medium text-ink">{x.producto}</p>
              <p className="text-xs text-ink-soft tabular-nums">
                {/* Con céntimos: un costo de pocos soles sin ellos engaña (2.40 → 2.60 se leería 2 → 3). */}
                {moneda(x.costoAnterior, 2)} → {moneda(x.costoActual, 2)} por {x.unidad.toLowerCase() || 'unidad'}
              </p>
            </div>
            <span
              className={cn(
                'inline-flex shrink-0 items-center gap-1 rounded-full px-2 py-0.5 text-xs font-semibold tabular-nums ring-1',
                sube ? 'bg-red-50 text-red-700 ring-red-200' : 'bg-emerald-50 text-emerald-700 ring-emerald-200',
              )}
            >
              {sube ? <TrendingUp size={12} aria-hidden="true" /> : <TrendingDown size={12} aria-hidden="true" />}
              {sube ? '+' : '−'}
              {pct(Math.abs(x.variacion), 1)}
            </span>
          </li>
        )
      })}
    </ul>
  )
}
