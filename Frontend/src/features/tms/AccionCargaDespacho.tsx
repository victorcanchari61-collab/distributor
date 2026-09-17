import { useEffect, useState } from 'react'
import { PackageCheck } from 'lucide-react'
import { Alert, Button, Checkbox, Modal, RowAction, VisorPdf } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { despachoApi } from './despachoApi'
import type { OpcionesCarga } from './despachoApi'

interface Props {
  id: number
  numero: string
}

/**
 * El reporte de carga, con sus filtros antes de generarlo.
 *
 * Primero se elige qué mercados y qué unidades de medida entran —solo las
 * bolsas, solo el mercado 7— y si va un bloque por mercado; recién entonces se
 * abre el PDF. Sin marcar nada sale el camión completo.
 */
export function AccionCargaDespacho({ id, numero }: Props) {
  const [paso, setPaso] = useState<'cerrado' | 'filtros' | 'visor'>('cerrado')
  const [opciones, setOpciones] = useState<OpcionesCarga | null>(null)
  const [error, setError] = useState('')
  const [mercados, setMercados] = useState<number[]>([])
  const [unidades, setUnidades] = useState<string[]>([])
  const [porMercado, setPorMercado] = useState(false)

  useEffect(() => {
    if (paso !== 'filtros' || opciones) return
    despachoApi
      .opcionesCarga(id)
      .then(setOpciones)
      .catch((e) => setError(e instanceof ApiError ? e.message : 'No pudimos cargar los filtros.'))
  }, [paso, opciones, id])

  const alternar = <T,>(lista: T[], valor: T) =>
    lista.includes(valor) ? lista.filter((v) => v !== valor) : [...lista, valor]

  const consulta = [
    mercados.length ? `mercados=${mercados.join(',')}` : '',
    unidades.length ? `unidades=${unidades.map(encodeURIComponent).join(',')}` : '',
    porMercado ? 'porMercado=true' : '',
  ]
    .filter(Boolean)
    .join('&')

  return (
    <>
      <RowAction label={`Reporte de carga de ${numero}`} tone="neutral" onClick={() => setPaso('filtros')}>
        <PackageCheck size={15} />
      </RowAction>

      {paso === 'filtros' && (
        <Modal
          open
          title={`Reporte de carga — ${numero}`}
          description="Elige qué entra. Sin marcar nada sale todo el camión."
          onClose={() => setPaso('cerrado')}
          footer={
            <>
              <Button variant="secondary" size="sm" onClick={() => setPaso('cerrado')}>
                Cancelar
              </Button>
              <Button size="sm" disabled={!opciones} onClick={() => setPaso('visor')}>
                Generar
              </Button>
            </>
          }
        >
          {error && <Alert>{error}</Alert>}
          {!opciones && !error && <p className="py-6 text-center text-sm text-ink-soft">Cargando...</p>}
          {opciones && (
            <div className="flex flex-col gap-5">
              <Grupo
                titulo="Mercados"
                todos={mercados.length === 0}
                onTodos={() => setMercados([])}
              >
                {opciones.mercados.map((m) => (
                  <Checkbox
                    key={m.id}
                    label={`Mercado ${m.nombre} (${m.pedidos} ${m.pedidos === 1 ? 'pedido' : 'pedidos'})`}
                    checked={mercados.includes(m.id)}
                    onChange={() => setMercados((p) => alternar(p, m.id))}
                  />
                ))}
              </Grupo>

              <Grupo
                titulo="Unidades de medida"
                todos={unidades.length === 0}
                onTodos={() => setUnidades([])}
              >
                {opciones.unidades.map((u) => (
                  <Checkbox
                    key={u.codigo}
                    label={`${u.nombre} (${u.productos} ${u.productos === 1 ? 'producto' : 'productos'})`}
                    checked={unidades.includes(u.codigo)}
                    onChange={() => setUnidades((p) => alternar(p, u.codigo))}
                  />
                ))}
              </Grupo>

              <div className="border-t border-line pt-4">
                <Checkbox
                  label="Separar por mercado (un bloque por cada uno)"
                  checked={porMercado}
                  onChange={(e) => setPorMercado(e.target.checked)}
                />
              </div>

              <p className="text-xs text-ink-soft">
                Cortes de horario: próximamente, cuando se registren los cambios de cada pedido.
              </p>
            </div>
          )}
        </Modal>
      )}

      {paso === 'visor' && (
        <VisorPdf
          documento="despacho"
          id={id}
          numero={numero}
          reporte="carga"
          consulta={consulta}
          onCerrar={() => setPaso('filtros')}
        />
      )}
    </>
  )
}

function Grupo({
  titulo,
  todos,
  onTodos,
  children,
}: {
  titulo: string
  todos: boolean
  onTodos: () => void
  children: React.ReactNode
}) {
  return (
    <div>
      <div className="mb-2 flex items-center justify-between">
        <p className="text-sm font-semibold text-ink">{titulo}</p>
        <button
          type="button"
          onClick={onTodos}
          className="text-xs font-semibold text-ink-soft hover:text-ink disabled:opacity-50"
          disabled={todos}
        >
          {todos ? 'Todos' : 'Quitar filtro'}
        </button>
      </div>
      <div className="grid gap-2 sm:grid-cols-2">{children}</div>
    </div>
  )
}
