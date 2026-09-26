import { useCallback, useEffect, useState } from 'react'
import { fechaCorta, fechaHora } from '../../lib/fechas'
import { ArrowLeft, Eye, HandCoins, Plus, Trash2, Undo2 } from 'lucide-react'
import {
  AccionPdf,
  AgregarProductoPanel,
  Alert,
  Badge,
  Button,
  Desplegable,
  Input,
  ListPage,
  Modal,
  PageHeader,
  PageSection,
  ResumenDocumento,
  RowAction,
  StatCard,
  SysDataTable,
  TablaProductosDetalle,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type {
  ColumnaDetalleProducto,
  ConsultaTabla,
  DataTableColumn,
  LineaProductoNueva,
} from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { productoApi } from '../maestros'
import type { ProductoResponse } from '../maestros'
import { almacenApi, prestamoApi, stockApi } from './inventarioApi'
import type {
  AlmacenResponse,
  PrestamoDetalleResponse,
  PrestamoDevolucionResponse,
  PrestamoFila,
  PrestamoResponse,
  TipoPrestamo,
  ResumenPrestamos,
} from './inventarioApi'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'

type FilaPrestamo = LineaProductoNueva

/**
 * Una sola tabla para el historial y para lo que se está por guardar: cada
 * línea de cada devolución es su propia fila (una devolución con 3 productos
 * sale en 3 filas, no apiladas en una), y una fila "nueva" por cada producto
 * pendiente cuando se está agregando. Todas comparten las mismas columnas.
 */
interface FilaDevolucionTabla {
  clave: string
  /** Repetido en cada línea de la misma devolución: por él se anula y se imprime. Null en una fila nueva. */
  devolucion: PrestamoDevolucionResponse | null
  producto: string
  /** Ya guardada: "12 Caja x12". Nueva: se muestra el input en su lugar. */
  cantidadGuardada: string | null
  /** Solo en una fila nueva: para el input y su tope. */
  pendiente: { prestamoDetalleId: number; cantidadPendiente: number; unidadBase: string; cantidad: number } | null
}

function estadoPrestamoBadge(estado: PrestamoResponse['estado']) {
  const tono = estado === 'ANULADO' ? 'danger' : estado === 'DEVUELTO' ? 'neutral' : 'warning'
  const texto = estado === 'ANULADO' ? 'Anulado' : estado === 'DEVUELTO' ? 'Devuelto' : 'Pendiente'
  return <Badge tone={tono}>{texto}</Badge>
}

/**
 * Mercadería que sale o entra desde fuera de la empresa: se presta y se
 * espera de vuelta. La contraparte no es un almacén propio — es un tercero —
 * y por eso cada préstamo lleva quién es y si ya se devolvió.
 *
 * DADO: sale como cualquier salida, hereda el costo del stock que consume.
 * RECIBIDO: entra al costo de referencia del producto (o el que se indique),
 * porque no hay factura de compra detrás — es solo para no dejar el stock en
 * cero soles mientras está prestado.
 */
export function PrestamosPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const [prestamos, setPrestamos] = useState<PrestamoFila[]>([])
  const [almacenes, setAlmacenes] = useState<AlmacenResponse[]>([])
  const [productos, setProductos] = useState<ProductoResponse[]>([])

  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [vista, setVista] = useState<'lista' | 'form'>('lista')
  const [detalleAbierto, setDetalleAbierto] = useState<PrestamoResponse | null>(null)
  const [devolucionAbierta, setDevolucionAbierta] = useState<PrestamoResponse | null>(null)
  const [cantidadesDevolucion, setCantidadesDevolucion] = useState<Record<number, string>>({})
  const [agregandoDevolucion, setAgregandoDevolucion] = useState(false)
  const [almacenDevolucionId, setAlmacenDevolucionId] = useState(0)
  const [guardando, setGuardando] = useState(false)
  const { confirmar, dialogo } = useConfirmacion()

  const [cabecera, setCabecera] = useState({
    tipo: 'DADO' as TipoPrestamo,
    contraparte: '',
    almacenId: 0,
    observacion: '',
  })
  const [filas, setFilas] = useState<FilaPrestamo[]>([])
  const [stockMap, setStockMap] = useState<Record<number, number>>({})

  /*
   * Los prestamos se acumulan con la operacion: la tabla pide su pagina y los
   * contadores salen del resumen.
   */
  const [consulta, setConsulta] = useState<ConsultaTabla | null>(null)
  const [totalRegistros, setTotalRegistros] = useState(0)
  const [resumen, setResumen] = useState<ResumenPrestamos | null>(null)

  const cargarPagina = useCallback(async (q: ConsultaTabla) => {
    setCargando(true)
    try {
      const pagina = await prestamoApi.listar(q)
      setPrestamos(pagina.items)
      setTotalRegistros(pagina.total)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los préstamos.')
    } finally {
      setCargando(false)
    }
  }, [])

  const cargarApoyo = useCallback(async () => {
    try {
      const [res, alms, prods] = await Promise.all([
        prestamoApi.resumen(),
        almacenApi.getAll(),
        productoApi.getAll(),
      ])
      setResumen(res)
      setAlmacenes(alms)
      setProductos(prods.filter((p) => p.activo && p.controlaStock))
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los datos de apoyo.')
    }
  }, [])

  const cargar = useCallback(async () => {
    await Promise.all([consulta ? cargarPagina(consulta) : Promise.resolve(), cargarApoyo()])
  }, [consulta, cargarPagina, cargarApoyo])

  useEffect(() => {
    void cargarApoyo()
  }, [cargarApoyo])

  useRealtime('prestamos', cargar)

  const activos = almacenes.filter((a) => a.activo)

  // Stock del almacén elegido, para mostrarlo mientras se arma cada línea.
  useEffect(() => {
    if (vista !== 'form' || !cabecera.almacenId) return
    let cancelado = false
    // Solo cuánto hay disponible: /disponible no trae catálogo ni costos.
    void stockApi.disponible(cabecera.almacenId).then((filas) => {
      if (!cancelado) setStockMap(Object.fromEntries(filas.map((f) => [f.productoId, f.disponible])))
    })
    return () => {
      cancelado = true
    }
  }, [vista, cabecera.almacenId])

  const abrirNuevo = () => {
    setCabecera({
      tipo: 'DADO',
      contraparte: '',
      almacenId: activos.find((a) => a.esPrincipal)?.id ?? activos[0]?.id ?? 0,
      observacion: '',
    })
    setFilas([])
    setVista('form')
  }

  const actualizarFila = (id: string, cambio: Partial<FilaPrestamo>) =>
    setFilas((prev) => prev.map((f) => (f.id === id ? { ...f, ...cambio } : f)))

  const guardar = async () => {
    if (!cabecera.contraparte.trim()) {
      return toast.error('Indica a quién le prestas o quién te presta.')
    }
    if (!cabecera.almacenId) return toast.error('Elige el almacén.')

    const validas = filas.filter((f) => f.productoId && f.cantidad)
    if (validas.length === 0) return toast.error('Agrega al menos un producto.')

    setGuardando(true)
    try {
      await prestamoApi.create({
        tipo: cabecera.tipo,
        contraparte: cabecera.contraparte.trim(),
        almacenId: cabecera.almacenId,
        observacion: cabecera.observacion.trim() || null,
        detalle: validas.map((f) => ({
          productoId: f.productoId,
          presentacionId: f.presentacionId || null,
          cantidad: Number(f.cantidad),
          costoPresentacion:
            cabecera.tipo === 'RECIBIDO' && f.costo ? Number(f.costo) : null,
        })),
      })
      setVista('lista')
      await cargar()
      toast.exito('Préstamo registrado')
    } catch (e) {
      toast.error(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos registrar el préstamo.',
      )
    } finally {
      setGuardando(false)
    }
  }

  // La fila no trae detalle ni devoluciones: el préstamo completo se pide al abrirlo.
  const conPrestamoCompleto = async (id: number, abrir: (p: PrestamoResponse) => void) => {
    try {
      abrir(await prestamoApi.getById(id))
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos abrir el préstamo.')
    }
  }

  const abrirDevolucion = (p: PrestamoResponse) => {
    setDevolucionAbierta(p)
    setAgregandoDevolucion(false)
    setCantidadesDevolucion({})
  }

  /*
   * Refresca lo que se ve tras registrar o anular una devolución.
   *
   * El préstamo que se está gestionando se pide por id y no se busca en la
   * lista: con paginación solo estaría si cayó en la página visible.
   */
  const refrescarDevolucion = useCallback(async (id: number) => {
    await cargar()
    setDevolucionAbierta(await prestamoApi.getById(id))
  }, [cargar])

  /** Abre la fila nueva de la tabla, sugerida con lo que falta devolver de cada producto. */
  const agregarDevolucion = () => {
    if (!devolucionAbierta) return
    setCantidadesDevolucion(
      Object.fromEntries(
        devolucionAbierta.detalle
          .filter((d) => d.cantidadPendiente > 0)
          .map((d) => [d.id, String(d.cantidadPendiente)]),
      ),
    )
    // Por defecto el principal, pero se puede cambiar: si ahí no hay stock
    // (o simplemente conviene guardarlo en otro), se elige cualquier otro.
    setAlmacenDevolucionId(activos.find((a) => a.esPrincipal)?.id ?? activos[0]?.id ?? 0)
    setAgregandoDevolucion(true)
  }

  const cancelarDevolucion = () => {
    setAgregandoDevolucion(false)
    setCantidadesDevolucion({})
  }

  const registrarDevolucion = async () => {
    if (!devolucionAbierta) return
    if (!almacenDevolucionId) return toast.error('Elige el almacén.')

    const detalle = devolucionAbierta.detalle
      .map((d) => ({
        prestamoDetalleId: d.id,
        cantidad: Number(cantidadesDevolucion[d.id] || 0),
      }))
      .filter((l) => l.cantidad > 0)

    if (detalle.length === 0) return toast.error('Indica cuánto se devuelve.')

    setGuardando(true)
    try {
      await prestamoApi.devolver(devolucionAbierta.id, almacenDevolucionId, detalle)
      setAgregandoDevolucion(false)
      setCantidadesDevolucion({})
      await refrescarDevolucion(devolucionAbierta.id)
      toast.exito('Devolución registrada')
    } catch (e) {
      toast.error(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos registrar la devolución.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const anularDevolucion = (d: PrestamoDevolucionResponse) =>
    confirmar({
      titulo: `Anular devolución ${d.numero}`,
      mensaje:
        'Revierte el stock que movió esta devolución y la línea del préstamo vuelve a quedar pendiente por esa cantidad. No se puede deshacer.',
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        if (!devolucionAbierta) return
        try {
          await prestamoApi.anularDevolucion(d.id)
          await refrescarDevolucion(devolucionAbierta.id)
          toast.exito('Devolución anulada')
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos anular la devolución.')
        }
      },
    })

  const anularPrestamo = (p: PrestamoFila) =>
    confirmar({
      titulo: `Anular ${p.numero}`,
      mensaje:
        'Revierte el stock que movió este préstamo al registrarse. Se bloquea si ya tiene alguna devolución registrada.',
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        try {
          await prestamoApi.anular(p.id)
          await cargar()
          toast.exito(`${p.numero} anulado`)
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos anular el préstamo.')
        }
      },
    })

  /*
   * Una sola tabla: cada línea de cada devolución guardada es su propia
   * fila (documento, fecha, estado y almacén se repiten en cada línea de una
   * misma devolución), y una fila por producto pendiente cuando se está
   * agregando una — mismas columnas para las dos cosas, nada aparte.
   */
  const columnasDevoluciones: DataTableColumn<FilaDevolucionTabla>[] = [
    {
      key: 'numero',
      label: 'Documento',
      sortable: false,
      render: (f) =>
        f.devolucion ? (
          <Badge tone={f.devolucion.estado === 'ANULADO' ? 'neutral' : undefined}>{f.devolucion.numero}</Badge>
        ) : (
          <Badge tone="sys">Nueva</Badge>
        ),
    },
    { key: 'producto', label: 'Producto', sortable: false },
    {
      key: 'cantidad',
      label: 'Cantidad',
      sortable: false,
      render: (f) =>
        f.cantidadGuardada ??
        (f.pendiente && (
          <Input
            size="sm"
            type="number"
            step="0.0001"
            max={f.pendiente.cantidadPendiente}
            value={cantidadesDevolucion[f.pendiente.prestamoDetalleId] ?? ''}
            onChange={(e) =>
              setCantidadesDevolucion({
                ...cantidadesDevolucion,
                [f.pendiente!.prestamoDetalleId]: e.target.value,
              })
            }
          />
        )),
    },
    {
      key: 'almacen',
      label: 'Almacén',
      sortable: false,
      render: (f) =>
        f.devolucion ? (
          f.devolucion.almacen
        ) : (
          <Desplegable
            size="sm"
            value={almacenDevolucionId}
            onChange={(v) => setAlmacenDevolucionId(Number(v))}
            options={activos.map((a) => ({ value: a.id, label: a.nombre, detalle: a.codigo }))}
          />
        ),
    },
    {
      key: 'fecha',
      label: 'Fecha',
      sortable: false,
      render: (f) => (f.devolucion ? fechaHora(f.devolucion.fecha) : <span className="text-ink-soft">—</span>),
    },
    {
      key: 'usuario',
      label: 'Registrada por',
      sortable: false,
      render: (f) => f.devolucion?.usuario ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'estado',
      label: 'Estado',
      sortable: false,
      render: (f) =>
        f.devolucion ? (
          <Badge tone={f.devolucion.estado === 'ANULADO' ? 'danger' : 'success'}>
            {f.devolucion.estado === 'ANULADO' ? 'Anulada' : 'Confirmada'}
          </Badge>
        ) : (
          <span className="text-ink-soft">—</span>
        ),
    },
  ]

  const columnasFilas: DataTableColumn<FilaPrestamo>[] = [
    {
      key: 'producto',
      label: 'Producto',
      value: (fila) => productos.find((p) => p.id === fila.productoId)?.nombre ?? '',
      render: (fila) => (
        <Desplegable
          value={fila.productoId}
          onChange={(v) => actualizarFila(fila.id, { productoId: Number(v), presentacionId: 0 })}
          options={productos.map((p) => ({ value: p.id, label: p.nombre, detalle: p.codigo }))}
        />
      ),
    },
    {
      key: 'presentacion',
      label: 'Presentación',
      render: (fila) => {
        const producto = productos.find((p) => p.id === fila.productoId)
        const presentaciones = producto?.presentaciones.filter((p) => p.activo) ?? []

        return (
          <Desplegable
            value={fila.presentacionId}
            onChange={(v) => actualizarFila(fila.id, { presentacionId: Number(v) })}
            placeholder={producto?.unidadBase ?? 'Elegir'}
            disabled={!producto}
            options={
              producto
                ? [
                    { value: 0, label: producto.unidadBase, nota: 'unidad base' },
                    ...presentaciones
                      .filter((p) => !p.esBase)
                      .map((p) => ({
                        value: p.id,
                        label: p.nombre,
                        detalle: `${p.factor} ${producto.unidadBase}`,
                      })),
                  ]
                : []
            }
          />
        )
      },
    },
    {
      key: 'cantidad',
      label: 'Cantidad',
      align: 'right',
      value: (fila) => Number(fila.cantidad) || 0,
      render: (fila) => (
        <Input
          type="number"
          step="0.0001"
          value={fila.cantidad}
          onChange={(e) => actualizarFila(fila.id, { cantidad: e.target.value })}
        />
      ),
    },
    ...(cabecera.tipo === 'RECIBIDO'
      ? [
          {
            key: 'costo',
            label: 'Costo',
            align: 'right' as const,
            value: (fila: FilaPrestamo) => Number(fila.costo) || 0,
            render: (fila: FilaPrestamo) => {
              const producto = productos.find((p) => p.id === fila.productoId)
              const presentaciones = producto?.presentaciones.filter((p) => p.activo) ?? []
              const presentacionElegida = presentaciones.find((p) => p.id === fila.presentacionId)

              return (
                <Input
                  type="number"
                  step="0.01"
                  disabled={!producto}
                  placeholder={
                    producto?.costoReferencia
                      ? String(producto.costoReferencia * (presentacionElegida?.factor ?? 1))
                      : '0.00'
                  }
                  value={fila.costo}
                  onChange={(e) => actualizarFila(fila.id, { costo: e.target.value })}
                />
              )
            },
          },
        ]
      : []),
  ]

  const columns: DataTableColumn<PrestamoFila>[] = [
    // Número y contraparte se buscan con el buscador de arriba, no en el panel.
    { key: 'numero', label: 'Número', filterable: false, render: (row) => <Badge>{row.numero}</Badge> },
    {
      key: 'tipo',
      label: 'Tipo',
      filterType: 'select',
      filterOptions: [
        { value: 'DADO', label: 'Prestado' },
        { value: 'RECIBIDO', label: 'Recibido' },
      ],
      render: (row) => (
        <Badge tone={row.tipo === 'DADO' ? 'warning' : 'success'}>
          {row.tipo === 'DADO' ? 'Prestado' : 'Recibido'}
        </Badge>
      ),
    },
    { key: 'contraparte', label: 'Contraparte', filterable: false },
    {
      key: 'almacen',
      label: 'Almacén',
      filterType: 'select',
      filterOptions: almacenes.map((a) => ({ value: a.nombre, label: a.nombre })),
    },
    {
      key: 'fecha',
      label: 'Fecha',
      filterType: 'date',
      render: (row) => fechaCorta(row.fecha),
    },
    {
      key: 'total',
      label: 'Valor',
      align: 'right',
      // Sin control numerico en el panel, buscar "9" contra "S/ 9.00" no
      // encuentra lo que la persona espera.
      filterable: false,
      render: (row) => `S/ ${row.total.toFixed(2)}`,
    },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'PENDIENTE', label: 'Pendiente' },
        { value: 'DEVUELTO', label: 'Devuelto' },
      ],
      render: (row) => estadoPrestamoBadge(row.estado),
    },
  ]

  if (vista === 'form') {
    return (
      <div className="space-y-5">
        <PageHeader
          icon={<HandCoins size={20} />}
          title="Nuevo préstamo"
          description="DADO: sale mercadería propia. RECIBIDO: entra la de un tercero."
          actions={
            <Button variant="secondary" size="sm" onClick={() => setVista('lista')}>
              <ArrowLeft size={15} />
              Volver
            </Button>
          }
        />

        <div className="grid grid-cols-1 gap-5 xl:grid-cols-[1fr_360px] xl:items-start">
          <PageSection
            title="Productos"
            description={`${filas.length} producto${filas.length === 1 ? '' : 's'} agregado${filas.length === 1 ? '' : 's'}`}
          >
            {cabecera.tipo === 'RECIBIDO' && (
              <p className="mb-3 text-xs text-ink-soft">Costo vacío usa el costo de referencia.</p>
            )}
            <AgregarProductoPanel
              productos={productos}
              stock={stockMap}
              pideCosto={cabecera.tipo === 'RECIBIDO'}
              onAgregar={(linea) => setFilas((f) => [...f, linea])}
            />

            <div className="mt-4">
              <SysDataTable
                columns={columnasFilas}
                rows={filas}
                rowKey="id"
                toolbar={false}
                empty="Agrega productos con el buscador de arriba."
                actions={(fila) => (
                  <RowAction
                    label={`Quitar ${productos.find((p) => p.id === fila.productoId)?.nombre ?? 'línea'}`}
                    tone="danger"
                    onClick={() => setFilas((f) => f.filter((x) => x.id !== fila.id))}
                  >
                    <Trash2 size={15} />
                  </RowAction>
                )}
              />
            </div>
          </PageSection>

          <PageSection title="Préstamo">
            <Desplegable
              label="Tipo"
              value={cabecera.tipo}
              onChange={(v) => setCabecera({ ...cabecera, tipo: v as TipoPrestamo })}
              options={[
                { value: 'DADO', label: 'Prestado', nota: 'sale mercadería propia' },
                { value: 'RECIBIDO', label: 'Recibido', nota: 'entra mercadería de un tercero' },
              ]}
            />

            <Desplegable
              className="mt-4"
              label="Almacén"
              value={cabecera.almacenId}
              onChange={(v) => setCabecera({ ...cabecera, almacenId: Number(v) })}
              options={activos.map((a) => ({ value: a.id, label: a.nombre, detalle: a.codigo }))}
            />

            <Input
              className="mt-4"
              label={cabecera.tipo === 'DADO' ? 'A quién le prestas' : 'Quién te presta'}
              placeholder="Bodega Rosa, Distribuidora López..."
              value={cabecera.contraparte}
              onChange={(e) => setCabecera({ ...cabecera, contraparte: e.target.value })}
            />

            <Input
              className="mt-4"
              label="Observación"
              optional
              placeholder="Motivo, fecha estimada de devolución..."
              value={cabecera.observacion}
              onChange={(e) => setCabecera({ ...cabecera, observacion: e.target.value })}
            />
          </PageSection>
        </div>

        <div className="flex justify-end gap-2">
          <Button variant="secondary" size="sm" onClick={() => setVista('lista')}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            Registrar préstamo
          </Button>
        </div>
      </div>
    )
  }

  return (
    <ListPage
      icon={<HandCoins size={20} />}
      title="Préstamos"
      description="Mercadería que sale o entra desde fuera de la empresa: se presta y se espera de vuelta."
      actions={
        puede('inv.prestamos', 'crear') ? (
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nuevo préstamo
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard
            label="Préstamos"
            value={String(resumen?.total ?? 0)}
            icon={<HandCoins size={18} />}
          />
          <StatCard
            label="Pendientes"
            value={String(resumen?.pendientes ?? 0)}
            icon={<HandCoins size={18} />}
            tono="warning"
          />
          <StatCard
            label="Devueltos"
            value={String(resumen?.devueltos ?? 0)}
            icon={<Undo2 size={18} />}
            tono="neutral"
          />
        </>
      }
      columns={columns}
      rows={prestamos}
      servidor={{
        total: totalRegistros,
        cargando,
        onConsulta: (q) => {
          setConsulta(q)
          void cargarPagina(q)
        },
      }}
      cardIcon={HandCoins}
      searchPlaceholder="Buscar por número, contraparte..."
      empty={cargando ? 'Cargando préstamos...' : 'Todavía no hay préstamos registrados.'}
      rowActions={(row) => (
        <>
          <RowAction label={`Ver ${row.numero}`} tone="view" onClick={() => void conPrestamoCompleto(row.id, setDetalleAbierto)}>
            <Eye size={15} />
          </RowAction>
          {puede('inv.prestamos', 'exportar') && (
            <AccionPdf documento="prestamos" id={row.id} numero={row.numero} />
          )}
          {puede('inv.prestamos', 'confirmar') && (
            <RowAction
              label={`Registrar devolución de ${row.numero}`}
              tone="warning"
              disabled={row.estado !== 'PENDIENTE'}
              disabledReason="Ya fue devuelto"
              onClick={() => void conPrestamoCompleto(row.id, abrirDevolucion)}
            >
              <Undo2 size={15} />
            </RowAction>
          )}
          {puede('inv.prestamos', 'anular') && (
            <RowAction
              label={`Anular ${row.numero}`}
              tone="danger"
              disabled={row.estado !== 'PENDIENTE' || row.tieneDevolucion}
              disabledReason={
                row.estado === 'ANULADO'
                  ? 'Ya está anulado'
                  : row.estado === 'DEVUELTO'
                    ? 'Ya se devolvió'
                    : 'Ya tiene una devolución registrada'
              }
              onClick={() => anularPrestamo(row)}
            >
              <Undo2 size={15} />
            </RowAction>
          )}
        </>
      )}
    >
      {/* Ver detalle */}
      <Modal
        open={detalleAbierto !== null}
        title={detalleAbierto ? `${detalleAbierto.numero} · ${detalleAbierto.contraparte}` : ''}
        description={
          detalleAbierto
            ? `Emisión ${fechaCorta(detalleAbierto.fecha)} · ${detalleAbierto.almacen} · ${
                detalleAbierto.tipo === 'DADO' ? 'Prestado' : 'Recibido'
              }`
            : undefined
        }
        onClose={() => setDetalleAbierto(null)}
        size="lg"
      >
        {detalleAbierto && (
          <div className="flex flex-col gap-3">
            {detalleAbierto.estado !== 'PENDIENTE' && <div>{estadoPrestamoBadge(detalleAbierto.estado)}</div>}

            <TablaProductosDetalle<PrestamoDetalleResponse>
              filas={detalleAbierto.detalle}
              rowKey={(l) => l.id}
              titulo={(l) => l.producto}
              subtitulo={(l) => `${l.codigo} · ${l.presentacion ?? l.unidadBase}`}
              grupos={[
                [
                  { key: 'cant', label: 'Cant.', render: (l) => `${l.cantidadPresentacion}` },
                  { key: 'costo', label: 'Costo', render: (l) => `S/ ${l.costoUnitario.toFixed(2)}` },
                  { key: 'subtotal', label: 'Subtotal', render: (l) => `S/ ${l.costoTotal.toFixed(2)}` },
                ] satisfies ColumnaDetalleProducto<PrestamoDetalleResponse>[],
                [
                  {
                    key: 'devuelto',
                    label: 'Devuelto',
                    render: (l) => `${l.cantidadDevuelta} ${l.unidadBase}`,
                  },
                  {
                    key: 'pendiente',
                    label: 'Pendiente',
                    render: (l) => `${l.cantidadPendiente} ${l.unidadBase}`,
                  },
                ] satisfies ColumnaDetalleProducto<PrestamoDetalleResponse>[],
              ]}
            />

            <ResumenDocumento total={detalleAbierto.total} />

            {detalleAbierto.observacion && (
              <p className="text-sm text-ink-soft">
                <span className="font-semibold text-ink-muted">Observación: </span>
                {detalleAbierto.observacion}
              </p>
            )}
          </div>
        )}
      </Modal>

      {/* Devolución */}
      <Modal
        open={devolucionAbierta !== null}
        title={devolucionAbierta ? `Devolución de ${devolucionAbierta.numero}` : ''}
        description="Puede ser parcial: lo que no se devuelva ahora queda pendiente."
        onClose={() => setDevolucionAbierta(null)}
        size="2xl"
        footer={
          agregandoDevolucion ? (
            <>
              <Button variant="secondary" size="sm" disabled={guardando} onClick={cancelarDevolucion}>
                Cancelar
              </Button>
              <Button size="sm" loading={guardando} onClick={() => void registrarDevolucion()}>
                Guardar devolución
              </Button>
            </>
          ) : (
            <>
              <Button variant="secondary" size="sm" onClick={() => setDevolucionAbierta(null)}>
                Cerrar
              </Button>
              {puede('inv.prestamos', 'confirmar') && (
                <Button
                  size="sm"
                  disabled={!devolucionAbierta?.detalle.some((d) => d.cantidadPendiente > 0)}
                  onClick={agregarDevolucion}
                >
                  <Plus size={15} />
                  Agregar devolución
                </Button>
              )}
            </>
          )
        }
      >
        {devolucionAbierta && (
          <div className="flex flex-col gap-5">
            {/* Mismo formato compacto que los cards de la pestaña Pago al convertir un pedido: sin icono, solo lo justo. */}
            <div className="grid grid-cols-2 gap-2 text-center sm:grid-cols-4 sm:gap-3">
              <div className="rounded-field border border-line px-2 py-2">
                <p className="text-[11px] font-semibold tracking-wide text-ink-soft uppercase">Productos</p>
                <p className="text-base font-semibold text-ink">{devolucionAbierta.detalle.length}</p>
              </div>
              <div className="rounded-field border border-line px-2 py-2">
                <p className="text-[11px] font-semibold tracking-wide text-ink-soft uppercase">Pendientes</p>
                <p
                  className={
                    devolucionAbierta.detalle.some((d) => d.cantidadPendiente > 0)
                      ? 'text-base font-semibold text-amber-700'
                      : 'text-base font-semibold text-ink'
                  }
                >
                  {devolucionAbierta.detalle.filter((d) => d.cantidadPendiente > 0).length}
                </p>
              </div>
              <div className="rounded-field border border-line px-2 py-2">
                <p className="text-[11px] font-semibold tracking-wide text-ink-soft uppercase">Devoluciones</p>
                <p className="text-base font-semibold text-ink">{devolucionAbierta.devoluciones.length}</p>
              </div>
              <div className="rounded-field border border-line px-2 py-2">
                <p className="text-[11px] font-semibold tracking-wide text-ink-soft uppercase">Anuladas</p>
                <p className="text-base font-semibold text-ink">
                  {devolucionAbierta.devoluciones.filter((d) => d.estado === 'ANULADO').length}
                </p>
              </div>
            </div>

            <SysDataTable<FilaDevolucionTabla>
              columns={columnasDevoluciones}
              rows={[
                ...(agregandoDevolucion
                  ? devolucionAbierta.detalle
                      .filter((d) => d.cantidadPendiente > 0)
                      .map((d) => ({
                        clave: `nueva-${d.id}`,
                        devolucion: null,
                        producto: d.producto,
                        cantidadGuardada: null,
                        pendiente: {
                          prestamoDetalleId: d.id,
                          cantidadPendiente: d.cantidadPendiente,
                          unidadBase: d.unidadBase,
                          cantidad: d.cantidad,
                        },
                      }))
                  : []),
                ...devolucionAbierta.devoluciones.flatMap((dv) =>
                  dv.detalle.map((l) => ({
                    clave: `${dv.id}-${l.prestamoDetalleId}`,
                    devolucion: dv,
                    producto: l.producto,
                    cantidadGuardada: `${l.cantidadPresentacion} ${l.presentacion ?? l.unidadBase}`,
                    pendiente: null,
                  })),
                ),
              ]}
              rowKey="clave"
              toolbar={false}
              paginacion={false}
              empty="Todavía no hay devoluciones registradas."
              actions={(f) =>
                f.devolucion && (
                  <>
                    <AccionPdf documento="devolucionesprestamo" id={f.devolucion.id} numero={f.devolucion.numero} />
                    {f.devolucion.estado === 'CONFIRMADO' && puede('inv.prestamos', 'anular') && (
                      <RowAction
                        label={`Anular devolución ${f.devolucion.numero}`}
                        tone="danger"
                        onClick={() => f.devolucion && anularDevolucion(f.devolucion)}
                      >
                        <Undo2 size={15} />
                      </RowAction>
                    )}
                  </>
                )
              }
            />
          </div>
        )}
      </Modal>

      {dialogo}
    </ListPage>
  )
}
