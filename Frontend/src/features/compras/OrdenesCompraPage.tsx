import { useCallback, useEffect, useState } from 'react'
import {
  ArrowLeft,
  CheckCircle2,
  ClipboardList,
  Pencil,
  Plus,
  ShoppingBag,
  Undo2,
} from 'lucide-react'
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
import { ordenCompraApi } from './comprasApi'
import type { CrearOrdenCompraRequest, OrdenCompraResponse } from './comprasApi'

interface FilaOrden {
  productoId: number
  presentacionId: number
  cantidad: string
  costo: string
}

const FILA_VACIA: FilaOrden = { productoId: 0, presentacionId: 0, cantidad: '', costo: '' }

/**
 * Órdenes de compra: lo que se le pide a un proveedor, antes de que exista
 * compromiso firme.
 *
 * Crear y editar son una vista completa, no un modal: la cabecera más las
 * líneas de productos no entran cómodas en un cajón chico. Confirmar cierra
 * la orden y hace nacer la Compra correspondiente, visible en "Mis compras".
 */
export function OrdenesCompraPage() {
  const [vista, setVista] = useState<'lista' | 'form'>('lista')
  const [ordenes, setOrdenes] = useState<OrdenCompraResponse[]>([])
  const [proveedores, setProveedores] = useState<ProveedorResponse[]>([])
  const [productos, setProductos] = useState<ProductoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [editando, setEditando] = useState<OrdenCompraResponse | null>(null)
  const [detalleAbierto, setDetalleAbierto] = useState<OrdenCompraResponse | null>(null)
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const [proveedorId, setProveedorId] = useState(0)
  const [fechaEsperada, setFechaEsperada] = useState('')
  const [observacion, setObservacion] = useState('')
  const [filas, setFilas] = useState<FilaOrden[]>([{ ...FILA_VACIA }])

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [ords, provs, prods] = await Promise.all([
        ordenCompraApi.getAll(),
        proveedorApi.getAll(),
        productoApi.getAll(),
      ])
      setOrdenes(ords)
      setProveedores(provs.filter((p) => p.activo))
      setProductos(prods.filter((p) => p.activo && p.controlaStock))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las órdenes de compra.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('ordenescompra', cargar)

  const abrirNueva = () => {
    setEditando(null)
    setProveedorId(0)
    setFechaEsperada('')
    setObservacion('')
    setFilas([{ ...FILA_VACIA }])
    setErrorForm('')
    setVista('form')
  }

  const abrirEdicion = (orden: OrdenCompraResponse) => {
    setEditando(orden)
    setProveedorId(orden.proveedorId)
    setFechaEsperada(orden.fechaEsperada ? orden.fechaEsperada.slice(0, 10) : '')
    setObservacion(orden.observacion ?? '')
    setFilas(
      orden.detalle.map((l) => {
        const producto = productos.find((p) => p.id === l.productoId)
        const presentacion = producto?.presentaciones.find((p) => p.id === l.presentacionId)
        const factor = presentacion?.factor ?? 1

        return {
          productoId: l.productoId,
          presentacionId: l.presentacionId ?? 0,
          cantidad: String(l.cantidadPresentacion),
          costo: String(l.costoUnitario * factor),
        }
      }),
    )
    setErrorForm('')
    setVista('form')
  }

  const actualizarFila = (i: number, cambio: Partial<FilaOrden>) =>
    setFilas((prev) => prev.map((f, idx) => (idx === i ? { ...f, ...cambio } : f)))

  const guardar = async () => {
    if (!proveedorId) return setErrorForm('Elige el proveedor.')

    const validas = filas.filter((f) => f.productoId && f.cantidad && f.costo)
    if (validas.length === 0) return setErrorForm('Agrega al menos un producto con su costo.')

    const body: CrearOrdenCompraRequest = {
      proveedorId,
      fechaEsperada: fechaEsperada || null,
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
      if (editando) {
        await ordenCompraApi.update(editando.id, body)
      } else {
        await ordenCompraApi.create(body)
      }
      setVista('lista')
      await cargar()
    } catch (e) {
      setErrorForm(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos guardar la orden de compra.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const confirmarOrden = (orden: OrdenCompraResponse) =>
    confirmar({
      titulo: `Confirmar ${orden.numero}`,
      mensaje:
        'El proveedor aceptó despachar: la orden se cierra y aparece en "Mis compras" lista para recibir. No se puede deshacer.',
      confirmar: 'Confirmar',
      accion: async () => {
        setError('')
        try {
          await ordenCompraApi.confirmar(orden.id)
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos confirmar la orden.')
        }
      },
    })

  const anularOrden = (orden: OrdenCompraResponse) =>
    confirmar({
      titulo: `Anular ${orden.numero}`,
      mensaje: 'Se anula la orden. No se puede deshacer.',
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await ordenCompraApi.anular(orden.id)
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos anular la orden.')
        }
      },
    })

  const columnasFilas: ColumnaEditable<FilaOrden>[] = [
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
        const compras = producto?.presentaciones.filter((p) => p.esCompra && p.activo) ?? []

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

  const columns: DataTableColumn<OrdenCompraResponse>[] = [
    { key: 'numero', label: 'Número', render: (row) => <Badge>{row.numero}</Badge> },
    { key: 'proveedor', label: 'Proveedor' },
    { key: 'fecha', label: 'Fecha', render: (row) => new Date(row.fecha).toLocaleDateString('es-PE') },
    {
      key: 'fechaEsperada',
      label: 'Fecha esperada',
      render: (row) => (row.fechaEsperada ? new Date(row.fechaEsperada).toLocaleDateString('es-PE') : '—'),
    },
    { key: 'total', label: 'Total', align: 'right', render: (row) => `S/ ${row.total.toFixed(2)}` },
    {
      key: 'estado',
      label: 'Estado',
      render: (row) => (
        <Badge
          tone={
            row.estado === 'CONFIRMADA' ? 'success' : row.estado === 'ANULADA' ? 'neutral' : 'warning'
          }
        >
          {row.estado === 'CONFIRMADA' ? 'Confirmada' : row.estado === 'ANULADA' ? 'Anulada' : 'Pendiente'}
        </Badge>
      ),
    },
  ]

  if (vista === 'form') {
    return (
      <div className="space-y-5">
        <PageHeader
          icon={<ClipboardList size={20} />}
          title={editando ? `Editar ${editando.numero}` : 'Nueva orden de compra'}
          description="Lo que se le pide al proveedor. Mientras esté Pendiente se puede editar; al confirmarla, ya no."
          actions={
            <Button variant="secondary" size="sm" onClick={() => setVista('lista')}>
              <ArrowLeft size={15} />
              Volver
            </Button>
          }
        />

        {errorForm && <Alert>{errorForm}</Alert>}

        <PageSection title="Datos generales">
          <div className="grid gap-4 sm:grid-cols-2">
            <BuscadorCampo
              label="Proveedor"
              value={proveedorId || null}
              onChange={(id) => setProveedorId(id ?? 0)}
              opciones={opcionesProveedor}
              placeholder="Buscar proveedor..."
              vacio="Ningún proveedor coincide"
            />

            <Input
              label="Fecha esperada de entrega"
              optional
              type="date"
              value={fechaEsperada}
              onChange={(e) => setFechaEsperada(e.target.value)}
            />
          </div>

          <Input
            className="mt-4"
            label="Observación"
            optional
            placeholder="Condiciones, referencia..."
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
            {editando ? 'Guardar cambios' : 'Registrar orden'}
          </Button>
        </div>

        {dialogo}
      </div>
    )
  }

  return (
    <ListPage
      icon={<ClipboardList size={20} />}
      title="Órdenes de compra"
      description="Lo que se le pide a un proveedor. Al confirmarla nace la compra correspondiente."
      actions={
        <Button size="sm" onClick={abrirNueva} iconRight={<Plus size={15} />}>
          Nueva orden
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Órdenes" value={String(ordenes.length)} icon={<ClipboardList size={18} />} />
          <StatCard
            label="Pendientes"
            value={String(ordenes.filter((o) => o.estado === 'PENDIENTE').length)}
            icon={<ClipboardList size={18} />}
            tono="warning"
          />
          <StatCard
            label="Confirmadas"
            value={String(ordenes.filter((o) => o.estado === 'CONFIRMADA').length)}
            icon={<CheckCircle2 size={18} />}
            tono="success"
          />
        </>
      }
      columns={columns}
      rows={ordenes}
      cardIcon={ClipboardList}
      searchPlaceholder="Buscar por número, proveedor..."
      empty={cargando ? 'Cargando órdenes...' : 'Todavía no hay órdenes de compra registradas.'}
      rowActions={(row) => (
        <>
          <RowAction label={`Ver ${row.numero}`} onClick={() => setDetalleAbierto(row)}>
            <ClipboardList size={15} />
          </RowAction>
          {row.estado === 'PENDIENTE' && (
            <>
              <RowAction label={`Editar ${row.numero}`} onClick={() => abrirEdicion(row)}>
                <Pencil size={15} />
              </RowAction>
              <RowAction label={`Confirmar y convertir a compra ${row.numero}`} onClick={() => confirmarOrden(row)}>
                <ShoppingBag size={15} />
              </RowAction>
              <RowAction label={`Anular ${row.numero}`} tone="danger" onClick={() => anularOrden(row)}>
                <Undo2 size={15} />
              </RowAction>
            </>
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
  )
}
