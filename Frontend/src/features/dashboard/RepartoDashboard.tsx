import { ClipboardList, PackageCheck, PackageX, Send } from 'lucide-react'
import { BarChart, DonutChart, FunnelChart, Gauge, Kpi, Marco, PALETA, SEMAFORO, compacto, diaCorto, diaLargo, moneda, pct } from '../../components/charts'
import { dashboardApi } from './dashboardApi'
import { Encabezado, FilaKpi, rejilla, useBloque, useTablero } from './comun'

/** Del pedido al cobro: cuántos se toman, cuántos se entregan completos y por qué se recorta lo demás. */
export function RepartoDashboard() {
  const t = useTablero()
  const b = useBloque(() => dashboardApi.reparto(t.desde, t.hasta), [t.desde, t.hasta, t.version])
  const r = b.datos

  const serie = r?.serie ?? []
  const sinPedidos = !r || serie.every((d) => d.pendientes + d.confirmados + d.anulados === 0)
  const tomados = r?.embudo[0]?.valor ?? 0
  const convertidos = r?.embudo[1]?.valor ?? 0

  return (
    <div className="space-y-5">
      <Encabezado
        icono={<PackageCheck size={20} />}
        titulo="Dashboard de pedidos y reparto"
        descripcion="Cuántos pedidos se toman, cuántos llegan completos y por qué no. Cada gráfico dice su conclusión debajo del título."
        tablero={t}
      />

      <FilaKpi cargando={b.cargando}>
        {r && (
          <>
            <Kpi titulo="Pedidos tomados" valor={String(tomados)} color={PALETA[0]} icono={<ClipboardList size={15} />} nota="Sin contar los anulados" />
            <Kpi titulo="Convertidos a venta" valor={String(convertidos)} color={PALETA[1]} icono={<Send size={15} />} nota={tomados > 0 ? `${pct((convertidos / tomados) * 100, 0)} de los pedidos` : undefined} />
            <Kpi titulo="Entrega completa" valor={r.entregaCompleta !== null ? pct(r.entregaCompleta, 0) : '—'} color={r.entregaCompleta !== null && r.entregaCompleta >= 90 ? SEMAFORO.bien : SEMAFORO.alerta} icono={<PackageCheck size={15} />} nota="Sin faltantes ni recortes" />
            {r.novedadesPorMotivo !== null && (
              <Kpi titulo="No entregado" valor={moneda(r.importeNovedades)} bajarEsBueno color={SEMAFORO.mal} icono={<PackageX size={15} />} nota="Mercadería que no llegó al cliente" />
            )}
          </>
        )}
      </FilaKpi>

      <div className={rejilla(3)}>
        <Marco
          className="lg:col-span-2"
          titulo="Pedidos por día"
          subtitulo="Cuántos se toman y en qué quedan"
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && sinPedidos}
          alto={240}
        >
          <BarChart
            alto={240}
            apilado
            etiquetas={serie.map((d) => diaCorto(d.fecha))}
            etiquetasLargas={serie.map((d) => diaLargo(d.fecha))}
            series={[
              { id: 'conf', nombre: 'Convertidos a venta', color: SEMAFORO.bien, valores: serie.map((d) => d.confirmados) },
              { id: 'pend', nombre: 'Pendientes', color: SEMAFORO.alerta, valores: serie.map((d) => d.pendientes) },
              { id: 'anu', nombre: 'Anulados', color: '#94a3b8', valores: serie.map((d) => d.anulados) },
            ]}
            formato={(n) => String(n)}
            formatoEje={(n) => String(n)}
          />
        </Marco>

        <Marco titulo="Entregas completas" subtitulo="De lo entregado, lo que llegó sin recortes" cargando={b.cargando} error={b.error} alto={240}>
          <div className="flex h-[240px] items-center justify-center">
            <Gauge valor={r?.entregaCompleta ?? null} titulo="sin faltantes ni recortes" meta={90} tamano={220} />
          </div>
        </Marco>
      </div>

      <div className={rejilla(2)}>
        <Marco titulo="Del pedido al cobro" subtitulo="A la derecha, qué parte de la etapa anterior llegó hasta ahí" cargando={b.cargando} error={b.error} vacio={!b.cargando && !b.error && sinPedidos} alto={210}>
          <FunnelChart etapas={(r?.embudo ?? []).map((e) => ({ nombre: e.nombre, valor: e.valor }))} />
        </Marco>

        {r?.novedadesPorMotivo !== null && (
          <Marco
            titulo="Por qué no llegó completo"
            subtitulo={r && r.importeNovedades > 0 && <>{moneda(r.importeNovedades)} en mercadería que no se entregó</>}
            cargando={b.cargando}
            error={b.error}
            vacio={!b.cargando && !b.error && !r?.novedadesPorMotivo?.length}
            mensajeVacio="Sin novedades en el período"
            alto={210}
          >
            <DonutChart porciones={(r?.novedadesPorMotivo ?? []).map((n) => ({ nombre: n.nombre, valor: n.valor }))} formato={compacto} centro={{ titulo: 'No entregado', valor: moneda(r?.importeNovedades ?? 0) }} />
          </Marco>
        )}
      </div>
    </div>
  )
}
