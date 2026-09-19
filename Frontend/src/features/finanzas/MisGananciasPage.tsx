import { useCallback, useState } from 'react'
import { Coins, Package, Percent, TrendingUp, Wallet } from 'lucide-react'
import { Alert, Badge, ListPage, StatCard } from '../../components/ui'
import type { ConsultaTabla, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta } from '../../lib/fechas'
import { useRealtime } from '../../lib/realtime'
import { gananciaApi } from './gananciaApi'
import type { GananciaOpciones, GananciaProducto, GananciaResumen } from './gananciaApi'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

const opcionesDe = (valores: string[]) => valores.map((v) => ({ value: v, label: v }))

/** Cuántos nombres se ven antes de resumir el resto: "NV-0004, NV-0005 +3". */
function lista(valores: string[], mostrar = 2) {
  if (valores.length <= mostrar) return valores.join(', ')
  return `${valores.slice(0, mostrar).join(', ')} +${valores.length - mostrar}`
}

/** Una ganancia: verde si es positiva, roja si se perdió plata. */
function Ganancia({ valor }: { valor: number }) {
  return (
    <span className={valor < 0 ? 'font-semibold text-red-600' : 'font-semibold text-emerald-700'}>
      {soles(valor)}
    </span>
  )
}

/**
 * Mis ganancias: cuánto se ganó con cada producto.
 *
 * La base es el producto: lo vendido menos lo que costó la mercadería que
 * salió (el costo real de cada salida, la más antigua primero, no uno de
 * referencia). De ahí, el panel de Filtros recorta por fecha, vendedor, venta,
 * categoría y marca; los totales de arriba siguen ese mismo recorte.
 *
 * Lo que se ve lo recorta el alcance: quien solo vende ve lo suyo.
 */
