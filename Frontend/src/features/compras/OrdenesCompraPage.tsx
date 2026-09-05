import { useCallback, useEffect, useState } from 'react'
import {
  ArrowLeft,
  Building2,
  CheckCircle2,
  ClipboardList,
  Eye,
  Pencil,
  Plus,
  ShoppingBag,
  Trash2,
  Undo2,
} from 'lucide-react'
import {
  AgregarProductoPanel,
  Alert,
  Badge,
  BuscadorCampo,
  BuscadorModal,
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
} from '../../components/ui'
import type {
  ColumnaDetalleProducto,
  DataTableColumn,
  LineaProductoNueva,
  OpcionBuscador,
} from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { useRealtime } from '../../lib/realtime'
import { productoApi, proveedorApi } from '../maestros'
import type { ProductoResponse, ProveedorResponse } from '../maestros'
import { stockApi } from '../inventario'
import { ordenCompraApi } from './comprasApi'
import type { CrearOrdenCompraRequest, LineaCompraResponse, OrdenCompraResponse } from './comprasApi'

function estadoOrdenBadge(estado: OrdenCompraResponse['estado']) {
  const tono = estado === 'CONFIRMADA' ? 'success' : estado === 'ANULADA' ? 'neutral' : 'warning'
  const texto = estado === 'CONFIRMADA' ? 'Confirmada' : estado === 'ANULADA' ? 'Anulada' : 'Pendiente'
  return <Badge tone={tono}>{texto}</Badge>
}

type FilaOrden = LineaProductoNueva

/**
 * Órdenes de compra: lo que se le pide a un proveedor, antes de que exista
 * compromiso firme.
 *
 * Crear y editar son una vista completa, no un modal: la cabecera más las
 * líneas de productos no entran cómodas en un cajón chico. Confirmar cierra
 * la orden y hace nacer la Compra correspondiente, visible en "Mis compras".
 */
