import { useEffect, useState } from 'react'
import { PackageCheck, Search } from 'lucide-react'
import {
  Alert,
  Badge,
  BuscadorModal,
  Button,
  Desplegable,
  Input,
  Modal,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import type { AlmacenResponse, CrearRecepcionRequest } from '../inventario'
import { recepcionApi } from '../inventario'
import type { CompraResponse } from './comprasApi'

export interface NuevaRecepcionModalProps {
  open: boolean
  onClose: () => void
  /** Si viene fijada (desde "Recibir" en una fila de Mis compras), se salta el buscador. */
  compraFija?: CompraResponse | null
  /** Compras Pendiente o Recibida parcial, para elegir cuando no viene fijada. */
  compras: CompraResponse[]
  almacenes: AlmacenResponse[]
  onCreada: () => void
}

/**
 * Registrar que llegó mercadería de una compra, total o parcialmente.
 *
 * Es más chico que el formulario de una orden/compra: no arma líneas nuevas,
 * solo dice cuánto de lo YA pactado llegó ahora. Por eso sí cabe en un modal.
 */
export function NuevaRecepcionModal({
  open,
  onClose,
  compraFija,
  compras,
  almacenes,
  onCreada,
}: NuevaRecepcionModalProps) {
  const [compra, setCompra] = useState<CompraResponse | null>(compraFija ?? null)
  const [buscadorAbierto, setBuscadorAbierto] = useState(false)
  const [almacenId, setAlmacenId] = useState(0)
  const [observacion, setObservacion] = useState('')
  const [cantidades, setCantidades] = useState<Record<number, string>>({})
  const [lotes, setLotes] = useState<Record<number, string>>({})
  const [vencimientos, setVencimientos] = useState<Record<number, string>>({})
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!open) return
    const inicial = compraFija ?? null
    setCompra(inicial)
    setAlmacenId(almacenes.find((a) => a.esPrincipal)?.id ?? almacenes[0]?.id ?? 0)
    setObservacion('')
    setError('')
    setCantidades(
      inicial
        ? Object.fromEntries(
            inicial.detalle
              .filter((d) => d.cantidadPendiente > 0)
              .map((d) => [d.id, String(d.cantidadPendiente)]),
          )
        : {},
    )
    setLotes({})
    setVencimientos({})
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, compraFija])

  const elegirCompra = (c: CompraResponse) => {
    setCompra(c)
    setCantidades(
      Object.fromEntries(
        c.detalle.filter((d) => d.cantidadPendiente > 0).map((d) => [d.id, String(d.cantidadPendiente)]),
      ),
    )
    setLotes({})
    setVencimientos({})
  }

  const guardar = async () => {
    if (!compra) return setError('Elige la compra.')
    if (!almacenId) return setError('Elige el almacén.')

    const detalle = compra.detalle
      .map((d) => ({
        compraDetalleId: d.id,
        cantidad: Number(cantidades[d.id] || 0),
        lote: lotes[d.id]?.trim() || null,
        fechaVencimiento: vencimientos[d.id] || null,
      }))
      .filter((l) => l.cantidad > 0)

    if (detalle.length === 0) return setError('Indica cuánto llegó.')

    const body: CrearRecepcionRequest = {
      compraId: compra.id,
      almacenId,
      observacion: observacion.trim() || null,
      detalle,
    }

    setGuardando(true)
    setError('')
    try {
      await recepcionApi.create(body)
      onClose()
      onCreada()
    } catch (e) {
      setError(
        e instanceof ApiError ? (e.errors.length ? e.errors.join(' ') : e.message) : 'No pudimos registrar la recepción.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const columnasCompra: DataTableColumn<CompraResponse>[] = [
    { key: 'numero', label: 'Número', render: (row) => <Badge>{row.numero}</Badge> },
    { key: 'proveedor', label: 'Proveedor' },
    {
      key: 'estado',
      label: 'Estado',
      render: (row) => (
        <Badge tone={row.estado === 'RECIBIDA_PARCIAL' ? 'warning' : 'neutral'}>
          {row.estado === 'RECIBIDA_PARCIAL' ? 'Parcial' : 'Pendiente'}
        </Badge>
      ),
    },
    { key: 'total', label: 'Total', align: 'right', render: (row) => `S/ ${row.total.toFixed(2)}` },
  ]

  return (
    <>
      <Modal
        open={open}
        title="Nueva recepción"
        description="Cuánto de lo pactado llegó ahora. Puede ser parcial."
        onClose={onClose}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={onClose}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()} disabled={!compra}>
              Registrar recepción
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {error && <Alert>{error}</Alert>}

          <div>
            <span className="ui-label mb-1.5 block">Compra</span>
            {compraFija ? (
              <div className="flex items-center gap-2 rounded-field border border-line px-3 py-2 text-sm">
                <Badge>{compraFija.numero}</Badge>
                <span className="text-ink">{compraFija.proveedor}</span>
              </div>
            ) : (
              <button
                type="button"
                onClick={() => setBuscadorAbierto(true)}
                className="flex h-[var(--height-field-md)] w-full items-center justify-between gap-2 rounded-field border border-line px-3 text-left text-sm hover:bg-surface-alt"
              >
                <span className={compra ? 'text-ink' : 'text-ink-soft'}>
                  {compra ? `${compra.numero} · ${compra.proveedor}` : 'Buscar compra...'}
                </span>
                <Search size={15} className="shrink-0 text-ink-soft" />
              </button>
            )}
          </div>

          <Desplegable
            label="Almacén de destino"
            value={almacenId}
            onChange={(v) => setAlmacenId(Number(v))}
            options={almacenes
              .filter((a) => a.activo)
              .map((a) => ({ value: a.id, label: a.nombre, detalle: a.codigo }))}
          />

          <Input
            label="Observación"
            optional
            placeholder="Guía de remisión, referencia..."
            value={observacion}
            onChange={(e) => setObservacion(e.target.value)}
          />

          {compra && (
            <>
              <hr className="border-line" />
              <p className="text-sm font-semibold text-ink">Qué llegó</p>
              <ul className="flex flex-col gap-2">
                {compra.detalle
                  .filter((d) => d.cantidadPendiente > 0)
                  .map((d) => (
                    <li key={d.id} className="rounded-field border border-line p-3">
                      <div className="grid grid-cols-[1fr_8rem] items-end gap-2">
                        <div>
                          <p className="text-sm font-medium text-ink">{d.producto}</p>
                          <p className="text-xs text-ink-soft">
                            Pendiente: {d.cantidadPendiente} {d.unidadBase} de {d.cantidad}
                          </p>
                        </div>
                        <Input
                          label={`Llegó (${d.unidadBase})`}
                          type="number"
                          step="0.0001"
                          max={d.cantidadPendiente}
                          value={cantidades[d.id] ?? ''}
                          onChange={(e) => setCantidades({ ...cantidades, [d.id]: e.target.value })}
                        />
                      </div>
                      <div className="mt-2 grid grid-cols-2 gap-2">
                        <Input
                          label="Lote"
                          optional
                          placeholder="Opcional"
                          value={lotes[d.id] ?? ''}
                          onChange={(e) => setLotes({ ...lotes, [d.id]: e.target.value })}
                        />
                        <Input
                          label="Vencimiento"
                          optional
                          type="date"
                          value={vencimientos[d.id] ?? ''}
                          onChange={(e) => setVencimientos({ ...vencimientos, [d.id]: e.target.value })}
                        />
                      </div>
                    </li>
                  ))}
              </ul>
            </>
          )}
        </div>
      </Modal>

      {!compraFija && (
        <BuscadorModal
          open={buscadorAbierto}
          onClose={() => setBuscadorAbierto(false)}
          title="Elegir compra"
          description="Solo las que aún tienen algo pendiente de recibir."
          columns={columnasCompra}
          rows={compras}
          cardIcon={PackageCheck}
          searchPlaceholder="Buscar por número, proveedor..."
          onSeleccionar={elegirCompra}
        />
      )}
    </>
  )
}
