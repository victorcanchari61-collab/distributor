import { useCallback, useEffect, useState } from 'react'
import { ArrowLeft, Eye, Package, Pencil, Plus, Truck, Undo2 } from 'lucide-react'
import {
  AccionPdf,
  Alert,
  Badge,
  Button,
  Desplegable,
  Input,
  ListPage,
  Modal,
  PageHeader,
  PageSection,
  RowAction,
  StatCard,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { conductorApi, vehiculoApi } from './flotaApi'
import type { ConductorResponse, VehiculoResponse } from './flotaApi'
import { rutaApi } from './rutaApi'
import type { RutaResponse } from './rutaApi'
import { despachoApi } from './despachoApi'
import type {
  DespachoPedidoResponse,
  DespachoResponse,
  ResumenDespachos,
} from './despachoApi'

const hoy = () => new Date().toISOString().slice(0, 10)

function estadoBadge(estado: DespachoResponse['estado']) {
  return estado === 'ANULADO' ? (
    <Badge tone="danger">Anulado</Badge>
  ) : (
    <Badge tone="success">Armado</Badge>
  )
}

/**
 * Despacho: la carga de un camión para un día y una ruta.
 *
 * Junta PEDIDOS, no ventas: el vendedor los toma en la calle, aquí se arma con
 * ellos el reparto, y es el repartidor quien convierte cada uno en venta al
 * entregarlo. Por eso esta pantalla no factura ni mueve stock.
 */
export function DespachosPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const [vista, setVista] = useState<'lista' | 'form'>('lista')
  const [despachos, setDespachos] = useState<DespachoResponse[]>([])
  const [resumen, setResumen] = useState<ResumenDespachos | null>(null)
  const [rutas, setRutas] = useState<RutaResponse[]>([])
  const [vehiculos, setVehiculos] = useState<VehiculoResponse[]>([])
  const [conductores, setConductores] = useState<ConductorResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [detalle, setDetalle] = useState<DespachoResponse | null>(null)
  const [editando, setEditando] = useState<DespachoResponse | null>(null)
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const [fecha, setFecha] = useState(hoy())
  const [rutaId, setRutaId] = useState(0)
  const [vehiculoId, setVehiculoId] = useState(0)
  const [conductorId, setConductorId] = useState(0)
  const [observacion, setObservacion] = useState('')
  const [disponibles, setDisponibles] = useState<DespachoPedidoResponse[]>([])
  const [cargandoPedidos, setCargandoPedidos] = useState(false)
  const [elegidos, setElegidos] = useState<number[]>([])

  /*
   * Si el conductor se cambió a mano, el camión deja de imponerlo.
   *
   * Sin esto, elegir otro vehículo pisaría la elección de quien ya dijo
   * expresamente "hoy maneja este otro", que es justo el caso que el
   * autocompletado tiene que ayudar, no estorbar.
   */
  const [conductorTocado, setConductorTocado] = useState(false)

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [lista, res, rts, vhs, cds] = await Promise.all([
        despachoApi.getAll(),
        despachoApi.resumen(),
        rutaApi.getAll(),
        vehiculoApi.getAll(),
        conductorApi.getAll(),
      ])
      setDespachos(lista)
      setResumen(res)
      setRutas(rts.filter((r) => r.activo))
      setVehiculos(vhs.filter((v) => v.activo))
      setConductores(cds.filter((c) => c.activo))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los despachos.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['despachos', 'pedidos', 'notasventa'], cargar)

  // El camión propone su conductor habitual; queda como propuesta hasta que
  // alguien decida otra cosa.
  useEffect(() => {
    if (conductorTocado || !vehiculoId) return
    const vehiculo = vehiculos.find((v) => v.id === vehiculoId)
    if (vehiculo?.conductorId) setConductorId(vehiculo.conductorId)
  }, [vehiculoId, vehiculos, conductorTocado])

  // Al cambiar de ruta se piden sus pedidos pendientes.
  useEffect(() => {
    if (vista !== 'form' || !rutaId) {
      setDisponibles([])
      return
    }

    let vivo = true
    setCargandoPedidos(true)
    void despachoApi
      .disponibles(rutaId, editando?.id)
      .then((lista) => {
        if (!vivo) return
        setDisponibles(lista)
        // Lo que ya no está disponible deja de estar marcado: si no, se
        // enviaría un pedido que otro camión se llevó.
        setElegidos((prev) => prev.filter((id) => lista.some((p) => p.pedidoId === id)))
      })
      .catch((e) => {
        if (vivo) setErrorForm(e instanceof ApiError ? e.message : 'No pudimos cargar los pedidos.')
      })
      .finally(() => {
        if (vivo) setCargandoPedidos(false)
      })

    return () => {
      vivo = false
    }
  }, [rutaId, vista, editando])

  const abrirNuevo = () => {
    setEditando(null)
    setFecha(hoy())
    setRutaId(0)
    setVehiculoId(0)
    setConductorId(0)
    setConductorTocado(false)
    setObservacion('')
    setElegidos([])
    setErrorForm('')
    setVista('form')
  }

  const abrirEdicion = (d: DespachoResponse) => {
    setEditando(d)
    setFecha(d.fecha.slice(0, 10))
    setRutaId(d.rutaId)
    setVehiculoId(d.vehiculoId)
    setConductorId(d.conductorId)
    // Al editar, el conductor guardado manda: fue una decisión que ya se tomó.
    setConductorTocado(true)
    setObservacion(d.observacion ?? '')
    setElegidos(d.detalle.map((p) => p.pedidoId))
    setErrorForm('')
    setVista('form')
  }

  const alternar = (pedidoId: number) =>
    setElegidos((prev) =>
      prev.includes(pedidoId) ? prev.filter((id) => id !== pedidoId) : [...prev, pedidoId],
    )

  const guardar = async () => {
    if (!rutaId) return setErrorForm('Elige la ruta.')
    if (!vehiculoId) return setErrorForm('Elige el vehículo.')
    if (!conductorId) return setErrorForm('Elige el conductor.')
    if (elegidos.length === 0) return setErrorForm('Marca al menos un pedido para cargar.')

    const body = {
      fecha,
      rutaId,
      vehiculoId,
      conductorId,
      observacion: observacion.trim() || null,
      pedidoIds: elegidos,
    }

    setGuardando(true)
    setErrorForm('')
    try {
      if (editando) {
        await despachoApi.update(editando.id, body)
      } else {
        await despachoApi.create(body)
      }
      setVista('lista')
      await cargar()
      toast.exito(editando ? 'Despacho actualizado' : 'Despacho creado')
    } catch (e) {
      setErrorForm(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos guardar el despacho.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const anular = (d: DespachoResponse) =>
    confirmar({
      titulo: `Anular ${d.numero}`,
      mensaje: 'Sus pedidos vuelven a quedar libres para otro despacho.',
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await despachoApi.anular(d.id)
          await cargar()
          toast.exito(`${d.numero} anulado`)
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos anular el despacho.')
        }
      },
    })

  const totalElegido = disponibles
    .filter((p) => elegidos.includes(p.pedidoId))
    .reduce((n, p) => n + p.total, 0)

  const columns: DataTableColumn<DespachoResponse>[] = [
    { key: 'numero', label: 'Número', render: (row) => <Badge>{row.numero}</Badge> },
    {
      key: 'fecha',
      label: 'Fecha',
      filterType: 'date',
      value: (row) => new Date(row.fecha).getTime(),
      render: (row) => new Date(row.fecha).toLocaleDateString(),
    },
    { key: 'ruta', label: 'Ruta' },
    { key: 'vehiculo', label: 'Vehículo' },
    { key: 'conductor', label: 'Conductor' },
    {
      key: 'pedidos',
      label: 'Entregas',
      align: 'right',
      filterable: false,
      // Cuántos de los que lleva ya se entregaron: es lo que se mira para
      // saber si el camión terminó su vuelta.
      render: (row) => (
        <Badge tone={row.entregados === row.pedidos ? 'success' : 'warning'}>
          {row.entregados} de {row.pedidos}
        </Badge>
      ),
    },
    {
      key: 'total',
      label: 'Total',
      align: 'right',
      filterable: false,
      render: (row) => `S/ ${row.total.toFixed(2)}`,
    },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'ARMADO', label: 'Armado' },
        { value: 'ANULADO', label: 'Anulado' },
      ],
      render: (row) => estadoBadge(row.estado),
    },
  ]

  if (vista === 'form') {
    return (
      <div className="flex flex-col gap-4">
        <PageHeader
          icon={<Truck size={20} />}
          title={editando ? `Editar ${editando.numero}` : 'Nuevo despacho'}
          description="Arma la carga del camión: elige la ruta y marca los pedidos que salen."
          actions={
            <Button variant="secondary" size="sm" onClick={() => setVista('lista')} iconRight={<ArrowLeft size={15} />}>
              Volver
            </Button>
          }
        />

        {errorForm && <Alert>{errorForm}</Alert>}

        <div className="grid gap-4 lg:grid-cols-[1fr_22rem]">
          <PageSection title="Pedidos" description="Los pendientes de los clientes de esa ruta.">
            {!rutaId ? (
              <p className="py-8 text-center text-sm text-ink-soft">
                Elige primero la ruta para ver sus pedidos.
              </p>
            ) : cargandoPedidos ? (
              <p className="py-8 text-center text-sm text-ink-soft">Cargando pedidos...</p>
            ) : disponibles.length === 0 ? (
              <p className="py-8 text-center text-sm text-ink-soft">
                No hay pedidos pendientes en esta ruta. Puede que ya estén en otro camión.
              </p>
            ) : (
              <div className="flex flex-col gap-2">
                {disponibles.map((p) => (
                  <label
                    key={p.pedidoId}
                    className="flex cursor-pointer items-start gap-3 rounded-field border border-line p-3 transition hover:border-ink-soft"
                  >
                    <input
                      type="checkbox"
                      className="mt-1"
                      checked={elegidos.includes(p.pedidoId)}
                      onChange={() => alternar(p.pedidoId)}
                    />
                    <span className="flex min-w-0 flex-1 flex-col">
                      <span className="flex items-center gap-2">
                        <Badge>{p.numero}</Badge>
                        <span className="truncate text-sm font-semibold text-ink">{p.cliente}</span>
                        {p.notaVentaNumero && <Badge tone="success">{p.notaVentaNumero}</Badge>}
                      </span>
                      {/* Dónde entregarlo: sin esto el reparto no se puede armar. */}
                      <span className="truncate text-xs text-ink-soft">
                        {[p.mercado, p.direccion].filter(Boolean).join(' — ') || 'Sin dirección'}
                        {p.telefono ? ` · ${p.telefono}` : ''}
                      </span>
                    </span>
                    <span className="text-sm font-semibold text-ink">S/ {p.total.toFixed(2)}</span>
                  </label>
                ))}
              </div>
            )}
          </PageSection>

          <PageSection title="Despacho">
            <div className="flex flex-col gap-4">
              <Input
                label="Fecha del reparto"
                type="date"
                value={fecha}
                onChange={(e) => setFecha(e.target.value)}
              />

              <Desplegable
                label="Ruta"
                value={rutaId}
                onChange={(v) => setRutaId(Number(v))}
                options={rutas.map((r) => ({ value: r.id, label: r.nombre }))}
              />

              <Desplegable
                label="Vehículo"
                value={vehiculoId}
                onChange={(v) => setVehiculoId(Number(v))}
                options={vehiculos.map((v) => ({
                  value: v.id,
                  label: v.placa,
                  detalle: v.conductor ?? undefined,
                }))}
              />

              <Desplegable
                label="Conductor"
                value={conductorId}
                onChange={(v) => {
                  setConductorId(Number(v))
                  setConductorTocado(true)
                }}
                options={conductores.map((c) => ({ value: c.id, label: c.nombre }))}
              />

              <label className="block">
                <span className="ui-label mb-1.5">Observación (opcional)</span>
                <textarea
                  rows={2}
                  value={observacion}
                  onChange={(e) => setObservacion(e.target.value)}
                  className="w-full rounded-field border border-line bg-surface px-3 py-2 text-sm text-ink outline-none placeholder:text-ink-soft focus:border-ink-soft"
                />
              </label>

              <div className="rounded-field bg-surface-alt p-3">
                <p className="text-xs text-ink-soft">Carga del camión</p>
                <p className="text-lg font-semibold text-ink">
                  {elegidos.length} pedido{elegidos.length === 1 ? '' : 's'}
                </p>
                <p className="text-sm text-ink-muted">S/ {totalElegido.toFixed(2)}</p>
              </div>

              <Button loading={guardando} onClick={() => void guardar()}>
                {editando ? 'Guardar cambios' : 'Armar despacho'}
              </Button>
            </div>
          </PageSection>
        </div>
      </div>
    )
  }

  return (
    <ListPage
      icon={<Truck size={20} />}
      title="Despachos"
      description="La carga de cada camión. Los pedidos se convierten en venta cuando el repartidor los entrega."
      actions={
        puede('tms.despachos', 'crear') ? (
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nuevo despacho
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Despachos" value={String(resumen?.total ?? 0)} icon={<Truck size={18} />} />
          <StatCard
            label="Armados"
            value={String(resumen?.armados ?? 0)}
            icon={<Package size={18} />}
            tono="success"
          />
          <StatCard
            label="Pedidos en ruta"
            value={String(resumen?.pedidosEnRuta ?? 0)}
            hint="cargados y sin entregar"
            icon={<Package size={18} />}
            tono="warning"
          />
        </>
      }
      columns={columns}
      rows={despachos}
      cardIcon={Truck}
      searchPlaceholder="Buscar por número, ruta, placa..."
      empty={cargando ? 'Cargando despachos...' : 'Todavía no hay despachos armados.'}
      actionsWidth={150}
      rowActions={(row) => (
        <>
          <RowAction label={`Ver ${row.numero}`} tone="view" onClick={() => setDetalle(row)}>
            <Eye size={15} />
          </RowAction>
          {/* Los papeles de la carga: dos copias por hoja, para el repartidor. */}
          {puede('tms.despachos', 'exportar') && (
            <AccionPdf documento="despacho" id={row.id} numero={row.numero} />
          )}
          {puede('tms.despachos', 'editar') && (
            <RowAction
              label={`Editar ${row.numero}`}
              disabled={row.estado === 'ANULADO'}
              disabledReason="Está anulado"
              onClick={() => abrirEdicion(row)}
            >
              <Pencil size={15} />
            </RowAction>
          )}
          {puede('tms.despachos', 'anular') && (
            <RowAction
              label={`Anular ${row.numero}`}
              tone="danger"
              disabled={row.estado === 'ANULADO' || row.entregados > 0}
              disabledReason={
                row.estado === 'ANULADO' ? 'Ya está anulado' : 'Ya tiene entregas facturadas'
              }
              onClick={() => anular(row)}
            >
              <Undo2 size={15} />
            </RowAction>
          )}
        </>
      )}
    >
      <Modal
        open={detalle !== null}
        size="lg"
        title={detalle ? `${detalle.numero} — ${detalle.ruta}` : ''}
        description={
          detalle
            ? `${detalle.vehiculo} · ${detalle.conductor} · ${new Date(detalle.fecha).toLocaleDateString()}`
            : ''
        }
        onClose={() => setDetalle(null)}
      >
        {detalle && (
          <div className="flex flex-col gap-3">
            {detalle.detalle.map((p) => (
              <div
                key={p.pedidoId}
                className="flex items-start justify-between gap-3 rounded-field border border-line p-3"
              >
                <span className="flex min-w-0 flex-col">
                  <span className="flex items-center gap-2">
                    <Badge>{p.numero}</Badge>
                    <span className="truncate text-sm font-semibold text-ink">{p.cliente}</span>
                  </span>
                  <span className="truncate text-xs text-ink-soft">
                    {[p.mercado, p.direccion].filter(Boolean).join(' — ') || 'Sin dirección'}
                  </span>
                </span>
                <span className="flex flex-col items-end">
                  <span className="text-sm font-semibold text-ink">S/ {p.total.toFixed(2)}</span>
                  {p.notaVentaNumero ? (
                    <Badge tone="success">{p.notaVentaNumero}</Badge>
                  ) : (
                    <span className="text-xs text-ink-soft">sin entregar</span>
                  )}
                </span>
              </div>
            ))}

            {detalle.observacion && (
              <p className="text-sm text-ink-soft">
                <span className="font-semibold text-ink-muted">Observación: </span>
                {detalle.observacion}
              </p>
            )}
          </div>
        )}
      </Modal>

      {dialogo}
    </ListPage>
  )
}
