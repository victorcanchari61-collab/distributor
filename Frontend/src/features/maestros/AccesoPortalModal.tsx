import { useEffect, useState } from 'react'
import { Check, Copy, MessageCircle, Send, ShieldCheck, ShieldOff } from 'lucide-react'
import { Alert, Badge, Button, Modal, useToast } from '../../components/ui'
import type { BadgeTone } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaHora } from '../../lib/fechas'
import { clienteApi } from './clienteApi'
import type { AccesoPortal, InvitacionPortal } from './clienteApi'

const ESTADOS: Record<AccesoPortal['estado'], { etiqueta: string; tono: BadgeTone; ayuda: string }> = {
  SIN_INVITAR: {
    etiqueta: 'Sin invitar',
    tono: 'neutral',
    ayuda: 'Todavía no puede entrar. Al invitarlo le llega un WhatsApp con un enlace para crear su usuario y contraseña.',
  },
  INVITADO: { etiqueta: 'Invitado', tono: 'warning', ayuda: 'Ya tiene el enlace, pero todavía no creó su acceso.' },
  ACTIVO: { etiqueta: 'Activo', tono: 'success', ayuda: 'Ya entra al portal con su usuario y manda sus cotizaciones.' },
  DESACTIVADO: {
    etiqueta: 'Desactivado',
    tono: 'danger',
    ayuda: 'No puede entrar. Al activarlo vuelve a entrar con el mismo usuario y contraseña.',
  },
}

/**
 * El acceso de un cliente al portal de cotizaciones (/portal): invitarlo (WhatsApp con el enlace para que él mismo
 * cree su usuario y contraseña), ver si ya entró, y prenderlo o apagarlo. El vendedor no crea ni conoce su contraseña.
 */
