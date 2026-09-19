import { useEffect, useState } from 'react'
import { PackageCheck } from 'lucide-react'
import { Alert, Button, Checkbox, Desplegable, Modal, RowAction, VisorPdf } from '../../components/ui'
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
 *
 * El corte de horario recorta por CUÁNDO se registró cada pedido, no por el día
 * del reparto: el primero es la carga base (hasta las 15:00) y los otros dos son
 * aumentos, solo lo que se agregó después, para sumarlo a lo que ya subió.
 */
export function AccionCargaDespacho({ id, numero }: Props) {
  const [paso, setPaso] = useState<'cerrado' | 'filtros' | 'visor'>('cerrado')
  const [opciones, setOpciones] = useState<OpcionesCarga | null>(null)
  const [error, setError] = useState('')
  const [mercados, setMercados] = useState<number[]>([])
  const [unidades, setUnidades] = useState<string[]>([])
  const [porMercado, setPorMercado] = useState(false)
  // 0 es todo el camión; 1, 2 y 3 son los cortes de horario.
  const [corte, setCorte] = useState(0)

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
    corte ? `corte=${corte}` : '',
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
              <div className="flex flex-col gap-1.5">
                <Desplegable
                  label="Corte de horario"
                  value={corte}
                  onChange={(v) => setCorte(Number(v))}
                  options={opciones.cortes.map((c) => ({ value: c.codigo, label: c.nombre }))}
                />
                {corte > 1 && (
                  <p className="text-xs text-ink-soft">
                    Aumentos: sale solo lo que se agregó en esa franja —lo que subió de cantidad, los productos y los
                    pedidos nuevos—, para sumarlo a lo que ya se cargó. Lo que bajó sale en negativo.
                  </p>
                )}
                {corte === 1 && (
                  <p className="text-xs text-ink-soft">
                    La carga base: los pedidos como quedaron hasta las 15:00, incluido lo registrado en días anteriores.
                  </p>
                )}
              </div>

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
                Los cortes cuentan por la fecha y hora en que se registró cada pedido o aumento; el día del reparto no
                influye.
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
