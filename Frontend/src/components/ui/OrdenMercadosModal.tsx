import { useEffect, useState } from 'react'
import { ArrowDown, ArrowUp, FileText, GripVertical, RotateCcw } from 'lucide-react'
import { Button } from './Button'
import { Modal } from './Modal'
import { cn } from './cn'
import { api } from '../../lib/apiClient'

interface MercadoDelCamion {
  id: number
  nombre: string
  pedidos: number
}

/**
 * Antes de generar los pedidos de un despacho: en qué orden de mercados salen las hojas.
 *
 * El repartidor entrega mercado por mercado, así que las hojas tienen que venir en el orden en que pasa el
 * camión. Se acomoda aquí, arrastrando o con las flechas, y recién al darle "Generar PDF" se arma el documento.
 * El orden vale para esa impresión: no se guarda en el despacho.
 */
export function OrdenMercadosModal({
  id,
  numero,
  onCancelar,
  onContinuar,
}: {
  id: number
  numero: string
  onCancelar: () => void
  /** Los ids de mercado en el orden elegido; vacío si se deja el orden de siempre. */
  onContinuar: (orden: number[]) => void
}) {
  const [mercados, setMercados] = useState<MercadoDelCamion[]>([])
  const [orden, setOrden] = useState<number[]>([])
  const [cargando, setCargando] = useState(true)
  const [arrastrando, setArrastrando] = useState<number | null>(null)
  const [sobre, setSobre] = useState<number | null>(null)

  // Los mercados que lleva el camión. Si no se pueden leer, se imprime en el orden de siempre.
  useEffect(() => {
    let vivo = true
    void api
      .get<{ mercados: MercadoDelCamion[] }>(`/despacho/${id}/carga/opciones`)
      .then((o) => {
        if (!vivo) return
        setMercados(o.mercados)
        setOrden(o.mercados.map((m) => m.id))
      })
      .catch(() => {})
      .finally(() => vivo && setCargando(false))
    return () => {
      vivo = false
    }
  }, [id])

  /** Pone un mercado en el lugar de otro. */
  const mover = (desdeId: number, haciaId: number) =>
    setOrden((actual) => {
      const de = actual.indexOf(desdeId)
      const a = actual.indexOf(haciaId)
      if (de < 0 || a < 0 || de === a) return actual
      const nuevo = [...actual]
      nuevo.splice(de, 1)
      nuevo.splice(a, 0, desdeId)
      return nuevo
    })

  const deFabrica = mercados.map((m) => m.id).join(',') === orden.join(',')

  return (
    <Modal
      open
      size="md"
      title={`Ordenar mercados — ${numero}`}
      description="Acomoda los mercados en el orden en que pasa el camión. Las hojas saldrán en ese orden."
      onClose={onCancelar}
      footer={
        <>
          <Button
            variant="ghost"
            size="sm"
            disabled={deFabrica}
            onClick={() => setOrden(mercados.map((m) => m.id))}
            iconRight={<RotateCcw size={15} />}
          >
            Restablecer
          </Button>
          <span className="flex-1" />
          <Button variant="secondary" size="sm" onClick={onCancelar}>
            Cancelar
          </Button>
          <Button
            size="sm"
            disabled={cargando}
            onClick={() => onContinuar(deFabrica ? [] : orden)}
            iconRight={<FileText size={15} />}
          >
            Generar PDF
          </Button>
        </>
      }
    >
      {cargando ? (
        <p className="py-8 text-center text-sm text-ink-soft">Cargando los mercados del camión...</p>
      ) : mercados.length === 0 ? (
        <p className="py-8 text-center text-sm text-ink-soft">
          No pudimos leer los mercados de este despacho. Las hojas saldrán en el orden de siempre.
        </p>
      ) : (
        <ol className="flex flex-col gap-1.5">
          {orden.map((mid, i) => {
            const m = mercados.find((x) => x.id === mid)
            if (!m) return null

            return (
              <li
                key={mid}
                draggable
                onDragStart={() => setArrastrando(mid)}
                onDragOver={(e) => {
                  e.preventDefault()
                  setSobre(mid)
                }}
                onDragLeave={() => setSobre((s) => (s === mid ? null : s))}
                onDrop={() => {
                  if (arrastrando !== null) mover(arrastrando, mid)
                  setArrastrando(null)
                  setSobre(null)
                }}
                onDragEnd={() => {
                  setArrastrando(null)
                  setSobre(null)
                }}
                className={cn(
                  'flex cursor-grab items-center gap-3 rounded-field border bg-white px-2.5 py-2 transition active:cursor-grabbing',
                  sobre === mid && arrastrando !== mid ? 'border-blue-500 bg-blue-50' : 'border-line',
                  arrastrando === mid && 'opacity-40',
                )}
              >
                <GripVertical size={16} className="shrink-0 text-ink-soft" aria-hidden />
                <span className="grid size-6 shrink-0 place-items-center rounded-full bg-surface-alt text-xs font-semibold text-ink">
                  {i + 1}
                </span>
                <span className="min-w-0 flex-1 truncate text-sm font-semibold text-ink">
                  {m.id === 0 ? m.nombre : `Mercado ${m.nombre}`}
                </span>
                <span className="shrink-0 text-xs text-ink-soft">
                  {m.pedidos} {m.pedidos === 1 ? 'pedido' : 'pedidos'}
                </span>
                <span className="flex shrink-0 gap-0.5">
                  <button
                    type="button"
                    aria-label="Subir"
                    disabled={i === 0}
                    onClick={() => mover(mid, orden[i - 1])}
                    className="rounded p-1 text-ink-soft hover:bg-surface-alt hover:text-ink disabled:opacity-30"
                  >
                    <ArrowUp size={15} />
                  </button>
                  <button
                    type="button"
                    aria-label="Bajar"
                    disabled={i === orden.length - 1}
                    onClick={() => mover(mid, orden[i + 1])}
                    className="rounded p-1 text-ink-soft hover:bg-surface-alt hover:text-ink disabled:opacity-30"
                  >
                    <ArrowDown size={15} />
                  </button>
                </span>
              </li>
            )
          })}
        </ol>
      )}
    </Modal>
  )
}
