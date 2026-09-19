import { Coins, Percent, TrendingUp } from 'lucide-react'
import {
  BarChart,
  HBarChart,
  Kpi,
  Marco,
  PALETA,
  SEMAFORO,
  ScatterChart,
  diaCorto,
  diaLargo,
  moneda,
  pct,
  variacion,
} from '../../components/charts'
import { dashboardApi } from './dashboardApi'
import { Encabezado, FilaKpi, frase, mediana, rejilla, useBloque, useTablero } from './comun'

/** Cuánto se gana, con qué margen, y qué productos conviene empujar o revisar. */
export function RentabilidadDashboard() {
  const t = useTablero()
  const b = useBloque(() => dashboardApi.ganancias(t.desde, t.hasta), [t.desde, t.hasta, t.version])
  const g = b.datos

  const serie = g?.serie ?? []
  const sinDatos = !g || serie.every((d) => d.importe === 0)

  // La matriz parte el plano en la mediana de volumen y en el margen general: lo que queda abajo
  // a la derecha vende mucho pero deja menos que el promedio de la casa.
  const conMargen = (g?.productos ?? []).filter((p) => p.margen !== null)
  const cortX = mediana(conMargen.map((p) => p.importe))
  const cortY = g?.margen ?? 0

  const colorDe = (p: { importe: number; margen: number | null }) => {
    const alto = p.importe >= cortX
    const bueno = (p.margen ?? 0) >= cortY
    return alto && bueno ? SEMAFORO.bien : alto ? SEMAFORO.mal : bueno ? PALETA[0] : SEMAFORO.neutro
  }

  const aRevisar = conMargen.filter((p) => p.importe >= cortX && (p.margen ?? 0) < cortY)
  const masVendidos = new Set([...conMargen].sort((a, c) => c.importe - a.importe).slice(0, 5).map((p) => p.nombre))

  return (
    <div className="space-y-5">
      <Encabezado
        icono={<TrendingUp size={20} />}
        titulo="Dashboard de rentabilidad"
        descripcion="Cuánto deja lo que se vende, con el costo real de cada salida. Cada gráfico dice su conclusión debajo del título."
        tablero={t}
      />

      <FilaKpi cargando={b.cargando}>
        {g && (
          <>
            <Kpi
              titulo="Ganancia"
              valor={moneda(g.ganancia)}
              cambio={variacion(g.ganancia, g.gananciaAnterior)}
              serie={serie.map((d) => d.ganancia)}
              color={PALETA[1]}
              icono={<Coins size={15} />}
            />
            <Kpi
              titulo="Margen"
              valor={g.margen !== null ? pct(g.margen) : '—'}
              cambio={g.margen !== null && g.margenAnterior !== null ? variacion(g.margen, g.margenAnterior) : null}
              color={PALETA[2]}
              icono={<Percent size={15} />}
              nota="Ganancia sobre lo vendido"
            />
            <Kpi titulo="Vendido" valor={moneda(g.importe)} color={PALETA[0]} nota="Ventas del período" />
            <Kpi titulo="Costo" valor={moneda(g.costo)} bajarEsBueno color={PALETA[6]} nota={g.lineasSinCosto > 0 ? `${g.lineasSinCosto} líneas sin costo conocido` : 'Lo que costó la mercadería vendida'} />
          </>
        )}
      </FilaKpi>

      <div className={rejilla(3)}>
        <Marco
          className="lg:col-span-2"
          titulo="Ganancia y margen por día"
          subtitulo={g && frase(variacion(g.ganancia, g.gananciaAnterior), `los ${t.dias} días anteriores`)}
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && sinDatos}
          alto={250}
        >
          <BarChart
            alto={250}
            etiquetas={serie.map((d) => diaCorto(d.fecha))}
            etiquetasLargas={serie.map((d) => diaLargo(d.fecha))}
            series={[{ id: 'ganancia', nombre: 'Ganancia', color: SEMAFORO.bien, valores: serie.map((d) => d.ganancia) }]}
            colorDe={(v) => (v < 0 ? SEMAFORO.mal : SEMAFORO.bien)}
            formato={(n) => moneda(n)}
            linea={{ nombre: 'Margen', color: SEMAFORO.alerta, valores: serie.map((d) => d.margen), formato: (n) => `${Math.round(n)}%` }}
          />
        </Marco>

        <Marco titulo="Ganancia por categoría" subtitulo="Cuánto deja cada rubro" cargando={b.cargando} error={b.error} vacio={!b.cargando && !b.error && !g?.porCategoria.length} alto={250}>
          <HBarChart items={(g?.porCategoria ?? []).map((i) => ({ nombre: i.nombre, valor: i.valor, color: i.valor < 0 ? SEMAFORO.mal : undefined }))} formato={(n) => moneda(n)} />
        </Marco>
      </div>

      <Marco
        titulo="Qué productos conviene empujar"
        subtitulo={
          g &&
          (aRevisar.length > 0 ? (
            <>
              {aRevisar.length} {aRevisar.length === 1 ? 'producto vende' : 'productos venden'} mucho y {aRevisar.length === 1 ? 'deja' : 'dejan'} menos que el margen de la casa ({pct(cortY)}):{' '}
              <strong className="text-ink">{aRevisar.slice(0, 3).map((p) => p.nombre).join(', ')}</strong>
            </>
          ) : (
            'Los productos que más venden dejan un margen sano'
          ))
        }
        cargando={b.cargando}
        error={b.error}
        vacio={!b.cargando && !b.error && conMargen.length < 2}
        mensajeVacio="Hacen falta al menos dos productos vendidos"
        alto={340}
      >
        <ScatterChart
          alto={340}
          etiquetaX="Importe vendido"
          etiquetaY="Margen %"
          formatoY={(n) => `${Math.round(n)}%`}
          cuadrantes={{ x: cortX, y: cortY, rotulos: ['Nicho rentable', 'Estrellas', 'Sin aporte', 'Vende mucho, deja poco'] }}
          puntos={conMargen.map((p) => ({
            nombre: p.nombre,
            x: p.importe,
            y: p.margen ?? 0,
            color: colorDe(p),
            rotulo: masVendidos.has(p.nombre) || (p.margen ?? 0) < 0,
            detalle: `${moneda(p.importe)} vendidos · ${pct(p.margen ?? 0)} de margen · ${moneda(p.ganancia)} de ganancia`,
          }))}
        />
      </Marco>
    </div>
  )
}
