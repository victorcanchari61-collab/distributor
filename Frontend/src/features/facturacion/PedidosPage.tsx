import { useCallback, useEffect, useState } from 'react'
import { idUnico } from '../../lib/ids'
import { fechaCorta } from '../../lib/fechas'
import { ArrowLeft, CheckCircle2, ClipboardList, Contact, Eye, History, PackageX, Pencil, Plus, ShoppingBag, Trash2, Undo2 } from 'lucide-react'
import {
  AccionPdf,
  AgregarProductoPanel,
  Alert,
  Badge,
  BuscadorCampo,
  BuscadorModal,
  Button,
  Checkbox,
  Desplegable,
  HistorialCambios,
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
  OpcionBuscador,
} from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { opcionesPresentacion, presentacionInicialDe } from '../../lib/presentaciones'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { clienteApi, productoApi } from '../maestros'
import type { ClienteResponse, ProductoResponse } from '../maestros'
import { almacenApi, stockApi } from '../inventario'
import type { AlmacenOpcion } from '../inventario'
import { listaPrecioApi } from './listaPrecioApi'
import type { ListaPrecioResponse } from './listaPrecioApi'
import { pedidoApi } from './ventasApi'
import { EntregaPedidoModal, NoEntregadoModal } from './EntregaPedidoModal'
import type { AuditoriaResponse } from '../config'
import type { CrearPedidoRequest, FormaPagoVenta, LineaVentaResponse, PedidoResponse, ResumenPedidos } from './ventasApi'

function estadoPedidoBadge(estado: PedidoResponse['estado']) {
  const tono = estado === 'CONFIRMADO' ? 'success' : estado === 'ANULADO' ? 'danger' : 'warning'
  const texto = estado === 'CONFIRMADO' ? 'Confirmado' : estado === 'ANULADO' ? 'Anulado' : 'Pendiente'
  return <Badge tone={tono}>{texto}</Badge>
}

type FilaPedido = LineaProductoNueva

/**
 * Pedidos: lo que pidió un cliente, antes de que exista una venta firme.
 *
 * Confirmarlo es despacharlo: ahí recién se elige el almacén y se crea la
 * NotaVenta correspondiente, que es la que descuenta el stock — el pedido
 * nunca lo toca.
 */
