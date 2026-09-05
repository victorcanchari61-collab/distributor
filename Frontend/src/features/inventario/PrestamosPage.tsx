import { useCallback, useEffect, useState } from 'react'
import { Eye, HandCoins, Plus, Trash2, Undo2 } from 'lucide-react'
import {
  AgregarProductoPanel,
  Alert,
  Badge,
  Button,
  Desplegable,
  Input,
  ListPage,
  Modal,
  ResumenDocumento,
  RowAction,
  StatCard,
  SysDataTable,
  TablaProductosDetalle,
} from '../../components/ui'
import type { ColumnaDetalleProducto, DataTableColumn, LineaProductoNueva } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { productoApi } from '../maestros'
import type { ProductoResponse } from '../maestros'
import { almacenApi, prestamoApi, stockApi } from './inventarioApi'
import type {
  AlmacenResponse,
  PrestamoDetalleResponse,
  PrestamoResponse,
  TipoPrestamo,
} from './inventarioApi'
import { useRealtime } from '../../lib/realtime'

type FilaPrestamo = LineaProductoNueva

function estadoPrestamoBadge(estado: PrestamoResponse['estado']) {
  return (
    <Badge tone={estado === 'DEVUELTO' ? 'neutral' : 'warning'}>
      {estado === 'DEVUELTO' ? 'Devuelto' : 'Pendiente'}
    </Badge>
  )
}

/**
 * Mercadería que sale o entra desde fuera de la empresa: se presta y se
 * espera de vuelta. La contraparte no es un almacén propio — es un tercero —
 * y por eso cada préstamo lleva quién es y si ya se devolvió.
 *
 * DADO: sale como cualquier salida, hereda el costo del stock que consume.
 * RECIBIDO: entra al costo de referencia del producto (o el que se indique),
 * porque no hay factura de compra detrás — es solo para no dejar el stock en
 * cero soles mientras está prestado.
 */
