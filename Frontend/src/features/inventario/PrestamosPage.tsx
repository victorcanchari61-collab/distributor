import { useCallback, useEffect, useState } from 'react'
import { fechaCorta, fechaHora } from '../../lib/fechas'
import { ArrowLeft, Check, Eye, HandCoins, Plus, Trash2, Undo2, X } from 'lucide-react'
import {
  AccionPdf,
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
  useConfirmacion,
  useToast,
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
import { almacenApi, prestamoApi, stockApi } from './inventarioApi'
import type {
  AlmacenResponse,
  PrestamoDetalleResponse,
  PrestamoDevolucionResponse,
  PrestamoResponse,
  TipoPrestamo,
  ResumenPrestamos,
} from './inventarioApi'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'

type FilaPrestamo = LineaProductoNueva

/**
 * Una fila de la tabla de devoluciones: una ya registrada, o la fila nueva
 * que se agrega para registrar una — igual que "Agregar pago" en Cobranza.
 */
interface FilaDevolucion {
  clave: string
  /** null en la fila nueva, mientras todavía no se guarda. */
  devolucion: PrestamoDevolucionResponse | null
}

const NUEVA_DEVOLUCION = 'nueva'

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
  const { puede } = usePermisos()
  const toast = useToast()
  const [prestamos, setPrestamos] = useState<PrestamoResponse[]>([])
  const [almacenes, setAlmacenes] = useState<AlmacenResponse[]>([])
  const [productos, setProductos] = useState<ProductoResponse[]>([])

  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [vista, setVista] = useState<'lista' | 'form'>('lista')
  const [detalleAbierto, setDetalleAbierto] = useState<PrestamoResponse | null>(null)
  const [devolucionAbierta, setDevolucionAbierta] = useState<PrestamoResponse | null>(null)
  const [cantidadesDevolucion, setCantidadesDevolucion] = useState<Record<number, string>>({})
  const [agregandoDevolucion, setAgregandoDevolucion] = useState(false)
  const [guardando, setGuardando] = useState(false)
  const { confirmar, dialogo } = useConfirmacion()

  const [cabecera, setCabecera] = useState({
    tipo: 'DADO' as TipoPrestamo,
    contraparte: '',
    almacenId: 0,
    observacion: '',
  })
  const [filas, setFilas] = useState<FilaPrestamo[]>([])
  const [stockMap, setStockMap] = useState<Record<number, number>>({})

  /*
   * Los prestamos se acumulan con la operacion: la tabla pide su pagina y los
   * contadores salen del resumen.
   */
  const [consulta, setConsulta] = useState<ConsultaTabla | null>(null)
  const [totalRegistros, setTotalRegistros] = useState(0)
  const [resumen, setResumen] = useState<ResumenPrestamos | null>(null)

  const cargarPagina = useCallback(async (q: ConsultaTabla) => {
    setCargando(true)
    try {
      const pagina = await prestamoApi.listar(q)
      setPrestamos(pagina.items)
      setTotalRegistros(pagina.total)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los préstamos.')
    } finally {
      setCargando(false)
    }
  }, [])

  const cargarApoyo = useCallback(async () => {
    try {
      const [res, alms, prods] = await Promise.all([
        prestamoApi.resumen(),
        almacenApi.getAll(),
        productoApi.getAll(),
      ])
      setResumen(res)
      setAlmacenes(alms)
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

  useRealtime('prestamos', cargar)

  const activos = almacenes.filter((a) => a.activo)

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
      tipo: 'DADO',
      contraparte: '',
      almacenId: activos.find((a) => a.esPrincipal)?.id ?? activos[0]?.id ?? 0,
      observacion: '',
    })
    setFilas([])
    setVista('form')
  }

  const actualizarFila = (id: string, cambio: Partial<FilaPrestamo>) =>
    setFilas((prev) => prev.map((f) => (f.id === id ? { ...f, ...cambio } : f)))

  const guardar = async () => {
    if (!cabecera.contraparte.trim()) {
      return toast.error('Indica a quién le prestas o quién te presta.')
    }
    if (!cabecera.almacenId) return toast.error('Elige el almacén.')

    const validas = filas.filter((f) => f.productoId && f.cantidad)
    if (validas.length === 0) return toast.error('Agrega al menos un producto.')

    setGuardando(true)
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
      setVista('lista')
      await cargar()
      toast.exito('Préstamo registrado')
    } catch (e) {
      toast.error(
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
    setAgregandoDevolucion(false)
    setCantidadesDevolucion({})
  }

  /*
   * Refresca lo que se ve tras registrar o anular una devolución.
   *
   * El préstamo que se está gestionando se pide por id y no se busca en la
   * lista: con paginación solo estaría si cayó en la página visible.
   */
  const refrescarDevolucion = useCallback(async (id: number) => {
    await cargar()
    setDevolucionAbierta(await prestamoApi.getById(id))
  }, [cargar])

  /** Abre la fila nueva de la tabla, sugerida con lo que falta devolver de cada producto. */
  const agregarDevolucion = () => {
    if (!devolucionAbierta) return
    setCantidadesDevolucion(
      Object.fromEntries(
        devolucionAbierta.detalle
          .filter((d) => d.cantidadPendiente > 0)
          .map((d) => [d.id, String(d.cantidadPendiente)]),
      ),
    )
    setAgregandoDevolucion(true)
  }

  const cancelarDevolucion = () => {
    setAgregandoDevolucion(false)
    setCantidadesDevolucion({})
  }

  const registrarDevolucion = async () => {
    if (!devolucionAbierta) return

    const detalle = devolucionAbierta.detalle
      .map((d) => ({
        prestamoDetalleId: d.id,
        cantidad: Number(cantidadesDevolucion[d.id] || 0),
      }))
      .filter((l) => l.cantidad > 0)

    if (detalle.length === 0) return toast.error('Indica cuánto se devuelve.')

    setGuardando(true)
    try {
      await prestamoApi.devolver(devolucionAbierta.id, detalle)
      setAgregandoDevolucion(false)
      setCantidadesDevolucion({})
      await refrescarDevolucion(devolucionAbierta.id)
      toast.exito('Devolución registrada')
    } catch (e) {
      toast.error(
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

  const anularDevolucion = (d: PrestamoDevolucionResponse) =>
    confirmar({
      titulo: `Anular devolución ${d.numero}`,
      mensaje:
        'Revierte el stock que movió esta devolución y la línea del préstamo vuelve a quedar pendiente por esa cantidad. No se puede deshacer.',
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        if (!devolucionAbierta) return
        try {
          await prestamoApi.anularDevolucion(d.id)
          await refrescarDevolucion(devolucionAbierta.id)
          toast.exito('Devolución anulada')
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos anular la devolución.')
        }
      },
    })

  /*
   * Cada devolución es un documento propio: una fila por evento, no por
   * producto. La fila nueva (sin guardar) reemplaza "Documento"/"Fecha"/etc
   * por los campos para escribir cuánto se devuelve de cada producto
   * pendiente — el mismo lugar que ocupará su resumen una vez guardada.
   */
  const columnasDevoluciones: DataTableColumn<FilaDevolucion>[] = [
    {
      key: 'numero',
      label: 'Documento',
      sortable: false,
      render: (f) =>
        f.devolucion ? (
          <Badge tone={f.devolucion.estado === 'ANULADO' ? 'neutral' : undefined}>
            {f.devolucion.numero}
          </Badge>
        ) : (
          <Badge tone="sys">Nueva</Badge>
        ),
    },
    {
      key: 'fecha',
      label: 'Fecha',
      sortable: false,
      render: (f) => (f.devolucion ? fechaHora(f.devolucion.fecha) : <span className="text-ink-soft">—</span>),
    },
    {
      key: 'productos',
      label: 'Productos',
      sortable: false,
      render: (f) => {
        if (f.devolucion) {
          return f.devolucion.detalle.length === 1
            ? `${f.devolucion.detalle[0].producto} · ${f.devolucion.detalle[0].cantidadPresentacion} ${f.devolucion.detalle[0].presentacion ?? f.devolucion.detalle[0].unidadBase}`
            : `${f.devolucion.detalle.length} productos`
        }

        // La fila nueva: un campo por cada producto que todavía tiene saldo pendiente.
        return (
          <div className="flex flex-col gap-2 py-1">
            {(devolucionAbierta?.detalle ?? [])
              .filter((d) => d.cantidadPendiente > 0)
              .map((d) => (
                <div key={d.id} className="grid grid-cols-[1fr_7rem] items-center gap-2">
                  <span className="text-xs text-ink-muted">
                    {d.producto}
                    <span className="block text-[11px] text-ink-soft">
                      Pendiente: {d.cantidadPendiente} {d.unidadBase} de {d.cantidad}
                    </span>
                  </span>
                  <Input
                    size="sm"
                    type="number"
                    step="0.0001"
                    max={d.cantidadPendiente}
                    value={cantidadesDevolucion[d.id] ?? ''}
                    onChange={(e) =>
                      setCantidadesDevolucion({ ...cantidadesDevolucion, [d.id]: e.target.value })
                    }
                  />
                </div>
              ))}
          </div>
        )
      },
    },
    {
      key: 'usuario',
      label: 'Registrada por',
      sortable: false,
      render: (f) => f.devolucion?.usuario ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'estado',
      label: 'Estado',
      sortable: false,
      render: (f) =>
        f.devolucion ? (
          <Badge tone={f.devolucion.estado === 'ANULADO' ? 'danger' : 'success'}>
            {f.devolucion.estado === 'ANULADO' ? 'Anulada' : 'Confirmada'}
          </Badge>
        ) : (
          <span className="text-ink-soft">—</span>
        ),
    },
  ]

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
    // Número y contraparte se buscan con el buscador de arriba, no en el panel.
    { key: 'numero', label: 'Número', filterable: false, render: (row) => <Badge>{row.numero}</Badge> },
    {
      key: 'tipo',
      label: 'Tipo',
      filterType: 'select',
      filterOptions: [
        { value: 'DADO', label: 'Prestado' },
        { value: 'RECIBIDO', label: 'Recibido' },
      ],
      render: (row) => (
        <Badge tone={row.tipo === 'DADO' ? 'warning' : 'success'}>
          {row.tipo === 'DADO' ? 'Prestado' : 'Recibido'}
        </Badge>
      ),
    },
    { key: 'contraparte', label: 'Contraparte', filterable: false },
    {
      key: 'almacen',
      label: 'Almacén',
      filterType: 'select',
      filterOptions: almacenes.map((a) => ({ value: a.nombre, label: a.nombre })),
    },
    {
      key: 'fecha',
      label: 'Fecha',
      filterType: 'date',
      render: (row) => fechaCorta(row.fecha),
    },
    {
      key: 'total',
      label: 'Valor',
      align: 'right',
      // Sin control numerico en el panel, buscar "9" contra "S/ 9.00" no
      // encuentra lo que la persona espera.
      filterable: false,
      render: (row) => `S/ ${row.total.toFixed(2)}`,
    },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'PENDIENTE', label: 'Pendiente' },
        { value: 'DEVUELTO', label: 'Devuelto' },
      ],
      render: (row) => estadoPrestamoBadge(row.estado),
    },
  ]

  if (vista === 'form') {
    return (
      <div className="space-y-5">
        <PageHeader
          icon={<HandCoins size={20} />}
          title="Nuevo préstamo"
          description="DADO: sale mercadería propia. RECIBIDO: entra la de un tercero."
          actions={
            <Button variant="secondary" size="sm" onClick={() => setVista('lista')}>
              <ArrowLeft size={15} />
              Volver
            </Button>
          }
        />

        <div className="grid grid-cols-1 gap-5 xl:grid-cols-[1fr_360px] xl:items-start">
          <PageSection
            title="Productos"
            description={`${filas.length} producto${filas.length === 1 ? '' : 's'} agregado${filas.length === 1 ? '' : 's'}`}
          >
            {cabecera.tipo === 'RECIBIDO' && (
              <p className="mb-3 text-xs text-ink-soft">Costo vacío usa el costo de referencia.</p>
            )}
            <AgregarProductoPanel
              productos={productos}
              stock={stockMap}
              pideCosto={cabecera.tipo === 'RECIBIDO'}
              onAgregar={(linea) => setFilas((f) => [...f, linea])}
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

          <PageSection title="Préstamo">
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
              className="mt-4"
              label="Almacén"
              value={cabecera.almacenId}
              onChange={(v) => setCabecera({ ...cabecera, almacenId: Number(v) })}
              options={activos.map((a) => ({ value: a.id, label: a.nombre, detalle: a.codigo }))}
            />

            <Input
              className="mt-4"
              label={cabecera.tipo === 'DADO' ? 'A quién le prestas' : 'Quién te presta'}
              placeholder="Bodega Rosa, Distribuidora López..."
              value={cabecera.contraparte}
              onChange={(e) => setCabecera({ ...cabecera, contraparte: e.target.value })}
            />

            <Input
              className="mt-4"
              label="Observación"
              optional
              placeholder="Motivo, fecha estimada de devolución..."
              value={cabecera.observacion}
              onChange={(e) => setCabecera({ ...cabecera, observacion: e.target.value })}
            />
          </PageSection>
        </div>

        <div className="flex justify-end gap-2">
          <Button variant="secondary" size="sm" onClick={() => setVista('lista')}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            Registrar préstamo
          </Button>
        </div>
      </div>
    )
  }

  return (
    <ListPage
      icon={<HandCoins size={20} />}
      title="Préstamos"
      description="Mercadería que sale o entra desde fuera de la empresa: se presta y se espera de vuelta."
      actions={
        puede('inv.prestamos', 'crear') ? (
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nuevo préstamo
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard
            label="Préstamos"
            value={String(resumen?.total ?? 0)}
            icon={<HandCoins size={18} />}
          />
          <StatCard
            label="Pendientes"
            value={String(resumen?.pendientes ?? 0)}
            icon={<HandCoins size={18} />}
            tono="warning"
          />
          <StatCard
            label="Devueltos"
            value={String(resumen?.devueltos ?? 0)}
            icon={<Undo2 size={18} />}
            tono="neutral"
          />
        </>
      }
      columns={columns}
      rows={prestamos}
      servidor={{
        total: totalRegistros,
        cargando,
        onConsulta: (q) => {
          setConsulta(q)
          void cargarPagina(q)
        },
      }}
      cardIcon={HandCoins}
      searchPlaceholder="Buscar por número, contraparte..."
      empty={cargando ? 'Cargando préstamos...' : 'Todavía no hay préstamos registrados.'}
      rowActions={(row) => (
        <>
          <RowAction label={`Ver ${row.numero}`} tone="view" onClick={() => setDetalleAbierto(row)}>
            <Eye size={15} />
          </RowAction>
          {puede('inv.prestamos', 'exportar') && (
            <AccionPdf documento="prestamos" id={row.id} numero={row.numero} />
          )}
          {puede('inv.prestamos', 'confirmar') && (
            <RowAction
              label={`Registrar devolución de ${row.numero}`}
              tone="warning"
              disabled={row.estado !== 'PENDIENTE'}
              disabledReason="Ya fue devuelto"
              onClick={() => abrirDevolucion(row)}
            >
              <Undo2 size={15} />
            </RowAction>
          )}
        </>
      )}
    >
      {/* Ver detalle */}
      <Modal
        open={detalleAbierto !== null}
        title={detalleAbierto ? `${detalleAbierto.numero} · ${detalleAbierto.contraparte}` : ''}
        description={
          detalleAbierto
            ? `Emisión ${fechaCorta(detalleAbierto.fecha)} · ${detalleAbierto.almacen} · ${
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
        size="lg"
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setDevolucionAbierta(null)}>
              Cerrar
            </Button>
            {puede('inv.prestamos', 'confirmar') && (
              <Button
                size="sm"
                disabled={
                  agregandoDevolucion ||
                  !devolucionAbierta?.detalle.some((d) => d.cantidadPendiente > 0)
                }
                onClick={agregarDevolucion}
              >
                <Plus size={15} />
                Agregar devolución
              </Button>
            )}
          </>
        }
      >
        {devolucionAbierta && (
          <div className="flex flex-col gap-4">
            {/*
              Con qué almacén queda: la devolución siempre va al mismo almacén con el que se
              registró el préstamo (no se elige otro), pero hay que verlo antes de confirmar.
            */}
            <div className="rounded-field bg-surface-alt px-3 py-2 text-sm text-ink-muted">
              {devolucionAbierta.tipo === 'DADO' ? 'Vuelve a' : 'Sale de'}{' '}
              <span className="font-semibold text-ink">{devolucionAbierta.almacen}</span>
            </div>

            <SysDataTable<FilaDevolucion>
              columns={columnasDevoluciones}
              rows={[
                ...(agregandoDevolucion ? [{ clave: NUEVA_DEVOLUCION, devolucion: null }] : []),
                ...devolucionAbierta.devoluciones.map((d) => ({ clave: String(d.id), devolucion: d })),
              ]}
              rowKey="clave"
              toolbar={false}
              empty="Todavía no hay devoluciones registradas."
              actions={(f) =>
                f.clave === NUEVA_DEVOLUCION ? (
                  <>
                    <RowAction
                      label="Guardar devolución"
                      tone="success"
                      disabled={guardando}
                      onClick={() => void registrarDevolucion()}
                    >
                      <Check size={15} />
                    </RowAction>
                    <RowAction label="Cancelar" tone="neutral" disabled={guardando} onClick={cancelarDevolucion}>
                      <X size={15} />
                    </RowAction>
                  </>
                ) : f.devolucion ? (
                  <>
                    <AccionPdf documento="devolucionesprestamo" id={f.devolucion.id} numero={f.devolucion.numero} />
                    {f.devolucion.estado === 'CONFIRMADO' && puede('inv.prestamos', 'anular') && (
                      <RowAction
                        label={`Anular devolución ${f.devolucion.numero}`}
                        tone="danger"
                        onClick={() => f.devolucion && anularDevolucion(f.devolucion)}
                      >
                        <Undo2 size={15} />
                      </RowAction>
                    )}
                  </>
                ) : null
              }
            />
          </div>
        )}
      </Modal>

      {dialogo}
    </ListPage>
  )
}
