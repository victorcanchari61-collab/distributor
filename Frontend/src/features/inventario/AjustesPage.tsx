import { useCallback, useEffect, useState } from 'react'
import { ArrowLeft, ClipboardCheck, Eye, ListChecks, Plus, Trash2, Undo2 } from 'lucide-react'
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
  ResumenDocumento,
  RowAction,
  StatCard,
  SysDataTable,
  TablaProductosDetalle,
  Tabs,
  useConfirmacion,
} from '../../components/ui'
import type {
  ColumnaDetalleProducto,
  ConsultaTabla,
  DataTableColumn,
  LineaProductoNueva,
} from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { productoApi } from '../maestros'
import type { ProductoResponse } from '../maestros'
import { almacenApi, ajusteApi, motivoApi, stockApi } from './inventarioApi'
import type {
  AlmacenResponse,
  DocumentoInventarioResponse,
  LineaDocumentoResponse,
  MotivoResponse,
  ResumenDocumentos,
} from './inventarioApi'
import { MotivosTabla } from './MotivosTabla'
import { useRealtime } from '../../lib/realtime'

type Pestana = 'ajustes' | 'motivos'

type FilaAjuste = LineaProductoNueva

function estadoDocumentoBadge(row: DocumentoInventarioResponse) {
  return (
    <Badge tone={row.estado === 'ANULADO' ? 'danger' : 'success'}>
      {row.estado === 'ANULADO' ? `Anulado${row.anuladoPor ? ` (${row.anuladoPor})` : ''}` : 'Confirmado'}
    </Badge>
  )
}

/**
 * Ajustes de inventario: el documento formal que mueve stock a mano.
 *
 * Solo ofrece motivos manuales (carga inicial, merma, sobrante...). Los del
 * sistema — venta, compra, sus anulaciones — los crea su propio documento, no
 * se eligen aquí: si se pudiera, el stock cambiaría sin que exista la
 * operación que lo explica.
 */
