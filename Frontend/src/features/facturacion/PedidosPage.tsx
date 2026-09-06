import { useCallback, useEffect, useState } from 'react'
import { ArrowLeft, CheckCircle2, ClipboardList, Contact, Eye, History, Pencil, Plus, ShoppingBag, Trash2, Undo2 } from 'lucide-react'
import {
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
} from '../../components/ui'
import type {
  ColumnaDetalleProducto,
  DataTableColumn,
  LineaProductoNueva,
  OpcionBuscador,
} from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { useRealtime } from '../../lib/realtime'
import { clienteApi, productoApi } from '../maestros'
import type { ClienteResponse, ProductoResponse } from '../maestros'
import { almacenApi, stockApi } from '../inventario'
import type { AlmacenResponse } from '../inventario'
import { listaPrecioApi } from './listaPrecioApi'
import type { ListaPrecioResponse } from './listaPrecioApi'
import { pedidoApi } from './ventasApi'
import type { AuditoriaResponse } from '../config'
import type { CrearPedidoRequest, LineaVentaResponse, PedidoResponse } from './ventasApi'

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
  const [vista, setVista] = useState<'lista' | 'form'>('lista')
  const [pedidos, setPedidos] = useState<PedidoResponse[]>([])
  const [clientes, setClientes] = useState<ClienteResponse[]>([])
  const [productos, setProductos] = useState<ProductoResponse[]>([])
  const [almacenes, setAlmacenes] = useState<AlmacenResponse[]>([])
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
  const [errorForm, setErrorForm] = useState('')

  const [clienteId, setClienteId] = useState(0)
  const [listaPrecioId, setListaPrecioId] = useState(0)
  const [observacion, setObservacion] = useState('')
  const [reservaStock, setReservaStock] = useState(false)
  const [almacenReservaId, setAlmacenReservaId] = useState(0)
  const [filas, setFilas] = useState<FilaPedido[]>([])
  const [stockMap, setStockMap] = useState<Record<number, number>>({})

  // --- Confirmar (despachar): un pedido no lleva pagos, solo pide almacén ---
  const [confirmando, setConfirmando] = useState<PedidoResponse | null>(null)
  const [confAlmacenId, setConfAlmacenId] = useState(0)
  const [confGuardando, setConfGuardando] = useState(false)
  const [confError, setConfError] = useState('')

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [peds, clis, prods, alms, lis] = await Promise.all([
        pedidoApi.getAll(),
        clienteApi.getAll(),
        productoApi.getAll(),
        almacenApi.getAll(),
        listaPrecioApi.getAll(),
      ])
      setPedidos(peds)
      setClientes(clis.filter((c) => c.activo))
      setProductos(prods.filter((p) => p.activo && p.controlaStock))
      setAlmacenes(alms.filter((a) => a.activo))
      setListas(lis.filter((l) => l.activo))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los pedidos.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['pedidos', 'notasventa', 'stock'], cargar)

  // El buscador de productos muestra el stock disponible del almacén elegido,
  // no el total: es lo que de verdad se puede prometer desde ahí.
  useEffect(() => {
    if (!almacenReservaId) return
    let cancelado = false
    void stockApi.getAll(almacenReservaId).then((stock) => {
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
    setObservacion('')
    setReservaStock(false)
    setAlmacenReservaId(primerAlmacenId)
    setFilas([])
    setErrorForm('')
    setVista('form')
  }

  const abrirEdicion = (pedido: PedidoResponse) => {
    setEditando(pedido)
    setClienteId(pedido.clienteId)
    setListaPrecioId(pedido.listaPrecioId ?? 0)
    setObservacion(pedido.observacion ?? '')
    setReservaStock(pedido.reservaStock)
    setAlmacenReservaId(pedido.almacenId ?? primerAlmacenId)
    setFilas(
      pedido.detalle
        .filter((l) => !l.anulado)
        .map((l) => ({
          id: crypto.randomUUID(),
          lineaId: l.id,
          productoId: l.productoId,
          presentacionId: l.presentacionId ?? 0,
          cantidad: String(l.cantidadPresentacion),
          costo: String(l.precioUnitario * (l.cantidadPresentacion ? l.cantidad / l.cantidadPresentacion : 1)),
          lote: '',
          fechaVencimiento: '',
        })),
    )
    setErrorForm('')
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

  const guardar = async () => {
    if (!clienteId) return setErrorForm('Elige el cliente.')

    const validas = filas.filter((f) => f.productoId && f.cantidad && f.costo)
    if (validas.length === 0) return setErrorForm('Agrega al menos un producto con su precio.')
    if (reservaStock && !almacenReservaId) return setErrorForm('Elige el almacén para reservar el stock.')

    const body: CrearPedidoRequest = {
      clienteId,
      listaPrecioId: listaPrecioId || null,
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
    setErrorForm('')
    try {
      if (editando) {
        await pedidoApi.update(editando.id, body)
      } else {
        await pedidoApi.create(body)
      }
      setVista('lista')
      await cargar()
    } catch (e) {
      setErrorForm(
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
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos anular el pedido.')
        }
      },
    })

  const abrirConfirmar = (pedido: PedidoResponse) => {
    setConfirmando(pedido)
    setConfAlmacenId(0)
    setConfError('')
  }

  const confirmarDespacho = async () => {
    if (!confirmando) return
    if (!confAlmacenId) return setConfError('Elige el almacén.')

    setConfGuardando(true)
    setConfError('')
    try {
      await pedidoApi.confirmar(confirmando.id, { almacenId: confAlmacenId })
      setConfirmando(null)
      await cargar()
    } catch (e) {
      setConfError(
        e instanceof ApiError ? (e.errors.length ? e.errors.join(' ') : e.message) : 'No pudimos confirmar el pedido.',
      )
    } finally {
      setConfGuardando(false)
    }
  }

  const columnasFilas: DataTableColumn<FilaPedido>[] = [
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
        const disponibles = producto?.presentaciones.filter((p) => p.esVenta && p.activo) ?? []
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
                    ...disponibles
                      .filter((p) => !p.esBase)
                      .map((p) => ({ value: p.id, label: p.nombre, detalle: `${p.factor} ${producto.unidadBase}` })),
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
    {
      key: 'costo',
      label: 'Precio de venta',
      align: 'right',
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
      key: 'subtotal',
      label: 'Subtotal',
      align: 'right',
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
    { key: 'numero', label: 'Número', render: (row) => <Badge>{row.numero}</Badge> },
    { key: 'cliente', label: 'Cliente' },
    { key: 'fecha', label: 'Fecha', render: (row) => new Date(row.fecha).toLocaleDateString('es-PE') },
    { key: 'total', label: 'Total', align: 'right', render: (row) => `S/ ${row.total.toFixed(2)}` },
    {
      key: 'estado',
      label: 'Estado',
      render: (row) => estadoPedidoBadge(row.estado),
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

        {errorForm && <Alert>{errorForm}</Alert>}

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
              costoLabel="Precio de venta"
              onAgregar={(linea: LineaProductoNueva) => setFilas((f) => [...f, linea])}
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

          <div className="flex flex-col gap-5">
            <PageSection title="Pedido">
              <BuscadorCampo
                label="Cliente"
                value={clienteId || null}
                onChange={(id) => setClienteId(id ?? 0)}
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
          onSeleccionar={(c) => setClienteId(c.id)}
        />

        {dialogo}
      </div>
    )
  }

  return (
    <ListPage
      icon={<ClipboardList size={20} />}
      title="Pedidos"
      description="Lo que pide un cliente. Al confirmarlo nace la nota de venta correspondiente."
      actions={
        <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
          Nuevo pedido
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Pedidos" value={String(pedidos.length)} icon={<ClipboardList size={18} />} />
          <StatCard
            label="Pendientes"
            value={String(pedidos.filter((p) => p.estado === 'PENDIENTE').length)}
            icon={<ClipboardList size={18} />}
            tono="warning"
          />
          <StatCard
            label="Confirmados"
            value={String(pedidos.filter((p) => p.estado === 'CONFIRMADO').length)}
            icon={<CheckCircle2 size={18} />}
            tono="success"
          />
        </>
      }
      columns={columns}
      // 5 íconos por fila (Ver, Historial, Editar, Confirmar, Anular): el
      // ancho por defecto de Acciones se queda corto y fuerza scroll horizontal.
      actionsWidth={175}
      rows={pedidos}
      cardIcon={ClipboardList}
      searchPlaceholder="Buscar por número, cliente..."
      empty={cargando ? 'Cargando pedidos...' : 'Todavía no hay pedidos registrados.'}
      rowActions={(row) => (
        <>
          <RowAction label={`Ver ${row.numero}`} tone="view" onClick={() => setDetalleAbierto(row)}>
            <Eye size={15} />
          </RowAction>
          <RowAction label={`Ver historial de ${row.numero}`} onClick={() => abrirHistorial(row)}>
            <History size={15} />
          </RowAction>
          <RowAction
            label={`Editar ${row.numero}`}
            disabled={row.estado !== 'PENDIENTE'}
            disabledReason="Solo se edita un pedido pendiente"
            onClick={() => abrirEdicion(row)}
          >
            <Pencil size={15} />
          </RowAction>
          <RowAction
            label={`Confirmar y despachar ${row.numero}`}
            tone="success"
            disabled={row.estado !== 'PENDIENTE'}
            disabledReason={row.estado === 'CONFIRMADO' ? 'Ya fue confirmado' : 'Está anulado'}
            onClick={() => abrirConfirmar(row)}
          >
            <ShoppingBag size={15} />
          </RowAction>
          <RowAction
            label={`Anular ${row.numero}`}
            tone="danger"
            disabled={row.estado !== 'PENDIENTE'}
            disabledReason={row.estado === 'CONFIRMADO' ? 'Ya generó su venta: anula esa' : 'Ya está anulado'}
            onClick={() => anularPedido(row)}
          >
            <Undo2 size={15} />
          </RowAction>
        </>
      )}
    >
      <Modal
        open={detalleAbierto !== null}
        title={detalleAbierto ? `${detalleAbierto.numero} · ${detalleAbierto.cliente}` : ''}
        description={
          detalleAbierto ? `Emisión ${new Date(detalleAbierto.fecha).toLocaleDateString('es-PE')}` : undefined
        }
        onClose={() => setDetalleAbierto(null)}
        size="lg"
      >
        {detalleAbierto && (
          <div className="flex flex-col gap-3">
            {detalleAbierto.estado !== 'PENDIENTE' && <div>{estadoPedidoBadge(detalleAbierto.estado)}</div>}

            {detalleAbierto.detalle.some((l) => l.anulado) && (
              <p className="text-xs text-ink-soft">
                Se quitaron productos al editar este pedido — quedan solo en "Ver historial".
              </p>
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
                  { key: 'precio', label: 'Precio', render: (l) => `S/ ${l.precioUnitario.toFixed(2)}` },
                  { key: 'subtotal', label: 'Subtotal', render: (l) => `S/ ${l.subtotal.toFixed(2)}` },
                ] satisfies ColumnaDetalleProducto<LineaVentaResponse>[],
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

      <Modal
        open={historialAbierto !== null}
        title={historialAbierto ? `Historial de ${historialAbierto.numero}` : ''}
        description={historialAbierto ? historialAbierto.cliente : undefined}
        onClose={() => setHistorialAbierto(null)}
        size="xl"
      >
        <HistorialCambios registros={historial} cargando={historialCargando} />
      </Modal>

      <Modal
        open={confirmando !== null}
        onClose={() => setConfirmando(null)}
        size="sm"
        title={confirmando ? `Confirmar ${confirmando.numero}` : ''}
        description="Elige de dónde sale la mercadería. El stock se descuenta al confirmar."
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setConfirmando(null)}>
              Cancelar
            </Button>
            <Button size="sm" loading={confGuardando} onClick={() => void confirmarDespacho()}>
              Confirmar y despachar
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {confError && <Alert>{confError}</Alert>}

          <Desplegable
            label="Almacén"
            value={confAlmacenId}
            onChange={(v) => setConfAlmacenId(Number(v))}
            placeholder="Elige el almacén"
            options={almacenes.map((a) => ({ value: a.id, label: a.nombre }))}
          />

          <p className="text-xs text-ink-soft">
            La nota de venta que nace queda a crédito, pendiente de cobro — un pedido no registra pagos.
          </p>

          <div className="flex items-center justify-between border-t border-line pt-3 text-sm font-semibold">
            <span>Total</span>
            <span className="text-ink">S/ {(confirmando?.total ?? 0).toFixed(2)}</span>
          </div>
        </div>
      </Modal>

      {dialogo}
    </ListPage>
  )
}
