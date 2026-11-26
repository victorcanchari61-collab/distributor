import { useEffect, useState } from 'react'
import { MessageSquareQuote } from 'lucide-react'
import { Alert, Badge, Button, Modal } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaHora } from '../../lib/fechas'
import { cotizacionApi } from './cotizacionApi'
import type { Cotizacion } from './cotizacionApi'

const soles = (n: number) => `S/ ${n.toLocaleString('es-PE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`

/**
 * Elegir una cotización en espera para armar el pedido con ella. Si el pedido ya tiene cliente, muestra solo las de
 * ese cliente; si no, todas las que le tocan a quien vende (el mismo alcance que en Pedidos).
 */
export function JalarCotizacionModal({
  abierto,
  clienteId,
  clienteNombre,
  onCerrar,
  onElegir,
}: {
  abierto: boolean
  clienteId: number
  clienteNombre: string
  onCerrar: () => void
  onElegir: (cotizacion: Cotizacion) => void
}) {
  const [cotizaciones, setCotizaciones] = useState<Cotizacion[] | null>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!abierto) return
    let vigente = true
    cotizacionApi
      .listar({ estado: 'EN_ESPERA', clienteId: clienteId || undefined })
      .then((r) => {
        if (!vigente) return
        setCotizaciones(r)
        setError('')
      })
      .catch((e) => vigente && setError(e instanceof ApiError ? e.message : 'No pudimos cargar las cotizaciones.'))
    return () => {
      vigente = false
      setCotizaciones(null)
    }
  }, [abierto, clienteId])

  return (
    <Modal
      open={abierto}
      onClose={onCerrar}
      title="Jalar cotización"
      description={
        clienteId
          ? `Las que mandó ${clienteNombre} desde el portal y siguen en espera.`
          : 'Las que mandaron tus clientes desde el portal y siguen en espera.'
      }
      size="lg"
    >
      {error ? (
        <Alert>{error}</Alert>
      ) : !cotizaciones ? (
        <p className="text-sm text-ink-muted">Cargando…</p>
      ) : cotizaciones.length === 0 ? (
        <div className="flex flex-col items-center gap-2 py-8 text-center">
          <MessageSquareQuote className="size-8 text-ink-soft" aria-hidden />
          <p className="font-medium text-ink">No hay cotizaciones en espera{clienteId ? ' de este cliente' : ''}</p>
          <p className="text-sm text-ink-muted">Aparecen aquí apenas el cliente las manda desde el portal.</p>
        </div>
      ) : (
        <ul className="divide-y divide-line overflow-hidden rounded-xl border border-line">
          {cotizaciones.map((c) => (
            <li key={c.id} className="flex flex-wrap items-center justify-between gap-3 bg-surface px-4 py-3">
              <div className="min-w-0">
                <p className="flex flex-wrap items-center gap-2 font-medium text-ink">
                  <Badge>{c.numero}</Badge> {c.cliente}
                </p>
                <p className="mt-0.5 text-xs text-ink-muted">
                  {fechaHora(c.fecha)} · {c.detalle.length} {c.detalle.length === 1 ? 'producto' : 'productos'} ·{' '}
                  {soles(c.total)}
                </p>
                {c.nota && <p className="mt-1 text-xs text-amber-800">Nota: {c.nota}</p>}
              </div>
              <Button size="sm" onClick={() => onElegir(c)}>
                Jalar
              </Button>
            </li>
          ))}
        </ul>
      )}
    </Modal>
  )
}
