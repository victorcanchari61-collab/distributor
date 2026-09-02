import { useCallback, useEffect, useState } from 'react'
import { ClipboardCheck, ListChecks, Plus, Undo2 } from 'lucide-react'
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
  Tabs,
  TablaEditable,
  useConfirmacion,
} from '../../components/ui'
import type { ColumnaEditable, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { productoApi } from '../maestros'
import type { ProductoResponse } from '../maestros'
import { almacenApi, ajusteApi, motivoApi } from './inventarioApi'
import type {
  AlmacenResponse,
  DocumentoInventarioResponse,
  MotivoResponse,
} from './inventarioApi'
import { MotivosTabla } from './MotivosTabla'
import { useRealtime } from '../../lib/realtime'

type Pestana = 'ajustes' | 'motivos'

interface FilaAjuste {
  productoId: number
  presentacionId: number
  cantidad: string
  costo: string
}

const FILA_VACIA: FilaAjuste = { productoId: 0, presentacionId: 0, cantidad: '', costo: '' }

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

  const [abierto, setAbierto] = useState(false)
  const [detalleAbierto, setDetalleAbierto] = useState<DocumentoInventarioResponse | null>(null)
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const [cabecera, setCabecera] = useState({
    almacenId: 0,
    motivoId: 0,
    observacion: '',
    flete: '',
  })
  const [filas, setFilas] = useState<FilaAjuste[]>([{ ...FILA_VACIA }])

  const { confirmar, dialogo } = useConfirmacion()

  const motivosManuales = motivos.filter((m) => !m.delSistema && m.activo)
  const motivo = motivos.find((m) => m.id === cabecera.motivoId)

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [docs, alms, mots, prods] = await Promise.all([
        ajusteApi.getAll(),
        almacenApi.getAll(),
        motivoApi.getAll(),
        productoApi.getAll(),
      ])
      setDocumentos(docs)
      setAlmacenes(alms)
      setMotivos(mots)
      setProductos(prods.filter((p) => p.activo && p.controlaStock))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los ajustes.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['ajustes', 'motivos'], cargar)

  const abrirNuevo = () => {
    setCabecera({
      almacenId: almacenes.find((a) => a.esPrincipal)?.id ?? almacenes[0]?.id ?? 0,
      motivoId: motivosManuales[0]?.id ?? 0,
      observacion: '',
      flete: '',
    })
    setFilas([{ ...FILA_VACIA }])
    setErrorForm('')
    setAbierto(true)
  }

  const actualizarFila = (i: number, cambio: Partial<FilaAjuste>) =>
    setFilas((prev) => prev.map((f, idx) => (idx === i ? { ...f, ...cambio } : f)))

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
        })),
      })
      setAbierto(false)
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

  const columnasFilas: ColumnaEditable<FilaAjuste>[] = [
    {
      key: 'producto',
      label: 'Producto',
      render: (fila, i) => (
        <Desplegable
          value={fila.productoId}
          onChange={(v) => actualizarFila(i, { productoId: Number(v), presentacionId: 0 })}
          options={productos.map((p) => ({ value: p.id, label: p.nombre, detalle: p.codigo }))}
        />
      ),
    },
    {
      key: 'presentacion',
      label: 'Presentación',
      className: 'w-36',
      render: (fila, i) => {
        const producto = productos.find((p) => p.id === fila.productoId)
        const compras = producto?.presentaciones.filter((p) => p.activo) ?? []

        return (
          <Desplegable
            value={fila.presentacionId}
            onChange={(v) => actualizarFila(i, { presentacionId: Number(v) })}
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
      className: 'w-28',
      render: (fila, i) => (
        <Input
          type="number"
          step="0.0001"
          value={fila.cantidad}
          onChange={(e) => actualizarFila(i, { cantidad: e.target.value })}
        />
      ),
    },
    ...(motivo?.pideCosto
      ? [
          {
            key: 'costo',
            label: 'Costo',
            align: 'right' as const,
            className: 'w-32',
            render: (fila: FilaAjuste, i: number) => {
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
                  onChange={(e) => actualizarFila(i, { costo: e.target.value })}
                />
              )
            },
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
      render: (row) => (
        <Badge tone={row.estado === 'ANULADO' ? 'neutral' : 'success'}>
          {row.estado === 'ANULADO' ? `Anulado${row.anuladoPor ? ` (${row.anuladoPor})` : ''}` : 'Confirmado'}
        </Badge>
      ),
    },
  ]

  const cabeceraPestanas = (
    <Tabs
      className="mb-5"
      active={pestana}
      onChange={(id) => setPestana(id as Pestana)}
      items={[
        { id: 'ajustes', label: 'Ajustes', icon: <ClipboardCheck size={15} />, badge: documentos.length },
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
            value={String(documentos.length)}
            icon={<ClipboardCheck size={18} />}
          />
          <StatCard
            label="Confirmados"
            value={String(documentos.filter((d) => d.estado === 'CONFIRMADO').length)}
            icon={<ClipboardCheck size={18} />}
            tono="success"
          />
          <StatCard
            label="Anulados"
            value={String(documentos.filter((d) => d.estado === 'ANULADO').length)}
            icon={<Undo2 size={18} />}
            tono="neutral"
          />
        </>
      }
      columns={columns}
      rows={documentos}
      cardIcon={ClipboardCheck}
      searchPlaceholder="Buscar por número, almacén, motivo..."
      empty={cargando ? 'Cargando ajustes...' : 'Todavía no hay ajustes registrados.'}
      rowActions={(row) => (
        <>
          <RowAction
            label={`Ver ${row.numero}`}
            onClick={() => {
              // El listado no trae el detalle: se pide completo al abrir, para
              // no cargar las líneas de 300 documentos que nadie va a mirar.
              setDetalleAbierto(row)
              void ajusteApi.getById(row.id).then(setDetalleAbierto)
            }}
          >
            <ClipboardCheck size={15} />
          </RowAction>
          {row.estado === 'CONFIRMADO' && (
            <RowAction label={`Anular ${row.numero}`} tone="danger" onClick={() => anular(row)}>
              <Undo2 size={15} />
            </RowAction>
          )}
        </>
      )}
    >
      {/* Nuevo ajuste */}
      <Modal
        open={abierto}
        title="Nuevo ajuste de inventario"
        description="Registra qué cambió y por qué. Confirmado, no se edita: se anula con otro documento."
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              Registrar ajuste
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {errorForm && <Alert>{errorForm}</Alert>}

          <div className="grid gap-4 sm:grid-cols-2">
            <Desplegable
              label="Almacén"
              value={cabecera.almacenId}
              onChange={(v) => setCabecera({ ...cabecera, almacenId: Number(v) })}
              options={almacenes
                .filter((a) => a.activo)
                .map((a) => ({ value: a.id, label: a.nombre, detalle: a.codigo }))}
            />
            <Desplegable
              label="Motivo"
              value={cabecera.motivoId}
              onChange={(v) => setCabecera({ ...cabecera, motivoId: Number(v) })}
              options={motivosManuales.map((m) => ({
                value: m.id,
                label: m.nombre,
                nota: m.tipo === 'ENTRADA' ? 'suma stock' : 'resta stock',
              }))}
            />
          </div>

          <Input
            label="Observación"
            optional
            placeholder="Motivo del ajuste, referencia..."
            value={cabecera.observacion}
            onChange={(e) => setCabecera({ ...cabecera, observacion: e.target.value })}
          />

          {motivo?.pideCosto && (
            <Input
              label="Flete"
              optional
              type="number"
              step="0.01"
              hint={<span className="text-xs text-ink-soft">de toda la entrada, se reparte</span>}
              value={cabecera.flete}
              onChange={(e) => setCabecera({ ...cabecera, flete: e.target.value })}
            />
          )}

          <hr className="border-line" />

          <div className="flex items-center justify-between">
            <p className="text-sm font-semibold text-ink">Productos</p>
            <Button
              variant="secondary"
              size="sm"
              onClick={() => setFilas((f) => [...f, { ...FILA_VACIA }])}
            >
              <Plus size={14} />
              Agregar
            </Button>
          </div>

          <TablaEditable
            columnas={columnasFilas}
            filas={filas}
            onQuitar={(i) => setFilas((f) => f.filter((_, idx) => idx !== i))}
            quitarLabel={(fila) => {
              const producto = productos.find((p) => p.id === fila.productoId)
              return `Quitar ${producto?.nombre ?? 'línea'}`
            }}
          />
        </div>
      </Modal>

      {/* Ver detalle */}
      <Modal
        open={detalleAbierto !== null}
        title={detalleAbierto ? `${detalleAbierto.numero} · ${detalleAbierto.motivo}` : ''}
        description={detalleAbierto?.observacion ?? undefined}
        onClose={() => setDetalleAbierto(null)}
      >
        {detalleAbierto && (
          <ul className="flex flex-col gap-2">
            {detalleAbierto.detalle.map((l) => (
              <li
                key={l.id}
                className="flex items-center justify-between gap-3 rounded-field border border-line px-3 py-2"
              >
                <span>
                  <span className="font-medium text-ink">{l.producto}</span>
                  <span className="ml-2 text-xs text-ink-soft">
                    {l.presentacion
                      ? `${l.cantidadPresentacion} ${l.presentacion}`
                      : `${l.cantidad} ${l.unidadBase}`}
                  </span>
                </span>
                <span className="text-sm">
                  S/ {l.costoUnitario} × {l.unidadBase} = S/ {l.costoTotal.toFixed(2)}
                </span>
              </li>
            ))}
          </ul>
        )}
      </Modal>

      {dialogo}
      </ListPage>
    </>
  )
}
