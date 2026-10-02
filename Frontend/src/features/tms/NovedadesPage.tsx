import { useCallback, useEffect, useState } from 'react'
import {
  AlertTriangle,
  CheckCircle2,
  ClipboardCheck,
  Eye,
  FileText,
  PackageX,
  RotateCcw,
  Wallet,
} from 'lucide-react'
import {
  Alert,
  Badge,
  BotonMas,
  Button,
  Desplegable,
  Input,
  ListPage,
  Modal,
  RowAction,
  StatCard,
  useConfirmacion,
  useToast,
  VisorReportePdf,
} from '../../components/ui'
import type { ConsultaTabla, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { novedadApi, textoCantidad } from './novedadApi'
import { resultadoRevisionApi } from './motivoNovedadApi'
import type { ResultadoRevisionOpcion } from './motivoNovedadApi'
import { ResultadoRevisionModal } from './ResultadoRevisionModal'
import type { EstadoNovedad, NovedadOpciones, NovedadResponse, ResumenNovedades } from './novedadApi'
import { almacenApi } from '../inventario'
import type { AlmacenOpcion } from '../inventario'
import { recojoApi } from '../facturacion/ventasApi'
import type { RecojoPendiente } from '../facturacion/ventasApi'

const ESTADOS: Record<EstadoNovedad, { texto: string; tono: 'warning' | 'success' | 'danger' | 'neutral' }> = {
  PENDIENTE: { texto: 'Por revisar', tono: 'warning' },
  RECIBIDA: { texto: 'Recibida', tono: 'success' },
  FALTANTE: { texto: 'Faltante', tono: 'danger' },
  SIN_RETORNO: { texto: 'Sin retorno', tono: 'neutral' },
  ANULADA: { texto: 'Anulada', tono: 'neutral' },
}

const opcionesDe = (valores: string[]) => valores.map((v) => ({ value: v, label: v }))

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
  const [opciones, setOpciones] = useState<NovedadOpciones>({
    productos: [],
    pedidos: [],
    clientes: [],
    despachos: [],
    motivos: [],
  })
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [consulta, setConsulta] = useState<ConsultaTabla | null>(null)
  const [total, setTotal] = useState(0)

  const [detalle, setDetalle] = useState<NovedadResponse | null>(null)
  const [revisando, setRevisando] = useState<NovedadResponse | null>(null)
  const [reporteAbierto, setReporteAbierto] = useState(false)

  // Los recojos van en la misma tabla: al verificarlos se elige el almacén.
  const [almacenes, setAlmacenes] = useState<AlmacenOpcion[]>([])
  const [verificandoRecojo, setVerificandoRecojo] = useState<RecojoPendiente | null>(null)

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
      // Solo lo que de verdad aparece en alguna novedad: los filtros son listas
      // para elegir, no cajas de búsqueda.
      setOpciones(await novedadApi.opciones())
    } catch {
      /* sin opciones el listado igual sirve; solo faltan las listas */
    }
    try {
      setAlmacenes((await almacenApi.opciones()).filter((a) => a.activo))
    } catch {
      /* sin almacenes no se puede verificar, pero el resto de la pantalla sirve */
    }
  }, [])

  const cargar = useCallback(async () => {
    await Promise.all([consulta ? cargarPagina(consulta) : Promise.resolve(), cargarApoyo()])
  }, [consulta, cargarPagina, cargarApoyo])

  useEffect(() => {
    void cargarApoyo()
  }, [cargarApoyo])

  useRealtime(['novedades', 'pedidos', 'notasventa'], cargar)

  /*
   * El reporte en PDF sale con lo mismo que muestra la tabla: la búsqueda, los
   * filtros y el orden. Viajan como el JSON de la consulta en un solo
   * parámetro; la página no, porque el papel es todo lo que ve el filtro.
   */
  const rutaReporte = () => {
    const c = {
      buscar: consulta?.buscar ?? '',
      orden: consulta?.orden ?? null,
      sentido: consulta?.sentido ?? null,
      filtros: consulta?.filtros ?? [],
    }
    return `/novedad/pdf?consulta=${encodeURIComponent(JSON.stringify(c))}`
  }

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
      filterType: 'select',
      filterOptions: opcionesDe(opciones.productos),
      render: (row) => (
        <span className="flex flex-col">
          <span className="font-semibold text-ink">{row.producto}</span>
          <span className="text-xs text-ink-soft">{row.codigo}</span>
        </span>
      ),
    },
    {
      // Lo que vuelve en el camión, dicho como se cuenta: "9 Caja + 5 UND".
      // En un recojo es lo que se recogió.
      key: 'cantidadNoEntregada',
      label: 'Cantidad',
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
      filterOptions: opcionesDe(opciones.motivos),
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
        { value: 'RECOJO', label: 'Recojo' },
      ],
      render: (row) => <TipoBadge tipo={row.tipo} />,
    },
    { key: 'pedido', label: 'Pedido', filterType: 'select', filterOptions: opcionesDe(opciones.pedidos) },
    { key: 'cliente', label: 'Cliente', filterType: 'select', filterOptions: opcionesDe(opciones.clientes) },
    {
      key: 'despacho',
      label: 'Despacho',
      filterType: 'select',
      filterOptions: opcionesDe(opciones.despachos),
      render: (row) => row.despacho ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: (Object.keys(ESTADOS) as EstadoNovedad[]).map((e) => ({ value: e, label: ESTADOS[e].texto })),
      render: (row) => (
        <div>
          <Badge tone={ESTADOS[row.estado].tono}>{ESTADOS[row.estado].texto}</Badge>
          {row.resultado && <div className="mt-0.5 text-xs text-ink-soft">{row.resultado}</div>}
        </div>
      ),
    },
  ]

  return (
    <div className="space-y-5">
      <ListPage
      icon={<PackageX size={20} />}
      title="Novedades de entrega"
      description="Lo que no llegó al cliente y lo que el repartidor recogió de otras ventas. Cuando la mercadería vuelve en el camión, aquí se cuenta y entra al almacén."
      actions={
        puede('tms.novedades', 'exportar') ? (
          <Button
            size="sm"
            variant="secondary"
            iconRight={<FileText size={15} />}
            onClick={() => setReporteAbierto(true)}
          >
            Reporte PDF
          </Button>
        ) : undefined
      }
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
      rows={novedades.map((n) => ({ ...n, clave: `${n.tipo}-${n.id}` }))}
      rowKey="clave"
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
          {/* Un recojo se verifica eligiendo a qué almacén entra; no se reabre. */}
          {row.tipo === 'RECOJO' ? (
            puede('tms.novedades', 'confirmar') &&
            row.estado === 'PENDIENTE' && (
              <RowAction
                tone="success"
                label={`Verificar el recojo de ${row.producto}`}
                onClick={() => setVerificandoRecojo(comoRecojo(row))}
              >
                <ClipboardCheck size={15} />
              </RowAction>
            )
          ) : (
          <>
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
        </>
      )}
    >
      <DetalleNovedad novedad={detalle} onClose={() => setDetalle(null)} />

      {/* Se monta solo al abrir, con los filtros que hay en ese momento. */}
      {reporteAbierto && (
        <VisorReportePdf
          ruta={rutaReporte()}
          titulo="Reporte de novedades de entrega"
          nombreArchivo="novedades.pdf"
          onCerrar={() => setReporteAbierto(false)}
        />
      )}

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

      <VerificarRecojoModal
        recojo={verificandoRecojo}
        almacenes={almacenes}
        onClose={() => setVerificandoRecojo(null)}
        onHecho={() => {
          setVerificandoRecojo(null)
          void cargar()
          toast.exito('Recojo verificado')
        }}
      />
    </div>
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

/** Qué pasó con la mercadería: entregada en menos, pedido sin entregar o recojo. */
function TipoBadge({ tipo }: { tipo: NovedadResponse['tipo'] }) {
  if (tipo === 'PEDIDO') return <Badge tone="danger">Pedido sin entregar</Badge>
  if (tipo === 'RECOJO') return <Badge tone="sys">Recojo</Badge>
  return <Badge tone="warning">Entregado en menos</Badge>
}

/** Un recojo de la tabla, con lo que pide el modal para verificarlo. */
function comoRecojo(n: NovedadResponse): RecojoPendiente {
  return {
    id: n.id,
    fecha: n.fecha,
    notaVentaId: n.notaVentaId ?? 0,
    notaVenta: n.notaVenta ?? n.pedido,
    cliente: n.cliente,
    productoId: n.productoId,
    producto: n.producto,
    presentacion: n.presentacion,
    unidadBase: n.unidadBase,
    cantidadPresentacion: n.factor ? n.cantidadNoEntregada / n.factor : n.cantidadNoEntregada,
    motivo: n.motivo,
    observacion: n.observacion,
    usuario: n.usuario,
    importe: n.importe,
  }
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
            <TipoBadge tipo={n.tipo} />
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
                {n.resultado && <Dato etiqueta="Resultado" valor={n.resultado} />}
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
  const { puede } = usePermisos()
  // Los resultados los arma el dueño (Motivos de novedad → Resultados de revisión).
  const [resultados, setResultados] = useState<ResultadoRevisionOpcion[]>([])
  const [resultadoId, setResultadoId] = useState(0)
  const [creandoResultado, setCreandoResultado] = useState(false)
  const [regresada, setRegresada] = useState('0')
  const [observacion, setObservacion] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  const elegido = resultados.find((r) => r.id === resultadoId)
  // Si no volvió todo, se pregunta cuánto volvió.
  const pideCantidad = elegido !== undefined && !elegido.volvioTodo

  useEffect(() => {
    if (!n) return
    setRegresada('0')
    setObservacion('')
    setError('')
    resultadoRevisionApi
      .opciones()
      .then((lista) => {
        setResultados(lista)
        setResultadoId(lista[0]?.id ?? 0)
      })
      .catch((e) => setError(e instanceof ApiError ? e.message : 'No pudimos cargar los resultados.'))
  }, [n])

  const guardar = async () => {
    if (!n) return
    if (!resultadoId) return setError('Elige el resultado.')

    const volvio = Number(regresada === '' ? 0 : regresada)
    if (pideCantidad && (volvio < 0 || volvio >= n.cantidadNoEntregada)) {
      return setError(`Lo que volvió tiene que ser menos de ${n.cantidadNoEntregada} ${n.unidadBase}.`)
    }

    setGuardando(true)
    setError('')
    try {
      await novedadApi.verificar(n.id, {
        resultadoId,
        cantidadRegresada: pideCantidad ? volvio : null,
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

          {/* El + crea un resultado sin salir de la revisión. */}
          <Desplegable
            label="Resultado"
            hint={
              puede('tms.motivos', 'crear') ? (
                <BotonMas label="Nuevo resultado" onClick={() => setCreandoResultado(true)} />
              ) : undefined
            }
            value={resultadoId}
            onChange={(v) => {
              setResultadoId(Number(v))
              setError('')
            }}
            placeholder="Elige el resultado"
            options={resultados.map((r) => ({
              value: r.id,
              label: r.nombre,
              nota: r.descripcion ?? (r.volvioTodo ? 'Volvió todo' : 'Se pide cuánto volvió'),
            }))}
          />

          {pideCantidad && (
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

      <ResultadoRevisionModal
        abierto={creandoResultado}
        editando={null}
        onClose={() => setCreandoResultado(false)}
        onGuardado={async (nuevo) => {
          setCreandoResultado(false)
          // Ya queda elegido: para eso se creó.
          setResultados(await resultadoRevisionApi.opciones())
          setResultadoId(nuevo.id)
        }}
      />
    </Modal>
  )
}

/**
 * El encargado dice a qué almacén entra un recojo: recién ahí suma stock de
 * verdad. El repartidor no lo elige — por eso este paso vive aquí y no en la
 * conversión del pedido.
 */
function VerificarRecojoModal({
  recojo: r,
  almacenes,
  onClose,
  onHecho,
}: {
  recojo: RecojoPendiente | null
  almacenes: AlmacenOpcion[]
  onClose: () => void
  onHecho: () => void
}) {
  const [almacenId, setAlmacenId] = useState(0)
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!r) return
    setAlmacenId(almacenes.find((a) => a.esPrincipal)?.id ?? almacenes[0]?.id ?? 0)
    setError('')
  }, [r, almacenes])

  const guardar = async () => {
    if (!r) return
    if (!almacenId) return setError('Elige el almacén.')

    setGuardando(true)
    setError('')
    try {
      await recojoApi.verificar(r.id, { almacenId })
      onHecho()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos verificar el recojo.')
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal
      open={r !== null}
      size="sm"
      title={r ? `Verificar recojo de ${r.producto}` : ''}
      description={r ? `${r.notaVenta} · ${r.cliente}` : undefined}
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            Verificar
          </Button>
        </>
      }
    >
      {r && (
        <div className="flex flex-col gap-4">
          {error && <Alert>{error}</Alert>}

          <p className="text-sm text-ink-muted">
            <span className="font-semibold text-ink">
              {r.cantidadPresentacion} {r.presentacion ?? r.unidadBase}
            </span>{' '}
            de vuelta ({r.motivo}). ¿A qué almacén entra?
          </p>

          <Desplegable
            label="Almacén"
            value={almacenId}
            onChange={(v) => {
              setAlmacenId(Number(v))
              setError('')
            }}
            placeholder="Elige el almacén"
            options={almacenes.map((a) => ({ value: a.id, label: a.nombre }))}
          />
        </div>
      )}
    </Modal>
  )
}
