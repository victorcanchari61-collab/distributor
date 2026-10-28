import { useCallback, useEffect, useState } from 'react'
import { Search, X } from 'lucide-react'
import { Input } from '../../../components/ui'
import { useDismiss } from '../../../components/ui/useDismiss'
import { crmApi } from '../crmApi'
import type { ClienteBuscado } from '../crmApi'

/**
 * El buscador de Gestión y seguimiento: se escribe parte del nombre, el documento o el código del cliente, aparece una
 * lista y al elegir uno se abre su ficha. Mientras tanto muestra el cliente que ya está abierto.
 */
export function BuscadorCliente({
  actual,
  alElegir,
}: {
  actual: { id: number; nombre: string } | null
  /** Sin cliente es que se quitó la elección. */
  alElegir: (cliente: { id: number; nombre: string } | null) => void
}) {
  const [texto, setTexto] = useState('')
  const [resultados, setResultados] = useState<ClienteBuscado[]>([])
  const [abierto, setAbierto] = useState(false)
  const [buscando, setBuscando] = useState(false)

  const cerrar = useCallback(() => setAbierto(false), [])
  const ref = useDismiss<HTMLDivElement>(cerrar)

  // La búsqueda espera a que se deje de escribir: no se pide en cada tecla.
  useEffect(() => {
    const buscado = texto.trim()
    if (buscado.length < 2) {
      setResultados([])
      return
    }

    let vigente = true
    setBuscando(true)
    const espera = setTimeout(() => {
      crmApi
        .buscar(buscado)
        .then((r) => vigente && setResultados(r))
        .catch(() => vigente && setResultados([]))
        .finally(() => vigente && setBuscando(false))
    }, 300)

    return () => {
      vigente = false
      clearTimeout(espera)
    }
  }, [texto])

  const elegir = (c: ClienteBuscado) => {
    alElegir({ id: c.id, nombre: c.nombre })
    setTexto('')
    setResultados([])
    setAbierto(false)
  }

  return (
    <div ref={ref} className="relative w-full sm:w-96">
      <Input
        size="md"
        icon={<Search size={16} />}
        placeholder={actual ? actual.nombre : 'Buscar cliente por nombre, documento o código...'}
        value={texto}
        onChange={(e) => {
          setTexto(e.target.value)
          setAbierto(true)
        }}
        onFocus={() => setAbierto(true)}
        aria-label="Buscar cliente"
      />

      {actual && !texto && (
        <button
          type="button"
          onClick={() => alElegir(null)}
          title="Quitar el cliente"
          aria-label="Quitar el cliente"
          className="absolute top-1/2 right-3 -translate-y-1/2 rounded-full p-1 text-ink-soft hover:bg-surface-alt hover:text-ink"
        >
          <X size={14} />
        </button>
      )}

      {abierto && texto.trim().length >= 2 && (
        <ul
          role="listbox"
          className="absolute z-30 mt-1 max-h-80 w-full overflow-auto rounded-field border border-line bg-white py-1 shadow-lg"
        >
          {buscando && resultados.length === 0 && <li className="px-3 py-2 text-sm text-ink-soft">Buscando...</li>}
          {!buscando && resultados.length === 0 && <li className="px-3 py-2 text-sm text-ink-soft">Ningún cliente coincide.</li>}

          {resultados.map((c) => (
            <li key={c.id} role="option" aria-selected={c.id === actual?.id}>
              <button
                type="button"
                onClick={() => elegir(c)}
                className="flex w-full flex-col items-start px-3 py-2 text-left hover:bg-surface-alt"
              >
                <span className="flex w-full items-center justify-between gap-2">
                  <span className="truncate text-sm font-semibold text-ink">{c.nombre}</span>
                  {!c.activo && <span className="shrink-0 text-[11px] font-semibold text-red-600">Inactivo</span>}
                </span>
                <span className="text-xs text-ink-soft">
                  {c.codigo} · {c.documento}
                  {c.mercado ? ` · ${c.mercado}` : ''}
                </span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
