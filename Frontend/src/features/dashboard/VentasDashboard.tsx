import { Coins, ShoppingCart, Users } from 'lucide-react'
import {
  BarChart,
  DonutChart,
  HBarChart,
  Heatmap,
  Kpi,
  LineChart,
  Marco,
  PALETA,
  SEMAFORO,
  compacto,
  diaCorto,
  diaLargo,
  moneda,
  variacion,
} from '../../components/charts'
import { dashboardApi } from './dashboardApi'
import { Encabezado, FilaKpi, frase, rejilla, useBloque, useTablero } from './comun'

/** Cuánto se vende, a quién, quién lo vende y en qué momento — con el mes proyectado a su cierre. */
export function VentasDashboard() {
  const t = useTablero()
  const b = useBloque(() => dashboardApi.ventas(t.desde, t.hasta), [t.desde, t.hasta, t.version])
  const v = b.datos

  const contra = `los ${t.dias} días anteriores`
  const serie = v?.serie ?? []
  const etiquetas = serie.map((d) => diaCorto(d.fecha))
  const largas = serie.map((d) => diaLargo(d.fecha))
  const sinVentas = !v || serie.every((d) => d.importe === 0)

  const mes = v?.mes
  const diasMes = mes?.diasMes ?? 0
  const relleno = (valores: (number | null)[]) => Array.from({ length: diasMes }, (_, i) => valores[i] ?? null)
  const cierre = mes ? (mes.serieProyeccion[diasMes - 1] ?? mes.acumulado) : 0

  const pareto = v?.pareto ?? []
  const calor = (v?.calor ?? []).map((c) => ({
    dia: c.dia,
    hora: c.hora,
    valor: c.importe,
    detalle: `${moneda(c.importe)} · ${c.notas} ${c.notas === 1 ? 'venta' : 'ventas'}`,
  }))

  return (
    <div className="space-y-5">
      <Encabezado
        icono={<ShoppingCart size={20} />}
        titulo="Dashboard de ventas"
        descripcion="Cuánto se vende, a quién, quién lo vende y cuándo. Cada gráfico dice su conclusión debajo del título."
        tablero={t}
      />

      <FilaKpi cargando={b.cargando}>
        {v && (
          <>
            <Kpi
              titulo="Ventas"
              valor={moneda(v.actual.importe)}
              cambio={variacion(v.actual.importe, v.anterior.importe)}
              serie={serie.map((d) => d.importe)}
              color={PALETA[0]}
              icono={<Coins size={15} />}
            />
            <Kpi
              titulo="Ticket promedio"
              valor={moneda(v.actual.ticket)}
              cambio={variacion(v.actual.ticket, v.anterior.ticket)}
              color={PALETA[4]}
              nota="Lo que deja una venta en promedio"
            />
            <Kpi
              titulo="Ventas realizadas"
              valor={String(v.actual.notas)}
              cambio={variacion(v.actual.notas, v.anterior.notas)}
              serie={serie.map((d) => d.notas)}
              color={PALETA[5]}
            />
            <Kpi
              titulo="Clientes que compraron"
              valor={String(v.actual.clientes)}
              cambio={variacion(v.actual.clientes, v.anterior.clientes)}
              color={PALETA[2]}
              icono={<Users size={15} />}
            />
          </>
        )}
      </FilaKpi>

      <div className={rejilla(3)}>
        <Marco
          className="lg:col-span-2"
          titulo="Ventas por día"
          subtitulo={
            v && (
              <>
                {frase(variacion(v.actual.importe, v.anterior.importe), contra)}
                {v.atipicos.length > 0 &&
                  ` · ${v.atipicos.length} ${v.atipicos.length === 1 ? 'día fuera de lo normal' : 'días fuera de lo normal'}`}
              </>
            )
          }
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && sinVentas}
          alto={250}
        >
          {v && (
            <LineChart
              alto={250}
              etiquetas={etiquetas}
              etiquetasLargas={largas}
              formato={(n) => moneda(n)}
              series={[
                { id: 'actual', nombre: 'Este período', color: PALETA[0], valores: serie.map((d) => d.importe), area: true },
                { id: 'anterior', nombre: 'Período anterior', color: '#94a3b8', valores: serie.map((d) => d.importeAnterior), punteada: true, grosor: 1.5 },
              ]}
              marcas={v.atipicos.map((a) => ({
                indice: a.indice,
                serie: 'actual',
                color: a.tipo === 'PICO' ? SEMAFORO.bien : SEMAFORO.mal,
                titulo: a.tipo === 'PICO' ? 'Día muy por encima de lo normal' : 'Día muy por debajo de lo normal',
              }))}
            />
          )}
        </Marco>

        <Marco
          titulo={mes ? `Avance de ${mes.nombre}` : 'Avance del mes'}
          subtitulo={
            mes && (
              <>
                Cierre proyectado <strong className="text-ink">{moneda(cierre)}</strong> ·{' '}
                {frase(variacion(mes.acumulado, mes.mesAnteriorMismoPunto), 'el mes pasado a esta fecha')}
              </>
            )
          }
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && (!mes || (mes.acumulado === 0 && mes.mesAnterior === 0))}
          alto={250}
        >
          {mes && (
            <LineChart
              alto={250}
              etiquetas={Array.from({ length: diasMes }, (_, i) => String(i + 1))}
              etiquetasLargas={Array.from({ length: diasMes }, (_, i) => `Día ${i + 1}`)}
              formato={(n) => moneda(n)}
              series={[
                { id: 'anterior', nombre: 'Mes pasado', color: '#94a3b8', valores: relleno(mes.serieAnterior), grosor: 1.5 },
                { id: 'actual', nombre: 'Este mes', color: PALETA[0], valores: relleno(mes.serieActual), area: true },
                { id: 'proyeccion', nombre: 'Proyección', color: PALETA[0], valores: relleno(mes.serieProyeccion), punteada: true },
              ]}
              marcas={[{ indice: diasMes - 1, serie: 'proyeccion', color: PALETA[0], titulo: `Cierre proyectado ${moneda(cierre)}` }]}
            />
          )}
        </Marco>
      </div>

      <div className={rejilla(3)}>
        <Marco
          titulo="Cuándo se vende"
          subtitulo="Cuanto más oscuro, más se vende en esa hora"
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && calor.length === 0}
          alto={210}
        >
          <Heatmap celdas={calor} color={PALETA[0]} />
        </Marco>

        <Marco
          className="lg:col-span-2"
          titulo="Clientes que sostienen las ventas"
          subtitulo={v && v.clientesTotal > 0 && <>{v.clientesAl80} de {v.clientesTotal} clientes hacen el 80% de lo vendido</>}
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && pareto.length === 0}
          alto={210}
        >
          <BarChart
            alto={210}
            etiquetas={pareto.map((_, i) => String(i + 1))}
            etiquetasLargas={pareto.map((p) => p.nombre)}
            series={[{ id: 'venta', nombre: 'Ventas', color: PALETA[0], valores: pareto.map((p) => p.valor) }]}
            formato={(n) => moneda(n)}
            linea={{ nombre: 'Acumulado', color: SEMAFORO.alerta, valores: pareto.map((p) => p.acumulado), formato: (n) => `${Math.round(n)}%`, max: 100 }}
          />
        </Marco>
      </div>

      <div className={rejilla(3)}>
        <Marco titulo="Quién vende" subtitulo="Importe por vendedor" cargando={b.cargando} error={b.error} vacio={!b.cargando && !b.error && !v?.porVendedor.length} alto={180}>
          <HBarChart items={(v?.porVendedor ?? []).map((i) => ({ nombre: i.nombre, valor: i.valor, detalle: `${i.cantidad}`, color: i.nombre.startsWith('Sin ') ? SEMAFORO.neutro : undefined }))} formato={(n) => moneda(n)} />
        </Marco>

        <Marco titulo="Qué se vende" subtitulo="Por categoría" cargando={b.cargando} error={b.error} vacio={!b.cargando && !b.error && !v?.porCategoria.length} alto={180}>
          <DonutChart porciones={(v?.porCategoria ?? []).map((i) => ({ nombre: i.nombre, valor: i.valor, color: i.nombre.startsWith('Sin ') ? SEMAFORO.neutro : undefined }))} formato={compacto} centro={{ titulo: 'Vendido', valor: moneda(v?.actual.importe ?? 0) }} />
        </Marco>

        <Marco titulo="Contado y crédito" subtitulo="Cómo pagan los clientes" cargando={b.cargando} error={b.error} vacio={!b.cargando && !b.error && !v?.porFormaPago.length} alto={180}>
          <DonutChart
            porciones={(v?.porFormaPago ?? []).map((i) => ({ nombre: i.nombre, valor: i.valor, color: i.nombre === 'Crédito' ? SEMAFORO.alerta : SEMAFORO.bien }))}
            formato={compacto}
          />
        </Marco>
      </div>

      <Marco titulo="Lo que más se vende" subtitulo="Los 10 productos con más importe" cargando={b.cargando} error={b.error} vacio={!b.cargando && !b.error && !v?.topProductos.length} alto={200}>
        <HBarChart items={(v?.topProductos ?? []).map((i) => ({ nombre: i.nombre, valor: i.valor }))} formato={(n) => moneda(n)} unColor={PALETA[0]} />
      </Marco>
    </div>
  )
}