export function AjustesPage() {
  const [pestana, setPestana] = useState<Pestana>('ajustes')
  const [documentos, setDocumentos] = useState<DocumentoInventarioResponse[]>([])
  const [almacenes, setAlmacenes] = useState<AlmacenResponse[]>([])
  const [motivos, setMotivos] = useState<MotivoResponse[]>([])
  const [productos, setProductos] = useState<ProductoResponse[]>([])

  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [vista, setVista] = useState<'lista' | 'form'>('lista')
  const [detalleAbierto, setDetalleAbierto] = useState<DocumentoInventarioResponse | null>(null)
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const [cabecera, setCabecera] = useState({
    almacenId: 0,
    motivoId: 0,
    observacion: '',
    flete: '',
  })
  const [filas, setFilas] = useState<FilaAjuste[]>([])
  const [stockMap, setStockMap] = useState<Record<number, number>>({})

  const { confirmar, dialogo } = useConfirmacion()

  const motivosManuales = motivos.filter((m) => !m.delSistema && m.activo)
  const motivo = motivos.find((m) => m.id === cabecera.motivoId)

  /*
   * Los ajustes se acumulan con la operacion: la tabla pide su pagina y los
   * contadores salen del resumen.
   */
  const [consulta, setConsulta] = useState<ConsultaTabla | null>(null)
  const [totalRegistros, setTotalRegistros] = useState(0)
  const [resumen, setResumen] = useState<ResumenDocumentos | null>(null)

  const cargarPagina = useCallback(async (q: ConsultaTabla) => {
    setCargando(true)
    try {
      const pagina = await ajusteApi.listar(q)
      setDocumentos(pagina.items)
      setTotalRegistros(pagina.total)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los ajustes.')
    } finally {
      setCargando(false)
    }
  }, [])

  const cargarApoyo = useCallback(async () => {
    try {
      const [res, alms, mots, prods] = await Promise.all([
        ajusteApi.resumen(),
        almacenApi.getAll(),
        motivoApi.getAll(),
        productoApi.getAll(),
      ])
      setResumen(res)
      setAlmacenes(alms)
      setMotivos(mots)
      setProductos(prods.filter((p) => p.activo && p.controlaStock))
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

  useRealtime(['ajustes', 'motivos'], cargar)

  // Stock del almacén elegido, para mostrarlo mientras se arma cada línea.
  useEffect(() => {
    if (vista !== 'form' || !cabecera.almacenId) return
    let cancelado = false
    void stockApi.getAll(cabecera.almacenId).then((filas) => {
      if (!cancelado) setStockMap(Object.fromEntries(filas.map((f) => [f.productoId, f.disponible])))
    })
    return () => {
      cancelado = true
    }
  }, [vista, cabecera.almacenId])

  const abrirNuevo = () => {
    setCabecera({
      almacenId: almacenes.find((a) => a.esPrincipal)?.id ?? almacenes[0]?.id ?? 0,
      motivoId: motivosManuales[0]?.id ?? 0,
      observacion: '',
      flete: '',
    })
    setFilas([])
    setErrorForm('')
    setVista('form')
  }

  const actualizarFila = (id: string, cambio: Partial<FilaAjuste>) =>
    setFilas((prev) => prev.map((f) => (f.id === id ? { ...f, ...cambio } : f)))

  // Solo tiene sentido cuando el motivo declara costo: un ajuste de salida
  // (merma, faltante) no valoriza nada, así que no hay total que mostrar.
  const total = filas.reduce((n, f) => n + (Number(f.cantidad) || 0) * (Number(f.costo) || 0), 0)

  const guardar = async () => {
    if (!cabecera.almacenId) return setErrorForm('Elige el almacén.')
    if (!cabecera.motivoId) return setErrorForm('Elige el motivo.')

    const validas = filas.filter((f) => f.productoId && f.cantidad)
    if (validas.length === 0) return setErrorForm('Agrega al menos un producto.')

    setGuardando(true)
    setErrorForm('')
    try {
      await ajusteApi.create({
        almacenId: cabecera.almacenId,
        motivoId: cabecera.motivoId,
        observacion: cabecera.observacion.trim() || null,
        flete: Number(cabecera.flete || 0),
        detalle: validas.map((f) => ({
          productoId: f.productoId,
          presentacionId: f.presentacionId || null,
          cantidad: Number(f.cantidad),
          costoPresentacion: motivo?.pideCosto ? Number(f.costo || 0) : null,
          lote: motivo?.pideCosto ? f.lote.trim() || null : null,
          fechaVencimiento: motivo?.pideCosto ? f.fechaVencimiento || null : null,
        })),
      })
      setVista('lista')
      await cargar()
    } catch (e) {
      setErrorForm(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos registrar el ajuste.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const columnasFilas: DataTableColumn<FilaAjuste>[] = [
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
        const compras = producto?.presentaciones.filter((p) => p.activo) ?? []

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
    ...(motivo?.pideCosto
      ? [
          {
            key: 'costo',
            label: 'Costo',
            align: 'right' as const,
            value: (fila: FilaAjuste) => Number(fila.costo) || 0,
            render: (fila: FilaAjuste) => {
              const producto = productos.find((p) => p.id === fila.productoId)
              const compras = producto?.presentaciones.filter((p) => p.activo) ?? []
              const presentacion = compras.find((p) => p.id === fila.presentacionId)

              return (
                <Input
                  type="number"
                  step="0.01"
                  disabled={!producto}
                  placeholder={
                    producto?.costoReferencia
                      ? String(producto.costoReferencia * (presentacion?.factor ?? 1))
                      : '0.00'
                  }
                  value={fila.costo}
                  onChange={(e) => actualizarFila(fila.id, { costo: e.target.value })}
                />
              )
            },
          },
          {
            key: 'lote',
            label: 'Lote',
            render: (fila: FilaAjuste) => (
              <Input
                optional
                placeholder="Opcional"
                value={fila.lote}
                onChange={(e) => actualizarFila(fila.id, { lote: e.target.value })}
              />
            ),
          },
          {
            key: 'vencimiento',
            label: 'Vencimiento',
            render: (fila: FilaAjuste) => (
              <Input
                optional
                type="date"
                value={fila.fechaVencimiento}
                onChange={(e) => actualizarFila(fila.id, { fechaVencimiento: e.target.value })}
              />
            ),
          },
          {
            key: 'subtotal',
            label: 'Subtotal',
            align: 'right' as const,
            value: (fila: FilaAjuste) => (Number(fila.cantidad) || 0) * (Number(fila.costo) || 0),
            render: (fila: FilaAjuste) => `S/ ${((Number(fila.cantidad) || 0) * (Number(fila.costo) || 0)).toFixed(2)}`,
          },
        ]
      : []),
  ]

  const anular = (doc: DocumentoInventarioResponse) =>
    confirmar({
      titulo: `Anular ${doc.numero}`,
      mensaje:
        'Se crea un documento que revierte el movimiento; el original queda en el historial marcado como anulado. No se puede deshacer.',
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await ajusteApi.anular(doc.id)
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos anular el documento.')
        }
      },
    })

  const columns: DataTableColumn<DocumentoInventarioResponse>[] = [
    { key: 'numero', label: 'Número', render: (row) => <Badge>{row.numero}</Badge> },
    { key: 'fecha', label: 'Fecha', render: (row) => new Date(row.fecha).toLocaleDateString('es-PE') },
    { key: 'almacen', label: 'Almacén' },
    {
      key: 'motivo',
      label: 'Motivo',
      render: (row) => (
        <Badge tone={row.motivoTipo === 'ENTRADA' ? 'success' : 'warning'}>{row.motivo}</Badge>
      ),
    },
    { key: 'lineas', label: 'Productos', align: 'right' },
    {
      key: 'total',
      label: 'Total',
      align: 'right',
      render: (row) => `S/ ${row.total.toFixed(2)}`,
    },
    {
      key: 'estado',
      label: 'Estado',
      render: (row) => estadoDocumentoBadge(row),
    },
  ]

  const cabeceraPestanas = (
    <Tabs
      className="mb-5"
      active={pestana}
      onChange={(id) => setPestana(id as Pestana)}
      items={[
        { id: 'ajustes', label: 'Ajustes', icon: <ClipboardCheck size={15} />, badge: resumen?.total ?? 0 },
        {
          id: 'motivos',
          label: 'Motivos',
          icon: <ListChecks size={15} />,
          // Solo los manuales: los del sistema no se listan en esta pestaña.
          badge: motivos.filter((m) => !m.delSistema).length,
        },
      ]}
    />
  )

  if (pestana === 'motivos') {
    return (
      <>
        {cabeceraPestanas}
        <MotivosTabla motivos={motivos} onRecargar={cargar} />
      </>
    )
  }

  if (vista === 'form') {
    return (
      <div className="space-y-5">
        <PageHeader
          icon={<ClipboardCheck size={20} />}
          title="Nuevo ajuste de inventario"
          description="Registra qué cambió y por qué. Confirmado, no se edita: se anula con otro documento."
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
              pideCosto={motivo?.pideCosto ?? false}
              pideLote={motivo?.pideCosto ?? false}
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
            <PageSection title="Ajuste">
              <Desplegable
                label="Almacén"
                value={cabecera.almacenId}
                onChange={(v) => setCabecera({ ...cabecera, almacenId: Number(v) })}
                options={almacenes
                  .filter((a) => a.activo)
                  .map((a) => ({ value: a.id, label: a.nombre, detalle: a.codigo }))}
              />

              <Desplegable
                className="mt-4"
                label="Motivo"
                value={cabecera.motivoId}
                onChange={(v) => setCabecera({ ...cabecera, motivoId: Number(v) })}
                options={motivosManuales.map((m) => ({
                  value: m.id,
                  label: m.nombre,
                  nota: m.tipo === 'ENTRADA' ? 'suma stock' : 'resta stock',
                }))}
              />

              <Input
                className="mt-4"
                label="Observación"
                optional
                placeholder="Motivo del ajuste, referencia..."
                value={cabecera.observacion}
                onChange={(e) => setCabecera({ ...cabecera, observacion: e.target.value })}
              />

              {motivo?.pideCosto && (
                <Input
                  className="mt-4"
                  label="Flete"
                  optional
                  type="number"
                  step="0.01"
                  hint={<span className="text-xs text-ink-soft">de toda la entrada, se reparte</span>}
                  value={cabecera.flete}
                  onChange={(e) => setCabecera({ ...cabecera, flete: e.target.value })}
                />
              )}
            </PageSection>

            {motivo?.pideCosto && (
              <PageSection title="Resumen">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-semibold text-ink-soft uppercase tracking-wide">
                    Total del ajuste
                  </span>
                  <span className="text-xl font-bold text-[rgb(var(--sys-rgb))]">
                    S/ {total.toFixed(2)}
                  </span>
                </div>
              </PageSection>
            )}
          </div>
        </div>

        <div className="flex justify-end gap-2">
          <Button variant="secondary" size="sm" onClick={() => setVista('lista')}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            Registrar ajuste
          </Button>
        </div>

        {dialogo}
      </div>
    )
  }

  return (
    <>
      {cabeceraPestanas}
      <ListPage
      icon={<ClipboardCheck size={20} />}
      title="Ajustes de inventario"
      description="Carga inicial, mermas, sobrantes y faltantes. Ventas y compras generan su propio movimiento."
      actions={
        <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
          Nuevo ajuste
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard
            label="Documentos"
            value={String(resumen?.total ?? 0)}
            icon={<ClipboardCheck size={18} />}
          />
          <StatCard
            label="Confirmados"
            value={String(resumen?.confirmados ?? 0)}
            icon={<ClipboardCheck size={18} />}
            tono="success"
          />
          <StatCard
            label="Anulados"
            value={String(resumen?.anulados ?? 0)}
            icon={<Undo2 size={18} />}
            tono="neutral"
          />
        </>
      }
      columns={columns}
      rows={documentos}
      servidor={{
        total: totalRegistros,
        cargando,
        onConsulta: (q) => {
          setConsulta(q)
          void cargarPagina(q)
        },
      }}
      cardIcon={ClipboardCheck}
      searchPlaceholder="Buscar por número, almacén, motivo..."
      empty={cargando ? 'Cargando ajustes...' : 'Todavía no hay ajustes registrados.'}
      rowActions={(row) => (
        <>
          <RowAction
            label={`Ver ${row.numero}`}
            tone="view"
            onClick={() => {
              // El listado no trae el detalle: se pide completo al abrir, para
              // no cargar las líneas de 300 documentos que nadie va a mirar.
              setDetalleAbierto(row)
              void ajusteApi.getById(row.id).then(setDetalleAbierto)
            }}
          >
            <Eye size={15} />
          </RowAction>
          <RowAction
            label={`Anular ${row.numero}`}
            tone="danger"
            disabled={row.estado !== 'CONFIRMADO'}
            disabledReason="Ya está anulado"
            onClick={() => anular(row)}
          >
            <Undo2 size={15} />
          </RowAction>
        </>
      )}
    >
      {/* Ver detalle */}
      <Modal
        open={detalleAbierto !== null}
        title={detalleAbierto ? `${detalleAbierto.numero} · ${detalleAbierto.motivo}` : ''}
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
            {detalleAbierto.estado === 'ANULADO' && <div>{estadoDocumentoBadge(detalleAbierto)}</div>}

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

      {dialogo}
      </ListPage>
    </>
  )
}
