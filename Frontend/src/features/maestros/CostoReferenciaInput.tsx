import { useEffect, useRef, useState } from 'react'
import { Desplegable, Input } from '../../components/ui'
import type { PresentacionResponse } from './productoApi'

/**
 * El costo por unidad base, dicho por presentación y limpio.
 *
 * Dos decimales: es plata, y así vuelve exactamente lo que se escribió. La multiplicación arrastra
 * basura de coma flotante —S/ 289 el saco volvía como 288.9991— y `Number(...)` quita además los
 * ceros que sobran: 280 y no 280.00.
 */
function aPresentacion(costoBase: string, factor: number) {
  if (!costoBase) return ''
  return String(Number((Number(costoBase) * factor).toFixed(2)))
}

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

  /*
    El texto del campo vive aqui, no se re-deriva del valor en cada tecla.

    El costo se guarda por unidad base y se muestra por presentacion, asi que
    cada tecla hacia ida y vuelta: dividir entre 50 al guardar, multiplicar por
    50 al repintar. En coma flotante eso no siempre cierra —0.56 × 50 da
    28.000000000000004—, y al escribir "280" el paso intermedio "28" se
    repintaba con esa basura y reemplazaba lo que se estaba tecleando: el 0
    final nunca llegaba a escribirse.

    Ahora lo tecleado se queda tal cual. Solo se vuelve a calcular desde el
    valor cuando el cambio NO vino de aqui: al abrir el formulario, o al
    elegir otra presentacion.
  */
  const [texto, setTexto] = useState(() => aPresentacion(valor, factor))
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
    // editar, las presentaciones pueden llegar despues que el costo, y sin
    // esto el campo mostraria el costo por kilo en la etiqueta del saco.
    if (vieneDeFuera) setTexto(aPresentacion(valor, factor))
  }, [valor, factor])

  const emitir = (costoBase: string) => {
    // Lo que sale de aqui no debe volver a pintarse encima de lo tecleado.
    ultimoValor.current = costoBase
    onChange(costoBase)
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
    const nuevoFactor = compras.find((p) => p.id === id)?.factor ?? 1
    cambioPropio.current = true
    if (texto) emitir(String(Number(texto) / nuevoFactor))
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
          value={texto}
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
