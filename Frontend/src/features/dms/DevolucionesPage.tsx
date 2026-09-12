import { useCallback, useEffect, useState } from 'react'
import { ArrowLeft, Check, Eye, Plus, Undo2, X } from 'lucide-react'
import {
  Alert,
  Badge,
  BuscadorCampo,
  Button,
  Input,
  ListPage,
  Modal,
  PageHeader,
  PageSection,
  RowAction,
  StatCard,
  useConfirmacion,
} from '../../components/ui'
import type { DataTableColumn, OpcionBuscador } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { notaVentaApi } from '../facturacion'
import type { NotaVentaResponse } from '../facturacion'
import { devolucionApi } from './devolucionApi'
import type {
  DevolucionResponse,
  LineaDevolvible,
  ResumenDevoluciones,
} from './devolucionApi'

function estadoBadge(estado: DevolucionResponse['estado']) {
  if (estado === 'APROBADA') return <Badge tone="success">Aprobada</Badge>
  if (estado === 'RECHAZADA') return <Badge tone="danger">Rechazada</Badge>
  return <Badge tone="warning">Solicitada</Badge>
}

/** Lo que se marca por línea al armar la devolución. */
interface FilaDevolucion {
  cantidad: string
  reingresa: boolean
}

/**
 * Devoluciones de cliente.
 *
 * Nacen de una nota de venta y no mueven nada hasta que alguien las aprueba:
 * quien recibe la mercadería en la calle no es quien decide aceptarla. Al
 * aprobarse entra el stock y la venta baja de importe, con lo que la deuda
 * del cliente baja sola.
 */
