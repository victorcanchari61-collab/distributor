import { ScrollText } from 'lucide-react'
import { Badge } from './Badge'
import type { AuditoriaResponse } from '../../features/config'

/** Un valor de la bitácora, legible. */
function formatearValor(valor: unknown): string {
  if (valor === null || valor === undefined || valor === '') return '—'
  if (typeof valor === 'boolean') return valor ? 'Sí' : 'No'
  if (typeof valor === 'number') return String(valor)
  return String(valor)
}

/**
 * Qué campos de una línea de producto se muestran, y cómo se llaman en
 * palabras del negocio. Lo que no está en esta lista no se pinta: `Cantidad`
 * (en unidad base), `ProductoId` o `PedidoId` son detalle técnico que no le
 * dice nada a quien despacha.
 */
const CAMPOS: { campo: string; etiqueta: string }[] = [
  { campo: 'CantidadPresentacion', etiqueta: 'Cantidad' },
  { campo: 'PrecioUnitario', etiqueta: 'Precio' },
]

export interface HistorialCambiosProps {
  registros: AuditoriaResponse[]
  cargando?: boolean
}

/**
 * Qué se le cambió a los productos del documento después de crearlo: una
 * línea por corrección, con el producto, el antes y el después.
 *
 * No muestra el alta: lo que se pidió de entrada ya se ve en el detalle. Solo
 * responde "qué se movió y cuándo" — que es lo que hace falta para saber, por
 * ejemplo, cuánto falta pesar de lo que aumentaron a media mañana.
 */
export function HistorialCambios({ registros, cargando }: HistorialCambiosProps) {
  if (cargando) {
    return <p className="py-4 text-center text-xs text-ink-soft">Cargando historial...</p>
  }

  if (registros.length === 0) {
    return (
      <p className="flex items-center justify-center gap-2 py-6 text-center text-xs text-ink-soft">
        <ScrollText size={14} />
        No se editó ningún producto: está tal cual se registró.
      </p>
    )
  }

  return (
    <ul className="flex flex-col gap-2">
      {registros.map((r) => {
        const anulado = r.valoresNuevos?.Anulado === true
        const cambios = CAMPOS.filter(
          ({ campo }) =>
            r.valoresNuevos?.[campo] !== undefined &&
            formatearValor(r.valoresAnteriores?.[campo]) !== formatearValor(r.valoresNuevos?.[campo]),
        )

        return (
          <li key={r.id} className="rounded-field border border-line bg-white px-3 py-2 text-[13px]">
            <div className="flex flex-wrap items-center gap-2">
              <span className="font-semibold text-ink">{r.descripcion ?? 'Producto'}</span>
              {anulado && <Badge tone="danger">Anulado</Badge>}
              <span className="ml-auto text-[11px] text-ink-soft">
                {new Date(r.fecha).toLocaleString('es-PE')} · {r.usuario}
              </span>
            </div>

            {!anulado && cambios.length > 0 && (
              <div className="mt-1 flex flex-wrap gap-x-4 gap-y-0.5">
                {cambios.map(({ campo, etiqueta }) => (
                  <span key={campo} className="text-ink-soft">
                    {etiqueta}:{' '}
                    <span className="line-through">{formatearValor(r.valoresAnteriores?.[campo])}</span>
                    <span className="mx-1">→</span>
                    <span className="font-semibold text-ink">{formatearValor(r.valoresNuevos?.[campo])}</span>
                  </span>
                ))}
              </div>
            )}

            {anulado && (
              <p className="mt-0.5 text-[12px] text-ink-soft">Se quitó del documento al editarlo.</p>
            )}
          </li>
        )
      })}
    </ul>
  )
}
