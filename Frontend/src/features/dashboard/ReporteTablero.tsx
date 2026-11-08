import { useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { FileBarChart, FileText, RefreshCw } from 'lucide-react'
import { moneda } from '../../components/charts'
import { Alert, Button, ListPage, VisorReportePdf, cn } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { usePermisos } from '../../lib/permisos'
import { dashboardApi } from './dashboardApi'
import type { ColumnaReporte, ConsultaReporte, Reporte, Tablero, TipoDato } from './dashboardApi'
import { useBloque } from './comun'
import type { Tablero as EstadoTablero } from './comun'

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

/** Cómo se llama la columna de cada dato de apoyo (el que antes iba en una segunda línea). */
const TITULO_APOYO: Record<string, string> = {
  ruta: 'Ruta',
  detalle: 'Detalle',
  unidad: 'Unidad',
  semana: 'Semana',
  comprobante: 'Comprobante',
  lote: 'Lote',
  venta: 'Nota de venta',
}

/**
 * Una columna del reporte como columnas de la tabla: la principal, alineada y formateada según su tipo, y, si trae un dato de
 * apoyo (la ruta del cliente, la unidad de la cantidad), ese dato en su propia columna a continuación.
 */
function columnasDe(c: ColumnaReporte): DataTableColumn<Fila>[] {
  const numerica = c.tipo !== 'texto' && c.tipo !== 'fecha'
  const principal: DataTableColumn<Fila> = {
    key: c.clave,
    label: c.titulo,
    align: numerica ? 'right' : 'left',
    filterable: false,
    // Para ordenar y buscar: el número o la fecha tal cual.
    value: (f) => (numerica ? numero(f[c.clave]) : String(f[c.clave] ?? '')),
    render: (f) => {
      const valor = f[c.clave]
      const negativo = c.tipo === 'moneda' && numero(valor) < 0
      return (
        <span className={cn('block truncate', c.destacada && 'font-semibold text-ink', negativo && 'text-red-600')}>
          {formatear(valor, c.tipo)}
        </span>
      )
    },
  }

  if (!c.apoyo) return [principal]
  const apoyo = c.apoyo
  return [
    principal,
    {
      key: `${c.clave}_${apoyo}`,
      label: TITULO_APOYO[apoyo] ?? apoyo.charAt(0).toUpperCase() + apoyo.slice(1),
      filterable: false,
      value: (f) => String(f[apoyo] ?? ''),
      render: (f) => {
        const valor = f[apoyo]
        return valor === null || valor === undefined || valor === '' ? (
          <span className="text-ink-soft">—</span>
        ) : (
          <span className="block truncate">{String(valor)}</span>
        )
      },
    },
  ]
}

/**
 * Un dashboard completo en una sola pantalla: arriba sus gráficos y debajo el reporte detallado. El backend arma el
 * reporte —vistas, columnas, filas, totales y filtros— y esta pantalla lo dibuja igual para todos: así cada dashboard
 * tiene su reporte sin una pantalla propia.
 *
 * Todo se elige en el ícono de filtros de la tabla: las fechas (que también mueven los gráficos), la vista del reporte
 * y los filtros propios de cada uno (cliente, ruta, proveedor, almacén...), como listas con solo lo que hay en esas
 * fechas. El PDF pide la misma consulta, con la búsqueda incluida: lo impreso es lo que se ve.
 */
export function ReporteTablero({
  tablero,
  t,
  icono,
  titulo: tituloPagina,
  descripcion,
  graficos,
  conFechas = true,
}: {
  tablero: Tablero
  /** El período y el contador de "Actualizar" que comparten los gráficos y el reporte. */
  t: EstadoTablero
  icono: ReactNode
  titulo: string
  descripcion: string
  /** Los indicadores y gráficos que van sobre la tabla. */
  graficos: ReactNode
  conFechas?: boolean
}) {
  const { puede } = usePermisos()
  const [vista, setVista] = useState<string | undefined>()
  const [filtrosPropios, setFiltrosPropios] = useState<Record<string, string>>({})
  const [desdeInicial] = useState(t.desde)
  const [hastaInicial] = useState(t.hasta)
  const [buscar, setBuscar] = useState('')
  const [pdf, setPdf] = useState(false)

  const base = useMemo(
    () => ({ desde: conFechas ? t.desde : undefined, hasta: conFechas ? t.hasta : undefined, filtros: filtrosPropios }),
    [conFechas, t.desde, t.hasta, filtrosPropios],
  )

  // Por contenido y no por objeto: la tabla avisa en cada tecla del buscador, y eso no recarga.
  const clave = JSON.stringify(base)
  const b = useBloque<Reporte>(() => dashboardApi.reporte(tablero, { ...base, vista }), [tablero, vista, clave, t.version])
  const r = b.datos

  const consulta = useMemo<ConsultaReporte>(
    () => ({ ...base, vista: r?.vista ?? vista, buscar }),
    [base, r?.vista, vista, buscar],
  )

  // Las de solo filtro deciden qué se trae: no son datos de las filas (ver SysDataTable).
  const columnasFiltro: DataTableColumn<Fila>[] = [
    ...(conFechas ? [{ key: 'f_fecha', label: 'Fechas', soloFiltro: true, filterType: 'date' as const }] : []),
    ...(r && r.vistas.length > 1
      ? [
          {
            key: 'f_vista',
            label: 'Ver',
            soloFiltro: true,
            filterType: 'select' as const,
            filterVacio: 'Predeterminada',
            filterOptions: r.vistas.map((v) => ({ value: v.id, label: v.texto })),
          },
        ]
      : []),
    ...(r?.filtros ?? []).map((f) => ({
      key: `f_${f.clave}`,
      label: f.titulo,
      soloFiltro: true,
      filterType: 'select' as const,
      filterOptions: f.opciones.map((o) => ({ value: o.valor, label: o.texto })),
    })),
  ]

  const visibles = (r?.columnas ?? []).flatMap(columnasDe)

  const titulo = r?.titulo ?? 'Reporte'
  const vistaTexto = r?.vistas.find((v) => v.id === r.vista)?.texto ?? ''

  return (
    <ListPage
      icon={icono}
      title={tituloPagina}
      description={descripcion}
      actions={
        <>
          <Button size="sm" variant="secondary" onClick={() => setPdf(true)} disabled={!r} iconRight={<FileText size={15} />} sinPermiso={!puede(`dashboard.${tablero}`, 'exportar')}>
            PDF
          </Button>
          <Button variant="secondary" size="sm" onClick={t.refrescar}>
            <RefreshCw size={14} />
            Actualizar
          </Button>
        </>
      }
      alert={b.error ? <Alert>{b.error}</Alert> : r?.aviso ? <Alert tone="info">{r.aviso}</Alert> : undefined}
      banner={graficos}
      columns={[...columnasFiltro, ...visibles]}
      rows={r?.filas ?? []}
      rowKey="clave"
      onConsulta={(q) => {
        const fecha = q.filtros.find((f) => f.columna === 'f_fecha')
        const propios: Record<string, string> = {}
        for (const f of q.filtros) {
          if (f.columna.startsWith('f_') && f.columna !== 'f_fecha' && f.columna !== 'f_vista' && f.valor) {
            propios[f.columna.slice(2)] = f.valor
          }
        }
        if (conFechas) t.cambiarRango(fecha?.valor || desdeInicial, fecha?.valorHasta || fecha?.valor || hastaInicial)
        setVista(q.filtros.find((f) => f.columna === 'f_vista')?.valor || undefined)
        setFiltrosPropios((previo) => (JSON.stringify(previo) === JSON.stringify(propios) ? previo : propios))
        setBuscar(q.buscar)
      }}
      filtrosIniciales={conFechas ? [{ column: 'f_fecha', operator: 'between', value: desdeInicial, valueTo: hastaInicial }] : undefined}
      cardIcon={FileBarChart}
      searchPlaceholder="Buscar en el reporte..."
      empty={b.cargando ? 'Cargando reporte...' : 'No hay datos con esos filtros.'}
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