export function OrdenesCompraPage() {
  const [vista, setVista] = useState<'lista' | 'form'>('lista')
  const [ordenes, setOrdenes] = useState<OrdenCompraResponse[]>([])
  const [proveedores, setProveedores] = useState<ProveedorResponse[]>([])
  const [productos, setProductos] = useState<ProductoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [editando, setEditando] = useState<OrdenCompraResponse | null>(null)
  const [detalleAbierto, setDetalleAbierto] = useState<OrdenCompraResponse | null>(null)
  const [buscadorAbierto, setBuscadorAbierto] = useState(false)
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const [proveedorId, setProveedorId] = useState(0)
  const [fechaEsperada, setFechaEsperada] = useState('')
  const [observacion, setObservacion] = useState('')
  const [filas, setFilas] = useState<FilaOrden[]>([])
  const [stockMap, setStockMap] = useState<Record<number, number>>({})

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [ords, provs, prods, stock] = await Promise.all([
        ordenCompraApi.getAll(),
        proveedorApi.getAll(),
        productoApi.getAll(),
        // Sin almacenId: no hay uno elegido en una orden todavía, así que se
        // muestra el stock total de la empresa.
        stockApi.getAll(),
      ])
      setOrdenes(ords)
      setProveedores(provs.filter((p) => p.activo))
      setProductos(prods.filter((p) => p.activo && p.controlaStock))
      setStockMap(Object.fromEntries(stock.map((s) => [s.productoId, s.disponible])))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las órdenes de compra.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['ordenescompra', 'stock'], cargar)

  const abrirNueva = () => {
    setEditando(null)
    setProveedorId(0)
    setFechaEsperada('')
    setObservacion('')
    setFilas([])
    setErrorForm('')
    setVista('form')
  }

  const abrirEdicion = (orden: OrdenCompraResponse) => {
    setEditando(orden)
    setProveedorId(orden.proveedorId)
    setFechaEsperada(orden.fechaEsperada ? orden.fechaEsperada.slice(0, 10) : '')
    setObservacion(orden.observacion ?? '')
    setFilas(
      orden.detalle.map((l) => {
        const producto = productos.find((p) => p.id === l.productoId)
        const presentacion = producto?.presentaciones.find((p) => p.id === l.presentacionId)
        const factor = presentacion?.factor ?? 1

        return {
          id: crypto.randomUUID(),
          productoId: l.productoId,
          presentacionId: l.presentacionId ?? 0,
          cantidad: String(l.cantidadPresentacion),
          costo: String(l.costoUnitario * factor),
          lote: '',
          fechaVencimiento: '',
        }
      }),
    )
    setErrorForm('')
    setVista('form')
  }

  const actualizarFila = (id: string, cambio: Partial<FilaOrden>) =>
    setFilas((prev) => prev.map((f) => (f.id === id ? { ...f, ...cambio } : f)))

  // Lo que suma la orden hasta ahora, con lo agregado en Productos.
  const total = filas.reduce((n, f) => n + (Number(f.cantidad) || 0) * (Number(f.costo) || 0), 0)

  const guardar = async () => {
    if (!proveedorId) return setErrorForm('Elige el proveedor.')

    const validas = filas.filter((f) => f.productoId && f.cantidad && f.costo)
    if (validas.length === 0) return setErrorForm('Agrega al menos un producto con su costo.')

    const body: CrearOrdenCompraRequest = {
      proveedorId,
      fechaEsperada: fechaEsperada || null,
      observacion: observacion.trim() || null,
      detalle: validas.map((f) => ({
        productoId: f.productoId,
        presentacionId: f.presentacionId || null,
        cantidad: Number(f.cantidad),
        costoPresentacion: Number(f.costo),
      })),
    }

    setGuardando(true)
    setErrorForm('')
    try {
      if (editando) {
        await ordenCompraApi.update(editando.id, body)
      } else {
        await ordenCompraApi.create(body)
      }
      setVista('lista')
      await cargar()
    } catch (e) {
      setErrorForm(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos guardar la orden de compra.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const confirmarOrden = (orden: OrdenCompraResponse) =>
    confirmar({
      titulo: `Confirmar ${orden.numero}`,
      mensaje:
        'El proveedor aceptó despachar: la orden se cierra y aparece en "Mis compras" lista para recibir. No se puede deshacer.',
      confirmar: 'Confirmar',
      accion: async () => {
        setError('')
        try {
          await ordenCompraApi.confirmar(orden.id)
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos confirmar la orden.')
        }
      },
    })

  const anularOrden = (orden: OrdenCompraResponse) =>
    confirmar({
      titulo: `Anular ${orden.numero}`,
      mensaje: 'Se anula la orden. No se puede deshacer.',
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await ordenCompraApi.anular(orden.id)
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos anular la orden.')
        }
      },
    })

  const columnasFilas: DataTableColumn<FilaOrden>[] = [
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
        const compras = producto?.presentaciones.filter((p) => p.esCompra && p.activo) ?? []

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
                    ...compras
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
    {
      key: 'costo',
      label: 'Costo pactado',
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

  const opcionesProveedor: OpcionBuscador<number>[] = proveedores.map((p) => ({
    item: p.id,
    label: p.nombre,
    detalle: p.documento,
    nota: p.rubro ?? undefined,
  }))

  const columnasProveedor: DataTableColumn<ProveedorResponse>[] = [
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
    { key: 'nombre', label: 'Razón social' },
    { key: 'rubro', label: 'Rubro' },
    { key: 'distrito', label: 'Distrito' },
  ]

  const columns: DataTableColumn<OrdenCompraResponse>[] = [
    { key: 'numero', label: 'Número', render: (row) => <Badge>{row.numero}</Badge> },
    { key: 'proveedor', label: 'Proveedor' },
    { key: 'fecha', label: 'Fecha', render: (row) => new Date(row.fecha).toLocaleDateString('es-PE') },
    {
      key: 'fechaEsperada',
      label: 'Fecha esperada',
      render: (row) => (row.fechaEsperada ? new Date(row.fechaEsperada).toLocaleDateString('es-PE') : '—'),
    },
    { key: 'total', label: 'Total', align: 'right', render: (row) => `S/ ${row.total.toFixed(2)}` },
    {
      key: 'estado',
      label: 'Estado',
      render: (row) => estadoOrdenBadge(row.estado),
    },
  ]

  if (vista === 'form') {
    return (
      <div className="space-y-5">
        <PageHeader
          icon={<ClipboardList size={20} />}
          title={editando ? `Editar ${editando.numero}` : 'Nueva orden de compra'}
          description="Lo que se le pide al proveedor. Mientras esté Pendiente se puede editar; al confirmarla, ya no."
          actions={
            <Button variant="secondary" size="sm" onClick={() => setVista('lista')}>
              <ArrowLeft size={15} />
              Volver
            </Button>
          }
        />

        {errorForm && <Alert>{errorForm}</Alert>}

        {/* Mismo layout que Mis compras: Productos a la izquierda porque es lo
            que más espacio pide (buscador y tabla); los datos de la orden y
            el total van en una columna angosta a la derecha, como un
            resumen de pedido. */}
        <div className="grid grid-cols-1 gap-5 lg:grid-cols-[1fr_360px] lg:items-start">
          <PageSection
            title="Productos"
            description={`${filas.length} producto${filas.length === 1 ? '' : 's'} agregado${filas.length === 1 ? '' : 's'}`}
          >
            <AgregarProductoPanel
              productos={productos}
              stock={stockMap}
              costoLabel="Costo pactado"
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
            <PageSection title="Orden">
              <BuscadorCampo
                label="Proveedor"
                value={proveedorId || null}
                onChange={(id) => setProveedorId(id ?? 0)}
                opciones={opcionesProveedor}
                placeholder="Buscar proveedor..."
                vacio="Ningún proveedor coincide"
                onAvanzado={() => setBuscadorAbierto(true)}
                avanzadoLabel="Búsqueda avanzada de proveedores"
              />

              <Input
                className="mt-4"
                label="Fecha esperada de entrega"
                optional
                type="date"
                value={fechaEsperada}
                onChange={(e) => setFechaEsperada(e.target.value)}
              />

              <Input
                className="mt-4"
                label="Observación"
                optional
                placeholder="Condiciones, referencia..."
                value={observacion}
                onChange={(e) => setObservacion(e.target.value)}
              />
            </PageSection>

            <PageSection title="Resumen">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold text-ink-soft uppercase tracking-wide">
                  Total de la orden
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
            {editando ? 'Guardar cambios' : 'Registrar orden'}
          </Button>
        </div>

        <BuscadorModal
          open={buscadorAbierto}
          onClose={() => setBuscadorAbierto(false)}
          title="Elegir proveedor"
          description="Busca por documento, razón social o rubro."
          columns={columnasProveedor}
          rows={proveedores}
          cardIcon={Building2}
          searchPlaceholder="Buscar proveedor..."
          onSeleccionar={(p) => setProveedorId(p.id)}
        />

        {dialogo}
      </div>
    )
  }

  return (
    <ListPage
      icon={<ClipboardList size={20} />}
      title="Órdenes de compra"
      description="Lo que se le pide a un proveedor. Al confirmarla nace la compra correspondiente."
      actions={
        <Button size="sm" onClick={abrirNueva} iconRight={<Plus size={15} />}>
          Nueva orden
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Órdenes" value={String(ordenes.length)} icon={<ClipboardList size={18} />} />
          <StatCard
            label="Pendientes"
            value={String(ordenes.filter((o) => o.estado === 'PENDIENTE').length)}
            icon={<ClipboardList size={18} />}
            tono="warning"
          />
          <StatCard
            label="Confirmadas"
            value={String(ordenes.filter((o) => o.estado === 'CONFIRMADA').length)}
            icon={<CheckCircle2 size={18} />}
            tono="success"
          />
        </>
      }
      columns={columns}
      rows={ordenes}
      cardIcon={ClipboardList}
      searchPlaceholder="Buscar por número, proveedor..."
      empty={cargando ? 'Cargando órdenes...' : 'Todavía no hay órdenes de compra registradas.'}
      rowActions={(row) => (
        <>
          <RowAction label={`Ver ${row.numero}`} tone="view" onClick={() => setDetalleAbierto(row)}>
            <Eye size={15} />
          </RowAction>
          <RowAction
            label={`Editar ${row.numero}`}
            disabled={row.estado !== 'PENDIENTE'}
            disabledReason="Solo se edita una orden pendiente"
            onClick={() => abrirEdicion(row)}
          >
            <Pencil size={15} />
          </RowAction>
          <RowAction
            label={`Confirmar y convertir a compra ${row.numero}`}
            tone="success"
            disabled={row.estado !== 'PENDIENTE'}
            disabledReason={row.estado === 'CONFIRMADA' ? 'Ya fue confirmada' : 'Está anulada'}
            onClick={() => confirmarOrden(row)}
          >
            <ShoppingBag size={15} />
          </RowAction>
          <RowAction
            label={`Anular ${row.numero}`}
            tone="danger"
            disabled={row.estado !== 'PENDIENTE'}
            disabledReason={row.estado === 'CONFIRMADA' ? 'Ya generó su compra: anula esa' : 'Ya está anulada'}
            onClick={() => anularOrden(row)}
          >
            <Undo2 size={15} />
          </RowAction>
        </>
      )}
    >
      <Modal
        open={detalleAbierto !== null}
        title={detalleAbierto ? `${detalleAbierto.numero} · ${detalleAbierto.proveedor}` : ''}
        description={
          detalleAbierto
            ? `Emisión ${new Date(detalleAbierto.fecha).toLocaleDateString('es-PE')} · Entrega est. ${
                detalleAbierto.fechaEsperada
                  ? new Date(detalleAbierto.fechaEsperada).toLocaleDateString('es-PE')
                  : '—'
              }`
            : undefined
        }
        onClose={() => setDetalleAbierto(null)}
        size="lg"
      >
        {detalleAbierto && (
          <div className="flex flex-col gap-3">
            {detalleAbierto.estado === 'ANULADA' && (
              <div>{estadoOrdenBadge(detalleAbierto.estado)}</div>
            )}

            <TablaProductosDetalle<LineaCompraResponse>
              filas={detalleAbierto.detalle}
              rowKey={(l) => l.id}
              titulo={(l) => l.producto}
              subtitulo={(l) => `${l.codigo} · ${l.presentacion ?? l.unidadBase}`}
              grupos={[
                [
                  { key: 'cant', label: 'Cant.', render: (l) => `${l.cantidadPresentacion}` },
                  { key: 'costo', label: 'Costo', render: (l) => `S/ ${l.costoUnitario.toFixed(2)}` },
                  { key: 'subtotal', label: 'Subtotal', render: (l) => `S/ ${l.costoTotal.toFixed(2)}` },
                ] satisfies ColumnaDetalleProducto<LineaCompraResponse>[],
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

      {dialogo}
    </ListPage>
  )
}
