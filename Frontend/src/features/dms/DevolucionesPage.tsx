import { useCallback, useEffect, useState } from 'react'
import { Check, Eye, Undo2, X } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Input,
  ListPage,
  Modal,
  RowAction,
  StatCard,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { devolucionApi } from './devolucionApi'
import type { DevolucionResponse, ResumenDevoluciones } from './devolucionApi'

function estadoBadge(estado: DevolucionResponse['estado']) {
  if (estado === 'APROBADA') return <Badge tone="success">Aprobada</Badge>
  if (estado === 'RECHAZADA') return <Badge tone="danger">Rechazada</Badge>
  return <Badge tone="warning">Solicitada</Badge>
}

/**
 * Devoluciones de cliente.
 *
 * Aqui no se registra ninguna: nacen de editarle la cantidad a una nota de
 * venta, que es donde de verdad ocurre —el cliente trae de vuelta parte de lo
 * que se llevo—. Esta pantalla es para verlas todas juntas y resolverlas, que
 * es lo que no se puede hacer venta por venta.
 *
 * Ninguna mueve nada hasta que se aprueba: quien recibe la mercaderia en la
 * calle no es quien decide aceptarla. Al aprobarse entra el stock y la venta
 * baja de importe, con lo que la deuda del cliente baja sola.
 */
export function DevolucionesPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const [devoluciones, setDevoluciones] = useState<DevolucionResponse[]>([])
  const [resumen, setResumen] = useState<ResumenDevoluciones | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [detalle, setDetalle] = useState<DevolucionResponse | null>(null)

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
          toast.exito(`${d.numero} aprobada`)
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
      toast.exito('Devolución rechazada')
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

  return (
    <ListPage
      icon={<Undo2 size={20} />}
      title="Devoluciones"
      description="Lo que el cliente devuelve, registrado al editarle la cantidad a su nota de venta. Entra al stock y se le descuenta cuando se aprueba."
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
