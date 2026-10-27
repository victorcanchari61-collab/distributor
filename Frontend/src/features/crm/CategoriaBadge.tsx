import { cn } from '../../components/ui'
import type { ColorCategoria } from './categorizacionApi'

/** Un color por nombre: así el backend guarda "sky" y cada pantalla lo pinta a su manera. */
export const CLASES_COLOR: Record<ColorCategoria, string> = {
  sky: 'bg-sky-100 text-sky-800 ring-sky-200',
  emerald: 'bg-emerald-100 text-emerald-800 ring-emerald-200',
  amber: 'bg-amber-100 text-amber-800 ring-amber-200',
  orange: 'bg-orange-100 text-orange-800 ring-orange-200',
  violet: 'bg-violet-100 text-violet-800 ring-violet-200',
  slate: 'bg-slate-100 text-slate-600 ring-slate-200',
  rose: 'bg-rose-100 text-rose-800 ring-rose-200',
}

/** La categoría de un cliente (Socio, Distribuidor...) con su letra y su color. */
export function CategoriaBadge({
  codigo,
  nombre,
  color,
  className,
}: {
  codigo: string | null | undefined
  nombre?: string | null
  color?: string | null
  className?: string
}) {
  if (!codigo) return <span className="text-ink-soft">—</span>

  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-[11px] font-semibold ring-1',
        CLASES_COLOR[(color as ColorCategoria) ?? 'slate'] ?? CLASES_COLOR.slate,
        className,
      )}
    >
      <span className="font-bold">{codigo}</span>
      {nombre && <span>{nombre}</span>}
    </span>
  )
}
