import { Fragment, useCallback, useEffect, useRef, useState } from 'react'
import { CheckCheck, FileDown, Link2Off, MessageCircle, RefreshCw, ServerOff, Smartphone, Wifi } from 'lucide-react'
import { Button, cn, useConfirmacion, useToast } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { empresaApi } from './empresaApi'
import type { EstadoWhatsApp } from './empresaApi'

/** Lo que se reemplaza en el mensaje al enviarlo, con lo que significa cada una. */
const VARIABLES = [
  { clave: '{cliente}', ayuda: 'Nombre del cliente' },
  { clave: '{tipo}', ayuda: 'factura, boleta, nota de crédito…' },
  { clave: '{numero}', ayuda: 'Serie y número: B001-00000012' },
  { clave: '{total}', ayuda: 'Importe: S/ 157.00' },
  { clave: '{empresa}', ayuda: 'Nombre comercial de la empresa' },
  { clave: '{url}', ayuda: 'Enlace que descarga el PDF' },
] as const

export const PLANTILLA_WHATSAPP =
  'Hola {cliente} 👋\nTe enviamos tu {tipo} {numero} por {total}.\n\nDescárgala aquí:\n{url}\n\nGracias por tu compra. — {empresa}'

type Tono = 'verde' | 'ambar' | 'rojo' | 'gris'

const ESTADOS: Record<string, { texto: string; detalle: string; tono: Tono }> = {
  conectado: { texto: 'Conectado', detalle: 'Listo para enviar comprobantes', tono: 'verde' },
  'esperando-qr': { texto: 'Esperando vinculación', detalle: 'Escanea el código con el celular de la empresa', tono: 'ambar' },
  desconectado: { texto: 'Desconectado', detalle: 'Se está reconectando…', tono: 'rojo' },
  'sin-servicio': { texto: 'Servicio apagado', detalle: 'No se pudo hablar con el servicio de WhatsApp', tono: 'rojo' },
}

const PUNTO: Record<Tono, string> = {
  verde: 'bg-emerald-500',
  ambar: 'bg-amber-500',
  rojo: 'bg-red-500',
  gris: 'bg-zinc-400',
}

interface Props {
  puedeEditar: boolean
  automatico: boolean
  plantilla: string
  onAutomatico: (valor: boolean) => void
  onPlantilla: (valor: string) => void
}

/**
 * El envío de comprobantes por WhatsApp: a la izquierda el celular vinculado (estado y QR), a la derecha lo que se
 * manda (envío automático, mensaje y cómo lo recibe el cliente). El enlace del mensaje baja el PDF directo al abrirse.
 */
