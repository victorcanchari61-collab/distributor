import { useEffect, useRef, useState } from 'react'
import { Desplegable, Input } from '../../components/ui'
import type { PresentacionResponse } from './productoApi'

/**
 * Qué se está escribiendo: plata (el costo, el precio) o kilos (el peso).
 *
 * Solo cambia cómo se lee el número —"S/ 3.40 por kilogramo" contra "50 kg por saco"— y cuántos
 * decimales sobreviven a la ida y vuelta. La mecánica de la conversión es la misma.
 */
export type MagnitudValor = 'dinero' | 'peso'

/**
 * Decimales con los que el número vuelve exacto a la presentación.
 *
 * Dos para la plata, que es como se cobra: S/ 289 el saco volvía como 288.9991 porque la
 * multiplicación arrastra basura de coma flotante. Tres para el peso, que baja de un céntimo sin
 * problema: un sobre de 30 g pesa 0.03 kg y con dos decimales se perdería.
 */
function aPresentacion(valorBase: string, factor: number, magnitud: MagnitudValor) {
  if (!valorBase) return ''
  const decimales = magnitud === 'peso' ? 3 : 2
  // `Number(...)` quita además los ceros que sobran: 280 y no 280.00.
  return String(Number((Number(valorBase) * factor).toFixed(decimales)))
}

export interface ValorPorPresentacionInputProps {
  /** Valor por unidad base, que es como se guarda. */
  valor: string
  onChange: (valorUnidadBase: string) => void
  /** Presentación en la que se escribe: el saco, la caja. */
  presentacionId: number
  onPresentacion: (id: number) => void
  presentaciones: PresentacionResponse[]
  unidadBase: string
  disabled?: boolean
  /**
   * Qué presentaciones se ofrecen. El costo se escribe sobre las que SE COMPRAN y el precio sobre
   * las que SE VENDEN: ofrecer las otras invita a poner el precio del saco en un producto que solo
   * sale por kilo. El peso no distingue —un saco pesa lo mismo se compre o se venda—, y va con
   * 'todas'.
   */
  uso?: 'compra' | 'venta' | 'todas'
  magnitud?: MagnitudValor
  etiqueta?: string
  marcador?: string
}

/**
 * Un valor del producto escrito por presentación y guardado por unidad base.
 *
 * Se escribe como se dice en el almacén —S/ 170 el saco, 50 kg el saco— y se guarda por unidad
 * base —S/ 3.40 el kilo, 1 kg el kilo—, que es como lo necesita todo lo demás. La etiqueta dice
 * sobre qué presentación está escrito, que es lo único que hacía falta aclarar.
 */
export function ValorPorPresentacionInput({
  valor,
  onChange,
  presentacionId,
  onPresentacion,
  presentaciones,
  unidadBase,
  disabled,
  uso = 'compra',
  magnitud = 'dinero',
  etiqueta = 'Costo de referencia',
  marcador,
}: ValorPorPresentacionInputProps) {
  const opciones = presentaciones.filter(
    (p) => p.activo && (uso === 'todas' || (uso === 'venta' ? p.esVenta : p.esCompra)),
  )
  const elegida = opciones.find((p) => p.id === presentacionId)
  const factor = elegida?.factor ?? 1

  /*
    El texto del campo vive aqui, no se re-deriva del valor en cada tecla.

    El valor se guarda por unidad base y se muestra por presentacion, asi que
    cada tecla hacia ida y vuelta: dividir entre 50 al guardar, multiplicar por
    50 al repintar. En coma flotante eso no siempre cierra —0.56 × 50 da
    28.000000000000004—, y al escribir "280" el paso intermedio "28" se
    repintaba con esa basura y reemplazaba lo que se estaba tecleando: el 0
    final nunca llegaba a escribirse.

    Ahora lo tecleado se queda tal cual. Solo se vuelve a calcular desde el
    valor cuando el cambio NO vino de aqui: al abrir el formulario, o al
    elegir otra presentacion.
  */
  const [texto, setTexto] = useState(() => aPresentacion(valor, factor, magnitud))
  const ultimoValor = useRef(valor)
  const ultimoFactor = useRef(factor)
  /** El cambio de presentación lo hizo esta misma caja: el número se conserva. */
  const cambioPropio = useRef(false)

  useEffect(() => {
    const vieneDeFuera = valor !== ultimoValor.current || factor !== ultimoFactor.current
    ultimoValor.current = valor
    ultimoFactor.current = factor

    if (cambioPropio.current) {
      cambioPropio.current = false
      return
    }
    // Tambien cuando solo cambia el factor sin que nadie lo tocara aqui: al
    // editar, las presentaciones pueden llegar despues que el valor, y sin
    // esto el campo mostraria el costo por kilo en la etiqueta del saco.
    if (vieneDeFuera) setTexto(aPresentacion(valor, factor, magnitud))
  }, [valor, factor, magnitud])

  const emitir = (valorBase: string) => {
    // Lo que sale de aqui no debe volver a pintarse encima de lo tecleado.
    ultimoValor.current = valorBase
    onChange(valorBase)
  }

  const escribir = (nuevo: string) => {
    setTexto(nuevo)
    emitir(nuevo ? String(Number(nuevo) / factor) : '')
  }

  /*
    Al cambiar de presentación el número escrito SE QUEDA y cambia a qué se
    refiere: si tecleaste 170 pensando en el saco y el selector decía Kilogramo,
    corriges el selector y sigue siendo 170 el saco. Convertirlo lo dispararía a
    8500 y parecería un error del sistema.
  */
  const cambiarPresentacion = (id: number) => {
    if (id === presentacionId) return
    const nuevoFactor = opciones.find((p) => p.id === id)?.factor ?? 1
    cambioPropio.current = true
    if (texto) emitir(String(Number(texto) / nuevoFactor))
    onPresentacion(id)
  }

  return (
    /*
      El numero y la presentacion, en la MISMA fila y bajo una sola etiqueta.

      Antes el selector iba debajo, en su propio campo con su propia etiqueta: el costo no lo
      mostraba (se compra de una sola forma) y el precio si, asi que las dos columnas del
      formulario quedaban con alturas distintas y la rejilla salia descuadrada. Asi cada campo
      ocupa una fila y todo alinea.
    */
    <div className="w-full min-w-0">
      <div className="mb-1.5 flex min-h-5 items-center gap-2">
        <span className="ui-label truncate">
          {etiqueta}
          <span className="ml-1.5 font-normal text-ink-soft">(opcional)</span>
        </span>
      </div>

      <div className="grid grid-cols-[minmax(0,1fr)_minmax(0,9.5rem)] gap-2">
        <Input
          type="number"
          step={magnitud === 'peso' ? '0.001' : '0.01'}
          min="0"
          placeholder={marcador ?? (magnitud === 'peso' ? '50' : '170.00')}
          value={texto}
          onChange={(e) => escribir(e.target.value)}
          disabled={disabled}
        />

        {/*
          Siempre, aunque solo haya una presentacion: "170" a secas no se sabe si es el saco o el
          kilo, y con una sola opcion el selector es justamente donde se lee cual.
        */}
        {opciones.length > 0 && (
          <Desplegable
            className="min-w-0"
            value={presentacionId}
            onChange={(v) => cambiarPresentacion(Number(v))}
            disabled={disabled || opciones.length === 1}
            options={opciones.map((p) => ({
              value: p.id,
              label: p.nombre,
              detalle: `${p.factor} ${unidadBase}`,
            }))}
          />
        )}
      </div>
    </div>
  )
}
