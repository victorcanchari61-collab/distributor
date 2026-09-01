import { useState } from 'react'
import { Search } from 'lucide-react'
import { cn } from './cn'
import { Input } from './Input'
import type { InputProps } from './Input'

export interface DocumentoInputProps extends Omit<InputProps, 'onChange' | 'value' | 'type'> {
  /** RUC son 11 digitos y DNI 8. */
  tipo: 'ruc' | 'dni'
  value: string
  onChange: (value: string) => void
  /** Se llama al pulsar Buscar o Enter con el numero completo. */
  onBuscar: (numero: string) => Promise<void> | void
  buscando?: boolean
}

const LARGO = { ruc: 11, dni: 8 }

/**
 * Campo de documento con boton de consulta en linea.
 *
 * Solo acepta digitos, corta al largo del tipo y habilita "Buscar" cuando el
 * numero esta completo. Se usa igual para el RUC de una empresa y el DNI de un
 * usuario, asi que la logica de tecleo vive aqui y no en cada formulario.
 */
export function DocumentoInput({
  tipo,
  value,
  onChange,
  onBuscar,
  buscando = false,
  label,
  className,
  ...rest
}: DocumentoInputProps) {
  const largo = LARGO[tipo]
  const completo = value.length === largo
  const [tocado, setTocado] = useState(false)

  const buscar = () => {
    if (!completo || buscando) return
    void onBuscar(value)
  }

  return (
    <div className={cn('w-full min-w-0', className)}>
      <div className="flex min-w-0 items-end gap-2">
        <Input
          // flex-1 + min-w-0: el campo cede ancho para que el boton siempre
          // quepa, incluso dentro de una columna estrecha del formulario.
          className="min-w-0 flex-1"
          label={label ?? tipo.toUpperCase()}
          inputMode="numeric"
          maxLength={largo}
          value={value}
          onChange={(e) => {
            setTocado(true)
            onChange(e.target.value.replace(/\D/g, '').slice(0, largo))
          }}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              e.preventDefault()
              buscar()
            }
          }}
          {...rest}
        />

        <button
          type="button"
          onClick={buscar}
          disabled={!completo || buscando}
          title={completo ? 'Consultar en línea' : `Ingresa los ${largo} dígitos`}
          aria-label="Consultar en línea"
          className={cn(
            'inline-flex h-control w-11 shrink-0 cursor-pointer items-center justify-center rounded-field',
            'bg-brand text-on-brand transition-colors hover:not-disabled:bg-brand-hover',
            'disabled:cursor-not-allowed disabled:opacity-50',
          )}
        >
          {buscando ? (
            <span
              aria-hidden="true"
              className="size-4 animate-spin rounded-full border-2 border-current border-r-transparent"
            />
          ) : (
            <Search size={16} />
          )}
        </button>
      </div>

      {tocado && value.length > 0 && !completo && (
        <p className="mt-1.5 text-xs text-ink-soft">
          Faltan {largo - value.length} dígito{largo - value.length === 1 ? '' : 's'}.
        </p>
      )}
    </div>
  )
}