export function WhatsAppEmpresa({ puedeEditar, automatico, plantilla, onAutomatico, onPlantilla }: Props) {
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()
  const [estado, setEstado] = useState<EstadoWhatsApp | null>(null)
  const [cargando, setCargando] = useState(true)
  const areaTexto = useRef<HTMLTextAreaElement>(null)

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

  /** Mete la variable donde está el cursor, en vez de obligar a escribirla. */
  const insertar = (clave: string) => {
    const el = areaTexto.current
    const actual = plantilla.trim() ? plantilla : PLANTILLA_WHATSAPP
    if (!el) return onPlantilla(actual + clave)
    const ini = el.selectionStart ?? actual.length
    const fin = el.selectionEnd ?? actual.length
    onPlantilla(actual.slice(0, ini) + clave + actual.slice(fin))
    requestAnimationFrame(() => {
      el.focus()
      el.setSelectionRange(ini + clave.length, ini + clave.length)
    })
  }

  const info = estado ? (ESTADOS[estado.estado] ?? { texto: estado.estado, detalle: '', tono: 'gris' as Tono }) : null
  const conectado = estado?.estado === 'conectado'
  const apagado = estado?.estado === 'sin-servicio'

  const texto = (plantilla.trim() || PLANTILLA_WHATSAPP)
    .replaceAll('{cliente}', 'JUAN PÉREZ')
    .replaceAll('{tipo}', 'boleta')
    .replaceAll('{numero}', 'B001-00000012')
    .replaceAll('{total}', 'S/ 157.00')
    .replaceAll('{empresa}', 'Titanic D')
    .replaceAll('{url}', 'https://tu-dominio.pe/api/publico/comprobante/3f9a…')

  return (
    <div className="grid gap-5 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
      {/* ------------------------------------------------------------ El celular */}
      <section className="flex flex-col rounded-panel border border-line bg-white">
        <header className="flex items-center gap-3 border-b border-line px-4 py-3.5">
          <span className="grid size-10 shrink-0 place-items-center rounded-full bg-emerald-50 text-emerald-600">
            <Smartphone size={20} />
          </span>
          <div className="min-w-0 flex-1">
            <h3 className="text-sm font-bold text-ink">Celular de la empresa</h3>
            <p className="truncate text-xs text-ink-soft">Desde este WhatsApp salen los comprobantes</p>
          </div>
          <Button variant="secondary" size="sm" loading={cargando} onClick={() => void cargar()} aria-label="Actualizar estado">
            <RefreshCw size={14} />
          </Button>
        </header>

        <div className="flex flex-1 flex-col gap-4 p-4">
          {info && (
            <div className="flex items-center gap-2.5 rounded-field bg-surface-muted px-3 py-2.5">
              <span className="relative flex size-2.5 shrink-0">
                {(conectado || esperando) && <span className={cn('absolute inline-flex size-full animate-ping rounded-full opacity-60', PUNTO[info.tono])} />}
                <span className={cn('relative inline-flex size-2.5 rounded-full', PUNTO[info.tono])} />
              </span>
              <div className="min-w-0">
                <p className="text-sm font-semibold text-ink">{info.texto}</p>
                <p className="text-xs text-ink-soft">{info.detalle}</p>
              </div>
            </div>
          )}

          {/* Esperando el QR */}
          {esperando && (
            <div className="flex flex-col items-center gap-4">
              {estado?.qrImagen ? (
                <div className="rounded-2xl border-2 border-dashed border-line-strong p-3">
                  <img src={estado.qrImagen} alt="Código QR para vincular WhatsApp" className="size-52 rounded-lg bg-white sm:size-60" />
                </div>
              ) : (
                <div className="grid size-52 place-items-center rounded-2xl border-2 border-dashed border-line-strong text-xs text-ink-soft">
                  Generando el código…
                </div>
              )}
              <ol className="w-full space-y-2 text-xs text-ink-muted">
                {['Abre WhatsApp en el celular de la empresa', 'Entra a Dispositivos vinculados', 'Toca «Vincular un dispositivo» y escanea el código'].map((paso, i) => (
                  <li key={paso} className="flex items-start gap-2.5">
                    <span className="grid size-5 shrink-0 place-items-center rounded-full bg-[rgb(var(--sys-rgb)/0.12)] text-[11px] font-bold text-[rgb(var(--sys-ink-rgb))]">
                      {i + 1}
                    </span>
                    <span className="pt-0.5">{paso}</span>
                  </li>
                ))}
              </ol>
            </div>
          )}

          {/* Vinculado */}
          {conectado && (
            <div className="flex flex-1 flex-col items-center justify-center gap-2 py-4 text-center">
              <span className="grid size-16 place-items-center rounded-full bg-emerald-50 text-emerald-600">
                <Wifi size={28} />
              </span>
              <p className="text-sm font-semibold text-ink">WhatsApp vinculado</p>
              <p className="max-w-[15rem] text-xs text-ink-soft">
                Los mensajes salen con una pausa de unos segundos entre uno y otro, para que WhatsApp no bloquee el número.
              </p>
              {estado.enCola > 0 && (
                <p className="rounded-full bg-amber-50 px-2.5 py-0.5 text-xs font-medium text-amber-700">
                  {estado.enCola} {estado.enCola === 1 ? 'mensaje esperando' : 'mensajes esperando'}
                </p>
              )}
              {puedeEditar && (
                <Button variant="secondary" size="sm" className="mt-2" onClick={desvincular}>
                  <Link2Off size={14} />
                  Cambiar celular
                </Button>
              )}
            </div>
          )}

          {/* El servicio no responde */}
          {apagado && (
            <div className="flex flex-col items-center gap-2 py-3 text-center">
              <span className="grid size-14 place-items-center rounded-full bg-red-50 text-red-500">
                <ServerOff size={26} />
              </span>
              <p className="text-sm font-semibold text-ink">El servicio de WhatsApp no responde</p>
              <p className="max-w-[17rem] text-xs text-ink-soft">
                Revisa que <code className="rounded bg-surface-muted px-1">distributor-whatsapp</code> esté corriendo en el servidor y toca
                actualizar.
              </p>
            </div>
          )}

          {estado?.faltaToken && (
            <p className="rounded-field border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-800">
              Falta el token en la configuración del servidor (<code>WhatsApp:Token</code>). Sin él no se puede enviar.
            </p>
          )}
        </div>
      </section>

      {/* ------------------------------------------------------- Lo que se manda */}
      <div className="flex min-w-0 flex-col gap-5">
        {/* Envío automático */}
        <section className="flex items-start gap-4 rounded-panel border border-line bg-white p-4">
          <span className="grid size-10 shrink-0 place-items-center rounded-full bg-[rgb(var(--sys-rgb)/0.1)] text-[rgb(var(--sys-ink-rgb))]">
            <MessageCircle size={20} />
          </span>
          <div className="min-w-0 flex-1">
            <h3 className="text-sm font-bold text-ink">Enviar cada comprobante automáticamente</h3>
            <p className="mt-0.5 text-xs text-ink-soft">
              Cuando SUNAT acepta una factura, boleta o nota, se manda una sola vez al teléfono del cliente. Si no tiene teléfono o falla, queda
              anotado en el comprobante y se puede enviar a mano.
            </p>
          </div>
          <button
            type="button"
            role="switch"
            aria-checked={automatico}
            aria-label="Enviar automáticamente"
            disabled={!puedeEditar}
            onClick={() => onAutomatico(!automatico)}
            className={cn(
              'relative mt-0.5 h-6 w-11 shrink-0 cursor-pointer rounded-full transition-colors duration-200 disabled:cursor-not-allowed disabled:opacity-50',
              automatico ? 'bg-emerald-500' : 'bg-zinc-300',
            )}
          >
            <span
              className={cn(
                'absolute top-0.5 left-0.5 size-5 rounded-full bg-white shadow transition-transform duration-200',
                automatico && 'translate-x-5',
              )}
            />
          </button>
        </section>

        {/* El mensaje y su vista previa */}
        <section className="rounded-panel border border-line bg-white">
          <header className="flex flex-wrap items-center justify-between gap-2 border-b border-line px-4 py-3.5">
            <div>
              <h3 className="text-sm font-bold text-ink">Mensaje</h3>
              <p className="text-xs text-ink-soft">Lo que recibe el cliente junto con el enlace del comprobante</p>
            </div>
            {puedeEditar && plantilla.trim() !== '' && (
              <button type="button" className="text-xs font-medium text-[rgb(var(--sys-ink-rgb))] hover:underline" onClick={() => onPlantilla('')}>
                Volver al mensaje de siempre
              </button>
            )}
          </header>

          <div className="grid gap-4 p-4 xl:grid-cols-2">
            {/* Editor */}
            <div className="flex min-w-0 flex-col gap-2.5">
              <textarea
                ref={areaTexto}
                rows={9}
                maxLength={1000}
                disabled={!puedeEditar}
                value={plantilla}
                placeholder={PLANTILLA_WHATSAPP}
                aria-label="Mensaje"
                onChange={(e) => onPlantilla(e.target.value)}
                className="w-full flex-1 resize-none rounded-field border border-line-strong bg-white px-3 py-2.5 text-sm leading-relaxed outline-none placeholder:text-ink-soft/70 focus:border-[rgb(var(--sys-rgb))] focus:ring-4 focus:ring-[rgb(var(--sys-rgb)/0.12)] disabled:bg-surface-muted"
              />
              <div>
                <p className="mb-1.5 text-[11px] font-medium tracking-wide text-ink-soft uppercase">Toca una variable para insertarla</p>
                <div className="flex flex-wrap gap-1.5">
                  {VARIABLES.map((v) => (
                    <button
                      key={v.clave}
                      type="button"
                      title={v.ayuda}
                      disabled={!puedeEditar}
                      onClick={() => insertar(v.clave)}
                      className="cursor-pointer rounded-full border border-line bg-surface-muted px-2.5 py-1 font-mono text-xs text-ink-muted transition-colors hover:border-[rgb(var(--sys-rgb))] hover:bg-[rgb(var(--sys-rgb)/0.08)] hover:text-[rgb(var(--sys-ink-rgb))] disabled:cursor-not-allowed disabled:opacity-50"
                    >
                      {v.clave}
                    </button>
                  ))}
                </div>
                <p className="mt-2 text-xs text-ink-soft">El enlace siempre se agrega, aunque lo quites del texto.</p>
              </div>
            </div>

            {/* Vista previa: el chat del cliente */}
            <div className="flex min-w-0 flex-col">
              <p className="mb-1.5 text-[11px] font-medium tracking-wide text-ink-soft uppercase">Así lo recibe el cliente</p>
              <div
                className="flex flex-1 flex-col justify-end rounded-2xl p-3"
                style={{
                  backgroundColor: '#efeae2',
                  backgroundImage: 'radial-gradient(rgba(0,0,0,0.045) 1px, transparent 1px)',
                  backgroundSize: '14px 14px',
                }}
              >
                <div className="relative ml-auto max-w-[94%] rounded-xl rounded-tr-sm bg-[#d9fdd3] px-3 py-2 shadow-sm">
                  <p className="text-[13px] leading-snug break-words whitespace-pre-wrap text-zinc-800">{formatoWhatsApp(texto)}</p>
                  <p className="mt-1 flex items-center justify-end gap-1 text-[10px] text-zinc-500">
                    10:32
                    <CheckCheck size={13} className="text-sky-500" />
                  </p>
                </div>
                <div className="mt-2 ml-auto flex max-w-[94%] items-center gap-2 rounded-lg bg-white/80 px-2.5 py-1.5 text-[11px] text-zinc-600 shadow-sm">
                  <FileDown size={14} className="shrink-0 text-emerald-600" />
                  Al tocar el enlace se descarga el PDF directo, sin abrir ninguna página.
                </div>
              </div>
            </div>
          </div>
        </section>
      </div>
      {dialogo}
    </div>
  )
}

/** Como lo dibuja WhatsApp: *negrita* y los enlaces en azul. */
function formatoWhatsApp(texto: string) {
  return texto.split(/(https?:\/\/\S+|\*[^*\n]+\*)/g).map((trozo, i) => {
    if (/^https?:\/\//.test(trozo)) {
      return (
        <span key={i} className="text-sky-600 underline decoration-sky-600/40">
          {trozo}
        </span>
      )
    }
    if (/^\*[^*\n]+\*$/.test(trozo)) return <strong key={i}>{trozo.slice(1, -1)}</strong>
    return <Fragment key={i}>{trozo}</Fragment>
  })
}
