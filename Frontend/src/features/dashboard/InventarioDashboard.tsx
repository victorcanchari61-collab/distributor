import { Boxes, CalendarX, PackageOpen, Snowflake } from 'lucide-react'
import { BarChart, DonutChart, HBarChart, Kpi, Marco, PALETA, SEMAFORO, compacto, moneda } from '../../components/charts'
import { dashboardApi } from './dashboardApi'
import { COLOR_SALUD, COLOR_VENCE, Encabezado, FilaKpi, rejilla, semaforoCobertura, useBloque, useTablero } from './comun'

/** Qué se acaba, qué está parado y qué vence: una foto de hoy, sin rango de fechas. */
export function InventarioDashboard() {
  const t = useTablero()
  const b = useBloque(() => dashboardApi.inventario(), [t.version])
  const i = b.datos

  const criticos = (i?.cobertura ?? []).filter((c) => c.dias < 7).length
  const porVencer = (i?.vencimientos ?? []).reduce((a, v) => a + v.valor, 0)

  return (
    <div className="space-y-5">
      <Encabezado
        icono={<Boxes size={20} />}
        titulo="Dashboard de inventario"
        descripcion="Cuánto dura lo que hay, dónde está la plata y qué vence. Es la foto de hoy, al ritmo de venta de los últimos 30 días."
        tablero={t}
        sinPeriodo
      />

      <FilaKpi cargando={b.cargando}>
        {i && (
          <>
            <Kpi titulo="Inventario" valor={moneda(i.valorTotal)} color={PALETA[5]} icono={<Boxes size={15} />} nota={`${i.productos} productos con stock · a costo`} />
            <Kpi titulo="Por agotarse" valor={String(criticos)} bajarEsBueno color={SEMAFORO.mal} icono={<PackageOpen size={15} />} nota="Duran menos de 7 días" />
            <Kpi titulo="Plata parada" valor={moneda(i.dormidoTotal)} bajarEsBueno color={SEMAFORO.alerta} icono={<Snowflake size={15} />} nota="Sin ventas hace 30 días" />
            <Kpi titulo="Por vencer" valor={moneda(porVencer)} bajarEsBueno color={SEMAFORO.mal} icono={<CalendarX size={15} />} nota="Vencido o que vence en 90 días" />
          </>
        )}
      </FilaKpi>

      <div className={rejilla(3)}>
        <Marco
          className="lg:col-span-2"
          titulo="Cuánto dura el stock"
          subtitulo={i && (criticos > 0 ? <>{criticos} {criticos === 1 ? 'producto se acaba' : 'productos se acaban'} en menos de una semana al ritmo de venta actual</> : 'Ningún producto se acaba esta semana')}
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && !i?.cobertura.length}
          mensajeVacio="Todavía no hay ventas para calcular el ritmo"
          alto={280}
        >
          <HBarChart
            maximo={60}
            referencias={[{ valor: 7, etiqueta: '7 días' }, { valor: 15, etiqueta: '15 días' }]}
            formato={(n) => `${n.toLocaleString('es-PE', { maximumFractionDigits: 0 })} d`}
            items={(i?.cobertura ?? []).map((c) => ({
              nombre: c.producto,
              valor: c.dias,
              color: semaforoCobertura(c.dias),
              detalle: `${c.stock.toLocaleString('es-PE', { maximumFractionDigits: 0 })} ${c.unidad}`,
            }))}
          />
        </Marco>

        <Marco titulo="Salud del stock" subtitulo="Productos según cuánto duran" cargando={b.cargando} error={b.error} vacio={!b.cargando && !b.error && !i?.salud.length} alto={280}>
          <DonutChart
            porciones={(i?.salud ?? []).map((s) => ({ nombre: s.nombre, valor: s.valor, color: COLOR_SALUD[s.nombre] }))}
            formato={(n) => String(n)}
            centro={{ titulo: 'Productos', valor: String((i?.salud ?? []).reduce((a, s) => a + s.valor, 0)) }}
          />
        </Marco>
      </div>

      <div className={rejilla(3)}>
        <Marco titulo="Dónde está la plata" subtitulo={i && <>Inventario valorizado a costo: <strong className="text-ink">{moneda(i.valorTotal)}</strong></>} cargando={b.cargando} error={b.error} vacio={!b.cargando && !b.error && !i?.valorPorCategoria.length} alto={210}>
          <DonutChart porciones={(i?.valorPorCategoria ?? []).map((v) => ({ nombre: v.nombre, valor: v.valor }))} formato={compacto} centro={{ titulo: 'Inventario', valor: compacto(i?.valorTotal ?? 0) }} />
        </Marco>

        <Marco titulo="Plata parada" subtitulo={i && (i.dormidoTotal > 0 ? <>{moneda(i.dormidoTotal)} en productos sin ventas hace 30 días</> : 'Todo lo que hay en stock se está moviendo')} cargando={b.cargando} error={b.error} vacio={!b.cargando && !b.error && !i?.dormido.length} mensajeVacio="Nada parado" alto={210}>
          <HBarChart items={(i?.dormido ?? []).map((d) => ({ nombre: d.nombre, valor: d.valor }))} formato={(n) => moneda(n)} unColor="#f59e0b" />
        </Marco>

        <Marco titulo="Lo que vence" subtitulo={i && (porVencer > 0 ? <>{moneda(porVencer)} vencidos o por vencer en 90 días</> : undefined)} cargando={b.cargando} error={b.error} vacio={!b.cargando && !b.error && porVencer === 0} mensajeVacio="Nada vence en 90 días" alto={210}>
          <BarChart
            alto={210}
            etiquetas={(i?.vencimientos ?? []).map((v) => v.nombre.replace(' días', ' d'))}
            series={[{ id: 'vence', nombre: 'A costo', color: SEMAFORO.alerta, valores: (i?.vencimientos ?? []).map((v) => v.valor) }]}
            colorDe={(_, idx) => COLOR_VENCE[idx]}
            formato={(n) => moneda(n)}
          />
        </Marco>
      </div>
    </div>
  )
}
