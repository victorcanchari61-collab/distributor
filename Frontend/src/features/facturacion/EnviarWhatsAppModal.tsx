import { useEffect, useState } from 'react'
import { Loader2, MessageCircle } from 'lucide-react'
import { Alert, Button, Input, Modal, useToast } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaHora } from '../../lib/fechas'
import { comprobanteApi } from './comprobanteApi'
import type { ComprobanteResponse } from './comprobanteApi'

/**
 * "Enviar documento": manda por WhatsApp el enlace que descarga el PDF del comprobante. Muestra el número al que va
 * —el del cliente, o el último al que se mandó— y se puede cambiar ahí mismo, solo para este envío.
 */
export function EnviarWhatsAppModal({
  comprobante,
  onClose,
  onEnviado,
}: {
  /** El comprobante a enviar; nulo con el modal cerrado. */
  comprobante: ComprobanteResponse | null
  onClose: () => void
  onEnviado: (c: ComprobanteResponse) => void
}) {
  const toast = useToast()
  const [telefono, setTelefono] = useState('')
  const [enviando, setEnviando] = useState(false)
  const [error, setError] = useState('')

  // Al abrir se propone el número del cliente; si ya se mandó antes, el último al que salió.
  useEffect(() => {
    if (!comprobante) return
    setTelefono(comprobante.clienteTelefono ?? comprobante.whatsAppTelefono ?? '')
    setError('')
  }, [comprobante])

  if (!comprobante) return null

  const c = comprobante
  const delCliente = c.clienteTelefono ?? ''
  const cambiado = telefono.trim() !== '' && delCliente !== '' && telefono.replace(/\D/g, '') !== delCliente.replace(/\D/g, '')
  const valido = telefono.replace(/\D/g, '').length >= 9

  const enviar = async () => {
    setEnviando(true)
    setError('')
    try {
      const nuevo = await comprobanteApi.enviarWhatsApp(c.id, telefono)
      onEnviado(nuevo)
      toast.exito(`${c.numeroCompleto} enviado a la cola de WhatsApp: sale en unos segundos`)
      onClose()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos enviar el comprobante por WhatsApp')
      // El intento queda anotado en el comprobante: se muestra al refrescar.
      try {
        onEnviado(await comprobanteApi.obtener(c.id))
      } catch {
        /* sin respuesta: se queda como estaba */
      }
    } finally {
      setEnviando(false)
    }
  }

  return (
    <Modal
      open
      size="sm"
      title="Enviar documento"
      description={`${c.tipoNombre} ${c.numeroCompleto}`}
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" disabled={enviando} onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={enviando} disabled={!valido} onClick={() => void enviar()}>
            <MessageCircle size={15} /> Enviar por WhatsApp
          </Button>
        </>
      }
    >
      <div className="relative flex flex-col gap-4">
        {error && <Alert>{error}</Alert>}

        {/* Mientras sale: se tapa el formulario y se ve que está trabajando, para no tocar Enviar dos veces. */}
        {enviando && (
          <div
            role="status"
            className="absolute inset-0 z-10 flex flex-col items-center justify-center gap-2 rounded-field bg-white/85 backdrop-blur-[1px]"
          >
            <Loader2 size={30} className="animate-spin text-emerald-600" />
            <p className="text-sm font-medium text-ink">Enviando por WhatsApp…</p>
          </div>
        )}

        <div className="rounded-field bg-surface-muted px-3 py-2.5 text-sm">
          <p className="font-medium text-ink">{c.clienteNombre}</p>
          <p className="text-xs text-ink-soft">
            {c.numeroCompleto} · S/ {c.total.toFixed(2)}
          </p>
        </div>

        <Input
          label="Número de WhatsApp"
          inputMode="tel"
          autoFocus
          placeholder="987654321"
          value={telefono}
          onChange={(e) => setTelefono(e.target.value)}
          error={telefono !== '' && !valido ? 'Escribe un número de al menos 9 dígitos' : undefined}
        />
        <p className="-mt-2 text-xs text-ink-soft">
          {delCliente === ''
            ? 'El cliente no tiene teléfono guardado: escríbelo para enviarlo.'
            : cambiado
              ? `Solo para este envío: el cliente sigue con ${delCliente}.`
              : 'Es el número del cliente. Puedes cambiarlo aquí mismo.'}
        </p>

        {c.whatsAppEstado === 'ENCOLADO' && c.whatsAppTelefono && c.whatsAppEnviadoEn && (
          <p className="text-xs text-ink-soft">
            Ya se envió a {c.whatsAppTelefono} el {fechaHora(c.whatsAppEnviadoEn)}. Si lo envías otra vez, le llega de nuevo.
          </p>
        )}
        <p className="text-xs text-ink-soft">El cliente recibe un enlace que descarga el PDF directamente.</p>
      </div>
    </Modal>
  )
}
