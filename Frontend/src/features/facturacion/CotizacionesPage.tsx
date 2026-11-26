import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { CircleCheck, Clock, FileText, MessageSquareQuote, XCircle } from 'lucide-react'
import { FaBan, FaCartPlus, FaEye } from 'react-icons/fa6'
import { navPath } from '../../components/layout'
import { Alert, Badge, Button, Input, ListPage, Modal, RowAction, StatCard, SysDataTable, useToast } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaHora } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { ESTADO_COTIZACION, cotizacionApi } from './cotizacionApi'
import type { Cotizacion, EstadoCotizacion, LineaCotizacion } from './cotizacionApi'

const soles = (n: number) => `S/ ${n.toLocaleString('es-PE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
const cantidad = (n: number) => n.toLocaleString('es-PE', { maximumFractionDigits: 3 })

/**
 * La bandeja de cotizaciones que los clientes mandan desde el portal. Atender una es crear el pedido jalándola: el
 * botón lleva a Pedidos con el formulario ya lleno (cliente, productos, precios y la nota), y al guardar el pedido la
 * cotización queda atendida. Si no se va a atender, se descarta con un motivo que ve el cliente.
 */
export function CotizacionesPage() {
  const toast = useToast()
  const navigate = useNavigate()
  const { puede } = usePermisos()
  const [cotizaciones, setCotizaciones] = useState<Cotizacion[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [estadoFiltro, setEstadoFiltro] = useState<EstadoCotizacion | ''>('EN_ESPERA')
  const [detalle, setDetalle] = useState<Cotizacion | null>(null)
  const [descartando, setDescartando] = useState<Cotizacion | null>(null)
  const [motivo, setMotivo] = useState('')
  const [guardando, setGuardando] = useState(false)

  const cargar = useCallback(async () => {
    try {
      setCotizaciones(await cotizacionApi.listar())
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las cotizaciones.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  // Una cotización nueva aparece sola: la manda el cliente desde su celular.
  useRealtime(['cotizaciones', 'pedidos'], cargar)

  const contar = (estado: EstadoCotizacion) => cotizaciones.filter((c) => c.estado === estado).length
  const enEspera = cotizaciones.filter((c) => c.estado === 'EN_ESPERA')
  const visibles = estadoFiltro ? cotizaciones.filter((c) => c.estado === estadoFiltro) : cotizaciones
  const puedeJalar = puede('fact.pedidos', 'crear')
  const puedeDescartar = puede('fact.cotizaciones', 'anular')

  /** Lleva a Pedidos con el formulario nuevo ya lleno con la cotización. */
  const crearPedido = (c: Cotizacion) => navigate(navPath('fact.pedidos'), { state: { desdeCotizacionId: c.id } })

  const descartar = async () => {
    if (!descartando) return
    if (!motivo.trim()) return toast.error('Escribe por qué no se atiende: lo verá el cliente.')
    setGuardando(true)
    try {
      await cotizacionApi.descartar(descartando.id, motivo.trim())
      toast.exito(`${descartando.numero} descartada`)
      setDescartando(null)
      await cargar()
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos descartarla.')
    } finally {
      setGuardando(false)
    }
  }

  const columnas: DataTableColumn<Cotizacion>[] = [
    { key: 'numero', label: 'Número', filterable: false, render: (r) => <Badge>{r.numero}</Badge> },
    { key: 'fecha', label: 'Fecha', filterType: 'date', render: (r) => fechaHora(r.fecha) },
    {
      key: 'cliente',
      label: 'Cliente',
      render: (r) => (
        <div className="flex flex-col">
          <span className="font-medium text-ink">{r.cliente}</span>
          <span className="text-xs text-ink-soft">{r.clienteDocumento}</span>
        </div>
      ),
    },
    {
      key: 'ruta',
      label: 'Ruta',
      filterType: 'select',
      filterOptions: [...new Set(cotizaciones.map((c) => c.ruta).filter(Boolean))]
        .sort()
        .map((r) => ({ value: r!, label: r! })),
    },
    { key: 'vendedor', label: 'Vendedor' },
    {
      key: 'productos',
      label: 'Productos',
      align: 'right',
      filterable: false,
      value: (r) => r.detalle.length,
      render: (r) => r.detalle.length,
    },
    { key: 'total', label: 'Total', align: 'right', filterable: false, render: (r) => soles(r.total) },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: Object.entries(ESTADO_COTIZACION).map(([value, e]) => ({ value, label: e.etiqueta })),
      render: (r) => (
        <div className="flex flex-col items-start gap-0.5">
          <Badge tone={ESTADO_COTIZACION[r.estado].tono}>{ESTADO_COTIZACION[r.estado].etiqueta}</Badge>
          {r.pedidoNumero && <span className="text-xs text-ink-soft">Pedido {r.pedidoNumero}</span>}
        </div>
      ),
    },
  ]

  const columnasLineas: DataTableColumn<LineaCotizacion>[] = [
    {
      key: 'producto',
      label: 'Producto',
      render: (l) => (
        <div className="flex flex-col">
          <span className="text-sm font-medium text-ink">{l.producto}</span>
          <span className="text-xs text-ink-soft">{l.codigo}</span>
        </div>
      ),
    },
    { key: 'presentacion', label: 'Presentación' },
    { key: 'cantidad', label: 'Cantidad', align: 'right', render: (l) => cantidad(l.cantidad) },
    { key: 'precioPresentacion', label: 'Precio', align: 'right', render: (l) => soles(l.precioPresentacion) },
    { key: 'subtotal', label: 'Subtotal', align: 'right', render: (l) => soles(l.subtotal) },
  ]

  return (
    <ListPage
      icon={<MessageSquareQuote size={20} />}
      title="Cotizaciones"
      description="Lo que los clientes mandan desde el portal. Atiéndela creando el pedido."
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard
            label="En espera"
            value={String(enEspera.length)}
            icon={<Clock size={18} />}
            tono={enEspera.length > 0 ? 'warning' : undefined}
            progreso={cotizaciones.length > 0 ? enEspera.length / cotizaciones.length : 0}
            accion={{ label: 'Ver', onClick: () => setEstadoFiltro('EN_ESPERA') }}
          />
          <StatCard
            label="Atendidas"
            value={String(contar('ATENDIDA'))}
            icon={<CircleCheck size={18} />}
            tono="success"
            progreso={cotizaciones.length > 0 ? contar('ATENDIDA') / cotizaciones.length : 0}
            accion={{ label: 'Ver', onClick: () => setEstadoFiltro('ATENDIDA') }}
          />
          <StatCard
            label="Descartadas o canceladas"
            value={String(contar('DESCARTADA') + contar('CANCELADA'))}
            icon={<XCircle size={18} />}
            accion={{ label: 'Ver todas', onClick: () => setEstadoFiltro('') }}
          />
        </>
      }
      columns={columnas}
      rows={visibles}
      cardIcon={FileText}
      searchPlaceholder="Buscar por número, cliente..."
      empty={
        cargando
          ? 'Cargando cotizaciones...'
          : estadoFiltro === 'EN_ESPERA'
            ? 'No hay cotizaciones esperando. Las que manden los clientes aparecen aquí solas.'
            : 'No hay cotizaciones con ese estado.'
      }
      rowActions={(row) => (
        <>
          <RowAction label={`Ver ${row.numero}`} tone="view" onClick={() => setDetalle(row)}>
            <FaEye size={15} />
          </RowAction>
          {row.estado === 'EN_ESPERA' && (
            <RowAction
              label={`Crear pedido con ${row.numero}`}
              tone="success"
              onClick={() => crearPedido(row)}
              sinPermiso={!puedeJalar}
            >
              <FaCartPlus size={15} />
            </RowAction>
          )}
          {row.estado === 'EN_ESPERA' && (
            <RowAction
              label={`Descartar ${row.numero}`}
              tone="danger"
              onClick={() => {
                setMotivo('')
                setDescartando(row)
              }}
              sinPermiso={!puedeDescartar}
            >
              <FaBan size={15} />
            </RowAction>
          )}
        </>
      )}
    >
      <Modal
        open={detalle !== null}
        onClose={() => setDetalle(null)}
        title={detalle ? `${detalle.numero} · ${detalle.cliente}` : ''}
        description={
          detalle
            ? `${fechaHora(detalle.fecha)}${detalle.vendedor ? ` · para ${detalle.vendedor}` : ''}`
            : undefined
        }
        size="lg"
        footer={
          detalle?.estado === 'EN_ESPERA' && puedeJalar ? (
            <>
              <Button variant="secondary" size="sm" onClick={() => setDetalle(null)}>
                Cerrar
              </Button>
              <Button size="sm" onClick={() => crearPedido(detalle)}>
                Crear pedido con esta cotización
              </Button>
            </>
          ) : undefined
        }
      >
        {detalle && (
          <div className="flex flex-col gap-3">
            <div className="flex flex-wrap items-center gap-2 text-sm">
              <Badge tone={ESTADO_COTIZACION[detalle.estado].tono}>{ESTADO_COTIZACION[detalle.estado].etiqueta}</Badge>
              {detalle.pedidoNumero && <span className="text-ink-muted">Se atendió con el pedido {detalle.pedidoNumero}</span>}
              {detalle.cerradaPor && <span className="text-ink-muted">· {detalle.cerradaPor}</span>}
            </div>
            {detalle.nota && (
              <p className="rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-900">
                <span className="font-semibold">Nota del cliente: </span>
                {detalle.nota}
              </p>
            )}
            {detalle.motivoDescarte && (
              <p className="rounded-lg bg-rose-50 px-3 py-2 text-sm text-rose-800">
                <span className="font-semibold">Motivo del descarte: </span>
                {detalle.motivoDescarte}
              </p>
            )}
            <SysDataTable<LineaCotizacion>
              columns={columnasLineas}
              rows={detalle.detalle}
              rowKey="id"
              toolbar={false}
              paginacion={false}
            />
            <p className="text-right text-sm text-ink-muted">
              Total referencial <span className="ml-2 text-lg font-bold text-ink">{soles(detalle.total)}</span>
            </p>
          </div>
        )}
      </Modal>

      <Modal
        open={descartando !== null}
        onClose={() => setDescartando(null)}
        title={descartando ? `Descartar ${descartando.numero}` : ''}
        description={descartando ? `${descartando.cliente} verá el motivo en su portal.` : undefined}
        size="md"
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setDescartando(null)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void descartar()}>
              Descartar
            </Button>
          </>
        }
      >
        <Input
          label="Motivo"
          value={motivo}
          onChange={(e) => setMotivo(e.target.value.slice(0, 250))}
          placeholder="Sin stock esta semana"
          autoFocus
        />
      </Modal>
    </ListPage>
  )
}
