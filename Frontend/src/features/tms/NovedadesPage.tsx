import { useCallback, useEffect, useState } from 'react'
import { AlertTriangle, CheckCircle2, ClipboardCheck, Eye, PackageX, RotateCcw, Wallet } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Desplegable,
  Input,
  ListPage,
  Modal,
  RowAction,
  StatCard,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { ConsultaTabla, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { motivoNovedadApi } from './motivoNovedadApi'
import { novedadApi, textoCantidad } from './novedadApi'
import type { EstadoNovedad, NovedadResponse, ResumenNovedades } from './novedadApi'

const ESTADOS: Record<EstadoNovedad, { texto: string; tono: 'warning' | 'success' | 'danger' | 'neutral' }> = {
  PENDIENTE: { texto: 'Por revisar', tono: 'warning' },
  RECIBIDA: { texto: 'Recibida', tono: 'success' },
  FALTANTE: { texto: 'Faltante', tono: 'danger' },
  SIN_RETORNO: { texto: 'Sin retorno', tono: 'neutral' },
  ANULADA: { texto: 'Anulada', tono: 'neutral' },
}

const cantidadNoEntregada = (n: NovedadResponse) =>
  textoCantidad(n.cantidadNoEntregada, n.factor, n.presentacion, n.unidadBase)

/**
 * Novedades de entrega: lo que no llegó al cliente y por qué.
 *
 * Sale de dos lugares: un producto que se entregó en menos al convertir el
 * pedido en venta, o un pedido entero que no se pudo entregar. Cada fila trae
 * el motivo que eligió quien entregó.
 *
 * Cuando la mercadería viajaba en el camión, el encargado la cuenta al volver
 * y deja constancia: llegó completa, o faltó algo.
 */
export function NovedadesPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const [novedades, setNovedades] = useState<NovedadResponse[]>([])
  const [resumen, setResumen] = useState<ResumenNovedades | null>(null)
  const [motivos, setMotivos] = useState<string[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [consulta, setConsulta] = useState<ConsultaTabla | null>(null)
  const [total, setTotal] = useState(0)

  const [detalle, setDetalle] = useState<NovedadResponse | null>(null)
  const [revisando, setRevisando] = useState<NovedadResponse | null>(null)

  const { confirmar, dialogo } = useConfirmacion()

  const cargarPagina = useCallback(async (q: ConsultaTabla) => {
    setCargando(true)
    try {
      const pagina = await novedadApi.listar(q)
      setNovedades(pagina.items)
      setTotal(pagina.total)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las novedades.')
    } finally {
      setCargando(false)
    }
  }, [])

  /** Los contadores y los motivos para filtrar no cambian al paginar. */
  const cargarApoyo = useCallback(async () => {
    try {
      setResumen(await novedadApi.resumen())
    } catch {
      /* los contadores son un adorno: sin ellos la lista igual sirve */
    }
    try {
      // Todos, activos o no: una novedad vieja puede tener un motivo ya desactivado.
      const lista = await motivoNovedadApi.getAll().catch(() => motivoNovedadApi.opciones())
      setMotivos(lista.map((m) => m.nombre))
    } catch {
      setMotivos([])
    }
  }, [])

  const cargar = useCallback(async () => {
    await Promise.all([consulta ? cargarPagina(consulta) : Promise.resolve(), cargarApoyo()])
  }, [consulta, cargarPagina, cargarApoyo])

  useEffect(() => {
    void cargarApoyo()
  }, [cargarApoyo])

  useRealtime(['novedades', 'pedidos', 'notasventa'], cargar)

  const reabrir = (n: NovedadResponse) =>
    confirmar({
      titulo: `Reabrir la revisión de ${n.producto}`,
      mensaje: 'Se borra lo que se contó y vuelve a quedar por revisar.',
      confirmar: 'Reabrir',
      tono: 'warning',
      accion: async () => {
        setError('')
        try {
          await novedadApi.reabrir(n.id)
          await cargar()
          toast.exito('La novedad volvió a quedar por revisar')
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos reabrir la novedad.')
        }
      },
    })

  const columns: DataTableColumn<NovedadResponse>[] = [
    {
      key: 'fecha',
      label: 'Fecha',
      width: 110,
      filterType: 'date',
      render: (row) => fechaCorta(row.fecha),
    },
    {
      key: 'producto',
      label: 'Producto',
      render: (row) => (
        <span className="flex flex-col">
          <span className="font-semibold text-ink">{row.producto}</span>
          <span className="text-xs text-ink-soft">{row.codigo}</span>
        </span>
      ),
    },
    {
      // Lo que el cliente no recibió, dicho como se cuenta: "9 Caja + 5 UND".
      key: 'cantidadNoEntregada',
      label: 'No entregado',
      filterable: false,
      render: (row) => <span className="font-semibold text-ink">{cantidadNoEntregada(row)}</span>,
    },
    {
      key: 'importe',
      label: 'Importe',
      align: 'right',
      filterable: false,
      render: (row) => `S/ ${row.importe.toFixed(2)}`,
    },
    {
      key: 'motivo',
      label: 'Motivo',
      filterType: 'select',
      filterOptions: [...new Set(motivos)]
        .sort((a, b) => a.localeCompare(b, 'es'))
        .map((m) => ({ value: m, label: m })),
      render: (row) => (
        <span className="flex flex-col">
          <span className="text-ink">{row.motivo}</span>
          {row.observacion && <span className="text-xs text-ink-soft">{row.observacion}</span>}
        </span>
      ),
    },
    {
      key: 'tipo',
      label: 'Qué pasó',
      filterType: 'select',
      filterOptions: [
        { value: 'LINEA', label: 'Entregado en menos' },
        { value: 'PEDIDO', label: 'Pedido sin entregar' },
      ],
      render: (row) =>
        row.tipo === 'PEDIDO' ? <Badge tone="danger">Pedido sin entregar</Badge> : <Badge tone="warning">Entregado en menos</Badge>,
    },
    { key: 'pedido', label: 'Pedido' },
    { key: 'cliente', label: 'Cliente' },
    {
      key: 'despacho',
      label: 'Despacho',
      render: (row) => row.despacho ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: (Object.keys(ESTADOS) as EstadoNovedad[]).map((e) => ({ value: e, label: ESTADOS[e].texto })),
      render: (row) => <Badge tone={ESTADOS[row.estado].tono}>{ESTADOS[row.estado].texto}</Badge>,
    },
  ]

  return (
    <ListPage
      icon={<PackageX size={20} />}
      title="Novedades de entrega"
      description="Lo que no llegó al cliente y el motivo. Cuando la mercadería vuelve en el camión, aquí se cuenta y se deja constancia."
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard
            label="Por revisar"
            value={String(resumen?.porRevisar ?? 0)}
            icon={<ClipboardCheck size={18} />}
            tono="warning"
          />
          <StatCard
            label="Recibidas"
            value={String(resumen?.recibidas ?? 0)}
            icon={<CheckCircle2 size={18} />}
            tono="success"
          />
          <StatCard
            label="Faltantes"
            value={String(resumen?.faltantes ?? 0)}
            icon={<AlertTriangle size={18} />}
            tono="danger"
          />
          <StatCard label="No entregado" value={`S/ ${(resumen?.importe ?? 0).toFixed(2)}`} icon={<Wallet size={18} />} />
        </>
      }
      columns={columns}
      actionsWidth={130}
      rows={novedades}
      servidor={{
        total,
        cargando,
        onConsulta: (q) => {
          setConsulta(q)
          void cargarPagina(q)
        },
      }}
      cardIcon={PackageX}
      searchPlaceholder="Buscar por producto, pedido, cliente, motivo..."
      empty={cargando ? 'Cargando novedades...' : 'No hay novedades: todo lo que salió se entregó completo.'}
      rowActions={(row) => (
        <>
          <RowAction tone="view" label={`Ver la novedad de ${row.producto}`} onClick={() => setDetalle(row)}>
            <Eye size={15} />
          </RowAction>
          {puede('tms.novedades', 'confirmar') && row.estado === 'PENDIENTE' && (
            <RowAction tone="success" label={`Revisar ${row.producto}`} onClick={() => setRevisando(row)}>
              <ClipboardCheck size={15} />
            </RowAction>
          )}
          {puede('tms.novedades', 'confirmar') && (row.estado === 'RECIBIDA' || row.estado === 'FALTANTE') && (
            <RowAction tone="warning" label={`Reabrir la revisión de ${row.producto}`} onClick={() => reabrir(row)}>
              <RotateCcw size={15} />
            </RowAction>
          )}
        </>
      )}
    >
      <DetalleNovedad novedad={detalle} onClose={() => setDetalle(null)} />

      <RevisarModal
        novedad={revisando}
        onClose={() => setRevisando(null)}
        onHecho={() => {
          setRevisando(null)
          void cargar()
          toast.exito('Revisión guardada')
        }}
      />

      {dialogo}
    </ListPage>
  )
}

