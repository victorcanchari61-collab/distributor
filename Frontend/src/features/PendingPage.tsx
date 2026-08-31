import { Construction } from 'lucide-react'

/** Marcador para las entradas del menu que todavia no tienen vista. */
export function PendingPage({ title, group }: { title: string; group?: string }) {
  return (
    <div className="flex min-h-[50vh] flex-col items-center justify-center rounded-panel border border-dashed border-line-strong bg-white/60 p-10 text-center">
      <span className="inline-flex size-14 items-center justify-center rounded-full bg-[rgb(var(--sys-rgb)/0.1)] text-[rgb(var(--sys-ink-rgb))]">
        <Construction size={26} />
      </span>
      <h2 className="mt-4 text-lg font-bold text-ink">{title}</h2>
      <p className="mt-1 max-w-sm text-sm text-ink-muted">
        {group ? `Módulo ${group}. ` : ''}
        Esta vista todavía no está construida.
      </p>
    </div>
  )
}
