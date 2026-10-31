import { useCallback, useEffect, useState } from 'react'
import { Link2Off, RefreshCw } from 'lucide-react'
import { Alert, Badge, Button, useConfirmacion, useToast } from '../../components/ui'
import type { BadgeTone } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { empresaApi } from './empresaApi'
import type { EstadoWhatsApp } from './empresaApi'

/** Lo que se reemplaza en el mensaje al enviarlo. */
export const VARIABLES_WHATSAPP = ['{cliente}', '{tipo}', '{numero}', '{total}', '{empresa}', '{url}'] as const

export const PLANTILLA_WHATSAPP =
  'Hola {cliente} 👋\nTe enviamos tu {tipo} {numero} por {total}.\n\nDescárgala aquí:\n{url}\n\nGracias por tu compra. — {empresa}'

const ESTADOS: Record<string, { texto: string; tono: BadgeTone }> = {
  conectado: { texto: 'Conectado', tono: 'success' },
  'esperando-qr': { texto: 'Esperando que escanees el QR', tono: 'warning' },
  desconectado: { texto: 'Desconectado', tono: 'danger' },
  'sin-servicio': { texto: 'El servicio no responde', tono: 'danger' },
}

interface Props {
  puedeEditar: boolean
  automatico: boolean
  plantilla: string
  onAutomatico: (valor: boolean) => void
  onPlantilla: (valor: string) => void
}

/**
 * El envío de comprobantes por WhatsApp: si el celular de la empresa está vinculado, si cada comprobante aceptado por
 * SUNAT se manda solo, y el mensaje. El enlace del mensaje baja el PDF directo al abrirse.
 */
