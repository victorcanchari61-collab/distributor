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
      {/*
        Apilado, no en dos columnas: el selector casi nunca esta —solo si se
        compra de varias formas— y una rejilla fija dejaba media fila vacia.
        Asi el costo entra como un campo mas de la rejilla del formulario.
      */}
      <div className="flex flex-col gap-3">
        <Input
          // La etiqueta dice de que presentacion es el numero, en vez de
          // dejarlo a la imaginacion: "S/ 170" a secas no se sabe si es el
          // saco o el kilo.
          label={`Costo de referencia${elegida ? ` — un ${elegida.nombre}` : ''}`}
          optional
          type="number"
          step="0.01"
          placeholder="170.00"
          value={enPresentacion}
          onChange={(e) => escribir(e.target.value)}
          disabled={disabled}
        />

        {/*
          El selector SOLO aparece si de verdad hay algo que elegir.
          
          Antes decia "Se compra por" y repetia la columna "Se compra" de la
          pestaña Presentaciones, que es donde eso se declara de verdad — dos
          sitios para el mismo dato, y podian contradecirse. Ahora las opciones
          salen de esa misma columna y esto es solo una pregunta de seguimiento
          sobre el costo: cuando se compra de una sola forma, ni se muestra.
        */}
        {compras.length > 1 && (
          <Desplegable
            label="Ese costo es de"
            value={presentacionId}
            onChange={(v) => cambiarPresentacion(Number(v))}
            disabled={disabled}
            options={compras.map((p) => ({
              value: p.id,
              label: p.nombre,
              detalle: `${p.factor} ${unidadBase}`,
            }))}
          />
        )}
      </div>

      {valor && Number(valor) > 0 && (
        <p className="rounded-field bg-slate-50 px-3 py-2 text-xs text-ink-muted">
          Equivale a{' '}
          <span className="font-semibold text-ink">
            {/* Dos decimales, que es como se cobra. Los cuatro solo cuando
                el centimo se come el numero: el sobre de 30 g sale a
                S/ 0.0025 el gramo y "S/ 0.00" no dice nada. */}
            S/ {Number(valor) < 0.01 ? Number(valor).toFixed(4) : Number(valor).toFixed(2)} por{' '}
            {unidadBase}
          </span>
          . Es lo que sueles pagar; el costo real lo fija cada entrada al almacén.
        </p>
      )}
    </div>
  )
}
