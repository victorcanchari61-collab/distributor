import { useCallback, useEffect, useState } from 'react'
import { fechaHora } from '../../lib/fechas'
import { ArrowDownCircle, ArrowUpCircle, BookOpen, Boxes, Lock, Warehouse } from 'lucide-react'
import { Alert, Badge, ListPage, Tabs } from '../../components/ui'
import type { ConsultaTabla, DataTableColumn, TabItem } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { almacenApi, kardexApi, motivoApi } from './inventarioApi'
import type { AlmacenResponse, KardexResponse, MotivoResponse, ResumenKardex } from './inventarioApi'
import { productoApi } from '../maestros'
import type { ProductoResponse } from '../maestros'
import { useRealtime } from '../../lib/realtime'

/** Cómo se llama cada tipo de documento en el papel, no el código interno. */
const TIPOS_DOCUMENTO: Record<string, string> = {
  AJUSTE: 'Ajuste',
  TRANSFERENCIA: 'Transferencia',
  PRESTAMO: 'Préstamo',
  DEVOLUCION_PRESTAMO: 'Devolución de préstamo',
  RECEPCION: 'Recepción de compra',
  NOTA_VENTA: 'Venta',
  DEVOLUCION_CLIENTE: 'Devolución de cliente',
  RECOJO: 'Recojo',
  ANULACION: 'Anulación',
}

/**
 * El kardex: todo lo que entró y salió, con el saldo que dejó cada línea.
 *
 * El almacén es una pestaña, igual que en Stock: cambiar de almacén cambia
 * todo el conjunto de movimientos, no es un filtro entre varios. Filtrar por
 * producto ya lo resuelve el embudo de la propia tabla — la columna
 * "Producto" se busca ahí — así que no hace falta un select aparte.
 *
 * Es solo lectura. Lo alimentan los ajustes hoy, y mañana las compras y
 * ventas: todos escriben aquí por el mismo camino.
 */
/**
 * Una cifra que puede no venir.
 *
 * Existe porque un backend viejo —o un campo agregado despues— dejaba la
 * pantalla en blanco entera: `undefined.toFixed()` revienta el render y React
 * desmonta el arbol. Un guion se lee y no tumba nada.
 */
function cifra(valor: number | null | undefined, decimales = 2) {
  return typeof valor === 'number' ? `S/ ${valor.toFixed(decimales)}` : '—'
}

