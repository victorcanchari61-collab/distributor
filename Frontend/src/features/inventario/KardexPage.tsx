import { useCallback, useEffect, useState } from 'react'
import { ArrowDownCircle, ArrowUpCircle, BookOpen, Boxes, Warehouse } from 'lucide-react'
import { Alert, Badge, ListPage, Tabs } from '../../components/ui'
import type { ConsultaTabla, DataTableColumn, TabItem } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { almacenApi, kardexApi } from './inventarioApi'
import type { AlmacenResponse, KardexResponse, ResumenKardex } from './inventarioApi'
import { useRealtime } from '../../lib/realtime'

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
export function KardexPage() {
  const [almacenes, setAlmacenes] = useState<AlmacenResponse[]>([])
  const [almacenId, setAlmacenId] = useState(0)

  const [kardex, setKardex] = useState<KardexResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    void almacenApi.getAll().then(setAlmacenes)
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
      render: (row) => new Date(row.fecha).toLocaleString('es-PE'),
    },
    { key: 'documento', label: 'Documento', sortable: false, render: (row) => <Badge>{row.documento}</Badge> },
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
      ],
      render: (row) =>
        row.tipo === 'ENTRADA' ? (
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
      render: (row) => (
        <span className="flex items-center gap-1.5">
          {row.motivo}
          {row.anulado && <Badge tone="danger">Anulado</Badge>}
        </span>
      ),
    },
    { key: 'producto', label: 'Producto', sortable: false },
    { key: 'almacen', label: 'Almacén', sortable: false },
    {
      key: 'cantidadPresentacion',
      sortable: false,
      label: 'Cantidad',
      align: 'right',
      render: (row) =>
        row.presentacion ? `${row.cantidadPresentacion} ${row.presentacion}` : `${row.cantidad}`,
    },
    {
      key: 'cantidad',
      sortable: false,
      label: 'En unidad base',
      align: 'right',
      render: (row) => (
        <span className={row.tipo === 'ENTRADA' ? 'text-emerald-600' : 'text-amber-600'}>
          {row.tipo === 'ENTRADA' ? '+' : '−'}
          {row.cantidad} {row.unidadBase}
        </span>
      ),
    },
    {
      key: 'costoTotal',
      sortable: false,
      label: 'Costo',
      align: 'right',
      render: (row) => `S/ ${row.costoTotal.toFixed(2)}`,
    },
    {
      key: 'saldo',
      sortable: false,
      label: 'Saldo',
      align: 'right',
      render: (row) => (
        <span className="font-semibold text-ink">
          {row.saldo} {row.unidadBase}
        </span>
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
