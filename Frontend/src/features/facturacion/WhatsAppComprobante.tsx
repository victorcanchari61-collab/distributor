import { useState } from 'react'
import { MessageCircle } from 'lucide-react'
import { Badge, Button, Input, useToast } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaHora } from '../../lib/fechas'
import { ESTADOS_WHATSAPP, comprobanteApi } from './comprobanteApi'
import type { ComprobanteResponse } from './comprobanteApi'

/**
 * El envío por WhatsApp de un comprobante aceptado: en qué quedó y el botón para mandarlo (o reenviarlo). Sin teléfono
 * escrito usa el del cliente; con uno escrito, lo manda a ese número.
 */
export function WhatsAppComprobante({
  comprobante: c,
  onCambio,
}: {
  comprobante: ComprobanteResponse
  onCambio: (c: ComprobanteResponse) => void
}) {
  const toast = useToast()
  const [telefono, setTelefono] = useState('')
  const [enviando, setEnviando] = useState(false)

  const estado = c.whatsAppEstado ? ESTADOS_WHATSAPP[c.whatsAppEstado] : null

  const enviar = async () => {
    setEnviando(true)
    try {
      const nuevo = await comprobanteApi.enviarWhatsApp(c.id, telefono)
      onCambio(nuevo)
      setTelefono('')
      toast.exito('Enviado a la cola de WhatsApp: sale en unos segundos')
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos enviar el comprobante por WhatsApp')
      // El intento queda anotado en el comprobante (sin teléfono, falló...): se muestra al refrescar.
      try {
        onCambio(await comprobanteApi.obtener(c.id))
      } catch {
        /* sin respuesta: se queda como estaba */
      }
    } finally {
      setEnviando(false)
    }
  }

  return (
    <div className="rounded-panel border border-line p-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="flex items-center gap-1.5 text-sm font-medium text-ink">
          <MessageCircle size={15} /> WhatsApp
        </p>
        {estado ? <Badge tone={estado.tone}>{estado.label}</Badge> : <Badge>Sin enviar</Badge>}
      </div>

      {estado && (
        <p className="mt-1.5 text-xs text-ink-soft">
          {c.whatsAppEstado === 'ENCOLADO' && c.whatsAppTelefono && c.whatsAppEnviadoEn
            ? `A ${c.whatsAppTelefono} · ${fechaHora(c.whatsAppEnviadoEn)}`
            : (c.whatsAppError ?? '')}
        </p>
      )}

      <div className="mt-2 flex flex-wrap items-end gap-2">
        <Input
          size="sm"
          className="w-48"
          inputMode="tel"
          aria-label="Teléfono"
          placeholder="Teléfono (si no, el del cliente)"
          value={telefono}
          onChange={(e) => setTelefono(e.target.value)}
        />
        <Button variant="secondary" size="sm" loading={enviando} onClick={() => void enviar()}>
          <MessageCircle size={15} /> {c.whatsAppEstado === 'ENCOLADO' ? 'Reenviar' : 'Enviar'}
        </Button>
      </div>
    </div>
  )
}
