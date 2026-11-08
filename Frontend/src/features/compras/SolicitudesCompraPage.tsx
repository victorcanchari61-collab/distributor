import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  AlertTriangle,
  ArrowLeft,
  CheckCircle2,
  ClipboardPen,
  Eye,
  Pencil,
  Send,
  ShoppingCart,
  Trash2,
  TrendingDown,
  Undo2,
  XCircle,
} from 'lucide-react'
import { idUnico } from '../../lib/ids'
import { fechaCorta } from '../../lib/fechas'
import {
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
  RowAction,
  StatCard,
  SysDataTable,
  TablaProductosDetalle,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { ColumnaDetalleProducto, DataTableColumn, LineaProductoNueva } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { navPath } from '../../components/layout/navigation'
import { opcionesPresentacion, presentacionInicialDe } from '../../lib/presentaciones'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { productoApi } from '../maestros'
import type { ProductoResponse } from '../maestros'
import { almacenApi, stockApi } from '../inventario'
import type { AlmacenOpcion } from '../inventario'
import { solicitudCompraApi } from './comprasApi'
import type {
  CrearSolicitudCompraRequest,
  EstadoSolicitudCompra,
  LineaSolicitudCompraResponse,
  SolicitudCompraFila,
  SolicitudCompraResponse,
  UrgenciaSolicitud,
} from './comprasApi'

const TONO_ESTADO = {
  BORRADOR: 'neutral',
  PENDIENTE: 'warning',
  ATENDIDA: 'success',
  RECHAZADA: 'danger',
  ANULADA: 'neutral',
} as const

const TEXTO_ESTADO: Record<EstadoSolicitudCompra, string> = {
  BORRADOR: 'Borrador',
  PENDIENTE: 'Pendiente',
  ATENDIDA: 'Atendida',
  RECHAZADA: 'Rechazada',
  ANULADA: 'Anulada',
}

const estadoBadge = (estado: EstadoSolicitudCompra) => (
  <Badge tone={TONO_ESTADO[estado]}>{TEXTO_ESTADO[estado]}</Badge>
)

const urgenciaBadge = (urgencia: UrgenciaSolicitud) =>
  urgencia === 'URGENTE' ? <Badge tone="danger">Urgente</Badge> : <span className="text-ink-soft">Normal</span>

/**
 * Solicitudes de compra: lo que el almacén pide que se compre.
 *
 * Es un documento INTERNO. El almacenero ve el stock pero no compra: aquí pide lo que hace falta, y quien compra
 * decide. De una solicitud sale la orden de compra —con proveedor y costos, que el almacén no maneja— y esa orden
 * es la que se le envía al proveedor. Por eso aquí no hay costos ni proveedores.
 *
 * Quien solo puede pedir (el almacenero) ve únicamente sus solicitudes; quien atiende ve todas.
 */
export function SolicitudesCompraPage() {
  const navigate = useNavigate()
  const { puede } = usePermisos()
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()

  const [vista, setVista] = useState<'lista' | 'form'>('lista')
  const [solicitudes, setSolicitudes] = useState<SolicitudCompraFila[]>([])
  const [almacenes, setAlmacenes] = useState<AlmacenOpcion[]>([])
  const [productos, setProductos] = useState<ProductoResponse[]>([])
  const [stockMap, setStockMap] = useState<Record<number, number>>({})
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [editando, setEditando] = useState<SolicitudCompraResponse | null>(null)
  const [detalleAbierto, setDetalleAbierto] = useState<SolicitudCompraResponse | null>(null)
  const [rechazando, setRechazando] = useState<SolicitudCompraFila | null>(null)
  const [motivo, setMotivo] = useState('')
  const [guardando, setGuardando] = useState(false)

  const [almacenId, setAlmacenId] = useState(0)
  const [urgencia, setUrgencia] = useState<UrgenciaSolicitud>('NORMAL')
  const [observacion, setObservacion] = useState('')
  const [filas, setFilas] = useState<LineaProductoNueva[]>([])
  const [trayendo, setTrayendo] = useState(false)

  const cargar = useCallback(async () => {
    try {
      const lista = await solicitudCompraApi.getAll()
      setSolicitudes(lista)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las solicitudes de compra.')
    } finally {
      setCargando(false)
    }
  }, [])

  // Los catálogos del formulario: solo hacen falta si quien entra puede pedir.
  const cargarApoyo = useCallback(async () => {
    if (!puede('compras.solicitudes', 'crear') && !puede('compras.solicitudes', 'editar')) return
    try {
      const [alms, prods, stock] = await Promise.all([
        almacenApi.opciones(),
        productoApi.getAll(),
        stockApi.disponible(),
      ])
      const activos = alms.filter((a) => a.activo)
      setAlmacenes(activos)
      setProductos(prods.filter((p) => p.activo))
      setStockMap(Object.fromEntries(stock.map((s) => [s.productoId, s.disponible])))
      // Con un solo almacén no hay nada que elegir.
      setAlmacenId((actual) => actual || (activos.length === 1 ? activos[0].id : 0))
    } catch {
      /* Sin catálogos se puede mirar la lista; el formulario avisará. */
    }
  }, [puede])

  useEffect(() => {
    void cargar()
    void cargarApoyo()
  }, [cargar, cargarApoyo])

  useRealtime(['solicitudescompra', 'ordenescompra'], cargar)

  const abrirNueva = () => {
    setEditando(null)
    setUrgencia('NORMAL')
    setObservacion('')
    setFilas([])
    setAlmacenId(almacenes.length === 1 ? almacenes[0].id : almacenId)
    setVista('form')
  }

  const conSolicitudCompleta = async (id: number, abrir: (s: SolicitudCompraResponse) => void) => {
    try {
      abrir(await solicitudCompraApi.getById(id))
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos abrir la solicitud.')
    }
  }

  const abrirEdicion = (s: SolicitudCompraResponse) => {
    setEditando(s)
    setAlmacenId(s.almacenId)
    setUrgencia(s.urgencia)
    setObservacion(s.observacion ?? '')
    setFilas(
      s.detalle.map((l) => ({
        id: idUnico(),
        productoId: l.productoId,
        presentacionId: l.presentacionId ?? 0,
        cantidad: String(l.cantidadPresentacion),
        costo: '',
        lote: '',
        fechaVencimiento: '',
      })),
    )
    setVista('form')
  }

  const actualizarFila = (id: string, cambio: Partial<LineaProductoNueva>) =>
    setFilas((prev) => prev.map((f) => (f.id === id ? { ...f, ...cambio } : f)))

  /** Trae lo que está bajo el mínimo en el almacén elegido, sin repetir lo que ya está en la lista. */
  const traerBajoMinimo = async () => {
    if (!almacenId) return toast.error('Elige primero el almacén.')

    setTrayendo(true)
    try {
      const sugeridos = await solicitudCompraApi.sugerencias(almacenId)
      const yaEstan = new Set(filas.map((f) => f.productoId))
      const nuevos = sugeridos.filter((s) => !yaEstan.has(s.productoId))

      if (nuevos.length === 0) {
        toast.exito(
          sugeridos.length === 0
            ? 'Ningún producto de ese almacén está bajo su mínimo.'
            : 'Lo que está bajo el mínimo ya está en la lista.',
        )
        return
      }

      setFilas((prev) => [
        ...prev,
        ...nuevos.map((s) => ({
          id: idUnico(),
          productoId: s.productoId,
          presentacionId: 0, // unidad base: es lo que sugiere el servidor
          cantidad: String(s.cantidadSugerida),
          costo: '',
          lote: '',
          fechaVencimiento: '',
        })),
      ])
      toast.exito(`Se agregaron ${nuevos.length} producto${nuevos.length === 1 ? '' : 's'} bajo el mínimo.`)
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos traer los productos bajo el mínimo.')
    } finally {
      setTrayendo(false)
    }
  }

  /** `enviar` false la deja en borrador; true la manda al administrador. Una ya enviada solo se corrige. */
  const guardar = async (enviar: boolean) => {
    if (!almacenId) return toast.error('Elige el almacén para el que se pide.')

    const validas = filas.filter((f) => f.productoId && Number(f.cantidad) > 0)
    if (validas.length === 0) return toast.error('Agrega al menos un producto con su cantidad.')

    const body: CrearSolicitudCompraRequest = {
      almacenId,
      urgencia,
      observacion: observacion.trim() || null,
      enviar,
      detalle: validas.map((f) => ({
        productoId: f.productoId,
        presentacionId: f.presentacionId || null,
        cantidad: Number(f.cantidad),
      })),
    }

    setGuardando(true)
    try {
      if (editando) await solicitudCompraApi.update(editando.id, body)
      else await solicitudCompraApi.create(body)

      setVista('lista')
      await cargar()
      toast.exito(
        enviar
          ? 'Solicitud enviada al administrador'
          : editando
            ? 'Solicitud actualizada'
            : 'Borrador guardado: la ves solo tú hasta que la envíes',
      )
    } catch (e) {
      toast.error(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos guardar la solicitud.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const enviar = (s: SolicitudCompraFila) =>
    confirmar({
      titulo: `Enviar ${s.numero}`,
      mensaje: 'Se envía al administrador para que la atienda. Después ya no es un borrador.',
      confirmar: 'Enviar',
      tono: 'pregunta',
      accion: async () => {
        setError('')
        try {
          await solicitudCompraApi.enviar(s.id)
          await cargar()
          toast.exito(`${s.numero} enviada al administrador`)
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos enviar la solicitud.')
        }
      },
    })

  const anular = (s: SolicitudCompraFila) =>
    confirmar({
      titulo: `Anular ${s.numero}`,
      mensaje: 'Se retira la solicitud: Compras ya no la verá para atender.',
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await solicitudCompraApi.anular(s.id)
          await cargar()
          toast.exito(`${s.numero} anulada`)
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos anular la solicitud.')
        }
      },
    })

  const rechazar = async () => {
    if (!rechazando) return
    if (!motivo.trim()) return toast.error('Escribe por qué se rechaza.')

    setGuardando(true)
    try {
      await solicitudCompraApi.rechazar(rechazando.id, motivo.trim())
      toast.exito(`${rechazando.numero} rechazada`)
      setRechazando(null)
      setMotivo('')
      await cargar()
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos rechazar la solicitud.')
    } finally {
      setGuardando(false)
    }
  }

  // La orden se arma en Órdenes de compra con las líneas ya cargadas: ahí se elige proveedor y se ponen los costos.
  const hacerOrden = (s: SolicitudCompraFila) =>
    navigate(navPath('compras.ordenes'), { state: { desdeSolicitudId: s.id } })

  const stats = useMemo(
    () => ({
      borradores: solicitudes.filter((s) => s.estado === 'BORRADOR').length,
      pendientes: solicitudes.filter((s) => s.estado === 'PENDIENTE').length,
      urgentes: solicitudes.filter((s) => s.estado === 'PENDIENTE' && s.urgencia === 'URGENTE').length,
      atendidas: solicitudes.filter((s) => s.estado === 'ATENDIDA').length,
      rechazadas: solicitudes.filter((s) => s.estado === 'RECHAZADA').length,
    }),
    [solicitudes],
  )

  const columnasFilas: DataTableColumn<LineaProductoNueva>[] = [
    {
      key: 'producto',
      label: 'Producto',
      value: (fila) => productos.find((p) => p.id === fila.productoId)?.nombre ?? '',
      render: (fila) => (
        <Desplegable
          value={fila.productoId}
          onChange={(v) =>
            actualizarFila(fila.id, {
              productoId: Number(v),
              presentacionId: presentacionInicialDe(productos, Number(v), 'compra'),
            })
          }
          options={productos.map((p) => ({ value: p.id, label: p.nombre, detalle: p.codigo }))}
        />
      ),
    },
    {
      key: 'presentacion',
      label: 'Presentación',
      render: (fila) => {
        const producto = productos.find((p) => p.id === fila.productoId)
        return (
          <Desplegable
            value={fila.presentacionId}
            onChange={(v) => actualizarFila(fila.id, { presentacionId: Number(v) })}
            placeholder={producto?.unidadBase ?? 'Elegir'}
            disabled={!producto}
            options={producto ? opcionesPresentacion(producto, 'compra', fila.presentacionId) : []}
          />
        )
      },
    },
    {
      key: 'stock',
      label: 'Stock',
      align: 'right',
      filterable: false,
      value: (fila) => stockMap[fila.productoId] ?? 0,
      render: (fila) => stockMap[fila.productoId] ?? '—',
    },
    {
      key: 'unidadBase',
      label: 'Unidad',
      filterable: false,
      value: (fila) => productos.find((p) => p.id === fila.productoId)?.unidadBase ?? '',
      render: (fila) => productos.find((p) => p.id === fila.productoId)?.unidadBase ?? '—',
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
  ]

  const columns: DataTableColumn<SolicitudCompraFila>[] = [
    { key: 'numero', label: 'Número', filterable: false, render: (row) => <Badge>{row.numero}</Badge> },
    { key: 'fecha', label: 'Fecha', filterType: 'date', render: (row) => fechaCorta(row.fecha) },
    {
      key: 'almacen',
      label: 'Almacén',
      filterType: 'select',
      filterOptions: [...new Set(solicitudes.map((s) => s.almacen))].map((a) => ({ value: a, label: a })),
    },
    {
      key: 'solicitante',
      label: 'Pidió',
      filterable: false,
      render: (row) => row.solicitante ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'lineas',
      label: 'Productos',
      align: 'right',
      filterable: false,
      render: (row) => row.lineas,
    },
    {
      key: 'urgencia',
      label: 'Urgencia',
      filterType: 'select',
      filterOptions: [
        { value: 'URGENTE', label: 'Urgente' },
        { value: 'NORMAL', label: 'Normal' },
      ],
      render: (row) => urgenciaBadge(row.urgencia),
    },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: (Object.keys(TEXTO_ESTADO) as EstadoSolicitudCompra[]).map((e) => ({
        value: e,
        label: TEXTO_ESTADO[e],
      })),
      render: (row) => estadoBadge(row.estado),
    },
    {
      key: 'ordenes',
      label: 'Órdenes de compra',
      filterable: false,
      value: (row) => row.ordenes.map((o) => o.numero).join(', '),
      render: (row) =>
        row.ordenes.length > 0 ? (
          <span className="text-ink-muted">{row.ordenes.map((o) => o.numero).join(', ')}</span>
        ) : (
          <span className="text-ink-soft">—</span>
        ),
    },
  ]

  if (vista === 'form') {
    return (
      <div className="space-y-5">
        <PageHeader
          icon={<ClipboardPen size={20} />}
          title={editando ? `Editar ${editando.numero}` : 'Nueva solicitud de compra'}
          description="Lo que hace falta comprar. Se arma como borrador y, cuando está lista, se envía al administrador."
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
            description={`${filas.length} producto${filas.length === 1 ? '' : 's'} en la solicitud`}
          >
            <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
              <p className="text-xs text-ink-soft">
                Sin precios: el costo y el proveedor los pone Compras al hacer la orden.
              </p>
              <Button variant="secondary" size="sm" loading={trayendo} onClick={() => void traerBajoMinimo()}>
                <TrendingDown size={15} />
                Traer lo que está bajo el mínimo
              </Button>
            </div>

            <AgregarProductoPanel
              productos={productos}
              stock={stockMap}
              uso="compra"
              pideCosto={false}
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

          <PageSection title="Solicitud">
            <Desplegable
              label="Almacén"
              value={almacenId}
              onChange={(v) => setAlmacenId(Number(v))}
              placeholder="Elegir"
              options={almacenes.map((a) => ({ value: a.id, label: a.nombre, detalle: a.codigo }))}
            />

            <div className="mt-4">
              <span className="ui-label">Urgencia</span>
              <div className="mt-1.5 flex gap-2" role="group" aria-label="Urgencia">
                {(['NORMAL', 'URGENTE'] as const).map((u) => (
                  <button
                    key={u}
                    type="button"
                    aria-pressed={urgencia === u}
                    onClick={() => setUrgencia(u)}
                    className={`flex-1 rounded-field border px-3 py-2 text-sm transition-colors ${
                      urgencia === u
                        ? u === 'URGENTE'
                          ? 'border-red-500 bg-red-50 font-semibold text-red-700'
                          : 'border-blue-500 bg-blue-50 font-semibold text-blue-700'
                        : 'border-line bg-white text-ink-muted hover:bg-surface-alt'
                    }`}
                  >
                    {u === 'URGENTE' ? 'Urgente' : 'Normal'}
                  </button>
                ))}
              </div>
            </div>

            <Input
              className="mt-4"
              label="Motivo u observación"
              optional
              placeholder="Se acaba el aceite, pedido grande del lunes..."
              value={observacion}
              onChange={(e) => setObservacion(e.target.value)}
            />
          </PageSection>
        </div>

        {/* En el teléfono los botones se apilan, el principal arriba: en una fila no caben sus textos. */}
        <div className="flex flex-col-reverse gap-2 sm:flex-row sm:justify-end">
          <Button variant="secondary" size="sm" className="w-full sm:w-auto" onClick={() => setVista('lista')}>
            Cancelar
          </Button>
          {/* Una ya enviada solo se corrige. Un borrador se guarda para seguir o se envía al administrador. */}
          {editando && editando.estado !== 'BORRADOR' ? (
            <Button size="sm" className="w-full sm:w-auto" loading={guardando} onClick={() => void guardar(false)}>
              Guardar cambios
            </Button>
          ) : (
            <>
              <Button
                variant="secondary"
                size="sm"
                className="w-full sm:w-auto"
                disabled={guardando}
                onClick={() => void guardar(false)}
              >
                Guardar borrador
              </Button>
              <Button
                size="sm"
                className="w-full sm:w-auto"
                loading={guardando}
                onClick={() => void guardar(true)}
                iconRight={<Send size={15} />}
              >
                Enviar al administrador
              </Button>
            </>
          )}
        </div>
      </div>
    )
  }

  return (
    <>
      <ListPage
        icon={<ClipboardPen size={20} />}
        title="Solicitudes de compra"
        description="Lo que el almacén pide que se compre. De cada solicitud sale la orden de compra para el proveedor."
        alert={error ? <Alert>{error}</Alert> : undefined}
        actions={
          puede('compras.solicitudes', 'crear') && (
            <Button size="sm" onClick={abrirNueva}>
              <ClipboardPen size={15} />
              Nueva solicitud
            </Button>
          )
        }
        stats={
          <>
            <StatCard
              label="Pendientes"
              value={String(stats.pendientes)}
              hint="esperando a Compras"
              icon={<ClipboardPen size={18} />}
              tono="warning"
            />
            <StatCard
              label="Urgentes"
              value={String(stats.urgentes)}
              hint="pendientes y urgentes"
              icon={<AlertTriangle size={18} />}
              tono="danger"
            />
            <StatCard
              label="Atendidas"
              value={String(stats.atendidas)}
              hint="ya tienen orden de compra"
              icon={<CheckCircle2 size={18} />}
              tono="success"
            />
            <StatCard
              label="Borradores"
              value={String(stats.borradores)}
              hint="sin enviar: solo los ves tú"
              icon={<Pencil size={18} />}
              tono="neutral"
            />
          </>
        }
        columns={columns}
        rows={solicitudes}
        cardIcon={ClipboardPen}
        searchPlaceholder="Buscar por número, almacén, quién pidió..."
        empty={cargando ? 'Cargando solicitudes...' : 'Todavía no hay solicitudes de compra.'}
        actionsWidth={170}
        rowActions={(row) => (
          <>
            <RowAction
              label={`Ver ${row.numero}`}
              tone="view"
              onClick={() => void conSolicitudCompleta(row.id, setDetalleAbierto)}
            >
              <Eye size={15} />
            </RowAction>
            {(row.estado === 'BORRADOR' || row.estado === 'PENDIENTE') && puede('compras.solicitudes', 'editar') && (
              <RowAction
                label={`Editar ${row.numero}`}
                onClick={() => void conSolicitudCompleta(row.id, abrirEdicion)}
              >
                <Pencil size={15} />
              </RowAction>
            )}
            {row.estado === 'BORRADOR' && puede('compras.solicitudes', 'crear') && (
              <RowAction label={`Enviar ${row.numero} al administrador`} tone="success" onClick={() => enviar(row)}>
                <Send size={15} />
              </RowAction>
            )}
            {(row.estado === 'PENDIENTE' || row.estado === 'ATENDIDA') &&
              puede('compras.solicitudes', 'confirmar') &&
              puede('compras.ordenes', 'crear') && (
                <RowAction label={`Hacer orden de compra con ${row.numero}`} tone="success" onClick={() => hacerOrden(row)}>
                  <ShoppingCart size={15} />
                </RowAction>
              )}
            {row.estado === 'PENDIENTE' && puede('compras.solicitudes', 'confirmar') && (
              <RowAction
                label={`Rechazar ${row.numero}`}
                tone="danger"
                onClick={() => {
                  setMotivo('')
                  setRechazando(row)
                }}
              >
                <XCircle size={15} />
              </RowAction>
            )}
            {(row.estado === 'BORRADOR' || row.estado === 'PENDIENTE') && puede('compras.solicitudes', 'anular') && (
              <RowAction label={`Anular ${row.numero}`} tone="danger" onClick={() => anular(row)}>
                <Undo2 size={15} />
              </RowAction>
            )}
          </>
        )}
      />

      {dialogo}

      <Modal
        open={detalleAbierto !== null}
        size="lg"
        title={detalleAbierto ? `Solicitud ${detalleAbierto.numero}` : ''}
        description={
          detalleAbierto
            ? `${detalleAbierto.almacen} · ${fechaCorta(detalleAbierto.fecha)}${
                detalleAbierto.solicitante ? ` · pidió ${detalleAbierto.solicitante}` : ''
              }`
            : ''
        }
        onClose={() => setDetalleAbierto(null)}
        footer={
          <Button variant="secondary" size="sm" onClick={() => setDetalleAbierto(null)}>
            Cerrar
          </Button>
        }
      >
        {detalleAbierto && (
          <div className="flex flex-col gap-4">
            <div className="flex flex-wrap items-center gap-2">
              {estadoBadge(detalleAbierto.estado)}
              {urgenciaBadge(detalleAbierto.urgencia)}
              {detalleAbierto.ordenes.map((o) => (
                <Badge key={o.id} tone="sys">
                  {o.numero}
                </Badge>
              ))}
            </div>

            {detalleAbierto.estado === 'RECHAZADA' && detalleAbierto.motivoRechazo && (
              <Alert tone="warning">Compras la rechazó: {detalleAbierto.motivoRechazo}</Alert>
            )}

            {detalleAbierto.observacion && (
              <p className="text-sm text-ink-muted">{detalleAbierto.observacion}</p>
            )}

            <TablaProductosDetalle<LineaSolicitudCompraResponse>
              filas={detalleAbierto.detalle}
              rowKey={(l) => l.id}
              titulo={(l) => l.producto}
              subtitulo={(l) => `${l.codigo} · ${l.presentacion ?? l.unidadBase}`}
              grupos={[
                [
                  { key: 'cant', label: 'Cantidad', render: (l) => `${l.cantidadPresentacion}` },
                  {
                    key: 'base',
                    label: 'En unidad base',
                    render: (l) => `${l.cantidad} ${l.unidadBase}`,
                  },
                ] satisfies ColumnaDetalleProducto<LineaSolicitudCompraResponse>[],
              ]}
            />
          </div>
        )}
      </Modal>

      <Modal
        open={rechazando !== null}
        size="sm"
        title={rechazando ? `Rechazar ${rechazando.numero}` : ''}
        description="Quien la pidió va a ver este motivo."
        onClose={() => setRechazando(null)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setRechazando(null)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void rechazar()}>
              Rechazar
            </Button>
          </>
        }
      >
        <Input
          label="Motivo"
          placeholder="Ya hay una orden en camino, no hay presupuesto..."
          value={motivo}
          onChange={(e) => setMotivo(e.target.value)}
        />
      </Modal>
    </>
  )
}