export function KardexPage() {
  const [almacenes, setAlmacenes] = useState<AlmacenResponse[]>([])
  const [almacenId, setAlmacenId] = useState(0)
  const [motivos, setMotivos] = useState<MotivoResponse[]>([])
  const [productos, setProductos] = useState<ProductoResponse[]>([])

  const [kardex, setKardex] = useState<KardexResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    void almacenApi.getAll().then(setAlmacenes)
    void motivoApi.getAll().then(setMotivos)
    void productoApi.getAll().then(setProductos)
  }, [])

  /*
   * El kardex crece una fila por cada linea de cada documento: es la tabla que
   * mas rapido escala, asi que no se trae entera. La tabla pide una pagina y
   * el servidor devuelve el saldo ya acumulado — no se puede calcular aca,
   * porque cada fila depende de todas las anteriores.
   */
  const [consulta, setConsulta] = useState<ConsultaTabla | null>(null)
  const [total, setTotal] = useState(0)
  const [resumen, setResumen] = useState<ResumenKardex | null>(null)

  const cargarPagina = useCallback(
    async (q: ConsultaTabla) => {
      setCargando(true)
      try {
        const pagina = await kardexApi.listar(q, almacenId || undefined)
        setKardex(pagina.items)
        setTotal(pagina.total)
        setError('')
      } catch (e) {
        setError(e instanceof ApiError ? e.message : 'No pudimos cargar el kardex.')
      } finally {
        setCargando(false)
      }
    },
    [almacenId],
  )

  const cargarResumen = useCallback(async () => {
    try {
      setResumen(await kardexApi.resumen(almacenId || undefined))
    } catch {
      // Los contadores del pie son secundarios: la tabla igual sirve.
    }
  }, [almacenId])

  const cargar = useCallback(async () => {
    await Promise.all([consulta ? cargarPagina(consulta) : Promise.resolve(), cargarResumen()])
  }, [consulta, cargarPagina, cargarResumen])

  // Cambiar de almacen es cambiar el listado entero: se vuelve a pedir.
  useEffect(() => {
    void cargarResumen()
    if (consulta) void cargarPagina({ ...consulta, pagina: 1 })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [almacenId])

  useRealtime('kardex', cargar)
  const almacenActivo = almacenes.find((a) => a.id === almacenId)

  const tabs: TabItem[] = [
    { id: '0', label: 'Todos', icon: <Boxes size={15} /> },
    ...almacenes.map((a) => ({
      id: String(a.id),
      label: a.nombre,
      icon: <Warehouse size={15} />,
    })),
  ]

  const columns: DataTableColumn<KardexResponse>[] = [
    {
      key: 'fecha',
      label: 'Fecha',
      filterType: 'date',
      render: (row) => fechaHora(row.fecha),
    },
    {
      // El numero de documento no se filtra por select (serian cientos de
      // opciones sin sentido): para buscar uno puntual esta el buscador de
      // arriba, que ya lo encuentra por texto.
      key: 'documento',
      label: 'Documento',
      sortable: false,
      filterable: false,
      render: (row) => <Badge>{row.documento}</Badge>,
    },
    {
      key: 'tipoDocumento',
      label: 'Tipo de documento',
      sortable: false,
      filterType: 'select',
      filterOptions: Object.entries(TIPOS_DOCUMENTO).map(([value, label]) => ({ value, label })),
      render: (row) =>
        row.tipoDocumento ? (
          TIPOS_DOCUMENTO[row.tipoDocumento] ?? row.tipoDocumento
        ) : (
          <span className="text-ink-soft">—</span>
        ),
    },
    {
      key: 'tipo',
      label: 'Tipo',
      // El kardex es un libro cronologico: reordenarlo por otra columna
      // partiria la pagina en un tramo no contiguo y el saldo acumulado
      // dejaria de tener sentido. Solo la fecha ordena.
      sortable: false,
      filterType: 'select',
      filterOptions: [
        { value: 'ENTRADA', label: 'Ingreso' },
        { value: 'SALIDA', label: 'Salida' },
        { value: 'RESERVA', label: 'Reserva' },
      ],
      render: (row) =>
        row.tipo === 'RESERVA' ? (
          <Badge tone="sys">
            <Lock size={13} className="mr-1 inline" />
            Reserva
          </Badge>
        ) : row.tipo === 'ENTRADA' ? (
          <Badge tone="success">
            <ArrowDownCircle size={13} className="mr-1 inline" />
            Ingreso
          </Badge>
        ) : (
          <Badge tone="warning">
            <ArrowUpCircle size={13} className="mr-1 inline" />
            Salida
          </Badge>
        ),
    },
    {
      key: 'motivo',
      sortable: false,
      label: 'Motivo',
      filterType: 'select',
      filterOptions: motivos.map((m) => ({ value: m.nombre, label: m.nombre })),
      render: (row) => (
        <span className="flex items-center gap-1.5">
          {row.motivo}
          {row.anulado && <Badge tone="danger">Anulado</Badge>}
        </span>
      ),
    },
    {
      key: 'producto',
      label: 'Producto',
      sortable: false,
      filterType: 'select',
      filterOptions: [...new Set(productos.map((p) => p.nombre))]
        .sort((a, b) => a.localeCompare(b, 'es'))
        .map((n) => ({ value: n, label: n })),
    },
    // El almacén ya se elige con la pestaña de arriba, no aquí de nuevo.
    { key: 'almacen', label: 'Almacén', sortable: false, filterable: false },
    /*
     * Cantidades e importes no entran al panel: el unico control es un
     * buscador de texto, y "9" contra "S/ 9.00" no encuentra lo esperado.
     */
    {
      key: 'cantidadPresentacion',
      sortable: false,
      label: 'Cantidad',
      align: 'right',
      filterable: false,
      render: (row) =>
        row.presentacion ? `${row.cantidadPresentacion} ${row.presentacion}` : `${row.cantidad}`,
    },
    {
      key: 'cantidad',
      sortable: false,
      label: 'En unidad base',
      align: 'right',
      filterable: false,
      render: (row) => (
        // La reserva no suma ni resta: por eso no lleva signo. Solo dice
        // cuanto quedo comprometido.
        <span
          className={
            row.tipo === 'RESERVA'
              ? 'text-[rgb(var(--sys-rgb))]'
              : row.tipo === 'ENTRADA'
                ? 'text-emerald-600'
                : 'text-amber-600'
          }
        >
          {row.tipo === 'RESERVA' ? '' : row.tipo === 'ENTRADA' ? '+' : '−'}
          {row.cantidad} {row.unidadBase}
        </span>
      ),
    },
    {
      key: 'costoUnitario',
      sortable: false,
      label: 'Costo unit.',
      align: 'right',
      filterable: false,
      render: (row) => (
        <span className="text-ink">
          {row.tipo === 'RESERVA' ? '—' : cifra(row.costoUnitario, 4)}
        </span>
      ),
    },
    {
      key: 'costoTotal',
      sortable: false,
      label: 'Costo',
      align: 'right',
      filterable: false,
      render: (row) => (row.tipo === 'RESERVA' ? '—' : cifra(row.costoTotal)),
    },
    /*
     * El libro de verdad: con cuanto llegaba, cuanto movio, con cuanto quedo.
     * Sin el saldo anterior no se puede comprobar una fila sola —habia que
     * mirar la de arriba— y si la pagina empieza a la mitad del historial no
     * habia con que empezar.
     */
    {
      key: 'saldoAnterior',
      sortable: false,
      label: 'Stock anterior',
      align: 'right',
      filterable: false,
      render: (row) => (
        <span className="text-ink">
          {row.saldoAnterior ?? '—'} {row.unidadBase}
        </span>
      ),
    },
    {
      key: 'saldo',
      sortable: false,
      label: 'Stock actual',
      align: 'right',
      filterable: false,
      render: (row) => (
        <span className="font-semibold text-ink">
          {row.saldo} {row.unidadBase}
        </span>
      ),
    },
    {
      key: 'valorizado',
      sortable: false,
      label: 'Valorizado',
      align: 'right',
      filterable: false,
      render: (row) => (
        <span className="font-medium text-ink">{cifra(row.valorizado)}</span>
      ),
    },
  ]

  return (
    <>
      {almacenes.length > 0 && (
        <Tabs
          className="mb-5"
          active={String(almacenId)}
          onChange={(id) => setAlmacenId(Number(id))}
          items={tabs}
        />
      )}

      <ListPage
        icon={<BookOpen size={20} />}
        title="Kardex"
        description={
          almacenActivo
            ? `Movimientos de ${almacenActivo.nombre}, con el saldo que dejó cada uno.`
            : 'Todo lo que entró y salió, con el saldo que dejó cada movimiento.'
        }
        alert={error ? <Alert>{error}</Alert> : undefined}
        columns={columns}
        rows={kardex}
        servidor={{
          total,
          cargando,
          onConsulta: (q) => {
            setConsulta(q)
            void cargarPagina(q)
          },
        }}
        cardIcon={BookOpen}
        searchPlaceholder="Buscar por documento, motivo, producto..."
        empty={
          cargando
            ? 'Cargando kardex...'
            : 'Todavía no hay movimientos. Se generan al registrar un ajuste.'
        }
        note={
          <>
            {resumen?.entradas ?? 0} entrada(s) · {resumen?.salidas ?? 0} salida(s)
          </>
        }
      />
    </>
  )
}