/** Una etiqueta con su valor en la ficha; "—" cuando no hay dato. */
function Dato({ etiqueta, valor }: { etiqueta: string; valor?: string | null }) {
  return (
    <div className="flex flex-col gap-0.5">
      <span className="text-[11px] font-semibold tracking-wide text-ink-soft uppercase">{etiqueta}</span>
      <span className="text-sm text-ink">{valor || '—'}</span>
    </div>
  )
}

function DetalleNovedad({ novedad: n, onClose }: { novedad: NovedadResponse | null; onClose: () => void }) {
  return (
    <Modal
      open={n !== null}
      size="lg"
      title={n ? n.producto : ''}
      description={n ? `${n.pedido} · ${n.cliente}` : undefined}
      onClose={onClose}
      footer={
        <Button variant="secondary" size="sm" onClick={onClose}>
          Cerrar
        </Button>
      }
    >
      {n && (
        <div className="flex flex-col gap-4">
          <div className="flex flex-wrap items-center gap-2">
            <Badge tone={ESTADOS[n.estado].tono}>{ESTADOS[n.estado].texto}</Badge>
            {n.tipo === 'PEDIDO' ? (
              <Badge tone="danger">Pedido sin entregar</Badge>
            ) : (
              <Badge tone="warning">Entregado en menos</Badge>
            )}
          </div>

          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
            <Dato etiqueta="Pedido" valor={textoCantidad(n.cantidadPedida, n.factor, n.presentacion, n.unidadBase)} />
            <Dato etiqueta="Se entregó" valor={textoCantidad(n.cantidadEntregada, n.factor, n.presentacion, n.unidadBase)} />
            <Dato etiqueta="No se entregó" valor={cantidadNoEntregada(n)} />
            <Dato etiqueta="Importe" valor={`S/ ${n.importe.toFixed(2)}`} />
            <Dato etiqueta="Motivo" valor={n.motivo} />
            <Dato
              etiqueta="La mercadería"
              valor={n.regresaAlAlmacen ? 'Viajó y vuelve al almacén' : 'Nunca salió del almacén'}
            />
            <Dato etiqueta="Despacho" valor={n.despacho} />
            <Dato etiqueta="Venta" valor={n.notaVenta} />
            <Dato etiqueta="Registrado" valor={`${fechaCorta(n.fecha)}${n.usuario ? ` · ${n.usuario}` : ''}`} />
          </div>

          {n.observacion && <Dato etiqueta="Observación de quien entregó" valor={n.observacion} />}

          {n.verificadoEn && (
            <div className="rounded-field border border-line p-3">
              <p className="mb-2 text-xs font-semibold tracking-wide text-ink-soft uppercase">Revisión del encargado</p>
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
                <Dato
                  etiqueta="Volvió"
                  valor={textoCantidad(n.cantidadRegresada ?? 0, n.factor, n.presentacion, n.unidadBase)}
                />
                <Dato
                  etiqueta="Faltó"
                  valor={textoCantidad(
                    Math.max(n.cantidadNoEntregada - (n.cantidadRegresada ?? 0), 0),
                    n.factor,
                    n.presentacion,
                    n.unidadBase,
                  )}
                />
                <Dato etiqueta="Revisó" valor={`${fechaCorta(n.verificadoEn)}${n.verificadoPor ? ` · ${n.verificadoPor}` : ''}`} />
              </div>
              {n.observacionVerificacion && (
                <div className="mt-3">
                  <Dato etiqueta="Observación" valor={n.observacionVerificacion} />
                </div>
              )}
            </div>
          )}
        </div>
      )}
    </Modal>
  )
}

