import { useCallback, useEffect, useState } from 'react'
import { Eye, PackageCheck, Plus, Undo2 } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  ListPage,
  Modal,
  ResumenDocumento,
  RowAction,
  StatCard,
  TablaProductosDetalle,
  useConfirmacion,
} from '../../components/ui'
import type { ColumnaDetalleProducto, ConsultaTabla, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { useRealtime } from '../../lib/realtime'
import { almacenApi, recepcionApi } from '../inventario'
import type {
  AlmacenResponse,
  DocumentoInventarioResponse,
  LineaDocumentoResponse,
  ResumenDocumentos,
} from '../inventario'
import { compraApi } from './comprasApi'
import type { CompraResponse } from './comprasApi'
import { NuevaRecepcionModal } from './NuevaRecepcionModal'

function estadoRecepcionBadge(row: DocumentoInventarioResponse) {
  return (
    <Badge tone={row.estado === 'ANULADO' ? 'danger' : 'success'}>
      {row.estado === 'ANULADO' ? `Anulada${row.anuladoPor ? ` (${row.anuladoPor})` : ''}` : 'Confirmada'}
    </Badge>
  )
}

/**
 * Recepciones: mercadería que llegó contra una compra. El historial completo,
 * y el punto de entrada para registrar una nueva sin pasar por Mis compras.
 */
export function RecepcionesPage() {
  const [recepciones, setRecepciones] = useState<DocumentoInventarioResponse[]>([])
  const [compras, setCompras] = useState<CompraResponse[]>([])
  const [almacenes, setAlmacenes] = useState<AlmacenResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [detalleAbierto, setDetalleAbierto] = useState<DocumentoInventarioResponse | null>(null)
  const [nuevaAbierta, setNuevaAbierta] = useState(false)

  const { confirmar, dialogo } = useConfirmacion()

  /*
   * Las recepciones se acumulan con la operacion: la tabla pide su pagina.
   *
   * Las compras NO se paginan: alimentan el selector de "nueva recepcion", que
   * tiene que ver todas las que esperan mercaderia aunque esten lejos en el
   * listado. Se piden ya filtradas — son pocas por definicion.
   */
  const [consulta, setConsulta] = useState<ConsultaTabla | null>(null)
  const [totalRegistros, setTotalRegistros] = useState(0)
  const [resumen, setResumen] = useState<ResumenDocumentos | null>(null)

  const cargarPagina = useCallback(async (q: ConsultaTabla) => {
    setCargando(true)
    try {
      const pagina = await recepcionApi.listar(q)
      setRecepciones(pagina.items)
      setTotalRegistros(pagina.total)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las recepciones.')
    } finally {
      setCargando(false)
    }
  }, [])

  const cargarApoyo = useCallback(async () => {
    try {
      const [res, abiertas, alms] = await Promise.all([
        recepcionApi.resumen(),
        compraApi.abiertas(),
        almacenApi.getAll(),
      ])
      setResumen(res)
      setCompras(abiertas)
      setAlmacenes(alms)
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

  useRealtime(['recepciones', 'compras'], cargar)

  const anular = (doc: DocumentoInventarioResponse) =>
    confirmar({
      titulo: `Anular ${doc.numero}`,
      mensaje:
        'Devuelve la mercadería recibida y la compra vuelve a quedar pendiente por esa cantidad. No se puede deshacer.',
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await recepcionApi.anular(doc.id)
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos anular la recepción.')
        }
      },
    })

  const columns: DataTableColumn<DocumentoInventarioResponse>[] = [
    { key: 'numero', label: 'Número', render: (row) => <Badge>{row.numero}</Badge> },
    { key: 'fecha', label: 'Fecha', render: (row) => new Date(row.fecha).toLocaleDateString('es-PE') },
    { key: 'compra', label: 'Compra', render: (row) => row.compra ?? '—' },
    { key: 'almacen', label: 'Almacén' },
    { key: 'lineas', label: 'Productos', align: 'right' },
    { key: 'total', label: 'Valor', align: 'right', render: (row) => `S/ ${row.total.toFixed(2)}` },
    {
      key: 'estado',
      label: 'Estado',
      render: (row) => estadoRecepcionBadge(row),
    },
  ]

  const comprasParaRecibir = compras.filter(
    (c) => c.estado === 'PENDIENTE' || c.estado === 'RECIBIDA_PARCIAL',
  )

  return (
    <ListPage
      icon={<PackageCheck size={20} />}
      title="Recepciones"
      description="Mercadería que llegó contra una compra. Puede ser total o parcial."
      actions={
        <Button
          size="sm"
          onClick={() => setNuevaAbierta(true)}
          disabled={!cargando && comprasParaRecibir.length === 0}
          iconRight={<Plus size={15} />}
        >
          Nueva recepción
        </Button>
      }
      alert={
        error ? (
          <Alert>{error}</Alert>
        ) : !cargando && comprasParaRecibir.length === 0 ? (
          <Alert>No hay compras pendientes de recibir por ahora.</Alert>
        ) : undefined
      }
      stats={
        <>
          <StatCard label="Recepciones" value={String(resumen?.total ?? 0)} icon={<PackageCheck size={18} />} />
          <StatCard
            label="Confirmadas"
            value={String(resumen?.confirmados ?? 0)}
            icon={<PackageCheck size={18} />}
            tono="success"
          />
          <StatCard
            label="Anuladas"
            value={String(resumen?.anulados ?? 0)}
            icon={<Undo2 size={18} />}
            tono="neutral"
          />
        </>
      }
      columns={columns}
      rows={recepciones}
      servidor={{
        total: totalRegistros,
        cargando,
        onConsulta: (q) => {
          setConsulta(q)
          void cargarPagina(q)
        },
      }}
      cardIcon={PackageCheck}
      searchPlaceholder="Buscar por número, compra, almacén..."
      empty={cargando ? 'Cargando recepciones...' : 'Todavía no hay recepciones registradas.'}
      rowActions={(row) => (
        <>
          <RowAction
            label={`Ver ${row.numero}`}
            tone="view"
            onClick={() => {
              setDetalleAbierto(row)
              void recepcionApi.getById(row.id).then(setDetalleAbierto)
            }}
          >
            <Eye size={15} />
          </RowAction>
          <RowAction
            label={`Anular ${row.numero}`}
            tone="danger"
            disabled={row.estado !== 'CONFIRMADO'}
            disabledReason="Ya está anulada"
            onClick={() => anular(row)}
          >
            <Undo2 size={15} />
          </RowAction>
        </>
      )}
    >
      <Modal
        open={detalleAbierto !== null}
        title={detalleAbierto ? `${detalleAbierto.numero} · ${detalleAbierto.compra ?? ''}` : ''}
        description={
          detalleAbierto
            ? `Emisión ${new Date(detalleAbierto.fecha).toLocaleDateString('es-PE')} · ${detalleAbierto.almacen}`
            : undefined
        }
        onClose={() => setDetalleAbierto(null)}
        size="lg"
      >
        {detalleAbierto && (
          <div className="flex flex-col gap-3">
            {detalleAbierto.estado === 'ANULADO' && <div>{estadoRecepcionBadge(detalleAbierto)}</div>}

            <TablaProductosDetalle<LineaDocumentoResponse>
              filas={detalleAbierto.detalle}
              rowKey={(l) => l.id}
              titulo={(l) => l.producto}
              subtitulo={(l) => `${l.codigo} · ${l.presentacion ?? l.unidadBase}`}
              grupos={[
                [
                  { key: 'cant', label: 'Cant.', render: (l) => `${l.cantidadPresentacion}` },
                  { key: 'costo', label: 'Costo', render: (l) => `S/ ${l.costoUnitario.toFixed(2)}` },
                  { key: 'subtotal', label: 'Subtotal', render: (l) => `S/ ${l.costoTotal.toFixed(2)}` },
                ] satisfies ColumnaDetalleProducto<LineaDocumentoResponse>[],
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

      <NuevaRecepcionModal
        open={nuevaAbierta}
        onClose={() => setNuevaAbierta(false)}
        compras={comprasParaRecibir}
        almacenes={almacenes}
        onCreada={() => void cargar()}
      />

      {dialogo}
    </ListPage>
  )
}
