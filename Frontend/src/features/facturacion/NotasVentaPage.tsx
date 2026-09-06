import { useCallback, useEffect, useState } from 'react'
import { ArrowLeft, Contact, Eye, History, Pencil, Plus, ShoppingBag, Trash2, Undo2 } from 'lucide-react'
import {
  AgregarProductoPanel,
  Alert,
  Badge,
  BuscadorCampo,
  BuscadorModal,
  Button,
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
  ConsultaTabla,
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
import { metodoPagoApi } from '../finanzas'
import type { MetodoPagoResponse, TipoMetodoPago } from '../finanzas'
import { listaPrecioApi } from './listaPrecioApi'
import type { ListaPrecioResponse } from './listaPrecioApi'
import { notaVentaApi } from './ventasApi'
import type { AuditoriaResponse } from '../config'
import type {
  CrearNotaVentaRequest,
  FormaPagoVenta,
  LineaVentaResponse,
  NotaVentaResponse,
  ResumenNotasVenta,
} from './ventasApi'

const FORMAS_PAGO: { value: FormaPagoVenta; label: string }[] = [
  { value: 'CONTADO', label: 'Contado' },
  { value: 'CREDITO', label: 'Crédito' },
]

function estadoNotaVentaBadge(estado: NotaVentaResponse['estado']) {
  return <Badge tone={estado === 'ANULADA' ? 'danger' : 'success'}>{estado === 'ANULADA' ? 'Anulada' : 'Confirmada'}</Badge>
}

const TIPOS_METODO_PAGO: { value: TipoMetodoPago; label: string }[] = [
  { value: 'EFECTIVO', label: 'Efectivo' },
  { value: 'BILLETERA_DIGITAL', label: 'Billetera digital' },
  { value: 'TRANSFERENCIA', label: 'Transferencia' },
]

type FilaVenta = LineaProductoNueva

/**
 * Notas de venta: la venta lista tal cual, nacida de confirmar un pedido o
 * registrada directa. El stock sale al momento de crearla — no existe una
 * "nota de venta a medio despachar" como sí existe una compra a medio
 * recibir, así que no hay una pantalla de despachos aparte.
 */
export function NotasVentaPage() {
  const [vista, setVista] = useState<'lista' | 'form'>('lista')
  const [notas, setNotas] = useState<NotaVentaResponse[]>([])
  const [clientes, setClientes] = useState<ClienteResponse[]>([])
  const [productos, setProductos] = useState<ProductoResponse[]>([])
  const [almacenes, setAlmacenes] = useState<AlmacenResponse[]>([])
  const [listas, setListas] = useState<ListaPrecioResponse[]>([])
  const [metodosPago, setMetodosPago] = useState<MetodoPagoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [editando, setEditando] = useState<NotaVentaResponse | null>(null)
  const [detalleAbierto, setDetalleAbierto] = useState<NotaVentaResponse | null>(null)
  const [historialAbierto, setHistorialAbierto] = useState<NotaVentaResponse | null>(null)
  const [historial, setHistorial] = useState<AuditoriaResponse[]>([])
  const [historialCargando, setHistorialCargando] = useState(false)
  const [buscadorAbierto, setBuscadorAbierto] = useState(false)
  const [pagosAbierto, setPagosAbierto] = useState(false)
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const [clienteId, setClienteId] = useState(0)
  const [almacenId, setAlmacenId] = useState(0)
  const [listaPrecioId, setListaPrecioId] = useState(0)
  const [formaPago, setFormaPago] = useState<FormaPagoVenta>('CONTADO')
  const [pagos, setPagos] = useState<{ metodoPagoId: number; monto: string }[]>([])
  const [pagoTipo, setPagoTipo] = useState<TipoMetodoPago | ''>('')
  const [pagoMetodoId, setPagoMetodoId] = useState(0)
  const [pagoMonto, setPagoMonto] = useState('')
  const [observacion, setObservacion] = useState('')
  const [filas, setFilas] = useState<FilaVenta[]>([])
  const [stockMap, setStockMap] = useState<Record<number, number>>({})

  const { confirmar, dialogo } = useConfirmacion()

  /*
   * Las ventas se acumulan con la operacion: la tabla pide solo la pagina que
   * muestra. Los contadores vienen del resumen — sumarlos sobre las filas
   * cargadas daria el total de 20 ventas, no el del negocio.
   */
  const [consulta, setConsulta] = useState<ConsultaTabla | null>(null)
  const [totalRegistros, setTotalRegistros] = useState(0)
  const [resumen, setResumen] = useState<ResumenNotasVenta | null>(null)

  const cargarPagina = useCallback(async (q: ConsultaTabla) => {
    setCargando(true)
    try {
      const pagina = await notaVentaApi.listar(q)
      setNotas(pagina.items)
      setTotalRegistros(pagina.total)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las notas de venta.')
    } finally {
      setCargando(false)
    }
  }, [])

  /** Catalogos del formulario y contadores: no cambian al paginar. */
  const cargarApoyo = useCallback(async () => {
    try {
      const [res, clis, prods, alms, lis, metodos] = await Promise.all([
        notaVentaApi.resumen(),
        clienteApi.getAll(),
        productoApi.getAll(),
        almacenApi.getAll(),
        listaPrecioApi.getAll(),
        metodoPagoApi.getAll(),
      ])
      setResumen(res)
      setClientes(clis.filter((c) => c.activo))
      setProductos(prods.filter((p) => p.activo && p.controlaStock))
      setAlmacenes(alms.filter((a) => a.activo))
      setListas(lis.filter((l) => l.activo))
      setMetodosPago(metodos.filter((m) => m.activo))
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

  useRealtime(['notasventa', 'pedidos', 'stock'], cargar)

  // Stock disponible del almacén elegido: es lo que se puede vender desde ahí.
  useEffect(() => {
    if (!almacenId) return
    let cancelado = false
    void stockApi.getAll(almacenId).then((stock) => {
      if (!cancelado) setStockMap(Object.fromEntries(stock.map((s) => [s.productoId, s.disponible])))
    })
    return () => {
      cancelado = true
    }
  }, [almacenId, notas])

  const abrirNueva = () => {
    setEditando(null)
    setClienteId(0)
    // El principal por defecto: quien tiene un solo depósito nunca lo elige.
    setAlmacenId(almacenes.find((a) => a.esPrincipal)?.id ?? almacenes[0]?.id ?? 0)
    setListaPrecioId(0)
    setFormaPago('CONTADO')
    setPagos([])
    setPagoTipo('')
    setPagoMetodoId(0)
    setPagoMonto('')
    setObservacion('')
    setFilas([])
    setErrorForm('')
    setVista('form')
  }

  const abrirEdicion = (nota: NotaVentaResponse) => {
    setEditando(nota)
    setClienteId(nota.clienteId)
    setAlmacenId(nota.almacenId)
    setListaPrecioId(0)
    setFormaPago(nota.formaPago)
    setPagos([])
    setPagoTipo('')
    setPagoMetodoId(0)
    setPagoMonto('')
    setObservacion(nota.observacion ?? '')
    setFilas(
      nota.detalle
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

  const abrirHistorial = (nota: NotaVentaResponse) => {
    setHistorialAbierto(nota)
    setHistorial([])
    setHistorialCargando(true)
    void notaVentaApi
      .historial(nota.id)
      .then(setHistorial)
      .catch(() => setHistorial([]))
      .finally(() => setHistorialCargando(false))
  }

  const actualizarFila = (id: string, cambio: Partial<FilaVenta>) =>
    setFilas((prev) => prev.map((f) => (f.id === id ? { ...f, ...cambio } : f)))

  const total = filas.reduce((n, f) => n + (Number(f.cantidad) || 0) * (Number(f.costo) || 0), 0)
  const totalPagado = pagos.reduce((n, p) => n + (Number(p.monto) || 0), 0)

  const agregarPago = () => {
    if (!pagoMetodoId || !pagoMonto || Number(pagoMonto) <= 0) return

    if (totalPagado + Number(pagoMonto) > total + 0.001) {
      setErrorForm(
        `Ese pago deja lo pagado en S/ ${(totalPagado + Number(pagoMonto)).toFixed(2)}, más que el total de la venta (S/ ${total.toFixed(2)}).`,
      )
      return
    }

    setErrorForm('')
    setPagos((prev) => [...prev, { metodoPagoId: pagoMetodoId, monto: pagoMonto }])
    setPagoTipo('')
    setPagoMetodoId(0)
    setPagoMonto('')
  }

  const quitarPago = (i: number) => setPagos((prev) => prev.filter((_, idx) => idx !== i))

  const guardar = async () => {
    if (!clienteId) return setErrorForm('Elige el cliente.')
    if (!almacenId) return setErrorForm('Elige el almacén.')

    const validas = filas.filter((f) => f.productoId && f.cantidad && f.costo)
    if (validas.length === 0) return setErrorForm('Agrega al menos un producto con su precio.')

    // Al editar no se tocan los pagos: eso ya tiene su propio flujo
    // ("Gestionar pagos" desde Ver detalle), así que ni se valida ni se envía.
    if (!editando && totalPagado > total + 0.001) {
      return setErrorForm(
        `Los pagos suman S/ ${totalPagado.toFixed(2)}, más que el total de la venta (S/ ${total.toFixed(2)}).`,
      )
    }

    const body: CrearNotaVentaRequest = {
      clienteId,
      almacenId,
      listaPrecioId: listaPrecioId || null,
      formaPago,
      pagos: editando ? [] : pagos.map((p) => ({ metodoPagoId: p.metodoPagoId, monto: Number(p.monto) })),
      observacion: observacion.trim() || null,
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
        await notaVentaApi.update(editando.id, body)
      } else {
        await notaVentaApi.create(body)
      }
      setVista('lista')
      await cargar()
    } catch (e) {
      setErrorForm(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos registrar la venta.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const anularNota = (nota: NotaVentaResponse) =>
    confirmar({
      titulo: `Anular ${nota.numero}`,
      mensaje: 'Se anula la venta y el stock que salió vuelve al almacén. No se puede deshacer.',
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await notaVentaApi.anular(nota.id)
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos anular la venta.')
        }
      },
    })

  const columnasFilas: DataTableColumn<FilaVenta>[] = [
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

  const columns: DataTableColumn<NotaVentaResponse>[] = [
    { key: 'numero', label: 'Número', render: (row) => <Badge>{row.numero}</Badge> },
    { key: 'cliente', label: 'Cliente' },
    {
      key: 'pedidoNumero',
      label: 'Origen',
      sortable: false,
      filterable: false,
      render: (row) => (row.pedidoNumero ? row.pedidoNumero : 'Directa'),
    },
    {
      key: 'fecha',
      label: 'Fecha',
      filterType: 'date',
      render: (row) => new Date(row.fecha).toLocaleDateString('es-PE'),
    },
    { key: 'total', label: 'Total', align: 'right', render: (row) => `S/ ${row.total.toFixed(2)}` },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'CONFIRMADA', label: 'Confirmada' },
        { value: 'ANULADA', label: 'Anulada' },
      ],
      render: (row) => estadoNotaVentaBadge(row.estado),
    },
  ]

  if (vista === 'form') {
    return (
      <div className="space-y-5">
        <PageHeader
          icon={<ShoppingBag size={20} />}
          title={editando ? `Editar ${editando.numero}` : 'Nueva venta directa'}
          description={
            editando
              ? 'El stock se ajusta solo con la diferencia. Los pagos no se tocan aquí: usa "Gestionar pagos" desde Ver detalle.'
              : 'Sin pasar por un pedido primero. El stock sale del almacén elegido al momento de registrarla.'
          }
          actions={
            <Button variant="secondary" size="sm" onClick={() => setVista('lista')}>
              <ArrowLeft size={15} />
              Volver
            </Button>
          }
        />

        {errorForm && <Alert>{errorForm}</Alert>}

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
            <PageSection title="Venta">
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
                label="Almacén"
                value={almacenId}
                onChange={(v) => setAlmacenId(Number(v))}
                placeholder="Elige el almacén"
                options={almacenes.map((a) => ({ value: a.id, label: a.nombre }))}
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

              {editando ? (
                <p className="mt-4 rounded-field bg-surface-alt px-3 py-2 text-xs text-ink-soft">
                  Forma de pago: <span className="font-medium text-ink">
                    {FORMAS_PAGO.find((f) => f.value === formaPago)?.label ?? formaPago}
                  </span>
                  . Los pagos se gestionan desde "Ver detalle" → Gestionar pagos.
                </p>
              ) : (
                <>
                  <Desplegable
                    className="mt-4"
                    label="Forma de pago"
                    value={formaPago}
                    onChange={(v) => {
                      const nueva = v as FormaPagoVenta
                      setFormaPago(nueva)
                      if (nueva === 'CREDITO') setPagos([])
                    }}
                    options={FORMAS_PAGO}
                  />

                  {formaPago === 'CONTADO' ? (
                    <div className="mt-4 flex items-center justify-between gap-3 rounded-field border border-line px-3 py-2.5">
                      <div>
                        <span className="ui-label block">Pagos</span>
                        <span className="text-xs text-ink-soft">
                          {pagos.length === 0
                            ? 'Sin registrar'
                            : `S/ ${totalPagado.toFixed(2)} de S/ ${total.toFixed(2)} · ${pagos.length} ${pagos.length === 1 ? 'línea' : 'líneas'}`}
                        </span>
                      </div>
                      <Button type="button" size="sm" variant="secondary" onClick={() => setPagosAbierto(true)}>
                        {pagos.length === 0 ? 'Agregar pago' : 'Gestionar pagos'}
                      </Button>
                    </div>
                  ) : (
                    <p className="mt-4 text-xs text-ink-soft">
                      Al crédito no se registra pago ahora — queda pendiente de cobro.
                    </p>
                  )}
                </>
              )}

              <Input
                className="mt-4"
                label="Observación"
                optional
                placeholder="Referencia..."
                value={observacion}
                onChange={(e) => setObservacion(e.target.value)}
              />
            </PageSection>

            <PageSection title="Resumen">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold text-ink-soft uppercase tracking-wide">Total de la venta</span>
                <span className="text-xl font-bold text-[rgb(var(--sys-rgb))]">S/ {total.toFixed(2)}</span>
              </div>
            </PageSection>
          </div>
        </div>

        <div className="flex justify-end gap-2">
          <Button variant="secondary" size="sm" onClick={() => setVista('lista')}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            {editando ? 'Guardar cambios' : 'Registrar venta'}
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

        <Modal
          open={pagosAbierto}
          onClose={() => setPagosAbierto(false)}
          size="sm"
          title="Pagos"
          description="Reparte el total entre uno o varios métodos."
          footer={
            <Button size="sm" onClick={() => setPagosAbierto(false)}>
              Listo
            </Button>
          }
        >
          <div className="flex flex-col gap-4">
            {errorForm && <Alert>{errorForm}</Alert>}

            <Desplegable
              label="Tipo"
              value={pagoTipo}
              onChange={(v) => {
                setPagoTipo(v as TipoMetodoPago)
                setPagoMetodoId(0)
              }}
              placeholder="Elige el tipo"
              options={TIPOS_METODO_PAGO}
            />

            <div className="flex gap-2">
              <div className="min-w-0 flex-1">
                <Desplegable
                  value={pagoMetodoId}
                  onChange={(v) => setPagoMetodoId(Number(v))}
                  placeholder={pagoTipo ? 'Método' : 'Elige el tipo primero'}
                  disabled={!pagoTipo}
                  options={metodosPago.filter((m) => m.tipo === pagoTipo).map((m) => ({ value: m.id, label: m.nombre }))}
                />
              </div>
              <div className="w-28 shrink-0">
                <Input
                  type="number"
                  step="0.01"
                  placeholder="Monto"
                  value={pagoMonto}
                  onChange={(e) => setPagoMonto(e.target.value)}
                />
              </div>
              <Button type="button" size="sm" variant="secondary" onClick={agregarPago}>
                <Plus size={15} />
              </Button>
            </div>

            {pagos.length === 0 ? (
              <p className="text-sm text-ink-soft">Todavía no hay pagos registrados.</p>
            ) : (
              <div className="flex flex-col gap-1.5">
                {pagos.map((p, i) => (
                  <div key={i} className="flex items-center justify-between rounded-field border border-line px-3 py-1.5 text-sm">
                    <span>{metodosPago.find((m) => m.id === p.metodoPagoId)?.nombre ?? '—'}</span>
                    <span className="flex items-center gap-2">
                      S/ {(Number(p.monto) || 0).toFixed(2)}
                      <button
                        type="button"
                        onClick={() => quitarPago(i)}
                        aria-label="Quitar pago"
                        className="text-ink-soft transition-colors hover:text-red-600"
                      >
                        <Trash2 size={13} />
                      </button>
                    </span>
                  </div>
                ))}
              </div>
            )}

            <div className="flex items-center justify-between border-t border-line pt-3 text-sm font-semibold">
              <span>Pagado</span>
              <span className={totalPagado > total + 0.001 ? 'text-red-600' : 'text-ink'}>
                S/ {totalPagado.toFixed(2)} de S/ {total.toFixed(2)}
              </span>
            </div>
          </div>
        </Modal>
      </div>
    )
  }

  return (
    <ListPage
      icon={<ShoppingBag size={20} />}
      title="Notas de venta"
      description="La venta lista tal cual: nació de confirmar un pedido o se registró directa."
      actions={
        <Button size="sm" onClick={abrirNueva} iconRight={<Plus size={15} />}>
          Nueva venta
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Notas de venta" value={String(resumen?.total ?? 0)} icon={<ShoppingBag size={18} />} />
          <StatCard
            label="Confirmadas"
            value={String(resumen?.confirmadas ?? 0)}
            icon={<ShoppingBag size={18} />}
            tono="success"
          />
          <StatCard
            label="Total vendido"
            value={`S/ ${(resumen?.totalVendido ?? 0).toFixed(2)}`}
            icon={<ShoppingBag size={18} />}
          />
        </>
      }
      columns={columns}
      // 4 íconos por fila (Ver, Historial, Editar, Anular) más 6 columnas de
      // datos: el ancho por defecto de Acciones queda muy justo.
      actionsWidth={150}
      rows={notas}
      servidor={{
        total: totalRegistros,
        cargando,
        onConsulta: (q) => {
          setConsulta(q)
          void cargarPagina(q)
        },
      }}
      cardIcon={ShoppingBag}
      searchPlaceholder="Buscar por número, cliente..."
      empty={cargando ? 'Cargando notas de venta...' : 'Todavía no hay notas de venta registradas.'}
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
            disabled={row.estado !== 'CONFIRMADA'}
            disabledReason="Ya está anulada"
            onClick={() => abrirEdicion(row)}
          >
            <Pencil size={15} />
          </RowAction>
          <RowAction
            label={`Anular ${row.numero}`}
            tone="danger"
            disabled={row.estado !== 'CONFIRMADA'}
            disabledReason="Ya está anulada"
            onClick={() => anularNota(row)}
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
          detalleAbierto
            ? `Emisión ${new Date(detalleAbierto.fecha).toLocaleDateString('es-PE')} · ${detalleAbierto.almacen} · ` +
              (FORMAS_PAGO.find((f) => f.value === detalleAbierto.formaPago)?.label ?? detalleAbierto.formaPago)
            : undefined
        }
        onClose={() => setDetalleAbierto(null)}
        size="lg"
      >
        {detalleAbierto && (
          <div className="flex flex-col gap-3">
            {detalleAbierto.estado === 'ANULADA' && <div>{estadoNotaVentaBadge(detalleAbierto.estado)}</div>}

            {detalleAbierto.detalle.some((l) => l.anulado) && (
              <p className="text-xs text-ink-soft">
                Se quitaron productos al editar esta venta — quedan solo en "Ver historial".
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

            <ResumenDocumento
              pagos={detalleAbierto.pagos.map((p) => ({ id: p.id, label: p.metodoPago, monto: p.monto }))}
              total={detalleAbierto.total}
            />

            {detalleAbierto.pedidoNumero && (
              <p className="text-sm text-ink-soft">
                <span className="font-semibold text-ink-muted">Pedido: </span>
                {detalleAbierto.pedidoNumero}
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

      {dialogo}
    </ListPage>
  )
}