export function PedidosPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const [vista, setVista] = useState<'lista' | 'form'>('lista')
  const [pedidos, setPedidos] = useState<PedidoResponse[]>([])
  const [clientes, setClientes] = useState<ClienteResponse[]>([])
  const [productos, setProductos] = useState<ProductoResponse[]>([])
  const [almacenes, setAlmacenes] = useState<AlmacenOpcion[]>([])
  const [listas, setListas] = useState<ListaPrecioResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [editando, setEditando] = useState<PedidoResponse | null>(null)
  const [detalleAbierto, setDetalleAbierto] = useState<PedidoResponse | null>(null)
  const [historialAbierto, setHistorialAbierto] = useState<PedidoResponse | null>(null)
  const [historial, setHistorial] = useState<AuditoriaResponse[]>([])
  const [historialCargando, setHistorialCargando] = useState(false)
  const [buscadorAbierto, setBuscadorAbierto] = useState(false)
  const [guardando, setGuardando] = useState(false)

  const [clienteId, setClienteId] = useState(0)
  const [listaPrecioId, setListaPrecioId] = useState(0)
  /* Lo que el vendedor acordo con el cliente: lo lee el repartidor. */
  const [condicionPago, setCondicionPago] = useState<FormaPagoVenta>('CONTADO')
  const [observacion, setObservacion] = useState('')
  const [reservaStock, setReservaStock] = useState(false)
  const [almacenReservaId, setAlmacenReservaId] = useState(0)
  const [filas, setFilas] = useState<FilaPedido[]>([])
  const [stockMap, setStockMap] = useState<Record<number, number>>({})

  // --- Convertir en venta (con lo que de verdad se entregó) y "no entregado" ---
  const [confirmando, setConfirmando] = useState<PedidoResponse | null>(null)
  const [noEntregando, setNoEntregando] = useState<PedidoResponse | null>(null)

  const { confirmar, dialogo } = useConfirmacion()

  /*
   * Los pedidos se acumulan con la operacion, asi que la tabla pide solo la
   * pagina que muestra. Los contadores de arriba vienen del resumen: contarlos
   * sobre las filas cargadas diria "20 pedidos".
   */
  const [consulta, setConsulta] = useState<ConsultaTabla | null>(null)
  const [totalRegistros, setTotalRegistros] = useState(0)
  const [resumen, setResumen] = useState<ResumenPedidos | null>(null)

  const cargarPagina = useCallback(async (q: ConsultaTabla) => {
    setCargando(true)
    try {
      const pagina = await pedidoApi.listar(q)
      setPedidos(pagina.items)
      setTotalRegistros(pagina.total)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los pedidos.')
    } finally {
      setCargando(false)
    }
  }, [])

  /** Catalogos del formulario y contadores: no cambian al paginar. */
  const cargarApoyo = useCallback(async () => {
    try {
      const [res, clis, prods, alms, lis] = await Promise.all([
        pedidoApi.resumen(),
        clienteApi.getAll(),
        productoApi.getAll(),
        almacenApi.opciones(),
        listaPrecioApi.getAll(),
      ])
      setResumen(res)
      setClientes(clis.filter((c) => c.activo))
      setProductos(prods.filter((p) => p.activo && p.controlaStock))
      setAlmacenes(alms.filter((a) => a.activo))
      setListas(lis.filter((l) => l.activo))
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

  useRealtime(['pedidos', 'notasventa', 'stock'], cargar)

  // El buscador de productos muestra el stock disponible del almacén elegido,
  // no el total: es lo que de verdad se puede prometer desde ahí.
  useEffect(() => {
    if (!almacenReservaId) return
    let cancelado = false
    void stockApi.disponible(almacenReservaId).then((stock) => {
      if (!cancelado) setStockMap(Object.fromEntries(stock.map((s) => [s.productoId, s.disponible])))
    })
    return () => {
      cancelado = true
    }
  }, [almacenReservaId, pedidos])

  // El almacén principal (marcado en Almacenes); si no hubiera, el más antiguo.
  const primerAlmacenId =
    almacenes.find((a) => a.esPrincipal)?.id ??
    (almacenes.length ? almacenes.reduce((min, a) => (a.id < min ? a.id : min), almacenes[0].id) : 0)

  const abrirNuevo = () => {
    setEditando(null)
    setClienteId(0)
    setListaPrecioId(0)
    setCondicionPago('CONTADO')
    setObservacion('')
    setReservaStock(false)
    setAlmacenReservaId(primerAlmacenId)
    setFilas([])
    setVista('form')
  }

  const abrirEdicion = (pedido: PedidoResponse) => {
    setEditando(pedido)
    setClienteId(pedido.clienteId)
    setListaPrecioId(pedido.listaPrecioId ?? 0)
    setCondicionPago(pedido.condicionPago)
    setObservacion(pedido.observacion ?? '')
    setReservaStock(pedido.reservaStock)
    setAlmacenReservaId(pedido.almacenId ?? primerAlmacenId)
    setFilas(
      pedido.detalle
        .filter((l) => !l.anulado)
        .map((l) => ({
          id: idUnico(),
          lineaId: l.id,
          productoId: l.productoId,
          presentacionId: l.presentacionId ?? 0,
          cantidad: String(l.cantidadPresentacion),
          // El precio pactado, tal cual se guardo: multiplicar el de unidad
          // base por el factor devolvia 13.5999 donde se habia puesto 13.60.
          costo: String(l.precioPresentacion),
          lote: '',
          fechaVencimiento: '',
        })),
    )
    setVista('form')
  }

  const abrirHistorial = (pedido: PedidoResponse) => {
    setHistorialAbierto(pedido)
    setHistorial([])
    setHistorialCargando(true)
    void pedidoApi
      .historial(pedido.id)
      .then(setHistorial)
      .catch(() => setHistorial([]))
      .finally(() => setHistorialCargando(false))
  }

  const actualizarFila = (id: string, cambio: Partial<FilaPedido>) =>
    setFilas((prev) => prev.map((f) => (f.id === id ? { ...f, ...cambio } : f)))

  // Lo que suma el pedido hasta ahora, con lo agregado en Productos.
  const total = filas.reduce((n, f) => n + (Number(f.cantidad) || 0) * (Number(f.costo) || 0), 0)


  /*
   * La lista con la que se cobra.
   *
   * Vacio en el formulario significa "la predeterminada", que es la que el
   * backend aplica a un cliente sin lista propia: para resolver precios hay
   * que resolver ese vacio a un id de verdad.
   */
  const listaEfectiva = listaPrecioId || listas.find((l) => l.esPredeterminada)?.id || 0

  /** Precio de una presentacion por esa cantidad, segun la lista elegida. */
  const precioDeLista = async (presentacionId: number, cantidad: number) => {
    if (!listaEfectiva) return null
    const precio = await listaPrecioApi.resolver(listaEfectiva, presentacionId, cantidad)
    return precio?.precio ?? null
  }


  /*
   * Elegir al cliente trae su lista.
   *
   * El mayorista tiene la suya guardada en su ficha: sin esto habia que
   * acordarse de cambiarla a mano en cada pedido, y basta olvidarlo una vez
   * para cobrarle precio de menudeo. Si el cliente no tiene lista propia se
   * vuelve a "la predeterminada", no se queda la del cliente anterior.
   */
  const elegirCliente = (id: number) => {
    setClienteId(id)
    setListaPrecioId(clientes.find((c) => c.id === id)?.listaPrecioId ?? 0)
  }

  const guardar = async () => {
    if (!clienteId) return toast.error('Elige el cliente.')

    const validas = filas.filter((f) => f.productoId && f.cantidad && f.costo)
    if (validas.length === 0) return toast.error('Agrega al menos un producto con su precio.')

    // Una linea sin precio se caia del pedido sin decir nada: el documento se
    // guardaba con un producto menos y nadie se enteraba.
    const sinPrecio = filas.find((f) => f.productoId && !Number(f.costo))
    if (sinPrecio) {
      const nombre = productos.find((p) => p.id === sinPrecio.productoId)?.nombre ?? 'Un producto'
      return toast.error(`${nombre} no tiene precio. Ponlo o quita la línea.`)
    }
    if (reservaStock && !almacenReservaId) return toast.error('Elige el almacén para reservar el stock.')

    const body: CrearPedidoRequest = {
      clienteId,
      listaPrecioId: listaPrecioId || null,
      condicionPago,
      observacion: observacion.trim() || null,
      reservaStock,
      almacenId: reservaStock ? almacenReservaId : null,
      detalle: validas.map((f) => ({
        id: f.lineaId ?? null,
        productoId: f.productoId,
        presentacionId: f.presentacionId || null,
        cantidad: Number(f.cantidad),
        precioUnitario: Number(f.costo),
      })),
    }

    setGuardando(true)
    try {
      if (editando) {
        await pedidoApi.update(editando.id, body)
      } else {
        await pedidoApi.create(body)
      }
      setVista('lista')
      await cargar()
      toast.exito(editando ? 'Pedido actualizado' : 'Pedido creado')
    } catch (e) {
      toast.error(
        e instanceof ApiError ? (e.errors.length ? e.errors.join(' ') : e.message) : 'No pudimos guardar el pedido.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const anularPedido = (pedido: PedidoResponse) =>
    confirmar({
      titulo: `Anular ${pedido.numero}`,
      mensaje: 'Se anula el pedido. No se puede deshacer.',
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await pedidoApi.anular(pedido.id)
          await cargar()
          toast.exito(`${pedido.numero} anulado`)
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos anular el pedido.')
        }
      },
    })

  const quitarNoEntregado = (pedido: PedidoResponse) =>
    confirmar({
      titulo: `Quitar la marca de ${pedido.numero}`,
      mensaje: 'El pedido deja de figurar como no entregado y vuelve a quedar solo pendiente.',
      confirmar: 'Quitar marca',
      tono: 'warning',
      accion: async () => {
        setError('')
        try {
          await pedidoApi.quitarNoEntregado(pedido.id)
          await cargar()
          toast.exito(`${pedido.numero} ya no figura como no entregado`)
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos quitar la marca.')
        }
      },
    })

  /** A cuántas unidades base equivale la presentación de esa línea. */
  const factorDeFila = (fila: { productoId: number; presentacionId: number }) =>
    productos
      .find((p) => p.id === fila.productoId)
      ?.presentaciones.find((x) => x.id === fila.presentacionId)?.factor ?? 1


  /** El selector de presentacion de una linea: se usa en dos sitios. */
  const presentacionDeFila = (fila: { id: string; productoId: number; presentacionId: number }) => {
    const producto = productos.find((p) => p.id === fila.productoId)
    return (
      <Desplegable
        value={fila.presentacionId}
        onChange={(v) => actualizarFila(fila.id, { presentacionId: Number(v) })}
        placeholder={producto?.unidadBase ?? 'Elegir'}
        disabled={!producto}
        options={producto ? opcionesPresentacion(producto, 'venta', fila.presentacionId) : []}
      />
    )
  }

  const columnasFilas: DataTableColumn<FilaPedido>[] = [
    {
      key: 'producto',
      label: 'Producto',
      // La cabecera de la tarjeta es un desplegable, no el nombre de la fila:
      // sin su etiqueta es el unico dato sin rotular de la tarjeta.
      etiquetaEnTarjeta: true,
      value: (fila) => productos.find((p) => p.id === fila.productoId)?.nombre ?? '',
      render: (fila) => (
        <Desplegable
          value={fila.productoId}
          onChange={(v) => actualizarFila(fila.id, { productoId: Number(v), presentacionId: presentacionInicialDe(productos, Number(v), 'venta') })}
          options={productos.map((p) => ({ value: p.id, label: p.nombre, detalle: p.codigo }))}
        />
      ),
    },
    {
      key: 'presentacion',
      label: 'Presentación',
      width: 190,
      render: presentacionDeFila,
    },
    {
      key: 'cantidad',
      label: 'Cantidad',
      align: 'right',
      width: 100,
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
    {
      key: 'costo',
      label: 'Precio de venta',
      align: 'right',
      width: 130,
      value: (fila) => Number(fila.costo) || 0,
      render: (fila) => (
        <Input
          type="number"
          step="0.01"
          value={fila.costo}
          onChange={(e) => actualizarFila(fila.id, { costo: e.target.value })}
        />
      ),
    },
    {
      /*
       * Lo que sale la unidad base.
       *
       * El precio de la fila es el de la presentacion —S/ 226.67 el saco—, y
       * asi no se puede comparar una linea en sacos contra otra en kilos ni
       * ver si el descuento por volumen quedo al derecho.
       */
      key: 'precioUnitario',
      label: 'P. unit.',
      align: 'right',
      width: 140,
      value: (fila) => {
        const factor = factorDeFila(fila)
        return factor > 0 ? (Number(fila.costo) || 0) / factor : 0
      },
      render: (fila) => {
        const producto = productos.find((p) => p.id === fila.productoId)
        const factor = factorDeFila(fila)
        const precio = Number(fila.costo) || 0
        return precio > 0 && factor > 0 ? (
          <span className="font-medium text-ink">
            S/ {(precio / factor).toFixed(2)} × {producto?.unidadBase}
          </span>
        ) : (
          <span className="text-ink-soft">—</span>
        )
      },
    },
    {
      key: 'subtotal',
      label: 'Subtotal',
      align: 'right',
      width: 120,
      value: (fila) => (Number(fila.cantidad) || 0) * (Number(fila.costo) || 0),
      render: (fila) => `S/ ${((Number(fila.cantidad) || 0) * (Number(fila.costo) || 0)).toFixed(2)}`,
    },
  ]

  const opcionesCliente: OpcionBuscador<number>[] = clientes.map((c) => ({
    item: c.id,
    label: c.nombre,
    detalle: c.documento,
    nota: c.distrito ?? undefined,
  }))

  const columnasCliente: DataTableColumn<ClienteResponse>[] = [
    {
      key: 'documento',
      label: 'Documento',
      render: (row) => (
        <span className="flex items-center gap-2">
          <span className="font-medium text-ink">{row.documento}</span>
          <Badge>{row.tipoDoc}</Badge>
        </span>
      ),
    },
    { key: 'nombre', label: 'Nombre' },
    { key: 'distrito', label: 'Distrito' },
    { key: 'ruta', label: 'Ruta' },
  ]

  const columns: DataTableColumn<PedidoResponse>[] = [
    // El número se busca con el buscador de arriba, no en el panel.
    { key: 'numero', label: 'Número', filterable: false, render: (row) => <Badge>{row.numero}</Badge> },
    {
      key: 'cliente',
      label: 'Cliente',
      filterType: 'select',
      filterOptions: [...new Set(clientes.map((c) => c.nombre))]
        .sort((a, b) => a.localeCompare(b, 'es'))
        .map((n) => ({ value: n, label: n })),
    },
    {
      key: 'fecha',
      label: 'Fecha',
      filterType: 'date',
      render: (row) => fechaCorta(row.fecha),
    },
    {
      key: 'total',
      label: 'Total',
      align: 'right',
      // Sin control numerico en el panel, buscar "9" contra "S/ 9.00" no
      // encuentra lo que la persona espera.
      filterable: false,
      render: (row) => `S/ ${row.total.toFixed(2)}`,
    },
    {
      // El otro lado del vinculo: la nota de venta ya muestra de que pedido
      // salio, y aqui se ve en que venta termino.
      key: 'notaVentaNumero',
      label: 'Venta',
      filterType: 'select',
      filterOptions: [
        { value: 'Convertido', label: 'Convertido' },
        { value: 'Sin convertir', label: 'Sin convertir' },
      ],
      render: (row) =>
        row.notaVentaNumero ? (
          <Badge tone="success">{row.notaVentaNumero}</Badge>
        ) : (
          <span className="text-ink-soft">—</span>
        ),
    },
    {
      /*
       * Lo que el repartidor necesita ver de un vistazo antes de salir: a
       * cuales hay que cobrarles al entregar.
       */
      key: 'condicionPago',
      label: 'Condición',
      width: 120,
      filterType: 'select',
      filterOptions: [
        { value: 'CONTADO', label: 'Contado' },
        { value: 'CREDITO', label: 'Crédito' },
      ],
      render: (row) =>
        row.condicionPago === 'CREDITO' ? (
          <Badge tone="warning">Crédito</Badge>
        ) : (
          <Badge tone="success">Contado</Badge>
        ),
    },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'PENDIENTE', label: 'Pendiente' },
        { value: 'CONFIRMADO', label: 'Confirmado' },
        { value: 'ANULADO', label: 'Anulado' },
      ],
      render: (row) => (
        <span className="inline-flex flex-wrap items-center gap-1">
          {estadoPedidoBadge(row.estado)}
          {row.noEntregadoMotivo && (
            <span title={row.noEntregadoObservacion ?? undefined}>
              <Badge tone="danger">No entregado: {row.noEntregadoMotivo}</Badge>
            </span>
          )}
        </span>
      ),
    },
  ]

  if (vista === 'form') {
    return (
      <div className="space-y-5">
        <PageHeader
          icon={<ClipboardList size={20} />}
          title={editando ? `Editar ${editando.numero}` : 'Nuevo pedido'}
          description="Lo que pide el cliente. Mientras esté Pendiente se puede editar; al confirmarlo, ya no."
          actions={
            <Button variant="secondary" size="sm" onClick={() => setVista('lista')}>
              <ArrowLeft size={15} />
              Volver
            </Button>
          }
        />


        {/* Mismo layout que Mis compras / Nueva venta: Productos a la
            izquierda porque es lo que más espacio pide (buscador y tabla);
            los datos del pedido y el total van en una columna angosta a la
            derecha, como un resumen de pedido. */}
        <div className="grid grid-cols-1 gap-5 lg:grid-cols-[1fr_360px] lg:items-start">
          <PageSection
            title="Productos"
            description={`${filas.length} producto${filas.length === 1 ? '' : 's'} agregado${filas.length === 1 ? '' : 's'}`}
          >
            <AgregarProductoPanel
              productos={productos}
              stock={stockMap}
              uso="venta"
              costoLabel="Precio de venta"
              resolverPrecio={precioDeLista}
              onAgregar={(linea: LineaProductoNueva) => setFilas((f) => [...f, linea])}
            />

            <div className="mt-4">
              <SysDataTable
                columns={columnasFilas}
                rows={filas}
                rowKey="id"
                toolbar={false}
                empty="Agrega productos con el buscador de arriba."
                // Una papelera no necesita 140px, que es lo que ocupa la
                // columna de acciones de un listado con tres botones.
                actionsWidth={64}
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

          <div className="flex flex-col gap-5">
            <PageSection title="Pedido">
              <BuscadorCampo
                label="Cliente"
                value={clienteId || null}
                onChange={(id) => elegirCliente(id ?? 0)}
                opciones={opcionesCliente}
                placeholder="Buscar cliente..."
                vacio="Ningún cliente coincide"
                onAvanzado={() => setBuscadorAbierto(true)}
                avanzadoLabel="Búsqueda avanzada de clientes"
              />

              <Desplegable
                className="mt-4"
                label="Lista de precios"
                optional
                value={listaPrecioId}
                onChange={(v) => setListaPrecioId(Number(v))}
                placeholder="Predeterminada"
                options={listas.map((l) => ({ value: l.id, label: l.nombre }))}
              />

              {/*
                Lo que se acordo, no lo que se cobro.
                El repartidor llega con el pedido y tiene que saber si deja la
                mercaderia solo contra el dinero o si va fiada; el cobro se
                registra despues, al entregar.
              */}
              <Desplegable
                className="mt-4"
                label="Condición de pago"
                value={condicionPago}
                onChange={(v) => setCondicionPago(v as FormaPagoVenta)}
                options={[
                  { value: 'CONTADO', label: 'Contado', nota: 'se cobra al entregar' },
                  { value: 'CREDITO', label: 'Crédito', nota: 'se deja fiado' },
                ]}
              />

              <Input
                className="mt-4"
                label="Observación"
                optional
                placeholder="Referencia..."
                value={observacion}
                onChange={(e) => setObservacion(e.target.value)}
              />

              <Desplegable
                className="mt-4"
                label="Almacén"
                value={almacenReservaId}
                onChange={(v) => setAlmacenReservaId(Number(v))}
                options={almacenes.map((a) => ({
                  value: a.id,
                  label: a.nombre,
                  detalle: a.codigo,
                  nota: a.esPrincipal ? 'principal' : undefined,
                }))}
              />
              <p className="mt-1 text-xs text-ink-soft">
                El buscador de productos muestra el stock disponible de este almacén.
              </p>

              <Checkbox
                className="mt-4"
                label="Reservar stock"
                checked={reservaStock}
                onChange={(e) => setReservaStock(e.target.checked)}
              />
              <p className="mt-1 text-xs text-ink-soft">
                Aparta el stock de ese almacén mientras el pedido esté pendiente, para que no se
                pueda prometer dos veces. Se libera solo al confirmar o anular el pedido.
              </p>
            </PageSection>

            <PageSection title="Resumen">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold text-ink-soft uppercase tracking-wide">
                  Total del pedido
                </span>
                <span className="text-xl font-bold text-[rgb(var(--sys-rgb))]">
                  S/ {total.toFixed(2)}
                </span>
              </div>
            </PageSection>
          </div>
        </div>

        <div className="flex justify-end gap-2">
          <Button variant="secondary" size="sm" onClick={() => setVista('lista')}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            {editando ? 'Guardar cambios' : 'Registrar pedido'}
          </Button>
        </div>

        <BuscadorModal
          open={buscadorAbierto}
          onClose={() => setBuscadorAbierto(false)}
          title="Elegir cliente"
          description="Busca por documento, nombre o distrito."
          columns={columnasCliente}
          rows={clientes}
          cardIcon={Contact}
          searchPlaceholder="Buscar cliente..."
          onSeleccionar={(c) => elegirCliente(c.id)}
        />

        {dialogo}
      </div>
    )
  }

  return (
    <ListPage
      icon={<ClipboardList size={20} />}
      title="Pedidos"
      description="Lo que pide un cliente. Al convertirlo nace su nota de venta."
      actions={
        puede('fact.pedidos', 'crear') ? (
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nuevo pedido
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Pedidos" value={String(resumen?.total ?? 0)} icon={<ClipboardList size={18} />} />
          <StatCard
            label="Pendientes"
            value={String(resumen?.pendientes ?? 0)}
            icon={<ClipboardList size={18} />}
            tono="warning"
          />
          <StatCard
            label="Confirmados"
            value={String(resumen?.confirmados ?? 0)}
            icon={<CheckCircle2 size={18} />}
            tono="success"
          />
        </>
      }
      columns={columns}
      // 6 íconos por fila (Ver, Historial, Editar, Confirmar, No entregado, Anular): el
      // ancho por defecto de Acciones se queda corto y fuerza scroll horizontal.
      actionsWidth={235}
      rows={pedidos}
      servidor={{
        total: totalRegistros,
        cargando,
        onConsulta: (q) => {
          setConsulta(q)
          void cargarPagina(q)
        },
      }}
      cardIcon={ClipboardList}
      searchPlaceholder="Buscar por número, cliente..."
      empty={cargando ? 'Cargando pedidos...' : 'Todavía no hay pedidos registrados.'}
      rowActions={(row) => (
        <>
          <RowAction label={`Ver ${row.numero}`} tone="view" onClick={() => setDetalleAbierto(row)}>
            <Eye size={15} />
          </RowAction>
          <RowAction tone="view" label={`Ver historial de ${row.numero}`} onClick={() => abrirHistorial(row)}>
            <History size={15} />
          </RowAction>
          {puede('fact.pedidos', 'exportar') && (
            <AccionPdf documento="pedido" id={row.id} numero={row.numero} />
          )}
          {puede('fact.pedidos', 'editar') && (
            <RowAction
              label={`Editar ${row.numero}`}
              disabled={row.estado !== 'PENDIENTE'}
              disabledReason="Solo se edita un pedido pendiente"
              onClick={() => abrirEdicion(row)}
            >
              <Pencil size={15} />
            </RowAction>
          )}
          {puede('fact.pedidos', 'confirmar') && (
            <RowAction
              label={`Convertir ${row.numero} en venta`}
              tone="success"
              disabled={row.estado !== 'PENDIENTE'}
              // El motivo nombra la venta: "ya fue convertido" deja buscandola.
              disabledReason={
                row.notaVentaNumero
                  ? `Ya es la venta ${row.notaVentaNumero}. Anúlala para rehacerla.`
                  : 'Está anulado'
              }
              onClick={() => setConfirmando(row)}
            >
              <ShoppingBag size={15} />
            </RowAction>
          )}
          {puede('fact.pedidos', 'confirmar') && (
            <RowAction
              label={
                row.noEntregadoMotivo
                  ? `Quitar la marca de no entregado de ${row.numero}`
                  : `Marcar ${row.numero} como no entregado`
              }
              tone="warning"
              disabled={row.estado !== 'PENDIENTE'}
              disabledReason="Solo un pedido pendiente puede marcarse como no entregado"
              onClick={() => (row.noEntregadoMotivo ? quitarNoEntregado(row) : setNoEntregando(row))}
            >
              <PackageX size={15} />
            </RowAction>
          )}
          {puede('fact.pedidos', 'anular') && (
            <RowAction
              label={`Anular ${row.numero}`}
              tone="danger"
              disabled={row.estado !== 'PENDIENTE'}
              disabledReason={row.estado === 'CONFIRMADO' ? 'Ya generó su venta: anula esa' : 'Ya está anulado'}
              onClick={() => anularPedido(row)}
            >
              <Undo2 size={15} />
            </RowAction>
          )}
        </>
      )}
    >
      <Modal
        open={detalleAbierto !== null}
        title={detalleAbierto ? `${detalleAbierto.numero} · ${detalleAbierto.cliente}` : ''}
        description={
          detalleAbierto ? `Emisión ${fechaCorta(detalleAbierto.fecha)}` : undefined
        }
        onClose={() => setDetalleAbierto(null)}
        size="lg"
      >
        {detalleAbierto && (
          <div className="flex flex-col gap-3">
            <div className="flex flex-wrap items-center gap-2">
              {detalleAbierto.estado !== 'PENDIENTE' && estadoPedidoBadge(detalleAbierto.estado)}
              {detalleAbierto.condicionPago === 'CREDITO' ? (
                <Badge tone="warning">Crédito · se deja fiado</Badge>
              ) : (
                <Badge tone="success">Contado · se cobra al entregar</Badge>
              )}
            </div>

            {detalleAbierto.detalle.some((l) => l.anulado) && (
              <p className="text-xs text-ink-soft">
                Se quitaron productos al editar este pedido — quedan solo en "Ver historial".
              </p>
            )}

            {detalleAbierto.noEntregadoMotivo && (
              <Alert tone="warning">
                No se entregó: {detalleAbierto.noEntregadoMotivo}
                {detalleAbierto.noEntregadoObservacion && ` — ${detalleAbierto.noEntregadoObservacion}`}
              </Alert>
            )}

            {detalleAbierto.reservaStock && (
              <p className="rounded-field bg-brand-soft px-3 py-2 text-xs font-medium text-brand">
                Stock reservado en {detalleAbierto.almacen}
              </p>
            )}

            <TablaProductosDetalle<LineaVentaResponse>
              filas={detalleAbierto.detalle.filter((l) => !l.anulado)}
              rowKey={(l) => l.id}
              titulo={(l) => l.producto}
              subtitulo={(l) => `${l.codigo} · ${l.presentacion ?? l.unidadBase}`}
              grupos={[
                [
                  { key: 'cant', label: 'Cant.', render: (l) => `${l.cantidadPresentacion}` },
                  // El pactado por presentacion, que es el que se cobro y el
                  // que sale en el papel; el de unidad base es derivado.
                  {
                    key: 'precio',
                    label: 'Precio',
                    render: (l) => `S/ ${l.precioPresentacion.toFixed(2)}`,
                  },
                  { key: 'subtotal', label: 'Subtotal', render: (l) => `S/ ${l.subtotal.toFixed(2)}` },
                ] satisfies ColumnaDetalleProducto<LineaVentaResponse>[],
              ]}
            />

            <ResumenDocumento total={detalleAbierto.total} />

            {detalleAbierto.notaVentaNumero && (
              <p className="text-sm text-ink-soft">
                <span className="font-semibold text-ink-muted">Nota de venta: </span>
                {detalleAbierto.notaVentaNumero}
              </p>
            )}

            {detalleAbierto.observacion && (
              <p className="text-sm text-ink-soft">
                <span className="font-semibold text-ink-muted">Observación: </span>
                {detalleAbierto.observacion}
              </p>
            )}
          </div>
        )}
      </Modal>

      <Modal
        open={historialAbierto !== null}
        title={historialAbierto ? `Historial de ${historialAbierto.numero}` : ''}
        description={historialAbierto ? historialAbierto.cliente : undefined}
        onClose={() => setHistorialAbierto(null)}
        size="xl"
      >
        <HistorialCambios registros={historial} cargando={historialCargando} />
      </Modal>

      <EntregaPedidoModal
        pedido={confirmando}
        almacenes={almacenes}
        onClose={() => setConfirmando(null)}
        onHecho={(mensaje) => {
          setConfirmando(null)
          void cargar()
          toast.exito(mensaje)
        }}
      />

      <NoEntregadoModal
        pedido={noEntregando}
        onClose={() => setNoEntregando(null)}
        onHecho={() => {
          setNoEntregando(null)
          void cargar()
          toast.exito('Pedido marcado como no entregado.')
        }}
      />

      {dialogo}
    </ListPage>
  )
}