export function PrestamosPage() {
  const [prestamos, setPrestamos] = useState<PrestamoResponse[]>([])
  const [almacenes, setAlmacenes] = useState<AlmacenResponse[]>([])
  const [productos, setProductos] = useState<ProductoResponse[]>([])

  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [detalleAbierto, setDetalleAbierto] = useState<PrestamoResponse | null>(null)
  const [devolucionAbierta, setDevolucionAbierta] = useState<PrestamoResponse | null>(null)
  const [cantidadesDevolucion, setCantidadesDevolucion] = useState<Record<number, string>>({})
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const [cabecera, setCabecera] = useState({
    tipo: 'DADO' as TipoPrestamo,
    contraparte: '',
    almacenId: 0,
    observacion: '',
  })
  const [filas, setFilas] = useState<FilaPrestamo[]>([])
  const [stockMap, setStockMap] = useState<Record<number, number>>({})

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [prest, alms, prods] = await Promise.all([
        prestamoApi.getAll(),
        almacenApi.getAll(),
        productoApi.getAll(),
      ])
      setPrestamos(prest)
      setAlmacenes(alms)
      setProductos(prods.filter((p) => p.activo && p.controlaStock))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los préstamos.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('prestamos', cargar)

  const activos = almacenes.filter((a) => a.activo)

  // Stock del almacén elegido, para mostrarlo mientras se arma cada línea.
  useEffect(() => {
    if (!abierto || !cabecera.almacenId) return
    let cancelado = false
    void stockApi.getAll(cabecera.almacenId).then((filas) => {
      if (!cancelado) setStockMap(Object.fromEntries(filas.map((f) => [f.productoId, f.disponible])))
    })
    return () => {
      cancelado = true
    }
  }, [abierto, cabecera.almacenId])

  const abrirNuevo = () => {
    setCabecera({
      tipo: 'DADO',
      contraparte: '',
      almacenId: activos.find((a) => a.esPrincipal)?.id ?? activos[0]?.id ?? 0,
      observacion: '',
    })
    setFilas([])
    setErrorForm('')
    setAbierto(true)
  }

  const actualizarFila = (id: string, cambio: Partial<FilaPrestamo>) =>
    setFilas((prev) => prev.map((f) => (f.id === id ? { ...f, ...cambio } : f)))

  const guardar = async () => {
    if (!cabecera.contraparte.trim()) {
      return setErrorForm('Indica a quién le prestas o quién te presta.')
    }
    if (!cabecera.almacenId) return setErrorForm('Elige el almacén.')

    const validas = filas.filter((f) => f.productoId && f.cantidad)
    if (validas.length === 0) return setErrorForm('Agrega al menos un producto.')

    setGuardando(true)
    setErrorForm('')
    try {
      await prestamoApi.create({
        tipo: cabecera.tipo,
        contraparte: cabecera.contraparte.trim(),
        almacenId: cabecera.almacenId,
        observacion: cabecera.observacion.trim() || null,
        detalle: validas.map((f) => ({
          productoId: f.productoId,
          presentacionId: f.presentacionId || null,
          cantidad: Number(f.cantidad),
          costoPresentacion:
            cabecera.tipo === 'RECIBIDO' && f.costo ? Number(f.costo) : null,
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
          : 'No pudimos registrar el préstamo.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const abrirDevolucion = (p: PrestamoResponse) => {
    setDevolucionAbierta(p)
    // Cada línea sale sugerida con lo que falta devolver: es lo mas comun.
    setCantidadesDevolucion(
      Object.fromEntries(p.detalle.map((d) => [d.id, String(d.cantidadPendiente)])),
    )
    setErrorForm('')
  }

  const registrarDevolucion = async () => {
    if (!devolucionAbierta) return

    const detalle = devolucionAbierta.detalle
      .map((d) => ({
        prestamoDetalleId: d.id,
        cantidad: Number(cantidadesDevolucion[d.id] || 0),
      }))
      .filter((l) => l.cantidad > 0)

    if (detalle.length === 0) return setErrorForm('Indica cuánto se devuelve.')

    setGuardando(true)
    setErrorForm('')
    try {
      await prestamoApi.devolver(devolucionAbierta.id, detalle)
      setDevolucionAbierta(null)
      await cargar()
    } catch (e) {
      setErrorForm(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos registrar la devolución.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const columnasFilas: DataTableColumn<FilaPrestamo>[] = [
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
    ...(cabecera.tipo === 'RECIBIDO'
      ? [
          {
            key: 'costo',
            label: 'Costo',
            align: 'right' as const,
            value: (fila: FilaPrestamo) => Number(fila.costo) || 0,
            render: (fila: FilaPrestamo) => {
              const producto = productos.find((p) => p.id === fila.productoId)
              const presentaciones = producto?.presentaciones.filter((p) => p.activo) ?? []
              const presentacionElegida = presentaciones.find((p) => p.id === fila.presentacionId)

              return (
                <Input
                  type="number"
                  step="0.01"
                  disabled={!producto}
                  placeholder={
                    producto?.costoReferencia
                      ? String(producto.costoReferencia * (presentacionElegida?.factor ?? 1))
                      : '0.00'
                  }
                  value={fila.costo}
                  onChange={(e) => actualizarFila(fila.id, { costo: e.target.value })}
                />
              )
            },
          },
        ]
      : []),
  ]

  const columns: DataTableColumn<PrestamoResponse>[] = [
    { key: 'numero', label: 'Número', render: (row) => <Badge>{row.numero}</Badge> },
    {
      key: 'tipo',
      label: 'Tipo',
      render: (row) => (
        <Badge tone={row.tipo === 'DADO' ? 'warning' : 'success'}>
          {row.tipo === 'DADO' ? 'Prestado' : 'Recibido'}
        </Badge>
      ),
    },
    { key: 'contraparte', label: 'Contraparte' },
    { key: 'almacen', label: 'Almacén' },
    {
      key: 'fecha',
      label: 'Fecha',
      render: (row) => new Date(row.fecha).toLocaleDateString('es-PE'),
    },
    { key: 'total', label: 'Valor', align: 'right', render: (row) => `S/ ${row.total.toFixed(2)}` },
    {
      key: 'estado',
      label: 'Estado',
      render: (row) => estadoPrestamoBadge(row.estado),
    },
  ]

  return (
    <ListPage
      icon={<HandCoins size={20} />}
      title="Préstamos"
      description="Mercadería que sale o entra desde fuera de la empresa: se presta y se espera de vuelta."
      actions={
        <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
          Nuevo préstamo
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard
            label="Préstamos"
            value={String(prestamos.length)}
            icon={<HandCoins size={18} />}
          />
          <StatCard
            label="Pendientes"
            value={String(prestamos.filter((p) => p.estado === 'PENDIENTE').length)}
            icon={<HandCoins size={18} />}
            tono="warning"
          />
          <StatCard
            label="Devueltos"
            value={String(prestamos.filter((p) => p.estado === 'DEVUELTO').length)}
            icon={<Undo2 size={18} />}
            tono="neutral"
          />
        </>
      }
      columns={columns}
      rows={prestamos}
      cardIcon={HandCoins}
      searchPlaceholder="Buscar por número, contraparte..."
      empty={cargando ? 'Cargando préstamos...' : 'Todavía no hay préstamos registrados.'}
      rowActions={(row) => (
        <>
          <RowAction label={`Ver ${row.numero}`} tone="view" onClick={() => setDetalleAbierto(row)}>
            <Eye size={15} />
          </RowAction>
          <RowAction
            label={`Registrar devolución de ${row.numero}`}
            tone="warning"
            disabled={row.estado !== 'PENDIENTE'}
            disabledReason="Ya fue devuelto"
            onClick={() => abrirDevolucion(row)}
          >
            <Undo2 size={15} />
          </RowAction>
        </>
      )}
    >
      {/* Nuevo préstamo */}
      <Modal
        open={abierto}
        title="Nuevo préstamo"
        description="DADO: sale mercadería propia. RECIBIDO: entra la de un tercero."
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              Registrar préstamo
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {errorForm && <Alert>{errorForm}</Alert>}

          <div className="grid gap-4 sm:grid-cols-2">
            <Desplegable
              label="Tipo"
              value={cabecera.tipo}
              onChange={(v) => setCabecera({ ...cabecera, tipo: v as TipoPrestamo })}
              options={[
                { value: 'DADO', label: 'Prestado', nota: 'sale mercadería propia' },
                { value: 'RECIBIDO', label: 'Recibido', nota: 'entra mercadería de un tercero' },
              ]}
            />
            <Desplegable
              label="Almacén"
              value={cabecera.almacenId}
              onChange={(v) => setCabecera({ ...cabecera, almacenId: Number(v) })}
              options={activos.map((a) => ({ value: a.id, label: a.nombre, detalle: a.codigo }))}
            />
          </div>

          <Input
            label={cabecera.tipo === 'DADO' ? 'A quién le prestas' : 'Quién te presta'}
            placeholder="Bodega Rosa, Distribuidora López..."
            value={cabecera.contraparte}
            onChange={(e) => setCabecera({ ...cabecera, contraparte: e.target.value })}
          />

          <Input
            label="Observación"
            optional
            placeholder="Motivo, fecha estimada de devolución..."
            value={cabecera.observacion}
            onChange={(e) => setCabecera({ ...cabecera, observacion: e.target.value })}
          />

          <hr className="border-line" />

          <p className="text-sm font-semibold text-ink">Agregar producto</p>
          {cabecera.tipo === 'RECIBIDO' && (
            <p className="-mt-2 text-xs text-ink-soft">Costo vacío usa el costo de referencia.</p>
          )}
          <AgregarProductoPanel
            productos={productos}
            stock={stockMap}
            pideCosto={cabecera.tipo === 'RECIBIDO'}
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
        title={detalleAbierto ? `${detalleAbierto.numero} · ${detalleAbierto.contraparte}` : ''}
        description={
          detalleAbierto
            ? `Emisión ${new Date(detalleAbierto.fecha).toLocaleDateString('es-PE')} · ${detalleAbierto.almacen} · ${
                detalleAbierto.tipo === 'DADO' ? 'Prestado' : 'Recibido'
              }`
            : undefined
        }
        onClose={() => setDetalleAbierto(null)}
        size="lg"
      >
        {detalleAbierto && (
          <div className="flex flex-col gap-3">
            {detalleAbierto.estado === 'DEVUELTO' && <div>{estadoPrestamoBadge(detalleAbierto.estado)}</div>}

            <TablaProductosDetalle<PrestamoDetalleResponse>
              filas={detalleAbierto.detalle}
              rowKey={(l) => l.id}
              titulo={(l) => l.producto}
              subtitulo={(l) => `${l.codigo} · ${l.presentacion ?? l.unidadBase}`}
              grupos={[
                [
                  { key: 'cant', label: 'Cant.', render: (l) => `${l.cantidadPresentacion}` },
                  { key: 'costo', label: 'Costo', render: (l) => `S/ ${l.costoUnitario.toFixed(2)}` },
                  { key: 'subtotal', label: 'Subtotal', render: (l) => `S/ ${l.costoTotal.toFixed(2)}` },
                ] satisfies ColumnaDetalleProducto<PrestamoDetalleResponse>[],
                [
                  {
                    key: 'devuelto',
                    label: 'Devuelto',
                    render: (l) => `${l.cantidadDevuelta} ${l.unidadBase}`,
                  },
                  {
                    key: 'pendiente',
                    label: 'Pendiente',
                    render: (l) => `${l.cantidadPendiente} ${l.unidadBase}`,
                  },
                ] satisfies ColumnaDetalleProducto<PrestamoDetalleResponse>[],
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

      {/* Devolución */}
      <Modal
        open={devolucionAbierta !== null}
        title={devolucionAbierta ? `Devolución de ${devolucionAbierta.numero}` : ''}
        description="Puede ser parcial: lo que no se devuelva ahora queda pendiente."
        onClose={() => setDevolucionAbierta(null)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setDevolucionAbierta(null)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void registrarDevolucion()}>
              Registrar devolución
            </Button>
          </>
        }
      >
        {devolucionAbierta && (
          <div className="flex flex-col gap-3">
            {errorForm && <Alert>{errorForm}</Alert>}

            {devolucionAbierta.detalle
              .filter((d) => d.cantidadPendiente > 0)
              .map((d) => (
                <div
                  key={d.id}
                  className="grid grid-cols-[1fr_8rem] items-end gap-2 rounded-field border border-line p-3"
                >
                  <div>
                    <p className="text-sm font-medium text-ink">{d.producto}</p>
                    <p className="text-xs text-ink-soft">
                      Pendiente: {d.cantidadPendiente} {d.unidadBase} de {d.cantidad}
                    </p>
                  </div>
                  <Input
                    label={`Devolver (${d.unidadBase})`}
                    type="number"
                    step="0.0001"
                    max={d.cantidadPendiente}
                    value={cantidadesDevolucion[d.id] ?? ''}
                    onChange={(e) =>
                      setCantidadesDevolucion({
                        ...cantidadesDevolucion,
                        [d.id]: e.target.value,
                      })
                    }
                  />
                </div>
              ))}
          </div>
        )}
      </Modal>
    </ListPage>
  )
}
