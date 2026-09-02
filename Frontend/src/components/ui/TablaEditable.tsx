import type { ReactNode } from 'react'
import { Trash2 } from 'lucide-react'
import { cn } from './cn'

export interface ColumnaEditable<T> {
  key: string
  label: string
  align?: 'left' | 'right'
  className?: string
  render: (fila: T, indice: number) => ReactNode
}

export interface TablaEditableProps<T> {
  columnas: ColumnaEditable<T>[]
  filas: T[]
  onQuitar: (indice: number) => void
  quitarLabel?: (fila: T, indice: number) => string
  className?: string
}

/**
 * Tabla para editar líneas dentro de un formulario (productos de un ajuste,
 * de una transferencia, de un préstamo...).
 *
 * No es SysDataTable: esa trae buscador, orden y columnas arrastrables
 * pensados para listados de cientos de filas, y buscar dentro de un campo que
 * cambia en cada tecleo no tiene sentido aquí. Esta solo pinta filas y deja
 * quitarlas; toma el mismo estilo de cabecera para que se vea de la misma
 * familia visual.
 */
export function TablaEditable<T>({
  columnas,
  filas,
  onQuitar,
  quitarLabel,
  className,
}: TablaEditableProps<T>) {
  return (
    <div className={cn('overflow-x-auto rounded-field border border-line', className)}>
      <table className="w-full min-w-[38rem] border-collapse text-sm">
        <thead>
          <tr className="border-b border-line bg-surface-soft text-left text-[11px] font-semibold tracking-wider text-ink-soft uppercase">
            {columnas.map((col) => (
              <th
                key={col.key}
                className={cn(
                  'px-3 py-2 font-semibold',
                  col.align === 'right' && 'text-right',
                  col.className,
                )}
              >
                {col.label}
              </th>
            ))}
            <th className="w-10 px-2 py-2" />
          </tr>
        </thead>
        <tbody className="divide-y divide-line">
          {filas.map((fila, i) => (
            <tr key={i} className="align-top">
              {columnas.map((col) => (
                <td key={col.key} className="p-2">
                  {col.render(fila, i)}
                </td>
              ))}
              <td className="p-2 text-center">
                <button
                  type="button"
                  onClick={() => onQuitar(i)}
                  aria-label={quitarLabel ? quitarLabel(fila, i) : 'Quitar línea'}
                  className="inline-flex size-9 items-center justify-center rounded-field text-red-600 hover:bg-red-50"
                >
                  <Trash2 size={15} />
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
