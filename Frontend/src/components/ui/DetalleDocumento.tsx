import type { ReactNode } from 'react'

/** Un dato de la cabecera: "Cliente", "Fecha", "Vendedor", "Estado"... */
export interface CampoInfo {
  etiqueta: string
  valor: ReactNode
}

/**
 * Caja con los datos generales del documento, en grilla — 2 columnas en
 * móvil, 4 en escritorio. El mismo bloque para cualquier documento
 * (compra, pedido, venta...), solo cambian los campos que le pasan.
 */
export function InfoDocumento({ campos }: { campos: CampoInfo[] }) {
  return (
    <div className="grid grid-cols-2 gap-x-4 gap-y-3 rounded-field border border-line bg-surface-alt p-3 sm:grid-cols-4">
      {campos.map((c) => (
        <div key={c.etiqueta} className="min-w-0">
          <p className="text-[10.5px] font-semibold tracking-wide text-ink-muted uppercase">{c.etiqueta}</p>
          <div className="mt-0.5 truncate text-sm font-semibold text-ink">{c.valor}</div>
        </div>
      ))}
    </div>
  )
}

export interface ColumnaDetalleProducto<T> {
  key: string
  label: string
  render: (row: T) => ReactNode
}

export interface TablaProductosDetalleProps<T> {
  filas: T[]
  rowKey: (row: T) => string | number
  titulo: (row: T) => string
  subtitulo: (row: T) => string
  /** Un grupo por fila de la tarjeta móvil; en escritorio se ven todas como columnas. */
  grupos: ColumnaDetalleProducto<T>[][]
}

/**
 * La lista de productos de un documento: tabla en escritorio (como una
 * factura de verdad), tarjetas en móvil (una por producto, con sus datos en
 * columnas) — la misma información, acomodada distinto según el ancho.
 */
export function TablaProductosDetalle<T>({
  filas,
  rowKey,
  titulo,
  subtitulo,
  grupos,
}: TablaProductosDetalleProps<T>) {
  const columnas = grupos.flat()

  return (
    <>
      <div className="hidden overflow-x-auto rounded-field border border-line sm:block">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-line bg-surface-alt text-left text-[11px] font-semibold tracking-wide text-ink-muted uppercase">
              <th className="px-3 py-2">Producto</th>
              {columnas.map((c) => (
                <th key={c.key} className="px-3 py-2 text-right">
                  {c.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filas.map((row) => (
              <tr key={rowKey(row)} className="border-b border-line last:border-0">
                <td className="px-3 py-2.5">
                  <p className="font-semibold text-ink">{titulo(row)}</p>
                  <p className="text-xs text-ink-soft">{subtitulo(row)}</p>
                </td>
                {columnas.map((c) => (
                  <td key={c.key} className="px-3 py-2.5 text-right">
                    {c.render(row)}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="flex flex-col gap-2 sm:hidden">
        {filas.map((row) => (
          <div key={rowKey(row)} className="rounded-field border border-line p-3">
            <p className="text-sm font-bold text-ink">{titulo(row)}</p>
            <p className="mt-0.5 text-xs text-ink-soft">{subtitulo(row)}</p>
            {grupos.map((grupo, i) => (
              <div key={i} className="mt-2 flex gap-3">
                {grupo.map((c) => (
                  <div key={c.key} className="flex-1">
                    <p className="text-[10.5px] text-ink-muted">{c.label}</p>
                    <p className="text-[13px] font-bold text-ink">{c.render(row)}</p>
                  </div>
                ))}
              </div>
            ))}
          </div>
        ))}
      </div>
    </>
  )
}

export interface PagoResumen {
  id: string | number
  label: string
  monto: number
}

/** Pagos a la izquierda (si los hay) y el total a la derecha, como el pie de una factura. */
export function ResumenDocumento({
  pagos,
  subtotal,
  total,
}: {
  pagos?: PagoResumen[]
  subtotal?: number
  total: number
}) {
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-[1fr_auto] sm:items-start">
      {pagos && pagos.length > 0 && (
        <div>
          <p className="mb-2 text-[11px] font-semibold tracking-wide text-ink-muted uppercase">Pagos</p>
          <ul className="flex flex-col gap-1.5">
            {pagos.map((p) => (
              <li key={p.id} className="flex items-center justify-between gap-4 text-sm">
                <span className="text-ink-soft">{p.label}</span>
                <span className="font-semibold text-ink">S/ {p.monto.toFixed(2)}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
      <div className="rounded-field border border-line p-3 sm:min-w-[13rem]">
        {subtotal != null && (
          <div className="flex items-center justify-between text-sm text-ink-soft">
            <span>Subtotal</span>
            <span>S/ {subtotal.toFixed(2)}</span>
          </div>
        )}
        <div className="mt-1 flex items-center justify-between">
          <span className="text-sm font-bold text-ink">Total</span>
          <span className="text-lg font-bold text-[rgb(var(--sys-rgb))]">S/ {total.toFixed(2)}</span>
        </div>
      </div>
    </div>
  )
}
