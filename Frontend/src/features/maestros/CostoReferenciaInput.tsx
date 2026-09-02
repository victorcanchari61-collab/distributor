import { Desplegable, Input } from '../../components/ui'
import type { PresentacionResponse } from './productoApi'

export interface CostoReferenciaInputProps {
  /** Costo por unidad base, que es como se guarda. */
  valor: string
  onChange: (costoUnidadBase: string) => void
  /** Presentación en la que se escribe: el saco, la caja. */
  presentacionId: number
  onPresentacion: (id: number) => void
  presentaciones: PresentacionResponse[]
  unidadBase: string
  disabled?: boolean
}

/**
 * Costo de referencia del producto.
 *
 * Se escribe como te lo cobra el proveedor —S/ 170 el saco— y se guarda por
 * unidad base —S/ 3.40 el kilo—, que es como lo necesita todo lo demás. La
 * equivalencia se muestra debajo para que se vea la conversión y no haya duda
 * de si el número era por saco o por kilo.
 *
 * Es una referencia: el costo real de cada compra lo fija la entrada al
 * almacén, no este campo.
 */
export function CostoReferenciaInput({
  valor,
  onChange,
  presentacionId,
  onPresentacion,
  presentaciones,
  unidadBase,
  disabled,
}: CostoReferenciaInputProps) {
  const compras = presentaciones.filter((p) => p.esCompra && p.activo)
  const elegida = compras.find((p) => p.id === presentacionId)
  const factor = elegida?.factor ?? 1

  // Lo que se ve en el campo: el costo por presentación, no por unidad base.
  const enPresentacion = valor ? String(Number(valor) * factor) : ''

  const escribir = (texto: string) => {
    if (!texto) return onChange('')
    onChange(String(Number(texto) / factor))
  }

  /*
    Al cambiar de presentación el número escrito SE QUEDA y cambia a qué se
    refiere: si tecleaste 170 pensando en el saco y el selector decía Kilogramo,
    corriges el selector y sigue siendo 170 el saco. Convertirlo lo dispararía a
    8500 y parecería un error del sistema.
  */
  const cambiarPresentacion = (id: number) => {
    const nuevoFactor = compras.find((p) => p.id === id)?.factor ?? 1
    if (enPresentacion) onChange(String(Number(enPresentacion) / nuevoFactor))
    onPresentacion(id)
  }

  return (
    <div className="flex flex-col gap-1.5">
      <div className="grid gap-4 sm:grid-cols-2">
        <Input
          label="Costo de referencia"
          optional
          type="number"
          step="0.01"
          placeholder="170.00"
          value={enPresentacion}
          onChange={(e) => escribir(e.target.value)}
          disabled={disabled}
        />

        <Desplegable
          label="Se compra por"
          value={presentacionId}
          onChange={(v) => cambiarPresentacion(Number(v))}
          disabled={disabled || compras.length === 0}
          options={compras.map((p) => ({
            value: p.id,
            label: p.nombre,
            detalle: `${p.factor} ${unidadBase}`,
          }))}
        />
      </div>

      {valor && Number(valor) > 0 && (
        <p className="rounded-field bg-slate-50 px-3 py-2 text-xs text-ink-muted">
          Equivale a{' '}
          <span className="font-semibold text-ink">
            S/ {Number(valor).toFixed(4)} por {unidadBase}
          </span>
          . Es lo que sueles pagar; el costo real lo fija cada entrada al almacén.
        </p>
      )}
    </div>
  )
}
