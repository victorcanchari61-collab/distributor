import type { ReactNode } from 'react'

export interface CifraPago {
  label: string
  /** Un monto en soles: se muestra como "S/ 170.00". */
  monto?: number
  /** Cualquier otro valor (una cantidad, "2 de 5"): se muestra tal cual. Gana sobre `monto`. */
  valor?: ReactNode
  /** exito: lo ya cobrado o pagado (verde). pendiente: lo que falta (ámbar). peligro: un faltante (rojo). */
  tono?: 'normal' | 'exito' | 'pendiente' | 'peligro'
  /** Una línea chica debajo, para explicar la cifra. */
  nota?: string
}

const COLOR: Record<NonNullable<CifraPago['tono']>, string> = {
  normal: 'text-ink',
  exito: 'text-emerald-700',
  pendiente: 'text-amber-700',
  peligro: 'text-red-700',
}

/**
 * Las cifras de un modal en recuadros chicos, lado a lado: a cobrar, cobrado, lo que queda; o productos, recibido,
 * pendiente. Es el formato de las cifras DENTRO de un modal (las tarjetas grandes con icono, StatCard, son para la
 * cabecera de una página).
 */
export function CifrasPago({ cifras }: { cifras: CifraPago[] }) {
  return (
    <div
      className="grid gap-2 text-center sm:gap-3"
      style={{ gridTemplateColumns: `repeat(${cifras.length}, minmax(0, 1fr))` }}
    >
      {cifras.map((c) => (
        <div key={c.label} className="rounded-field border border-line px-2 py-2">
          <p className="text-[11px] font-semibold tracking-wide text-ink-soft uppercase">{c.label}</p>
          <p className={`text-base font-semibold ${COLOR[c.tono ?? 'normal']}`}>
            {c.valor ?? `S/ ${(c.monto ?? 0).toFixed(2)}`}
          </p>
          {c.nota && <p className="mt-0.5 text-[11px] text-ink-soft">{c.nota}</p>}
        </div>
      ))}
    </div>
  )
}