export function WhatsAppEmpresa({ puedeEditar, automatico, plantilla, onAutomatico, onPlantilla }: Props) {
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()
  const [estado, setEstado] = useState<EstadoWhatsApp | null>(null)
  const [cargando, setCargando] = useState(true)

  const cargar = useCallback(async () => {
    try {
      setEstado(await empresaApi.estadoWhatsApp())
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos consultar el estado de WhatsApp.')
    } finally {
      setCargando(false)
    }
  }, [toast])

  useEffect(() => {
    void cargar()
  }, [cargar])

  // Mientras espera el QR se vuelve a mirar cada pocos segundos: al escanearlo pasa solo a "conectado".
  const esperando = estado?.estado === 'esperando-qr'
  useEffect(() => {
    if (!esperando) return
    const id = window.setInterval(() => void cargar(), 4000)
    return () => window.clearInterval(id)
  }, [esperando, cargar])

  const desvincular = () =>
    confirmar({
      titulo: 'Cambiar el celular de WhatsApp',
      mensaje: 'Se cierra la sesión actual y aparece un QR nuevo para vincular otro celular. Mientras tanto no se envía nada.',
      confirmar: 'Desvincular',
      tono: 'warning',
      accion: async () => {
        try {
          const r = await empresaApi.desvincularWhatsApp()
          toast.exito(r.mensaje)
          // El servicio tarda un momento en sacar el QR nuevo.
          window.setTimeout(() => void cargar(), 1500)
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos desvincular.')
        }
      },
    })

  const info = estado ? (ESTADOS[estado.estado] ?? { texto: estado.estado, tono: 'neutral' as BadgeTone }) : null

  const vistaPrevia = (plantilla.trim() || PLANTILLA_WHATSAPP)
    .replaceAll('{cliente}', 'JUAN PÉREZ')
    .replaceAll('{tipo}', 'boleta')
    .replaceAll('{numero}', 'B001-00000012')
    .replaceAll('{total}', 'S/ 157.00')
    .replaceAll('{empresa}', 'Titanic D')
    .replaceAll('{url}', 'https://tu-dominio/api/publico/comprobante/3f9a…')

  return (
    <div className="space-y-5">
      {/* El celular */}
      <div className="space-y-3 rounded-field border border-line p-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p className="text-sm font-semibold text-ink">Celular de la empresa</p>
            <p className="text-xs text-ink-soft">Desde este WhatsApp salen los comprobantes. Se vincula como WhatsApp Web.</p>
          </div>
          <div className="flex items-center gap-2">
            {info && <Badge tone={info.tono}>{info.texto}</Badge>}
            <Button variant="secondary" size="sm" loading={cargando} onClick={() => void cargar()}>
              <RefreshCw size={14} />
              Actualizar
            </Button>
            {puedeEditar && estado?.estado === 'conectado' && (
              <Button variant="secondary" size="sm" onClick={desvincular}>
                <Link2Off size={14} />
                Cambiar celular
              </Button>
            )}
          </div>
        </div>

        {estado?.faltaToken && (
          <Alert tone="warning">
            Falta el token de WhatsApp en la configuración del servidor (<code>WhatsApp:Token</code>). Sin él no se puede enviar.
          </Alert>
        )}
        {estado?.estado === 'sin-servicio' && (
          <Alert>
            No se pudo hablar con el servicio de WhatsApp. Revisa que <code>distributor-whatsapp</code> esté corriendo en el servidor.
          </Alert>
        )}

        {esperando && estado?.qrImagen && (
          <div className="flex flex-col items-center gap-2 py-2">
            <img src={estado.qrImagen} alt="Código QR para vincular WhatsApp" className="size-56 rounded-field border border-line bg-white p-2" />
            <p className="max-w-sm text-center text-xs text-ink-soft">
              En el celular de la empresa: WhatsApp → Dispositivos vinculados → Vincular un dispositivo, y escanea este código.
            </p>
          </div>
        )}
        {estado?.estado === 'conectado' && estado.enCola > 0 && (
          <p className="text-xs text-ink-soft">
            {estado.enCola} {estado.enCola === 1 ? 'mensaje esperando' : 'mensajes esperando'} su turno: salen con una pausa entre uno y otro.
          </p>
        )}
      </div>

      {/* El envío automático y el mensaje */}
      <div className="space-y-3 rounded-field border border-line p-4">
        <label className="flex cursor-pointer items-start gap-3">
          <input
            type="checkbox"
            checked={automatico}
            disabled={!puedeEditar}
            onChange={(e) => onAutomatico(e.target.checked)}
            className="mt-0.5 size-4 cursor-pointer rounded border-line-strong accent-[rgb(var(--sys-rgb))]"
          />
          <span>
            <span className="block text-sm font-semibold text-ink">Enviar cada comprobante aceptado por WhatsApp</span>
            <span className="block text-xs text-ink-soft">
              Cuando SUNAT acepta una factura, boleta o nota, se manda una sola vez al teléfono del cliente. Si el cliente no tiene teléfono o falla,
              queda anotado en el comprobante y se puede enviar a mano. En modo pruebas el mensaje lo dice.
            </span>
          </span>
        </label>

        <div>
          <div className="mb-1 flex flex-wrap items-center justify-between gap-2">
            <label htmlFor="plantilla-wa" className="text-sm font-medium text-ink">
              Mensaje
            </label>
            {puedeEditar && (
              <button type="button" className="text-xs text-[rgb(var(--sys-ink-rgb))] hover:underline" onClick={() => onPlantilla('')}>
                Usar el mensaje de siempre
              </button>
            )}
          </div>
          <textarea
            id="plantilla-wa"
            rows={6}
            maxLength={1000}
            disabled={!puedeEditar}
            value={plantilla}
            placeholder={PLANTILLA_WHATSAPP}
            onChange={(e) => onPlantilla(e.target.value)}
            className="w-full rounded-field border border-line-strong bg-white px-3 py-2 text-sm outline-none focus:border-[rgb(var(--sys-rgb))] disabled:bg-surface-muted"
          />
          <p className="mt-1 text-xs text-ink-soft">
            Variables: {VARIABLES_WHATSAPP.map((v) => <code key={v} className="mr-1.5 rounded bg-surface-muted px-1">{v}</code>)}
            El enlace siempre se agrega, aunque lo quites del texto.
          </p>
        </div>

        <div>
          <p className="mb-1 text-xs font-medium text-ink-soft">Así lo recibe el cliente</p>
          <pre className="rounded-field bg-[#dcf8c6] px-3 py-2 font-sans text-[13px] whitespace-pre-wrap text-zinc-800">{vistaPrevia}</pre>
          <p className="mt-1.5 text-xs text-ink-soft">
            El enlace descarga el PDF directo al abrirlo: no abre ninguna página, el navegador baja el archivo y termina.
          </p>
        </div>
      </div>
      {dialogo}
    </div>
  )
}
