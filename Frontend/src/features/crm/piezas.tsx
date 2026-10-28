import type { ReactNode } from 'react'
import type { LucideIcon } from 'lucide-react'
import { cn } from '../../components/ui'
import type { EstadoClave, TipoContacto, TonoGestion } from './crmApi'
import { CONTACTO_UI, TONOS } from './contacto'
import { ESTADOS_UI } from './formato'

/**
 * Una tarjeta de reporte: un número grande con su título, el rango que cubre y una línea de detalle, con el color de lo
 * que mide. Es la misma de los reportes de 7power: Crítico, En riesgo, En seguimiento y Normal son tarjetas de estas.
 * Si se le pasa `onClick` es un filtro: la activa queda marcada.
 */
export function TarjetaReporte({
  titulo,
  nota,
  valor,
  detalle,
  icono: Icono,
  color,
  onClick,
  activa,
}: {
  titulo: ReactNode
  /** Un texto corto junto al título (el rango del estado). */
  nota?: string
  valor: ReactNode
  detalle?: ReactNode
  icono: LucideIcon
  color: string
  onClick?: () => void
  activa?: boolean
}) {
  const contenido = (
    <>
      <span
        className="flex size-11 shrink-0 items-center justify-center rounded-xl"
        style={{ backgroundColor: `${color}1a`, color }}
      >
        <Icono size={20} />
      </span>
      <div className="min-w-0 flex-1 text-left">
        <p className="flex flex-wrap items-baseline gap-x-2 text-xs font-semibold text-ink-muted">
          <span className="truncate">{titulo}</span>
          {nota && <span className="font-normal text-ink-soft">{nota}</span>}
        </p>
        <p className="mt-0.5 truncate text-2xl leading-tight font-extrabold text-ink tabular-nums" style={{ color }}>
          {valor}
        </p>
        {detalle && <p className="mt-0.5 text-xs text-ink-soft">{detalle}</p>}
      </div>
    </>
  )

  const base = 'flex w-full items-start gap-3 rounded-panel border bg-white p-4'

  if (!onClick) return <div className={cn(base, 'border-line')}>{contenido}</div>

  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={activa}
      className={cn(base, 'cursor-pointer transition-shadow hover:shadow-md', activa ? 'shadow-md' : 'border-line')}
      style={activa ? { borderColor: color, boxShadow: `0 0 0 2px ${color}33` } : undefined}
    >
      {contenido}
    </button>
  )
}

/** La etiqueta del estado de un cliente, con su color: Crítico, En riesgo... */
export function EtiquetaEstado({ estado, className }: { estado: EstadoClave; className?: string }) {
  const ui = ESTADOS_UI[estado]
  return (
    <span
      className={cn('inline-flex items-center rounded-md px-2 py-0.5 text-xs font-semibold whitespace-nowrap', className)}
      style={{ color: ui.color, backgroundColor: ui.fondo }}
    >
      {ui.etiqueta}
    </span>
  )
}

/** La etiqueta de color del resultado de una gestión. */
export function EtiquetaResultado({ tono, texto }: { tono: TonoGestion; texto: string }) {
  const { color, fondo } = TONOS[tono] ?? TONOS.neutro
  return (
    <span className="inline-flex items-center rounded-md px-2 py-0.5 text-xs font-semibold whitespace-nowrap" style={{ color, backgroundColor: fondo }}>
      {texto}
    </span>
  )
}

/** Un círculo con el icono de cómo fue el contacto (llamada, WhatsApp, visita o correo). */
export function IconoContacto({ tipo, tamano = 36 }: { tipo: TipoContacto; tamano?: number }) {
  const { color, icono: Icono } = CONTACTO_UI[tipo]
  return (
    <span
      className="flex shrink-0 items-center justify-center rounded-full text-white"
      style={{ backgroundColor: color, width: tamano, height: tamano }}
    >
      <Icono size={Math.round(tamano * 0.45)} />
    </span>
  )
}
