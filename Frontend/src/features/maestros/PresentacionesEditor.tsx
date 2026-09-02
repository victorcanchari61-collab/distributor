import { Plus, Trash2 } from 'lucide-react'
import { Badge, Button, Input, Select, cn } from '../../components/ui'
import type { PresentacionRequest, UnidadResponse } from './productoApi'

export interface FilaPresentacion extends PresentacionRequest {
  /** Id cuando ya existe en la base; undefined mientras es nueva. */
  id?: number
  esBase?: boolean
}

export interface PresentacionesEditorProps {
  filas: FilaPresentacion[]
  unidades: UnidadResponse[]
  /** Código de la unidad base del producto, para leer los factores. */
  unidadBase: string
  onChange: (filas: FilaPresentacion[]) => void
  disabled?: boolean
}

/**
 * Editor de las formas de comprar y vender un producto.
 *
 * El factor es la pieza que hay que entender: dice cuántas unidades base
 * equivale una presentación. Un saco de 50 kg tiene factor 50, y comprar dos
 * mete 100 kg al almacén. Por eso cada fila muestra la equivalencia escrita.
 *
 * La presentación base (factor 1) no aparece aquí: la crea el backend con la
 * unidad base y no se puede borrar ni cambiar.
 */
export function PresentacionesEditor({
  filas,
  unidades,
  unidadBase,
  onChange,
  disabled,
}: PresentacionesEditorProps) {
  const activas = unidades.filter((u) => u.activo)

  const actualizar = (indice: number, cambio: Partial<FilaPresentacion>) =>
    onChange(filas.map((f, i) => (i === indice ? { ...f, ...cambio } : f)))

  const agregar = () =>
    onChange([
      ...filas,
      {
        unidadId: activas[0]?.id ?? 0,
        nombre: '',
        factor: 0,
        esCompra: true,
        esVenta: true,
        activo: true,
      },
    ])

  const quitar = (indice: number) => onChange(filas.filter((_, i) => i !== indice))

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-sm font-semibold text-ink">Presentaciones</p>
          <p className="text-xs text-ink-soft">
            Cómo se compra y se vende. El factor dice a cuántos{' '}
            <span className="font-semibold">{unidadBase || 'unidad base'}</span> equivale.
          </p>
        </div>
        <Button variant="secondary" size="sm" onClick={agregar} disabled={disabled}>
          <Plus size={15} />
          Agregar
        </Button>
      </div>

      {filas.length === 0 ? (
        <p className="rounded-field bg-slate-50 px-3 py-4 text-center text-xs text-ink-soft">
          Solo se venderá por {unidadBase || 'la unidad base'}. Agrega una presentación si
          además vendes por saco, caja o bolsa.
        </p>
      ) : (
        <ul className="flex flex-col gap-2">
          {filas.map((fila, i) => {
            const unidad = activas.find((u) => u.id === fila.unidadId)
            return (
              <li
                key={fila.id ?? `nueva-${i}`}
                className="rounded-field border border-line bg-white p-3"
              >
                <div className="grid grid-cols-2 gap-2 sm:grid-cols-[1fr_7rem_6.5rem_auto]">
                  <Input
                    label="Nombre"
                    size="sm"
                    placeholder="Saco 50 kg"
                    value={fila.nombre}
                    onChange={(e) => actualizar(i, { nombre: e.target.value })}
                    disabled={disabled}
                  />

                  <Select
                    label="Unidad"
                    size="sm"
                    value={fila.unidadId}
                    onChange={(e) => actualizar(i, { unidadId: Number(e.target.value) })}
                    disabled={disabled}
                  >
                    {activas.map((u) => (
                      <option key={u.id} value={u.id}>
                        {u.codigo}
                      </option>
                    ))}
                  </Select>

                  <Input
                    label="Factor"
                    size="sm"
                    type="number"
                    min={0}
                    step="0.0001"
                    value={fila.factor || ''}
                    onChange={(e) => actualizar(i, { factor: Number(e.target.value) })}
                    disabled={disabled}
                  />

                  <div className="flex items-end pb-0.5">
                    <button
                      type="button"
                      onClick={() => quitar(i)}
                      disabled={disabled}
                      aria-label={`Quitar ${fila.nombre || 'presentación'}`}
                      className={cn(
                        'inline-flex size-9 items-center justify-center rounded-field',
                        'text-red-600 transition-colors hover:bg-red-50 disabled:opacity-40',
                      )}
                    >
                      <Trash2 size={15} />
                    </button>
                  </div>
                </div>

                <div className="mt-2 flex flex-wrap items-center gap-3">
                  {/* La equivalencia escrita evita el error clasico de poner
                      el factor al reves (1/50 en vez de 50). */}
                  <Badge tone={fila.factor > 0 ? 'sys' : 'neutral'}>
                    {fila.factor > 0
                      ? `1 ${unidad?.codigo ?? '?'} = ${fila.factor} ${unidadBase}`
                      : 'Falta el factor'}
                  </Badge>

                  <label className="flex items-center gap-1.5 text-xs text-ink-muted">
                    <input
                      type="checkbox"
                      checked={fila.esCompra}
                      onChange={(e) => actualizar(i, { esCompra: e.target.checked })}
                      disabled={disabled}
                    />
                    Se compra así
                  </label>

                  <label className="flex items-center gap-1.5 text-xs text-ink-muted">
                    <input
                      type="checkbox"
                      checked={fila.esVenta}
                      onChange={(e) => actualizar(i, { esVenta: e.target.checked })}
                      disabled={disabled}
                    />
                    Se vende así
                  </label>
                </div>
              </li>
            )
          })}
        </ul>
      )}
    </div>
  )
}