export function AccesoPortalModal({
  cliente,
  onClose,
  puedeEditar,
}: {
  cliente: { id: number; nombre: string } | null
  onClose: () => void
  puedeEditar: boolean
}) {
  const toast = useToast()
  const [acceso, setAcceso] = useState<AccesoPortal | null>(null)
  const [invitacion, setInvitacion] = useState<InvitacionPortal | null>(null)
  const [error, setError] = useState('')
  const [trabajando, setTrabajando] = useState(false)
  const [copiado, setCopiado] = useState(false)

  useEffect(() => {
    if (!cliente) return
    let vigente = true
    clienteApi
      .portal(cliente.id)
      .then((a) => {
        if (!vigente) return
        setAcceso(a)
        setInvitacion(null)
        setError('')
      })
      .catch((e) => vigente && setError(e instanceof ApiError ? e.message : 'No pudimos ver su acceso.'))
    return () => {
      vigente = false
    }
  }, [cliente])

  const invitar = async () => {
    if (!cliente) return
    setTrabajando(true)
    try {
      const r = await clienteApi.invitarPortal(cliente.id)
      setInvitacion(r)
      setAcceso(r.acceso)
      if (r.enviadoPorWhatsApp) toast.exito('Invitación enviada por WhatsApp')
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos invitarlo.')
    } finally {
      setTrabajando(false)
    }
  }

  const cambiarActivo = async (activo: boolean) => {
    if (!cliente) return
    setTrabajando(true)
    try {
      setAcceso(await clienteApi.portalActivo(cliente.id, activo))
      toast.exito(activo ? 'Acceso activado' : 'Acceso desactivado: ya no puede entrar')
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos cambiar su acceso.')
    } finally {
      setTrabajando(false)
    }
  }

  const copiar = async () => {
    if (!invitacion) return
    try {
      await navigator.clipboard.writeText(invitacion.enlace)
      setCopiado(true)
      setTimeout(() => setCopiado(false), 2000)
    } catch {
      toast.error('No se pudo copiar: selecciona el enlace y cópialo a mano.')
    }
  }

  // Mientras carga el de otro cliente no se muestra el del anterior.
  const vigente = acceso && cliente ? acceso : null
  const estado = vigente ? ESTADOS[vigente.estado] : null

  return (
    <Modal
      open={cliente !== null}
      onClose={() => {
        setAcceso(null)
        setInvitacion(null)
        onClose()
      }}
      title="Acceso al portal de cotizaciones"
      description={cliente?.nombre}
      size="md"
    >
      {error ? (
        <Alert tone="error">{error}</Alert>
      ) : !vigente || !estado ? (
        <p className="text-sm text-ink-muted">Cargando…</p>
      ) : (
        <div className="space-y-4">
          <div className="space-y-2 rounded-xl border border-line p-4">
            <div className="flex items-center justify-between gap-3">
              <span className="text-sm font-medium text-ink-muted">Estado</span>
              <Badge tone={estado.tono}>{estado.etiqueta}</Badge>
            </div>
            <p className="text-sm text-ink-muted">{estado.ayuda}</p>
            <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 pt-1 text-sm">
              {vigente.usuario && (
                <>
                  <dt className="text-ink-soft">Usuario</dt>
                  <dd className="font-medium text-ink">{vigente.usuario}</dd>
                </>
              )}
              <dt className="text-ink-soft">WhatsApp</dt>
              <dd className="text-ink">
                {vigente.telefono ?? <span className="text-amber-700">Sin teléfono en su ficha</span>}
              </dd>
              {vigente.fechaInvitacion && (
                <>
                  <dt className="text-ink-soft">Invitado</dt>
                  <dd className="text-ink">
                    {fechaHora(vigente.fechaInvitacion)}
                    {vigente.invitadoPor ? ` · por ${vigente.invitadoPor}` : ''}
                  </dd>
                </>
              )}
              {vigente.invitacionVence && (
                <>
                  <dt className="text-ink-soft">El enlace vence</dt>
                  <dd className="text-ink">{fechaHora(vigente.invitacionVence)}</dd>
                </>
              )}
              {vigente.ultimoIngreso && (
                <>
                  <dt className="text-ink-soft">Último ingreso</dt>
                  <dd className="text-ink">{fechaHora(vigente.ultimoIngreso)}</dd>
                </>
              )}
            </dl>
          </div>

          {invitacion && (
            <div className="space-y-2">
              {invitacion.enviadoPorWhatsApp ? (
                <Alert tone="info">
                  <span className="inline-flex items-center gap-1.5">
                    <MessageCircle className="size-4" aria-hidden /> Le llegó el enlace por WhatsApp.
                  </span>
                </Alert>
              ) : (
                <Alert tone="warning">
                  No salió por WhatsApp: {invitacion.motivoNoEnviado} Copia el enlace y mándaselo tú.
                </Alert>
              )}
              <div className="flex items-center gap-2">
                <input
                  readOnly
                  value={invitacion.enlace}
                  onFocus={(e) => e.currentTarget.select()}
                  aria-label="Enlace de invitación"
                  className="min-w-0 flex-1 rounded-lg border border-line bg-surface px-3 py-2 text-xs text-ink-muted"
                />
                <Button
                  size="sm"
                  variant="secondary"
                  onClick={() => void copiar()}
                  iconRight={copiado ? <Check size={15} /> : <Copy size={15} />}
                >
                  {copiado ? 'Copiado' : 'Copiar'}
                </Button>
              </div>
              <p className="text-xs text-ink-soft">El enlace sirve una sola vez y vence en 7 días.</p>
            </div>
          )}

          {puedeEditar && (
            <div className="flex flex-wrap gap-2">
              {vigente.estado !== 'DESACTIVADO' && (
                <Button size="sm" loading={trabajando} onClick={() => void invitar()} iconRight={<Send size={15} />}>
                  {vigente.estado === 'SIN_INVITAR' ? 'Invitar al portal' : 'Volver a enviar invitación'}
                </Button>
              )}
              {vigente.estado === 'DESACTIVADO' ? (
                <Button
                  size="sm"
                  loading={trabajando}
                  onClick={() => void cambiarActivo(true)}
                  iconRight={<ShieldCheck size={15} />}
                >
                  Activar acceso
                </Button>
              ) : (
                vigente.estado !== 'SIN_INVITAR' && (
                  <Button
                    size="sm"
                    variant="secondary"
                    loading={trabajando}
                    onClick={() => void cambiarActivo(false)}
                    iconRight={<ShieldOff size={15} />}
                  >
                    Desactivar acceso
                  </Button>
                )
              )}
            </div>
          )}
          {vigente.estado === 'ACTIVO' && puedeEditar && (
            <p className="text-xs text-ink-soft">
              Volver a enviar la invitación le deja elegir usuario y contraseña de nuevo. Si solo olvidó la contraseña,
              puede pedir una nueva él mismo desde el portal.
            </p>
          )}
        </div>
      )}
    </Modal>
  )
}
