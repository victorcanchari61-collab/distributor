import { useCallback, useEffect, useState } from 'react'
import { ArrowRight, Plus, Trash2, Truck, Undo2 } from 'lucide-react'
import {
  AgregarProductoPanel,
  Alert,
  Badge,
  Button,
  Desplegable,
  Input,
  ListPage,
  Modal,
  RowAction,
  StatCard,
  SysDataTable,
  useConfirmacion,
} from '../../components/ui'
import type { DataTableColumn, LineaProductoNueva } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { productoApi } from '../maestros'
import type { ProductoResponse } from '../maestros'
import { almacenApi, stockApi, transferenciaApi } from './inventarioApi'
import type { AlmacenResponse, DocumentoInventarioResponse } from './inventarioApi'
import { useRealtime } from '../../lib/realtime'

type FilaTransferencia = LineaProductoNueva

/**
 * Transferencias entre dos almacenes propios.
 *
 * A diferencia de un ajuste, no se declara costo: la mercadería se lleva el
 * mismo costo con el que estaba en origen. Por dentro, cada línea sale de
 * origen (heredando el costo de las capas que consume) y crea en destino una
 * capa nueva por cada costo distinto que tocó, así que el costo nunca se
 * promedia ni se inventa.
 */
export function TransferenciasPage() {
  const [documentos, setDocumentos] = useState<DocumentoInventarioResponse[]>([])
  const [almacenes, setAlmacenes] = useState<AlmacenResponse[]>([])
  const [productos, setProductos] = useState<ProductoResponse[]>([])

  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [detalleAbierto, setDetalleAbierto] = useState<DocumentoInventarioResponse | null>(null)
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const [cabecera, setCabecera] = useState({
    almacenOrigenId: 0,
    almacenDestinoId: 0,
    observacion: '',
  })
  const [filas, setFilas] = useState<FilaTransferencia[]>([])
  const [stockMap, setStockMap] = useState<Record<number, number>>({})

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [docs, alms, prods] = await Promise.all([
        transferenciaApi.getAll(),
        almacenApi.getAll(),
        productoApi.getAll(),
      ])
      setDocumentos(docs)
      setAlmacenes(alms)
      setProductos(prods.filter((p) => p.activo && p.controlaStock))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las transferencias.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('transferencias', cargar)

  const activos = almacenes.filter((a) => a.activo)

  // Stock del almacén de origen, para mostrarlo mientras se arma cada línea.
  useEffect(() => {
    if (!abierto || !cabecera.almacenOrigenId) return
    let cancelado = false
    void stockApi.getAll(cabecera.almacenOrigenId).then((filas) => {
      if (!cancelado) setStockMap(Object.fromEntries(filas.map((f) => [f.productoId, f.stock])))
    })
    return () => {
      cancelado = true
    }
  }, [abierto, cabecera.almacenOrigenId])

  const abrirNuevo = () => {
    setCabecera({
      almacenOrigenId: activos.find((a) => a.esPrincipal)?.id ?? activos[0]?.id ?? 0,
      almacenDestinoId: 0,
      observacion: '',
    })
    setFilas([])
    setErrorForm('')
    setAbierto(true)
  }

  const actualizarFila = (id: string, cambio: Partial<FilaTransferencia>) =>
    setFilas((prev) => prev.map((f) => (f.id === id ? { ...f, ...cambio } : f)))

  const guardar = async () => {
    if (!cabecera.almacenOrigenId) return setErrorForm('Elige el almacén de origen.')
    if (!cabecera.almacenDestinoId) return setErrorForm('Elige el almacén de destino.')
    if (cabecera.almacenOrigenId === cabecera.almacenDestinoId) {
      return setErrorForm('El origen y el destino no pueden ser el mismo almacén.')
    }

    const validas = filas.filter((f) => f.productoId && f.cantidad)
    if (validas.length === 0) return setErrorForm('Agrega al menos un producto.')

    setGuardando(true)
    setErrorForm('')
    try {
      await transferenciaApi.create({
        almacenOrigenId: cabecera.almacenOrigenId,
        almacenDestinoId: cabecera.almacenDestinoId,
        observacion: cabecera.observacion.trim() || null,
        detalle: validas.map((f) => ({
          productoId: f.productoId,
          presentacionId: f.presentacionId || null,
          cantidad: Number(f.cantidad),
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
          : 'No pudimos registrar la transferencia.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const columnasFilas: DataTableColumn<FilaTransferencia>[] = [
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
        const presentaciones = producto?.presentaciones.filter((p) => p.activo) ?? []

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
                    ...presentaciones
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
  ]

  const anular = (doc: DocumentoInventarioResponse) =>
    confirmar({
      titulo: `Anular ${doc.numero}`,
      mensaje:
        'Devuelve la mercadería a origen y la retira de destino. Si ya se vendió algo de lo que llegó, no se podrá anular esa parte.',
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await transferenciaApi.anular(doc.id)
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos anular la transferencia.')
        }
      },
    })

  const columns: DataTableColumn<DocumentoInventarioResponse>[] = [
    { key: 'numero', label: 'Número', render: (row) => <Badge>{row.numero}</Badge> },
    {
      key: 'fecha',
      label: 'Fecha',
      render: (row) => new Date(row.fecha).toLocaleDateString('es-PE'),
    },
    {
      key: 'almacen',
      label: 'De → A',
      render: (row) => (
        <span className="flex items-center gap-1.5">
          {row.almacen}
          <ArrowRight size={13} className="text-ink-soft" />
          {row.almacenDestino}
        </span>
      ),
    },
    { key: 'lineas', label: 'Productos', align: 'right' },
    { key: 'total', label: 'Valor', align: 'right', render: (row) => `S/ ${row.total.toFixed(2)}` },
    {
      key: 'estado',
      label: 'Estado',
      render: (row) => (
        <Badge tone={row.estado === 'ANULADO' ? 'neutral' : 'success'}>
          {row.estado === 'ANULADO' ? `Anulada${row.anuladoPor ? ` (${row.anuladoPor})` : ''}` : 'Confirmada'}
        </Badge>
      ),
    },
  ]

  return (
    <ListPage
      icon={<Truck size={20} />}
      title="Transferencias"
      description="Mueve mercadería entre tus almacenes. El costo viaja con ella: no se vuelve a declarar."
      actions={
        <Button
          size="sm"
          onClick={abrirNuevo}
          disabled={activos.length < 2}
          iconRight={<Plus size={15} />}
        >
          Nueva transferencia
        </Button>
      }
      alert={
        error ? (
          <Alert>{error}</Alert>
        ) : activos.length < 2 ? (
          <Alert>Necesitas al menos dos almacenes activos para transferir.</Alert>
        ) : undefined
      }
      stats={
        <>
          <StatCard
            label="Transferencias"
            value={String(documentos.length)}
            icon={<Truck size={18} />}
          />
          <StatCard
            label="Confirmadas"
            value={String(documentos.filter((d) => d.estado === 'CONFIRMADO').length)}
            icon={<Truck size={18} />}
            tono="success"
          />
          <StatCard
            label="Anuladas"
            value={String(documentos.filter((d) => d.estado === 'ANULADO').length)}
            icon={<Undo2 size={18} />}
            tono="neutral"
          />
        </>
      }
      columns={columns}
      rows={documentos}
      cardIcon={Truck}
      searchPlaceholder="Buscar por número, almacén..."
      empty={cargando ? 'Cargando transferencias...' : 'Todavía no hay transferencias registradas.'}
      rowActions={(row) => (
        <>
          <RowAction
            label={`Ver ${row.numero}`}
            onClick={() => {
              // El listado no trae el detalle completo: se pide al abrir.
              setDetalleAbierto(row)
              void transferenciaApi.getById(row.id).then(setDetalleAbierto)
            }}
          >
            <Truck size={15} />
          </RowAction>
          {row.estado === 'CONFIRMADO' && (
            <RowAction label={`Anular ${row.numero}`} tone="danger" onClick={() => anular(row)}>
              <Undo2 size={15} />
            </RowAction>
          )}
        </>
      )}
    >
      {/* Nueva transferencia */}
      <Modal
        open={abierto}
        title="Nueva transferencia"
        description="Confirmada, no se edita: se anula con otro documento."
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              Registrar transferencia
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {errorForm && <Alert>{errorForm}</Alert>}

          <div className="grid gap-4 sm:grid-cols-2">
            <Desplegable
              label="Origen"
              value={cabecera.almacenOrigenId}
              onChange={(v) => setCabecera({ ...cabecera, almacenOrigenId: Number(v) })}
              options={activos.map((a) => ({ value: a.id, label: a.nombre, detalle: a.codigo }))}
            />
            <Desplegable
              label="Destino"
              value={cabecera.almacenDestinoId}
              onChange={(v) => setCabecera({ ...cabecera, almacenDestinoId: Number(v) })}
              options={activos
                .filter((a) => a.id !== cabecera.almacenOrigenId)
                .map((a) => ({ value: a.id, label: a.nombre, detalle: a.codigo }))}
            />
          </div>

          <Input
            label="Observación"
            optional
            placeholder="Motivo, guía de remisión..."
            value={cabecera.observacion}
            onChange={(e) => setCabecera({ ...cabecera, observacion: e.target.value })}
          />

          <hr className="border-line" />

          <p className="text-sm font-semibold text-ink">Agregar producto</p>
          <AgregarProductoPanel
            productos={productos}
            stock={stockMap}
            pideCosto={false}
            onAgregar={(linea) => setFilas((f) => [...f, linea])}
          />

          <hr className="border-line" />

          <div className="flex items-center justify-between">
            <p className="text-sm font-semibold text-ink">Productos</p>
            <span className="text-xs text-ink-soft">
              {filas.length} producto{filas.length === 1 ? '' : 's'} agregado{filas.length === 1 ? '' : 's'}
            </span>
          </div>

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
      </Modal>

      {/* Ver detalle */}
      <Modal
        open={detalleAbierto !== null}
        title={detalleAbierto?.numero ?? ''}
        description={
          detalleAbierto
            ? `${detalleAbierto.almacen} → ${detalleAbierto.almacenDestino}`
            : undefined
        }
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
                  <Badge tone={l.tipo === 'ENTRADA' ? 'success' : 'warning'}>
                    {l.tipo === 'ENTRADA' ? 'Entra' : 'Sale'}
                  </Badge>
                  <span className="ml-2 font-medium text-ink">{l.producto}</span>
                  <span className="ml-2 text-xs text-ink-soft">
                    {l.almacen} ·{' '}
                    {l.presentacion
                      ? `${l.cantidadPresentacion} ${l.presentacion}`
                      : `${l.cantidad} ${l.unidadBase}`}
                  </span>
                </span>
                <span className="text-sm">S/ {l.costoTotal.toFixed(2)}</span>
              </li>
            ))}
          </ul>
        )}
      </Modal>

      {dialogo}
    </ListPage>
  )
}
