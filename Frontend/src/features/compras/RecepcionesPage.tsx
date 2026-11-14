import { useCallback, useEffect, useState } from 'react'
import { fechaCorta } from '../../lib/fechas'
import { PackageCheck, Plus, Undo2 } from 'lucide-react'
import { FaEye, FaRotateLeft } from 'react-icons/fa6'
import {
  AccionPdf,
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
  useToast,
} from '../../components/ui'
import type { ColumnaDetalleProducto, ConsultaTabla, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { almacenApi, recepcionApi } from '../inventario'
import type {
  AlmacenOpcion,
  DocumentoInventarioResponse,
  LineaDocumentoResponse,
  ResumenDocumentos,
} from '../inventario'
import { compraApi } from './comprasApi'
import type { CompraResponse } from './comprasApi'
import { NuevaRecepcionModal } from './NuevaRecepcionModal'

import { opcional } from '../../lib/apoyo'
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
  const { puede } = usePermisos()
  const toast = useToast()
  const [recepciones, setRecepciones] = useState<DocumentoInventarioResponse[]>([])
  const [compras, setCompras] = useState<CompraResponse[]>([])
  // Aparte de las abiertas (para elegir en "Nueva recepción"), el filtro del
  // panel necesita los números de TODAS las compras con alguna recepción,
  // también las ya recibidas enteras. Solo los números, no las compras.
  const [comprasConRecepcion, setComprasConRecepcion] = useState<string[]>([])
  const [almacenes, setAlmacenes] = useState<AlmacenOpcion[]>([])
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
      const [res, abiertas, numeros, alms] = await Promise.all([
        recepcionApi.resumen(),
        opcional(compraApi.abiertas(), []),
        opcional(compraApi.conRecepcion(), []),
        opcional(almacenApi.opciones(), []),
      ])
      setResumen(res)
      setCompras(abiertas)
      setComprasConRecepcion(numeros)
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
          toast.exito(`${doc.numero} anulada`)
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos anular la recepción.')
        }
      },
    })

  const columns: DataTableColumn<DocumentoInventarioResponse>[] = [
    // El número se busca con el buscador de arriba, no en el panel.
    { key: 'numero', label: 'Número', filterable: false, render: (row) => <Badge>{row.numero}</Badge> },
    {
      key: 'fecha',
      label: 'Fecha',
      filterType: 'date',
      render: (row) => fechaCorta(row.fecha),
    },
    {
      key: 'compra',
      label: 'Compra',
      filterType: 'select',
      filterOptions: comprasConRecepcion.map((n) => ({ value: n, label: n })),
      render: (row) => row.compra ?? '—',
    },
    {
      key: 'almacen',
      label: 'Almacén',
      filterType: 'select',
      filterOptions: almacenes.map((a) => ({ value: a.nombre, label: a.nombre })),
    },
    /*
     * Ni el conteo de productos ni el valor entran al panel: el unico control
     * es un buscador de texto, y "9" contra "S/ 9.00" no encuentra lo que la
     * persona espera.
     */
    { key: 'lineas', label: 'Productos', align: 'right', filterable: false },
    {
      key: 'total',
      label: 'Valor',
      align: 'right',
      filterable: false,
      render: (row) => `S/ ${row.total.toFixed(2)}`,
    },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'CONFIRMADO', label: 'Confirmada' },
        { value: 'ANULADO', label: 'Anulada' },
      ],
      render: (row) => estadoRecepcionBadge(row),
    },
  ]

  const total = resumen?.total ?? 0
  const confirmadas = resumen?.confirmados ?? 0
  const anuladas = resumen?.anulados ?? 0

  // Las tarjetas llevan a lo que cuentan: "Ver las 12" pone ese filtro en la columna Estado.
  const [filtroPedido, setFiltroPedido] = useState<{ column: string; value: string; vez: number }>()
  const verEstado = (value: string) =>
    setFiltroPedido((f) => ({ column: 'estado', value, vez: (f?.vez ?? 0) + 1 }))

  const comprasParaRecibir = compras.filter(
    (c) => c.estado === 'PENDIENTE' || c.estado === 'RECIBIDA_PARCIAL',
  )

  return (
    <ListPage
      icon={<PackageCheck size={20} />}
      title="Recepciones"
      description="Mercadería que llegó de una compra."
      actions={
        <Button
          size="sm"
          onClick={() => setNuevaAbierta(true)}
          disabled={!cargando && comprasParaRecibir.length === 0}
          iconRight={<Plus size={15} />}
          sinPermiso={!puede('compras.recepciones', 'crear')}>
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
          <StatCard
            label="Recepciones"
            value={String(total)}
            icon={<PackageCheck size={18} />}
            progreso={total > 0 ? 1 : 0}
            accion={{ label: 'Ver todas', onClick: () => verEstado('') }}
          />
          <StatCard
            label="Confirmadas"
            value={String(confirmadas)}
            icon={<PackageCheck size={18} />}
            tono="success"
            progreso={total > 0 ? confirmadas / total : 0}
            accion={{
              label: confirmadas > 0 ? `Ver las ${confirmadas}` : 'Ver',
              onClick: () => verEstado('CONFIRMADO'),
            }}
          />
          <StatCard
            label="Anuladas"
            value={String(anuladas)}
            icon={<Undo2 size={18} />}
            tono="neutral"
            progreso={total > 0 ? anuladas / total : 0}
            accion={{ label: anuladas > 0 ? `Ver las ${anuladas}` : 'Ver', onClick: () => verEstado('ANULADO') }}
          />
        </>
      }
      filtroPedido={filtroPedido}
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
            <FaEye size={15} />
          </RowAction>
          {puede('compras.recepciones', 'exportar') && (
            <AccionPdf documento="recepciones" id={row.id} numero={row.numero} />
          )}
          <RowAction
            label={`Anular ${row.numero}`}
            tone="danger"
            disabled={row.estado !== 'CONFIRMADO'}
            disabledReason="Ya está anulada"
            onClick={() => anular(row)}
            sinPermiso={!puede('compras.recepciones', 'anular')}>
            <FaRotateLeft size={15} />
          </RowAction>
        </>
      )}
    >
      <Modal
        open={detalleAbierto !== null}
        title={detalleAbierto ? `${detalleAbierto.numero} · ${detalleAbierto.compra ?? ''}` : ''}
        description={
          detalleAbierto
            ? `Emisión ${fechaCorta(detalleAbierto.fecha)} · ${detalleAbierto.almacen}`
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
