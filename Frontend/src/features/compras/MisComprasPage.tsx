import { useCallback, useEffect, useState } from 'react'
import { ArrowLeft, PackageCheck, Plus, ShoppingBag, Undo2 } from 'lucide-react'
import {
  Alert,
  Badge,
  BuscadorCampo,
  Button,
  Desplegable,
  Input,
  ListPage,
  Modal,
  PageHeader,
  PageSection,
  RowAction,
  StatCard,
  TablaEditable,
  useConfirmacion,
} from '../../components/ui'
import type { ColumnaEditable, DataTableColumn, OpcionBuscador } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { useRealtime } from '../../lib/realtime'
import { productoApi, proveedorApi } from '../maestros'
import type { ProductoResponse, ProveedorResponse } from '../maestros'
import { almacenApi } from '../inventario'
import type { AlmacenResponse } from '../inventario'
import { compraApi } from './comprasApi'
import type { CompraResponse, CrearCompraRequest } from './comprasApi'
import { NuevaRecepcionModal } from './NuevaRecepcionModal'

interface FilaCompra {
  productoId: number
  presentacionId: number
  cantidad: string
  costo: string
}

const FILA_VACIA: FilaCompra = { productoId: 0, presentacionId: 0, cantidad: '', costo: '' }

/**
 * Mis compras: lo que está listo para recibir, sea porque vino de confirmar
 * una orden o porque se registró directa (al contado, sin negociación
 * previa). Las dos terminan igual aquí.
 *
 * Crear una compra directa es una vista completa, igual que una orden.
 */
