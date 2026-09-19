import { useCallback, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { Boxes, Coins, LayoutDashboard, PackageCheck, RefreshCw, ShoppingCart, TrendingUp, Wallet } from 'lucide-react'
import { Button, DateRangePicker, PageHeader, cn } from '../../components/ui'
import { NAV_DASHBOARD_FUENTES } from '../../components/layout'
import {
  BarChart,
  DonutChart,
  FunnelChart,
  Gauge,
  HBarChart,
  Heatmap,
  Kpi,
  LineChart,
  Marco,
  PALETA,
  SEMAFORO,
  ScatterChart,
  compacto,
  diaCorto,
  diaLargo,
  moneda,
  pct,
  variacion,
} from '../../components/charts'
import { ApiError } from '../../lib/apiClient'
import { desplazarDias, hoyLocal } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { dashboardApi } from './dashboardApi'
import type {
  DashboardCobranza,
  DashboardGanancias,
  DashboardInventario,
  DashboardReparto,
  DashboardVentas,
} from './dashboardApi'

// ------------------------------------------------------------------- Período

interface Periodo {
  id: string
  etiqueta: string
  desde: string
  hasta: string
}

function periodos(): Periodo[] {
  const hoy = hoyLocal()
  return [
    { id: '7', etiqueta: '7 días', desde: desplazarDias(-6), hasta: hoy },
    { id: '30', etiqueta: '30 días', desde: desplazarDias(-29), hasta: hoy },
    { id: 'mes', etiqueta: 'Este mes', desde: `${hoy.slice(0, 8)}01`, hasta: hoy },
    { id: '90', etiqueta: '90 días', desde: desplazarDias(-89), hasta: hoy },
  ]
}

/** Cuántos días abarca un rango, ambos extremos incluidos. */
function diasDe(desde: string, hasta: string): number {
  const [a, b] = [desde, hasta].map((f) => {
    const [y, m, d] = f.split('-').map(Number)
    return new Date(y, m - 1, d).getTime()
  })
  return Math.round((b - a) / 86_400_000) + 1
}

// ---------------------------------------------------------------------- Datos

interface Bloque<T> {
  datos: T | null
  cargando: boolean
  error: string
}

/**
 * Carga un bloque del tablero por su cuenta: mientras llega muestra el esqueleto, si falla lo
 * dice solo en ese gráfico, y si la persona cambia el período antes de que llegue, la respuesta
 * vieja se descarta en vez de pisar la nueva.
 */
function useBloque<T>(activo: boolean, cargar: () => Promise<T>, dependencias: unknown[]): Bloque<T> {
  const [estado, setEstado] = useState<Bloque<T>>({ datos: null, cargando: activo, error: '' })

  useEffect(() => {
    if (!activo) return
    let vigente = true
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setEstado((e) => ({ ...e, cargando: true, error: '' }))
    cargar()
      .then((datos) => vigente && setEstado({ datos, cargando: false, error: '' }))
      .catch((e) =>
        vigente &&
        setEstado({ datos: null, cargando: false, error: e instanceof ApiError ? e.message : 'No pudimos cargar este gráfico.' }),
      )
    return () => {
      vigente = false
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activo, ...dependencias])

  return estado
}

// ------------------------------------------------------------------ Estructura

function Seccion({ icono, titulo, children }: { icono: ReactNode; titulo: string; children: ReactNode }) {
  return (
    <section className="space-y-3">
      <h2 className="flex items-center gap-2 text-[15px] font-bold text-ink">
        <span className="flex size-7 items-center justify-center rounded-lg bg-[rgb(var(--sys-rgb)/0.12)] text-[rgb(var(--sys-ink-rgb))]">
          {icono}
        </span>
        {titulo}
      </h2>
      {children}
    </section>
  )
}

const rejilla = (columnas: 2 | 3) => cn('grid gap-4', columnas === 3 ? 'lg:grid-cols-3' : 'lg:grid-cols-2')

/** "▲ 12 %" en palabras, para el subtítulo de un gráfico. */
function frase(cambio: number | null, contra: string): string {
  if (cambio === null) return `Sin ${contra} con qué comparar`
  const abs = Math.abs(cambio).toLocaleString('es-PE', { maximumFractionDigits: 0 })
  if (Math.abs(cambio) < 0.5) return `Igual que ${contra}`
  return `${cambio > 0 ? '+' : '−'}${abs}% frente a ${contra}`
}

const COLOR_SALUD: Record<string, string> = {
  Agotado: '#991b1b',
  Crítico: SEMAFORO.mal,
  Atención: SEMAFORO.alerta,
  Sano: SEMAFORO.bien,
  Sobrestock: '#7c3aed',
  'Sin rotación': SEMAFORO.neutro,
}

const COLOR_DEUDA = [SEMAFORO.bien, '#65a30d', SEMAFORO.alerta, '#ea580c', SEMAFORO.mal]
const COLOR_VENCE = [SEMAFORO.mal, '#ea580c', SEMAFORO.alerta, '#65a30d', SEMAFORO.bien]

const semaforoDias = (dias: number) => (dias <= 15 ? SEMAFORO.bien : dias <= 30 ? SEMAFORO.alerta : SEMAFORO.mal)
const semaforoCobertura = (dias: number) => (dias < 7 ? SEMAFORO.mal : dias < 15 ? SEMAFORO.alerta : SEMAFORO.bien)

// ---------------------------------------------------------------------- Página

/**
 * El tablero: solo gráficos, con la conclusión de cada uno escrita debajo del título.
 *
 * Cada bloque pide sus datos por separado y solo si la persona puede ver la pantalla de origen,
 * así que un vendedor ve sus ventas y un almacenero su inventario, sin que el tablero les muestre
 * nada que no verían en el menú.
 */
export function DashboardPage() {
  const { puedeVer } = usePermisos()

  const opciones = useMemo(periodos, [])
  const [periodo, setPeriodo] = useState<Periodo>(opciones[1])
  const [version, setVersion] = useState(0)
  const { desde, hasta } = periodo
  const dias = diasDe(desde, hasta)

  const [fuenteVentas, fuenteGanancias, fuenteCobranza, fuenteInventario, fuenteReparto] = NAV_DASHBOARD_FUENTES
  const verVentas = puedeVer(fuenteVentas)
  const verGanancias = puedeVer(fuenteGanancias)
  const verCobranza = puedeVer(fuenteCobranza)
  const verInventario = puedeVer(fuenteInventario)
  const verReparto = puedeVer(fuenteReparto)

  const ventas = useBloque(verVentas, () => dashboardApi.ventas(desde, hasta), [desde, hasta, version])
  const ganancias = useBloque(verGanancias, () => dashboardApi.ganancias(desde, hasta), [desde, hasta, version])
  const cobranza = useBloque(verCobranza, () => dashboardApi.cobranza(desde, hasta), [desde, hasta, version])
  const inventario = useBloque(verInventario, () => dashboardApi.inventario(), [version])
  const reparto = useBloque(verReparto, () => dashboardApi.reparto(desde, hasta), [desde, hasta, version])

  const cambiarRango = useCallback((d: string, h: string) => {
    if (d && h) setPeriodo({ id: 'custom', etiqueta: 'Personalizado', desde: d, hasta: h })
  }, [])

  if (!verVentas && !verGanancias && !verCobranza && !verInventario && !verReparto) {
    return (
      <Marco titulo="Dashboard" vacio mensajeVacio="Todavía no tienes acceso a ninguna pantalla con datos para graficar." alto={160}>
        {null}
      </Marco>
    )
  }

  return (
    <div className="space-y-6">
      <PageHeader
        icon={<LayoutDashboard size={20} />}
        title="Dashboard"
        description="Cómo va el negocio, en gráficos. Cada uno dice su conclusión debajo del título."
        actions={
          <Button variant="secondary" size="sm" onClick={() => setVersion((v) => v + 1)}>
            <RefreshCw size={14} />
            Actualizar
          </Button>
        }
      />

      {/* Período */}
      <div className="flex flex-wrap items-center gap-2">
        <div className="flex flex-wrap gap-1.5" role="group" aria-label="Período">
          {opciones.map((o) => (
            <button
              key={o.id}
              type="button"
              onClick={() => setPeriodo(o)}
              className={cn(
                'cursor-pointer rounded-full border px-3 py-1.5 text-xs font-semibold transition-colors',
                periodo.id === o.id
                  ? 'border-transparent bg-[rgb(var(--sys-rgb))] text-[var(--sys-on)]'
                  : 'border-line bg-white text-ink-muted hover:bg-surface-alt',
              )}
            >
              {o.etiqueta}
            </button>
          ))}
        </div>

        <div className="w-56 max-w-full">
          <DateRangePicker from={desde} to={hasta} onChange={cambiarRango} />
        </div>
      </div>

      <Indicadores
        ventas={ventas}
        ganancias={ganancias}
        cobranza={cobranza}
        inventario={inventario}
        mostrar={{ ventas: verVentas, ganancias: verGanancias, cobranza: verCobranza, inventario: verInventario }}
      />

      {verVentas && (
        <Seccion icono={<ShoppingCart size={15} />} titulo="Ventas">
          <BloqueVentas b={ventas} dias={dias} />
        </Seccion>
      )}

      {verGanancias && (
        <Seccion icono={<TrendingUp size={15} />} titulo="Rentabilidad">
          <BloqueGanancias b={ganancias} dias={dias} />
        </Seccion>
      )}

      {verCobranza && (
        <Seccion icono={<Wallet size={15} />} titulo="Cobranza">
          <BloqueCobranza b={cobranza} />
        </Seccion>
      )}

      {verInventario && (
        <Seccion icono={<Boxes size={15} />} titulo="Inventario">
          <BloqueInventario b={inventario} />
        </Seccion>
      )}

      {verReparto && (
        <Seccion icono={<PackageCheck size={15} />} titulo="Pedidos y reparto">
          <BloqueReparto b={reparto} />
        </Seccion>
      )}
    </div>
  )
}

// ----------------------------------------------------------------- Indicadores

function Indicadores({
  ventas,
  ganancias,
  cobranza,
  inventario,
  mostrar,
}: {
  ventas: Bloque<DashboardVentas>
  ganancias: Bloque<DashboardGanancias>
  cobranza: Bloque<DashboardCobranza>
  inventario: Bloque<DashboardInventario>
  mostrar: { ventas: boolean; ganancias: boolean; cobranza: boolean; inventario: boolean }
}) {
  const v = ventas.datos
  const g = ganancias.datos
  const c = cobranza.datos
  const i = inventario.datos

  const vacio = <div className="h-[132px] animate-pulse rounded-panel bg-surface-alt" aria-busy="true" />

  return (
    <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
      {mostrar.ventas &&
        (v ? (
          <>
            <Kpi
              titulo="Ventas"
              valor={moneda(v.actual.importe)}
              cambio={variacion(v.actual.importe, v.anterior.importe)}
              serie={v.serie.map((d) => d.importe)}
              color={PALETA[0]}
              icono={<Coins size={15} />}
            />
            <Kpi
              titulo="Ticket promedio"
              valor={moneda(v.actual.ticket)}
              cambio={variacion(v.actual.ticket, v.anterior.ticket)}
              nota={`${v.actual.notas} ventas · ${v.actual.clientes} clientes`}
              color={PALETA[4]}
            />
          </>
        ) : (
          <>
            {vacio}
            {vacio}
          </>
        ))}

      {mostrar.ganancias &&
        (g ? (
          <Kpi
            titulo="Ganancia"
            valor={moneda(g.ganancia)}
            cambio={variacion(g.ganancia, g.gananciaAnterior)}
            serie={g.serie.map((d) => d.ganancia)}
            color={PALETA[1]}
            nota={g.margen !== null ? `Margen ${pct(g.margen)}` : 'Sin ventas en el período'}
          />
        ) : (
          vacio
        ))}

      {mostrar.cobranza &&
        (c ? (
          <Kpi
            titulo="Por cobrar"
            valor={moneda(c.totalPorCobrar)}
            bajarEsBueno
            color={PALETA[2]}
            nota={`${c.cuentas} notas · ${c.clientes} clientes`}
          />
        ) : (
          vacio
        ))}

      {mostrar.inventario &&
        !mostrar.cobranza &&
        (i ? <Kpi titulo="Inventario" valor={moneda(i.valorTotal)} nota={`${i.productos} productos con stock`} color={PALETA[5]} /> : vacio)}
    </div>
  )
}

// ---------------------------------------------------------------------- Ventas

function BloqueVentas({ b, dias }: { b: Bloque<DashboardVentas>; dias: number }) {
  const v = b.datos
  const sinVentas = !v || v.serie.every((d) => d.importe === 0)
  const contra = `los ${dias} días anteriores`

  const serie = v?.serie ?? []
  const etiquetas = serie.map((d) => diaCorto(d.fecha))
  const largas = serie.map((d) => diaLargo(d.fecha))

  const mes = v?.mes
  const diasMes = mes?.diasMes ?? 0
  const relleno = (valores: (number | null)[]) => Array.from({ length: diasMes }, (_, i) => valores[i] ?? null)
  const cierre = mes ? (mes.serieProyeccion[diasMes - 1] ?? mes.acumulado) : 0

  const paretoBarras = v?.pareto ?? []
  const calor = (v?.calor ?? []).map((c) => ({
    dia: c.dia,
    hora: c.hora,
    valor: c.importe,
    detalle: `${moneda(c.importe)} · ${c.notas} ${c.notas === 1 ? 'venta' : 'ventas'}`,
  }))

  return (
    <div className="space-y-4">
      <div className={rejilla(3)}>
        <Marco
          className="lg:col-span-2"
          titulo="Ventas por día"
          subtitulo={
            v && (
              <>
                {frase(variacion(v.actual.importe, v.anterior.importe), contra)}
                {v.atipicos.length > 0 && ` · ${v.atipicos.length} ${v.atipicos.length === 1 ? 'día fuera de lo normal' : 'días fuera de lo normal'}`}
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
                Cierre proyectado <strong className="text-ink">{moneda(cierre)}</strong> · {frase(variacion(mes.acumulado, mes.mesAnteriorMismoPunto), 'el mes pasado a esta fecha')}
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
          titulo="Clientes que sostienen las ventas"
          subtitulo={v && v.clientesTotal > 0 && <>{v.clientesAl80} de {v.clientesTotal} clientes hacen el 80% de lo vendido</>}
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && paretoBarras.length === 0}
          alto={210}
          className="lg:col-span-2"
        >
          <BarChart
            alto={210}
            etiquetas={paretoBarras.map((_, i) => String(i + 1))}
            etiquetasLargas={paretoBarras.map((p) => p.nombre)}
            series={[{ id: 'venta', nombre: 'Ventas', color: PALETA[0], valores: paretoBarras.map((p) => p.valor) }]}
            formato={(n) => moneda(n)}
            linea={{ nombre: 'Acumulado', color: SEMAFORO.alerta, valores: paretoBarras.map((p) => p.acumulado), formato: (n) => `${Math.round(n)}%`, max: 100 }}
          />
        </Marco>
      </div>

      <div className={rejilla(3)}>
        <Marco titulo="Quién vende" subtitulo="Importe por vendedor" cargando={b.cargando} error={b.error} vacio={!b.cargando && !b.error && !v?.porVendedor.length} alto={180}>
          <HBarChart items={(v?.porVendedor ?? []).map((i) => ({ nombre: i.nombre, valor: i.valor, detalle: `${i.cantidad}` }))} formato={(n) => moneda(n)} />
        </Marco>

        <Marco titulo="Qué se vende" subtitulo="Por categoría" cargando={b.cargando} error={b.error} vacio={!b.cargando && !b.error && !v?.porCategoria.length} alto={180}>
          <DonutChart porciones={(v?.porCategoria ?? []).map((i) => ({ nombre: i.nombre, valor: i.valor }))} formato={compacto} centro={{ titulo: 'Vendido', valor: moneda(v?.actual.importe ?? 0) }} />
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

// ------------------------------------------------------------------ Ganancias

function mediana(valores: number[]): number {
  if (valores.length === 0) return 0
  const orden = [...valores].sort((a, b) => a - b)
  const m = Math.floor(orden.length / 2)
  return orden.length % 2 ? orden[m] : (orden[m - 1] + orden[m]) / 2
}

function BloqueGanancias({ b, dias }: { b: Bloque<DashboardGanancias>; dias: number }) {
  const g = b.datos
  const sinDatos = !g || g.serie.every((d) => d.importe === 0)
  const serie = g?.serie ?? []

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
    <div className="space-y-4">
      <div className={rejilla(3)}>
        <Marco
          className="lg:col-span-2"
          titulo="Ganancia y margen por día"
          subtitulo={g && <>{frase(variacion(g.ganancia, g.gananciaAnterior), `los ${dias} días anteriores`)}{g.lineasSinCosto > 0 && ` · ${g.lineasSinCosto} líneas sin costo`}</>}
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && sinDatos}
          alto={240}
        >
          <BarChart
            alto={240}
            etiquetas={serie.map((d) => diaCorto(d.fecha))}
            etiquetasLargas={serie.map((d) => diaLargo(d.fecha))}
            series={[{ id: 'ganancia', nombre: 'Ganancia', color: SEMAFORO.bien, valores: serie.map((d) => d.ganancia) }]}
            colorDe={(v) => (v < 0 ? SEMAFORO.mal : SEMAFORO.bien)}
            formato={(n) => moneda(n)}
            linea={{ nombre: 'Margen', color: SEMAFORO.alerta, valores: serie.map((d) => d.margen), formato: (n) => `${Math.round(n)}%` }}
          />
        </Marco>

        <Marco titulo="Ganancia por categoría" subtitulo="Cuánto deja cada rubro" cargando={b.cargando} error={b.error} vacio={!b.cargando && !b.error && !g?.porCategoria.length} alto={240}>
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
        alto={320}
      >
        <ScatterChart
          alto={320}
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

// ------------------------------------------------------------------- Cobranza

function BloqueCobranza({ b }: { b: Bloque<DashboardCobranza> }) {
  const c = b.datos
  const cobros = c?.cobros ?? []
  const sinDeuda = !c || c.totalPorCobrar === 0
  const masVieja = c?.antiguedad.filter((a) => a.valor > 0).at(-1)

  return (
    <div className="space-y-4">
      <div className={rejilla(3)}>
        <Marco
          titulo="Cuánto hace que se debe"
          subtitulo={c && (sinDeuda ? 'Nadie debe nada' : <>{pct(((c.antiguedad[3].valor + c.antiguedad[4].valor) / c.totalPorCobrar) * 100, 0)} de la deuda pasa de 30 días</>)}
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && sinDeuda}
          mensajeVacio="Sin cuentas por cobrar"
          alto={230}
        >
          <BarChart
            alto={230}
            etiquetas={(c?.antiguedad ?? []).map((a) => a.nombre.replace(' días', ' d'))}
            etiquetasLargas={(c?.antiguedad ?? []).map((a) => `${a.nombre} · ${a.cantidad} ${a.cantidad === 1 ? 'nota' : 'notas'}`)}
            series={[{ id: 'deuda', nombre: 'Por cobrar', color: SEMAFORO.alerta, valores: (c?.antiguedad ?? []).map((a) => a.valor) }]}
            colorDe={(_, i) => COLOR_DEUDA[i]}
            formato={(n) => moneda(n)}
          />
        </Marco>

        <Marco
          titulo="Quién debe más"
          subtitulo={masVieja && `La deuda más vieja tiene ${masVieja.nombre.replace('Más de 60', 'más de 60 días').replace(' días', ' días')}`}
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && !c?.deudores.length}
          mensajeVacio="Sin deudores"
          alto={230}
        >
          <HBarChart
            items={(c?.deudores ?? []).map((d) => ({ nombre: d.cliente, valor: d.saldo, color: semaforoDias(d.dias), detalle: `${d.dias} d` }))}
            formato={(n) => moneda(n)}
          />
        </Marco>

        <Marco
          titulo="Cobros por día"
          subtitulo={c && <>Cobrado <strong className="text-ink">{moneda(c.cobradoPeriodo)}</strong> · a crédito se dio {moneda(c.creditoOtorgado)}</>}
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && !c?.metodos.length}
          mensajeVacio="Sin cobros en el período"
          alto={230}
        >
          <BarChart
            alto={230}
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

// ----------------------------------------------------------------- Inventario

function BloqueInventario({ b }: { b: Bloque<DashboardInventario> }) {
  const i = b.datos
  const criticos = (i?.cobertura ?? []).filter((c) => c.dias < 7).length
  const porVencer = (i?.vencimientos ?? []).reduce((a, v) => a + v.valor, 0)

  return (
    <div className="space-y-4">
      <div className={rejilla(3)}>
        <Marco
          className="lg:col-span-2"
          titulo="Cuánto dura el stock"
          subtitulo={i && (criticos > 0 ? <>{criticos} {criticos === 1 ? 'producto se acaba' : 'productos se acaban'} en menos de una semana al ritmo de venta actual</> : 'Ningún producto se acaba esta semana')}
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && !i?.cobertura.length}
          mensajeVacio="Todavía no hay ventas para calcular el ritmo"
          alto={260}
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

        <Marco titulo="Salud del stock" subtitulo="Productos según cuánto duran" cargando={b.cargando} error={b.error} vacio={!b.cargando && !b.error && !i?.salud.length} alto={260}>
          <DonutChart
            porciones={(i?.salud ?? []).map((s) => ({ nombre: s.nombre, valor: s.valor, color: COLOR_SALUD[s.nombre] }))}
            formato={(n) => String(n)}
            centro={{ titulo: 'Productos', valor: String((i?.salud ?? []).reduce((a, s) => a + s.valor, 0)) }}
          />
        </Marco>
      </div>

      <div className={rejilla(3)}>
        <Marco titulo="Dónde está la plata" subtitulo={i && <>Inventario valorizado a costo: <strong className="text-ink">{moneda(i.valorTotal)}</strong></>} cargando={b.cargando} error={b.error} vacio={!b.cargando && !b.error && !i?.valorPorCategoria.length} alto={200}>
          <DonutChart porciones={(i?.valorPorCategoria ?? []).map((v) => ({ nombre: v.nombre, valor: v.valor }))} formato={compacto} centro={{ titulo: 'Inventario', valor: compacto(i?.valorTotal ?? 0) }} />
        </Marco>

        <Marco titulo="Plata parada" subtitulo={i && (i.dormidoTotal > 0 ? <>{moneda(i.dormidoTotal)} en productos sin ventas hace 30 días</> : 'Todo lo que hay en stock se está moviendo')} cargando={b.cargando} error={b.error} vacio={!b.cargando && !b.error && !i?.dormido.length} mensajeVacio="Nada parado" alto={200}>
          <HBarChart items={(i?.dormido ?? []).map((d) => ({ nombre: d.nombre, valor: d.valor }))} formato={(n) => moneda(n)} unColor="#f59e0b" />
        </Marco>

        <Marco titulo="Lo que vence" subtitulo={i && (porVencer > 0 ? <>{moneda(porVencer)} vencen en los próximos 90 días</> : undefined)} cargando={b.cargando} error={b.error} vacio={!b.cargando && !b.error && porVencer === 0} mensajeVacio="Nada vence en 90 días" alto={200}>
          <BarChart
            alto={200}
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

// -------------------------------------------------------------------- Reparto

function BloqueReparto({ b }: { b: Bloque<DashboardReparto> }) {
  const r = b.datos
  const serie = r?.serie ?? []
  const sinPedidos = !r || r.serie.every((d) => d.pendientes + d.confirmados + d.anulados === 0)

  return (
    <div className="space-y-4">
      <div className={rejilla(3)}>
        <Marco
          className="lg:col-span-2"
          titulo="Pedidos por día"
          subtitulo="Cuántos se toman y en qué quedan"
          cargando={b.cargando}
          error={b.error}
          vacio={!b.cargando && !b.error && sinPedidos}
          alto={230}
        >
          <BarChart
            alto={230}
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

        <Marco titulo="Entregas completas" subtitulo="De lo entregado, lo que llegó sin recortes" cargando={b.cargando} error={b.error} alto={230}>
          <div className="flex h-[230px] items-center justify-center">
            <Gauge valor={r?.entregaCompleta ?? null} titulo="sin faltantes ni recortes" meta={90} tamano={220} />
          </div>
        </Marco>
      </div>

      <div className={rejilla(2)}>
        <Marco titulo="Del pedido al cobro" subtitulo="Dónde se pierde el pedido" cargando={b.cargando} error={b.error} vacio={!b.cargando && !b.error && sinPedidos} alto={200}>
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
            alto={200}
          >
            <DonutChart porciones={(r?.novedadesPorMotivo ?? []).map((n) => ({ nombre: n.nombre, valor: n.valor }))} formato={compacto} centro={{ titulo: 'No entregado', valor: moneda(r?.importeNovedades ?? 0) }} />
          </Marco>
        )}
      </div>
    </div>
  )
}