/**
 * El encargado cuenta lo que volvió en el camión: llegó todo, o faltó algo.
 * Lo que no llegó queda como faltante — a cargo de quien lo llevó.
 */
function RevisarModal({
  novedad: n,
  onClose,
  onHecho,
}: {
  novedad: NovedadResponse | null
  onClose: () => void
  onHecho: () => void
}) {
  const [resultado, setResultado] = useState<'RECIBIDA' | 'FALTANTE'>('RECIBIDA')
  const [regresada, setRegresada] = useState('0')
  const [observacion, setObservacion] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!n) return
    setResultado('RECIBIDA')
    setRegresada('0')
    setObservacion('')
    setError('')
  }, [n])

  const guardar = async () => {
    if (!n) return

    const volvio = Number(regresada === '' ? 0 : regresada)
    if (resultado === 'FALTANTE' && (volvio < 0 || volvio >= n.cantidadNoEntregada)) {
      return setError(`Lo que volvió tiene que ser menos de ${n.cantidadNoEntregada} ${n.unidadBase}.`)
    }

    setGuardando(true)
    setError('')
    try {
      await novedadApi.verificar(n.id, {
        estado: resultado,
        cantidadRegresada: resultado === 'FALTANTE' ? volvio : null,
        observacion: observacion.trim() || null,
      })
      onHecho()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos guardar la revisión.')
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal
      open={n !== null}
      size="sm"
      title={n ? `Revisar ${n.producto}` : ''}
      description={n ? `${n.pedido} · ${n.cliente}` : undefined}
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            Guardar revisión
          </Button>
        </>
      }
    >
      {n && (
        <div className="flex flex-col gap-4">
          {error && <Alert>{error}</Alert>}

          <p className="text-sm text-ink-muted">
            No se entregó <span className="font-semibold text-ink">{cantidadNoEntregada(n)}</span> ({n.motivo}). ¿Qué
            encontraste al contar lo que volvió?
          </p>

          <Desplegable
            label="Resultado"
            value={resultado}
            onChange={(v) => {
              setResultado(v as 'RECIBIDA' | 'FALTANTE')
              setError('')
            }}
            options={[
              { value: 'RECIBIDA', label: 'Volvió completa', nota: 'Está de vuelta en el almacén' },
              { value: 'FALTANTE', label: 'Faltó algo', nota: 'No volvió todo lo que no se entregó' },
            ]}
          />

          {resultado === 'FALTANTE' && (
            <Input
              label={`Cuánto volvió (${n.unidadBase})`}
              type="number"
              min={0}
              step="any"
              value={regresada}
              onChange={(e) => {
                setRegresada(e.target.value)
                setError('')
              }}
            />
          )}

          <Input
            label="Observación"
            optional
            maxLength={250}
            value={observacion}
            onChange={(e) => setObservacion(e.target.value)}
          />
        </div>
      )}
    </Modal>
  )
}
