import { CalendarClock, HandCoins, Wallet } from 'lucide-react'
import { BarChart, HBarChart, Kpi, Marco, PALETA, SEMAFORO, diaCorto, diaLargo, moneda, pct } from '../../components/charts'
import { dashboardApi } from './dashboardApi'
import { COLOR_DEUDA, Encabezado, FilaKpi, rejilla, semaforoDias, useBloque, useTablero } from './comun'

/** Cuánto se debe, hace cuánto, quién y cuánto se cobró — para saber a quién llamar primero. */
export function CobranzaDashboard() {
  const t = useTablero()
  const b = useBloque(() => dashboardApi.cobranza(t.desde, t.hasta), [t.desde, t.hasta, t.version])
  const c = b.datos

  const cobros = c?.cobros ?? []
  const sinDeuda = !c || c.totalPorCobrar === 0
  const vieja = c ? c.antiguedad[3].valor + c.antiguedad[4].valor : 0
  const masVieja = c?.antiguedad.filter((a) => a.valor > 0).at(-1)

  return (
    <div className="space-y-5">
      <Encabezado
        icono={<Wallet size={20} />}
        titulo="Dashboard de cobranza"
        descripcion="Lo que se debe, hace cuánto y lo que se ha cobrado. Cada gráfico dice su conclusión debajo del título."
        tablero={t}
      />

      <FilaKpi cargando={b.cargando}>
        {c && (
          <>
            <Kpi titulo="Por cobrar" valor={moneda(c.totalPorCobrar)} bajarEsBueno color={PALETA[2]} icono={<Wallet size={15} />} nota={`${c.cuentas} notas · ${c.clientes} clientes`} />
            <Kpi
              titulo="Deuda de más de 30 días"
              valor={c.totalPorCobrar > 0 ? pct((vieja / c.totalPorCobrar) * 100, 0) : '0%'}
              bajarEsBueno
              color={SEMAFORO.mal}
              icono={<CalendarClock size={15} />}
              nota={vieja > 0 ? `${moneda(vieja)} sin cobrar hace más de un mes` : 'Nada atrasado'}
            />
            <Kpi titulo="Cobrado" valor={moneda(c.cobradoPeriodo)} color={PALETA[1]} icono={<HandCoins size={15} />} nota="En el período elegido" />
            <Kpi titulo="Crédito otorgado" valor={moneda(c.creditoOtorgado)} color={PALETA[4]} nota="Vendido a crédito en el período" />
          </>
        )}
      </FilaKpi>

      <div className={rejilla(3)}>
        <Marco
          titulo="Cuánto hace que se debe"
          subtitulo={c && (sinDeuda ? 'Nadie debe nada' : <>{pct((vieja / c.totalPorCobrar) * 100, 0)} de la deuda pasa de 30 días</>)}
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && sinDeuda}
          mensajeVacio="Sin cuentas por cobrar"
          alto={240}
        >
          <BarChart
            alto={240}
            etiquetas={(c?.antiguedad ?? []).map((a) => a.nombre.replace(' días', ' d'))}
            etiquetasLargas={(c?.antiguedad ?? []).map((a) => `${a.nombre} · ${a.cantidad} ${a.cantidad === 1 ? 'nota' : 'notas'}`)}
            series={[{ id: 'deuda', nombre: 'Por cobrar', color: SEMAFORO.alerta, valores: (c?.antiguedad ?? []).map((a) => a.valor) }]}
            colorDe={(_, i) => COLOR_DEUDA[i]}
            formato={(n) => moneda(n)}
          />
        </Marco>

        <Marco
          titulo="Quién debe más"
          subtitulo={masVieja && `La deuda más vieja tiene ${masVieja.nombre === 'Más de 60' ? 'más de 60 días' : masVieja.nombre}`}
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && !c?.deudores.length}
          mensajeVacio="Sin deudores"
          alto={240}
        >
          <HBarChart items={(c?.deudores ?? []).map((d) => ({ nombre: d.cliente, valor: d.saldo, color: semaforoDias(d.dias), detalle: `${d.dias} d` }))} formato={(n) => moneda(n)} />
        </Marco>

        <Marco
          titulo="Cobros por día"
          subtitulo={c && <>Por método de pago · a crédito se dio {moneda(c.creditoOtorgado)}</>}
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && !c?.metodos.length}
          mensajeVacio="Sin cobros en el período"
          alto={240}
        >
          <BarChart
            alto={240}
            apilado
            etiquetas={cobros.map((d) => diaCorto(d.fecha))}
            etiquetasLargas={cobros.map((d) => diaLargo(d.fecha))}
            series={(c?.metodos ?? []).map((m, i) => ({ id: m, nombre: m, color: PALETA[i % PALETA.length], valores: cobros.map((d) => d.valores[i] ?? 0) }))}
            formato={(n) => moneda(n)}
          />
        </Marco>
      </div>
    </div>
  )
}
