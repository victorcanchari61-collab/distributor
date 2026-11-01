import { useState } from 'react'
import { MessageCircle } from 'lucide-react'
import { Badge, Button } from '../../components/ui'
import { fechaHora } from '../../lib/fechas'
import { ESTADOS_WHATSAPP } from './comprobanteApi'
import type { ComprobanteResponse } from './comprobanteApi'
import { EnviarWhatsAppModal } from './EnviarWhatsAppModal'

/**
 * El envío por WhatsApp de un comprobante aceptado, en su detalle: en qué quedó y el botón "Enviar documento", que
 * abre el diálogo con el número del cliente (editable) para mandarlo o reenviarlo.
 */
export function WhatsAppComprobante({
  comprobante: c,
  onCambio,
}: {
  comprobante: ComprobanteResponse
  onCambio: (c: ComprobanteResponse) => void
}) {
  const [abierto, setAbierto] = useState(false)
  const estado = c.whatsAppEstado ? ESTADOS_WHATSAPP[c.whatsAppEstado] : null

  return (
    <div className="rounded-panel border border-line p-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="flex items-center gap-1.5 text-sm font-medium text-ink">
          <MessageCircle size={15} /> WhatsApp
        </p>
        <div className="flex items-center gap-2">
          {estado ? <Badge tone={estado.tone}>{estado.label}</Badge> : <Badge>Sin enviar</Badge>}
          <Button variant="secondary" size="sm" onClick={() => setAbierto(true)}>
            <MessageCircle size={15} /> {c.whatsAppEstado === 'ENCOLADO' ? 'Reenviar documento' : 'Enviar documento'}
          </Button>
        </div>
      </div>

      {estado && (
        <p className="mt-1.5 text-xs text-ink-soft">
          {c.whatsAppEstado === 'ENCOLADO' && c.whatsAppTelefono && c.whatsAppEnviadoEn
            ? `A ${c.whatsAppTelefono} · ${fechaHora(c.whatsAppEnviadoEn)}`
            : (c.whatsAppError ?? '')}
        </p>
      )}

      <EnviarWhatsAppModal comprobante={abierto ? c : null} onClose={() => setAbierto(false)} onEnviado={onCambio} />
    </div>
  )
}