export function DevolucionesPage() {
  const { puede } = usePermisos()
  const [vista, setVista] = useState<'lista' | 'form'>('lista')
  const [devoluciones, setDevoluciones] = useState<DevolucionResponse[]>([])
  const [resumen, setResumen] = useState<ResumenDevoluciones | null>(null)
  const [ventas, setVentas] = useState<NotaVentaResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [detalle, setDetalle] = useState<DevolucionResponse | null>(null)

  // --- Formulario ---
  const [venta, setVenta] = useState<NotaVentaResponse | null>(null)
  const [lineas, setLineas] = useState<LineaDevolvible[]>([])
  const [filas, setFilas] = useState<Record<number, FilaDevolucion>>({})
  const [motivo, setMotivo] = useState('')
  const [observacion, setObservacion] = useState('')
  const [cargandoLineas, setCargandoLineas] = useState(false)
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [lista, res] = await Promise.all([devolucionApi.getAll(), devolucionApi.resumen()])
      setDevoluciones(lista)
      setResumen(res)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las devoluciones.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['devoluciones', 'notasventa'], cargar)

  // Catálogos del formulario: no cambian al ir y venir de la lista.
  useEffect(() => {
    void notaVentaApi
      .getAll('CONFIRMADA')
      .then(setVentas)
      .catch(() => {
        /* Sin catálogo la lista sigue sirviendo: solo no se puede registrar. */
      })
  }, [])

  // Al elegir la venta se piden sus líneas con lo que queda por devolver.
  useEffect(() => {
    if (!venta) {
      setLineas([])
      setFilas({})
      return
    }

    let vivo = true
    setCargandoLineas(true)
    void devolucionApi
      .devolvible(venta.id)
      .then((l) => {
        if (!vivo) return
        setLineas(l)
        setFilas(
          Object.fromEntries(
            l.map((x) => [x.notaVentaDetalleId, { cantidad: '', reingresa: true }]),
          ),
        )
      })
      .catch((e) => {
        if (vivo) setErrorForm(e instanceof ApiError ? e.message : 'No pudimos cargar la venta.')
      })
      .finally(() => {
        if (vivo) setCargandoLineas(false)
      })

    return () => {
      vivo = false
    }
  }, [venta])

  const abrirNueva = () => {
    setVenta(null)
    setLineas([])
    setFilas({})
    setMotivo('')
    setObservacion('')
    setErrorForm('')
    setVista('form')
  }

  const cambiar = (id: number, cambio: Partial<FilaDevolucion>) =>
    setFilas((prev) => ({ ...prev, [id]: { ...prev[id], ...cambio } }))

  const total = lineas.reduce((suma, l) => {
    const cantidad = Number(filas[l.notaVentaDetalleId]?.cantidad) || 0
    return suma + cantidad * l.precioUnitario
  }, 0)

  const guardar = async () => {
    if (!venta) return setErrorForm('Elige la venta que se devuelve.')

    const detalleEnviado = lineas
      .map((l) => ({
        notaVentaDetalleId: l.notaVentaDetalleId,
        cantidad: Number(filas[l.notaVentaDetalleId]?.cantidad) || 0,
        reingresaStock: filas[l.notaVentaDetalleId]?.reingresa ?? true,
      }))
      .filter((l) => l.cantidad > 0)

    if (detalleEnviado.length === 0) return setErrorForm('Indica cuánto se devuelve de alguna línea.')

    // El tope se comprueba aquí también para no hacer ir y volver al servidor
    // por algo que ya se ve en pantalla. La regla vive en el backend.
    const pasada = lineas.find((l) => {
      const cantidad = Number(filas[l.notaVentaDetalleId]?.cantidad) || 0
      return cantidad > l.disponible
    })
    if (pasada) {
      return setErrorForm(
        `De ${pasada.producto} solo quedan ${pasada.disponible} por devolver.`,
      )
    }

    setGuardando(true)
    setErrorForm('')
    try {
      await devolucionApi.create({
        notaVentaId: venta.id,
        motivo: motivo.trim() || null,
        observacion: observacion.trim() || null,
        detalle: detalleEnviado,
      })
      setVista('lista')
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

  const aprobar = (d: DevolucionResponse) =>
    confirmar({
      titulo: `Aprobar ${d.numero}`,
      mensaje:
        'Entra la mercadería que vuelve al stock y la venta baja de importe, así que el cliente deja de deberla. No se puede deshacer.',
      confirmar: 'Aprobar',
      accion: async () => {
        setError('')
        try {
          await devolucionApi.aprobar(d.id)
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos aprobar la devolución.')
        }
      },
    })

  const [rechazando, setRechazando] = useState<DevolucionResponse | null>(null)
  const [motivoRechazo, setMotivoRechazo] = useState('')
  const [rechazandoGuardando, setRechazandoGuardando] = useState(false)

  const rechazar = async () => {
    if (!rechazando) return
    if (!motivoRechazo.trim()) return setErrorForm('Di por qué se rechaza.')

    setRechazandoGuardando(true)
    try {
      await devolucionApi.rechazar(rechazando.id, motivoRechazo.trim())
      setRechazando(null)
      setMotivoRechazo('')
      await cargar()
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos rechazar la devolución.')
    } finally {
      setRechazandoGuardando(false)
    }
  }

  const columns: DataTableColumn<DevolucionResponse>[] = [
    { key: 'numero', label: 'Número', render: (row) => <Badge>{row.numero}</Badge> },
    {
      key: 'fecha',
      label: 'Fecha',
      filterType: 'date',
      value: (row) => new Date(row.fecha).getTime(),
      render: (row) => new Date(row.fecha).toLocaleDateString(),
    },
    { key: 'notaVenta', label: 'Venta' },
    { key: 'cliente', label: 'Cliente' },
    { key: 'motivo', label: 'Motivo', render: (row) => row.motivo ?? '—' },
    {
      key: 'total',
      label: 'Importe',
      align: 'right',
      filterable: false,
      render: (row) => `S/ ${row.total.toFixed(2)}`,
    },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'SOLICITADA', label: 'Solicitada' },
        { value: 'APROBADA', label: 'Aprobada' },
        { value: 'RECHAZADA', label: 'Rechazada' },
      ],
      render: (row) => estadoBadge(row.estado),
    },
  ]

  if (vista === 'form') {
    const opciones: OpcionBuscador<NotaVentaResponse>[] = ventas.map((v) => ({
      item: v,
      label: `${v.numero} — ${v.cliente}`,
      detalle: new Date(v.fecha).toLocaleDateString(),
      nota: `S/ ${v.total.toFixed(2)}`,
    }))

    return (
      <div className="flex flex-col gap-4">
        <PageHeader
          icon={<Undo2 size={20} />}
          title="Nueva devolución"
          description="Elige la venta y marca cuánto vuelve de cada línea. No mueve nada hasta que se apruebe."
          actions={
            <Button variant="secondary" size="sm" onClick={() => setVista('lista')}>
              <ArrowLeft size={15} />
              Volver
            </Button>
          }
        />

        {errorForm && <Alert>{errorForm}</Alert>}

        <div className="grid gap-4 lg:grid-cols-[1fr_22rem]">
          <PageSection
            title="Qué se devuelve"
            description="Solo se puede devolver lo que queda: lo ya devuelto antes no cuenta."
          >
            {!venta ? (
              <p className="py-8 text-center text-sm text-ink-soft">
                Elige primero la venta para ver sus productos.
              </p>
            ) : cargandoLineas ? (
              <p className="py-8 text-center text-sm text-ink-soft">Cargando la venta...</p>
            ) : (
              <div className="flex flex-col gap-2">
                {lineas.map((l) => {
                  const fila = filas[l.notaVentaDetalleId] ?? { cantidad: '', reingresa: true }
                  const agotada = l.disponible <= 0

                  return (
                    <div
                      key={l.notaVentaDetalleId}
                      className="flex flex-wrap items-center gap-3 rounded-field border border-line p-3"
                    >
                      <span className="flex min-w-0 flex-1 flex-col">
                        <span className="truncate text-sm font-semibold text-ink">{l.producto}</span>
                        <span className="text-xs text-ink-soft">
                          {l.codigo} · vendidas {l.vendida} {l.presentacion ?? l.unidadBase}
                          {l.devuelta > 0 && ` · ya devueltas ${l.devuelta}`}
                        </span>
                      </span>

                      <div className="w-28">
                        <Input
                          label="Devuelve"
                          type="number"
                          min={0}
                          max={l.disponible}
                          disabled={agotada}
                          value={fila.cantidad}
                          onChange={(e) =>
                            cambiar(l.notaVentaDetalleId, { cantidad: e.target.value })
                          }
                        />
                      </div>

                      {/*
                        Por línea, no por devolución: en la misma caja pueden
                        venir sacos sanos y uno roto.
                      */}
                      <label className="flex w-40 cursor-pointer items-start gap-2 text-xs text-ink-muted">
                        <input
                          type="checkbox"
                          className="mt-0.5"
                          disabled={agotada}
                          checked={fila.reingresa}
                          onChange={(e) =>
                            cambiar(l.notaVentaDetalleId, { reingresa: e.target.checked })
                          }
                        />
                        <span>
                          Vuelve al stock
                          {!fila.reingresa && (
                            <span className="block text-ink-soft">se da de baja como merma</span>
                          )}
                        </span>
                      </label>

                      <span className="w-20 text-right text-sm text-ink-muted">
                        S/ {((Number(fila.cantidad) || 0) * l.precioUnitario).toFixed(2)}
                      </span>
                    </div>
                  )
                })}
              </div>
            )}
          </PageSection>

          <PageSection title="Devolución">
            <div className="flex flex-col gap-4">
              <BuscadorCampo
                label="Nota de venta"
                value={venta}
                onChange={setVenta}
                opciones={opciones}
                placeholder="Buscar por número o cliente..."
                vacio="No hay ventas confirmadas."
              />

              <Input
                label="Motivo"
                placeholder="Producto en mal estado, error en el pedido..."
                value={motivo}
                onChange={(e) => setMotivo(e.target.value)}
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
                <p className="text-xs text-ink-soft">Se le descuenta al cliente</p>
                <p className="text-lg font-semibold text-ink">S/ {total.toFixed(2)}</p>
                <p className="text-xs text-ink-soft">cuando se apruebe</p>
              </div>

              <Button loading={guardando} onClick={() => void guardar()}>
                Registrar devolución
              </Button>
            </div>
          </PageSection>
        </div>
      </div>
    )
  }

  return (
    <ListPage
      icon={<Undo2 size={20} />}
      title="Devoluciones"
      description="Lo que el cliente devuelve de una venta. Entra al stock y se le descuenta cuando se aprueba."
      actions={
        puede('dms.devoluciones', 'crear') ? (
          <Button size="sm" onClick={abrirNueva} iconRight={<Plus size={15} />}>
            Nueva devolución
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard
            label="Devoluciones"
            value={String(resumen?.total ?? 0)}
            icon={<Undo2 size={18} />}
          />
          <StatCard
            label="Por aprobar"
            value={String(resumen?.solicitadas ?? 0)}
            hint="esperando decisión"
            icon={<Check size={18} />}
            tono="warning"
          />
          <StatCard
            label="Aprobadas"
            value={String(resumen?.aprobadas ?? 0)}
            icon={<Check size={18} />}
            tono="success"
          />
          <StatCard
            label="Descontado a clientes"
            value={`S/ ${(resumen?.importe ?? 0).toFixed(2)}`}
            hint="solo lo aprobado"
            icon={<Undo2 size={18} />}
            tono="neutral"
          />
        </>
      }
      columns={columns}
      rows={devoluciones}
      cardIcon={Undo2}
      searchPlaceholder="Buscar por número, venta, cliente..."
      empty={cargando ? 'Cargando devoluciones...' : 'Todavía no hay devoluciones.'}
      actionsWidth={150}
      rowActions={(row) => (
        <>
          <RowAction label={`Ver ${row.numero}`} tone="view" onClick={() => setDetalle(row)}>
            <Eye size={15} />
          </RowAction>

          {puede('dms.devoluciones', 'confirmar') && (
            <RowAction
              label={`Aprobar ${row.numero}`}
              tone="success"
              disabled={row.estado !== 'SOLICITADA'}
              disabledReason={row.estado === 'APROBADA' ? 'Ya fue aprobada' : 'Ya fue rechazada'}
              onClick={() => aprobar(row)}
            >
              <Check size={15} />
            </RowAction>
          )}

          {puede('dms.devoluciones', 'confirmar') && (
            <RowAction
              label={`Rechazar ${row.numero}`}
              tone="danger"
              disabled={row.estado !== 'SOLICITADA'}
              disabledReason={row.estado === 'APROBADA' ? 'Ya fue aprobada' : 'Ya fue rechazada'}
              onClick={() => {
                setRechazando(row)
                setMotivoRechazo('')
                setErrorForm('')
              }}
            >
              <X size={15} />
            </RowAction>
          )}
        </>
      )}
    >
      <Modal
        open={detalle !== null}
        size="lg"
        title={detalle ? `${detalle.numero} — ${detalle.notaVenta}` : ''}
        description={detalle ? `${detalle.cliente} · vuelve a ${detalle.almacen}` : ''}
        onClose={() => setDetalle(null)}
      >
        {detalle && (
          <div className="flex flex-col gap-3">
            {detalle.detalle.map((l) => (
              <div
                key={l.id}
                className="flex items-start justify-between gap-3 rounded-field border border-line p-3"
              >
                <span className="flex min-w-0 flex-col">
                  <span className="truncate text-sm font-semibold text-ink">{l.producto}</span>
                  <span className="text-xs text-ink-soft">
                    {l.cantidadPresentacion} {l.presentacion ?? l.unidadBase} ·{' '}
                    {l.reingresaStock ? 'vuelve al stock' : 'dada de baja como merma'}
                  </span>
                </span>
                <span className="text-sm font-semibold text-ink">S/ {l.importe.toFixed(2)}</span>
              </div>
            ))}

            <div className="flex justify-between border-t border-line pt-3 text-sm">
              <span className="font-semibold text-ink-muted">Total</span>
              <span className="font-semibold text-ink">S/ {detalle.total.toFixed(2)}</span>
            </div>

            {detalle.motivo && (
              <p className="text-sm text-ink-soft">
                <span className="font-semibold text-ink-muted">Motivo: </span>
                {detalle.motivo}
              </p>
            )}

            {/* Quién la resolvió y por qué: sin esto, un rechazo no se explica. */}
            {detalle.estado !== 'SOLICITADA' && (
              <p className="text-sm text-ink-soft">
                <span className="font-semibold text-ink-muted">
                  {detalle.estado === 'APROBADA' ? 'Aprobada por: ' : 'Rechazada por: '}
                </span>
                {detalle.aprobadoPor ?? '—'}
                {detalle.motivoRechazo && ` — ${detalle.motivoRechazo}`}
              </p>
            )}
          </div>
        )}
      </Modal>

      <Modal
        open={rechazando !== null}
        size="sm"
        title={rechazando ? `Rechazar ${rechazando.numero}` : ''}
        description="No entra mercadería ni se le descuenta nada al cliente."
        onClose={() => setRechazando(null)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setRechazando(null)}>
              Cancelar
            </Button>
            <Button size="sm" loading={rechazandoGuardando} onClick={() => void rechazar()}>
              Rechazar
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-3">
          {errorForm && <Alert>{errorForm}</Alert>}
          <Input
            label="Motivo del rechazo"
            placeholder="El cliente no trajo la mercadería"
            value={motivoRechazo}
            onChange={(e) => setMotivoRechazo(e.target.value)}
          />
        </div>
      </Modal>

      {dialogo}
    </ListPage>
  )
}
