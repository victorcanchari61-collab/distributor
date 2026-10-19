import { useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { AlertTriangle, BarChart3, Coins, FileBarChart, FileText, Hash, TrendingUp } from 'lucide-react'
import { moneda } from '../../components/charts'
import { Alert, Button, ListPage, StatCard, VisorReportePdf, cn } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { desplazarDias, hoyLocal } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { dashboardApi } from './dashboardApi'
import type { ColumnaReporte, ConsultaReporte, Reporte, Tablero, TipoDato } from './dashboardApi'
import { useBloque } from './comun'

type Fila = Record<string, unknown>

const numero = (v: unknown) => (typeof v === 'number' ? v : Number(v ?? 0))

/** Un día del backend ("2026-10-13T00:00:00Z") leído tal cual: es un día de calle, no un instante. */
const dia = (v: unknown) => (typeof v === 'string' && v.length >= 10 ? v.slice(0, 10).split('-').reverse().join('/') : '—')

/** Un valor como se lee, según su tipo. Montos con 2 decimales. */
function formatear(valor: unknown, tipo: TipoDato): string {
  if (valor === null || valor === undefined || valor === '') return '—'
  switch (tipo) {
    case 'moneda':
      return moneda(numero(valor), 2)
    case 'entero':
      return numero(valor).toLocaleString('es-PE', { maximumFractionDigits: 0 })
    case 'cantidad':
      return numero(valor).toLocaleString('es-PE', { maximumFractionDigits: 3 })
    case 'porcentaje':
      return `${numero(valor).toLocaleString('es-PE', { minimumFractionDigits: 1, maximumFractionDigits: 1 })}%`
    case 'fecha':
      return dia(valor)
    default:
      return String(valor)
  }
}

const ICONO: Record<string, ReactNode> = {
  sys: <BarChart3 size={18} />,
  success: <TrendingUp size={18} />,
  warning: <Coins size={18} />,
  danger: <AlertTriangle size={18} />,
  neutral: <Hash size={18} />,
}

/** Una columna del reporte como columna de la tabla: alineada y formateada según su tipo. */
function columnaDe(c: ColumnaReporte): DataTableColumn<Fila> {
  const numerica = c.tipo !== 'texto' && c.tipo !== 'fecha'
  return {
    key: c.clave,
    label: c.titulo,
    align: numerica ? 'right' : 'left',
    filterable: false,
    // Para ordenar y buscar: el número o la fecha tal cual, y el texto con su apoyo.
    value: (f) =>
      numerica ? numero(f[c.clave]) : `${f[c.clave] ?? ''}${c.apoyo && f[c.apoyo] ? ` ${f[c.apoyo]}` : ''}`,
    render: (f) => {
      const valor = f[c.clave]
      const negativo = c.tipo === 'moneda' && numero(valor) < 0
      const apoyo = c.apoyo ? f[c.apoyo] : null
      return (
        <div className="min-w-0">
          <p className={cn('truncate', c.destacada && 'font-semibold text-ink', negativo && 'text-red-600')}>
            {formatear(valor, c.tipo)}
          </p>
          {apoyo !== null && apoyo !== undefined && apoyo !== '' && (
            <p className="truncate text-xs text-ink-soft">{String(apoyo)}</p>
          )}
        </div>
      )
    },
  }
}

/**
 * La pestaña Reportes de un dashboard. El backend arma el reporte —vistas, columnas, filas,
 * totales y filtros— y esta pestaña lo dibuja igual para todos: así cada dashboard tiene su
 * reporte sin una pantalla propia.
 *
 * Las fechas y los filtros (cliente, ruta, proveedor, almacén...) van en el ícono de filtros como
 * listas, con solo lo que hay en esas fechas. El PDF pide la misma consulta, con la búsqueda
 * incluida: lo impreso es lo que se ve.
 */
export function ReporteTablero({ tablero, conFechas = true }: { tablero: Tablero; conFechas?: boolean }) {
  const { puede } = usePermisos()
  const [vista, setVista] = useState<string | undefined>()
  const [desdeInicial] = useState(() => desplazarDias(-29))
  const [consultaBase, setConsultaBase] = useState<Omit<ConsultaReporte, 'vista' | 'buscar'>>(() => ({
    desde: conFechas ? desdeInicial : undefined,
    hasta: conFechas ? hoyLocal() : undefined,
    filtros: {},
  }))
  const [buscar, setBuscar] = useState('')
  const [pdf, setPdf] = useState(false)

  // Por contenido y no por objeto: la tabla avisa en cada tecla del buscador, y eso no recarga.
  const clave = JSON.stringify(consultaBase)
  const b = useBloque<Reporte>(() => dashboardApi.reporte(tablero, { ...consultaBase, vista }), [tablero, vista, clave])
  const r = b.datos

  const consulta = useMemo<ConsultaReporte>(
    () => ({ ...consultaBase, vista: r?.vista ?? vista, buscar }),
    [consultaBase, r?.vista, vista, buscar],
  )

  // Las de solo filtro deciden qué se trae: no son datos de las filas (ver SysDataTable).
  const columnasFiltro: DataTableColumn<Fila>[] = [
    ...(conFechas ? [{ key: 'f_fecha', label: 'Fechas', soloFiltro: true, filterType: 'date' as const }] : []),
    ...(r?.filtros ?? []).map((f) => ({
      key: `f_${f.clave}`,
      label: f.titulo,
      soloFiltro: true,
      filterType: 'select' as const,
      filterOptions: f.opciones.map((o) => ({ value: o.valor, label: o.texto })),
    })),
  ]

  const visibles = (r?.columnas ?? []).map(columnaDe)

  // Los totales, en una línea bajo la tabla: la tabla no tiene fila de pie.
  const totales = (r?.columnas ?? [])
    .filter((c) => r?.totales[c.clave] !== undefined && r?.totales[c.clave] !== null)
    .map((c) => `${c.titulo} ${formatear(r?.totales[c.clave], c.tipo)}`)

  const titulo = r?.titulo ?? 'Reporte'
  const vistaTexto = r?.vistas.find((v) => v.id === r.vista)?.texto ?? ''

  return (
    <ListPage
      icon={<FileBarChart size={20} />}
      title={titulo}
      description="El detalle, filtrado como lo necesites."
      actions={
        puede(`dashboard.${tablero}`, 'exportar') ? (
          <Button size="sm" variant="secondary" onClick={() => setPdf(true)} disabled={!r} iconRight={<FileText size={15} />}>
            PDF
          </Button>
        ) : undefined
      }
      alert={b.error ? <Alert>{b.error}</Alert> : r?.aviso ? <Alert tone="info">{r.aviso}</Alert> : undefined}
      stats={
        r?.resumen.length ? (
          <>
            {r.resumen.map((s) => (
              <StatCard
                key={s.titulo}
                label={s.titulo}
                value={formatear(s.valor, s.tipo)}
                icon={ICONO[s.tono] ?? ICONO.neutral}
                tono={s.tono}
                hint={s.nota ?? undefined}
              />
            ))}
          </>
        ) : undefined
      }
      banner={
        r && r.vistas.length > 1 ? (
          <div className="flex flex-wrap items-center gap-1.5" role="group" aria-label="Ver">
            <span className="mr-1 text-xs font-semibold text-ink-muted">Ver</span>
            {r.vistas.map((v) => (
              <button
                key={v.id}
                type="button"
                aria-pressed={r.vista === v.id}
                onClick={() => setVista(v.id)}
                className={cn(
                  'cursor-pointer rounded-full border px-3 py-1.5 text-xs font-semibold transition-colors',
                  r.vista === v.id
                    ? 'border-transparent bg-[rgb(var(--sys-rgb))] text-[var(--sys-on)]'
                    : 'border-line bg-white text-ink-muted hover:bg-surface-alt',
                )}
              >
                {v.texto}
              </button>
            ))}
          </div>
        ) : undefined
      }
      columns={[...columnasFiltro, ...visibles]}
      rows={r?.filas ?? []}
      rowKey="clave"
      onConsulta={(q) => {
        const fecha = q.filtros.find((f) => f.columna === 'f_fecha')
        const filtros: Record<string, string> = {}
        for (const f of q.filtros) {
          if (f.columna.startsWith('f_') && f.columna !== 'f_fecha' && f.valor) filtros[f.columna.slice(2)] = f.valor
        }
        setConsultaBase({
          desde: conFechas ? fecha?.valor || desdeInicial : undefined,
          hasta: conFechas ? fecha?.valorHasta || fecha?.valor || hoyLocal() : undefined,
          filtros,
        })
        setBuscar(q.buscar)
      }}
      filtrosIniciales={conFechas ? [{ column: 'f_fecha', operator: 'between', value: desdeInicial, valueTo: hoyLocal() }] : undefined}
      cardIcon={FileBarChart}
      searchPlaceholder="Buscar en el reporte..."
      empty={b.cargando ? 'Cargando reporte...' : 'No hay datos con esos filtros.'}
      note={
        totales.length > 0 || r?.nota ? (
          <div className="space-y-1">
            {totales.length > 0 && (
              <p className="font-semibold text-ink-muted">
                Totales{buscar ? ' de lo buscado' : ''}: {totales.join(' · ')}
              </p>
            )}
            {r?.nota && <p>{r.nota}</p>}
          </div>
        ) : undefined
      }
    >
      {pdf && r && (
        <VisorReportePdf
          ruta={dashboardApi.rutaReportePdf(tablero, consulta)}
          titulo={`${titulo} · ${vistaTexto.toLowerCase()}`}
          nombreArchivo={`${tablero}-${r.vista}.pdf`}
          onCerrar={() => setPdf(false)}
        />
      )}
    </ListPage>
  )
}