export function MisGananciasPage() {
  const [productos, setProductos] = useState<GananciaProducto[]>([])
  const [resumen, setResumen] = useState<GananciaResumen | null>(null)
  const [opciones, setOpciones] = useState<GananciaOpciones>({
    vendedores: [],
    categorias: [],
    marcas: [],
    productos: [],
    ventas: [],
  })
  const [totalRegistros, setTotalRegistros] = useState(0)
  const [consulta, setConsulta] = useState<ConsultaTabla | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const cargarPagina = useCallback(async (q: ConsultaTabla) => {
    setCargando(true)
    try {
      const pagina = await gananciaApi.listar(q)
      setProductos(pagina.items)
      setTotalRegistros(pagina.total)
      setResumen(pagina.resumen)
      setOpciones(pagina.opciones)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos calcular las ganancias.')
    } finally {
      setCargando(false)
    }
  }, [])

  // Una venta nueva, o una que se anula, cambia lo ganado.
  useRealtime(['notasventa', 'stock'], () => (consulta ? cargarPagina(consulta) : Promise.resolve()))

  const columns: DataTableColumn<GananciaProducto>[] = [
    {
      key: 'producto',
      label: 'Producto',
      filterType: 'select',
      filterOptions: opcionesDe(opciones.productos),
      render: (row) => (
        <span className="flex flex-col">
          <span className="flex items-center gap-2 font-semibold text-ink">
            {row.producto}
            {row.sinCosto && <Badge tone="warning">Sin costo</Badge>}
          </span>
          <span className="text-xs text-ink-soft">{row.codigo}</span>
        </span>
      ),
    },
    {
      key: 'categoria',
      label: 'Categoría',
      filterType: 'select',
      filterOptions: opcionesDe(opciones.categorias),
    },
    {
      key: 'marca',
      label: 'Marca',
      filterType: 'select',
      filterOptions: opcionesDe(opciones.marcas),
    },
    {
      key: 'vendedor',
      label: 'Vendedor',
      filterType: 'select',
      filterOptions: opcionesDe(opciones.vendedores),
      // Quien lo vendió; un producto puede haber salido por varias personas.
      render: (row) => lista(row.vendedores),
    },
    {
      // Los números de las ventas en que salió; el filtro elige una concreta.
      key: 'venta',
      label: 'Ventas',
      filterType: 'select',
      filterOptions: opcionesDe(opciones.ventas),
      render: (row) => (
        <span className="flex flex-col">
          <span>{lista(row.notas)}</span>
          {row.ventas > 1 && <span className="text-xs text-ink-soft">{row.ventas} ventas</span>}
        </span>
      ),
    },
    {
      key: 'fecha',
      label: 'Última venta',
      filterType: 'date',
      render: (row) => fechaCorta(row.ultimaVenta),
    },
    {
      key: 'cantidad',
      label: 'Vendido',
      align: 'right',
      filterable: false,
      render: (row) => `${Number(row.cantidad.toFixed(2))} ${row.unidadBase}`,
    },
    { key: 'importe', label: 'Importe', align: 'right', filterable: false, render: (row) => soles(row.importe) },
    { key: 'costo', label: 'Costo', align: 'right', filterable: false, render: (row) => soles(row.costo) },
    {
      key: 'ganancia',
      label: 'Ganancia',
      align: 'right',
      filterable: false,
      render: (row) => <Ganancia valor={row.ganancia} />,
    },
    {
      key: 'margen',
      label: 'Margen',
      align: 'right',
      filterable: false,
      render: (row) => (row.margen === null ? '—' : `${row.margen.toFixed(1)} %`),
    },
  ]

  const ganancia = resumen?.ganancia ?? 0

  return (
    <ListPage
      icon={<TrendingUp size={20} />}
      title="Mis ganancias"
      description={
        resumen?.soloPropio
          ? 'Lo que ganaste con cada producto que vendiste: lo vendido menos lo que costó la mercadería.'
          : 'Cuánto se ganó con cada producto: lo vendido menos lo que costó la mercadería.'
      }
      alert={
        error ? (
          <Alert>{error}</Alert>
        ) : resumen && resumen.lineasSinCosto > 0 ? (
          <Alert tone="warning">
            {resumen.lineasSinCosto === 1 ? '1 producto vendido no tiene' : `${resumen.lineasSinCosto} productos vendidos no tienen`}{' '}
            costo: la mercadería entró sin declarar cuánto costó. En esos la ganancia sale igual al precio y el total
            queda inflado. Están marcados como «Sin costo».
          </Alert>
        ) : undefined
      }
      banner={
        resumen && (
          <p className="text-xs text-ink-soft">
            Ventas del <span className="font-semibold text-ink-muted">{fechaCorta(resumen.desde)}</span> al{' '}
            <span className="font-semibold text-ink-muted">{fechaCorta(resumen.hasta)}</span>. Cambia el rango, el
            vendedor, la venta, la categoría o la marca en el ícono de Filtros.
          </p>
        )
      }
      stats={
        <>
          <StatCard
            label="Vendido"
            value={soles(resumen?.importe ?? 0)}
            icon={<Wallet size={18} />}
            hint={`${resumen?.ventas ?? 0} ${resumen?.ventas === 1 ? 'venta' : 'ventas'}`}
          />
          <StatCard label="Costo de la mercadería" value={soles(resumen?.costo ?? 0)} icon={<Coins size={18} />} tono="neutral" />
          <StatCard
            label="Ganancia"
            value={soles(ganancia)}
            icon={<TrendingUp size={18} />}
            tono={ganancia < 0 ? 'danger' : 'success'}
          />
          <StatCard
            label="Margen"
            value={resumen?.margen == null ? '—' : `${resumen.margen.toFixed(1)} %`}
            icon={<Percent size={18} />}
            tono="sys"
            hint="Ganancia sobre lo vendido"
          />
          <StatCard
            label="Productos"
            value={String(resumen?.productos ?? 0)}
            icon={<Package size={18} />}
            tono="neutral"
          />
        </>
      }
      columns={columns}
      rows={productos}
      rowKey="productoId"
      servidor={{
        total: totalRegistros,
        cargando,
        onConsulta: (q) => {
          setConsulta(q)
          void cargarPagina(q)
        },
      }}
      cardIcon={TrendingUp}
      searchPlaceholder="Buscar por producto, categoría, marca..."
      empty={cargando ? 'Calculando ganancias...' : 'No hay ventas con esos filtros.'}
    />
  )
}