export function MisComprasPage() {
  const [vista, setVista] = useState<'lista' | 'form'>('lista')
  const [compras, setCompras] = useState<CompraResponse[]>([])
  const [proveedores, setProveedores] = useState<ProveedorResponse[]>([])
  const [productos, setProductos] = useState<ProductoResponse[]>([])
  const [almacenes, setAlmacenes] = useState<AlmacenResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [detalleAbierto, setDetalleAbierto] = useState<CompraResponse | null>(null)
  const [recepcionAbierta, setRecepcionAbierta] = useState<CompraResponse | null>(null)
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const [proveedorId, setProveedorId] = useState(0)
  const [observacion, setObservacion] = useState('')
  const [filas, setFilas] = useState<FilaCompra[]>([{ ...FILA_VACIA }])

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [comps, provs, prods, alms] = await Promise.all([
        compraApi.getAll(),
        proveedorApi.getAll(),
        productoApi.getAll(),
        almacenApi.getAll(),
      ])
      setCompras(comps)
      setProveedores(provs.filter((p) => p.activo))
      setProductos(prods.filter((p) => p.activo && p.controlaStock))
      setAlmacenes(alms)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las compras.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['compras', 'recepciones'], cargar)

  const abrirNueva = () => {
    setProveedorId(0)
    setObservacion('')
    setFilas([{ ...FILA_VACIA }])
    setErrorForm('')
    setVista('form')
  }

  const actualizarFila = (i: number, cambio: Partial<FilaCompra>) =>
    setFilas((prev) => prev.map((f, idx) => (idx === i ? { ...f, ...cambio } : f)))

  const guardar = async () => {
    if (!proveedorId) return setErrorForm('Elige el proveedor.')

    const validas = filas.filter((f) => f.productoId && f.cantidad && f.costo)
    if (validas.length === 0) return setErrorForm('Agrega al menos un producto con su costo.')

    const body: CrearCompraRequest = {
      proveedorId,
      observacion: observacion.trim() || null,
      detalle: validas.map((f) => ({
        productoId: f.productoId,
        presentacionId: f.presentacionId || null,
        cantidad: Number(f.cantidad),
        costoPresentacion: Number(f.costo),
      })),
    }

    setGuardando(true)
    setErrorForm('')
    try {
      await compraApi.create(body)
      setVista('lista')
      await cargar()
    } catch (e) {
      setErrorForm(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos registrar la compra.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const anularCompra = (compra: CompraResponse) =>
    confirmar({
      titulo: `Anular ${compra.numero}`,
      mensaje: 'Se anula la compra. No se puede deshacer.',
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await compraApi.anular(compra.id)
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos anular la compra.')
        }
      },
    })

  const columnasFilas: ColumnaEditable<FilaCompra>[] = [
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
      className: 'w-40',
      render: (fila, i) => {
        const producto = productos.find((p) => p.id === fila.productoId)
        const disponibles = producto?.presentaciones.filter((p) => p.esCompra && p.activo) ?? []

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
                    ...disponibles
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
    {
      key: 'costo',
      label: 'Costo pactado',
      align: 'right',
      className: 'w-36',
      render: (fila, i) => (
        <Input
          type="number"
          step="0.01"
          value={fila.costo}
          onChange={(e) => actualizarFila(i, { costo: e.target.value })}
        />
      ),
    },
  ]

  const opcionesProveedor: OpcionBuscador<number>[] = proveedores.map((p) => ({
    item: p.id,
    label: p.nombre,
    detalle: p.documento,
    nota: p.rubro ?? undefined,
  }))

  const columns: DataTableColumn<CompraResponse>[] = [
    { key: 'numero', label: 'Número', render: (row) => <Badge>{row.numero}</Badge> },
    { key: 'proveedor', label: 'Proveedor' },
    {
      key: 'ordenCompraNumero',
      label: 'Origen',
      render: (row) => (row.ordenCompraNumero ? row.ordenCompraNumero : 'Directa'),
    },
    { key: 'fecha', label: 'Fecha', render: (row) => new Date(row.fecha).toLocaleDateString('es-PE') },
    { key: 'total', label: 'Total', align: 'right', render: (row) => `S/ ${row.total.toFixed(2)}` },
    {
      key: 'estado',
      label: 'Estado',
      render: (row) => {
        const tono =
          row.estado === 'RECIBIDA_TOTAL'
            ? 'success'
            : row.estado === 'RECIBIDA_PARCIAL'
              ? 'warning'
              : row.estado === 'ANULADA'
                ? 'neutral'
                : 'warning'
        const texto =
          row.estado === 'RECIBIDA_TOTAL'
            ? 'Recibida'
            : row.estado === 'RECIBIDA_PARCIAL'
              ? 'Parcial'
              : row.estado === 'ANULADA'
                ? 'Anulada'
                : 'Pendiente'
        return <Badge tone={tono}>{texto}</Badge>
      },
    },
  ]

  const comprasParaRecibir = compras.filter(
    (c) => c.estado === 'PENDIENTE' || c.estado === 'RECIBIDA_PARCIAL',
  )

  if (vista === 'form') {
    return (
      <div className="space-y-5">
        <PageHeader
          icon={<ShoppingBag size={20} />}
          title="Nueva compra directa"
          description="Al contado, en el momento: sin pasar por una orden formal al proveedor primero."
          actions={
            <Button variant="secondary" size="sm" onClick={() => setVista('lista')}>
              <ArrowLeft size={15} />
              Volver
            </Button>
          }
        />

        {errorForm && <Alert>{errorForm}</Alert>}

        <PageSection title="Datos generales">
          <BuscadorCampo
            className="sm:w-1/2"
            label="Proveedor"
            value={proveedorId || null}
            onChange={(id) => setProveedorId(id ?? 0)}
            opciones={opcionesProveedor}
            placeholder="Buscar proveedor..."
            vacio="Ningún proveedor coincide"
          />

          <Input
            className="mt-4"
            label="Observación"
            optional
            placeholder="Guía, referencia..."
            value={observacion}
            onChange={(e) => setObservacion(e.target.value)}
          />
        </PageSection>

        <PageSection
          title="Productos"
          actions={
            <Button variant="secondary" size="sm" onClick={() => setFilas((f) => [...f, { ...FILA_VACIA }])}>
              <Plus size={14} />
              Agregar
            </Button>
          }
        >
          <TablaEditable
            columnas={columnasFilas}
            filas={filas}
            onQuitar={(i) => setFilas((f) => f.filter((_, idx) => idx !== i))}
            quitarLabel={(fila) => {
              const producto = productos.find((p) => p.id === fila.productoId)
              return `Quitar ${producto?.nombre ?? 'línea'}`
            }}
          />
        </PageSection>

        <div className="flex justify-end gap-2">
          <Button variant="secondary" size="sm" onClick={() => setVista('lista')}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            Registrar compra
          </Button>
        </div>

      </div>
    )
  }

  return (
    <ListPage
      icon={<ShoppingBag size={20} />}
      title="Mis compras"
      description="Listas para recibir: nacieron de confirmar una orden o se registraron directas."
      actions={
        <Button size="sm" onClick={abrirNueva} iconRight={<Plus size={15} />}>
          Nueva compra
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Compras" value={String(compras.length)} icon={<ShoppingBag size={18} />} />
          <StatCard
            label="Por recibir"
            value={String(comprasParaRecibir.length)}
            icon={<PackageCheck size={18} />}
            tono="warning"
          />
          <StatCard
            label="Recibidas"
            value={String(compras.filter((c) => c.estado === 'RECIBIDA_TOTAL').length)}
            icon={<PackageCheck size={18} />}
            tono="success"
          />
        </>
      }
      columns={columns}
      rows={compras}
      cardIcon={ShoppingBag}
      searchPlaceholder="Buscar por número, proveedor..."
      empty={cargando ? 'Cargando compras...' : 'Todavía no hay compras registradas.'}
      rowActions={(row) => (
        <>
          <RowAction label={`Ver ${row.numero}`} onClick={() => setDetalleAbierto(row)}>
            <ShoppingBag size={15} />
          </RowAction>
          {(row.estado === 'PENDIENTE' || row.estado === 'RECIBIDA_PARCIAL') && (
            <RowAction label={`Recibir ${row.numero}`} onClick={() => setRecepcionAbierta(row)}>
              <PackageCheck size={15} />
            </RowAction>
          )}
          {row.estado === 'PENDIENTE' && (
            <RowAction label={`Anular ${row.numero}`} tone="danger" onClick={() => anularCompra(row)}>
              <Undo2 size={15} />
            </RowAction>
          )}
        </>
      )}
    >
      <Modal
        open={detalleAbierto !== null}
        title={detalleAbierto ? `${detalleAbierto.numero} · ${detalleAbierto.proveedor}` : ''}
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
                    {l.presentacion ? `${l.cantidadPresentacion} ${l.presentacion}` : `${l.cantidad} ${l.unidadBase}`}
                    {' · '}
                    recibido {l.cantidadRecibida} de {l.cantidad} {l.unidadBase}
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

      <NuevaRecepcionModal
        open={recepcionAbierta !== null}
        onClose={() => setRecepcionAbierta(null)}
        compraFija={recepcionAbierta}
        compras={comprasParaRecibir}
        almacenes={almacenes}
        onCreada={() => void cargar()}
      />

      {dialogo}
    </ListPage>
  )
}
