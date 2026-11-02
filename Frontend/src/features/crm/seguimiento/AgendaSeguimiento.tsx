import { useCallback, useEffect, useState } from 'react'
import { CalendarCheck, CalendarClock, MessageCircle, Phone } from 'lucide-react'
import { Alert, Badge, StatCard, Tabs } from '../../../components/ui'
import { ApiError } from '../../../lib/apiClient'
import { fechaCorta, instanteMs } from '../../../lib/fechas'
import { useRealtime } from '../../../lib/realtime'
import { crmApi } from '../crmApi'
import type { AgendaItem, AgendaSeguimiento as Agenda } from '../crmApi'
import { whatsapp } from '../contacto'
import { EtiquetaResultado, IconoContacto } from '../piezas'

const hora = (iso: string) => new Date(instanteMs(iso)).toLocaleTimeString('es-PE', { hour: '2-digit', minute: '2-digit' })

/** Cuánto lleva vencido: "hace 3 días", "hace 2 h". */
function atraso(iso: string) {
  const minutos = Math.max(0, Math.round((Date.now() - instanteMs(iso)) / 60_000))
  if (minutos < 60) return `hace ${Math.max(1, minutos)} min`
  const horas = Math.round(minutos / 60)
  if (horas < 24) return `hace ${horas} h`
  const dias = Math.round(horas / 24)
  return `hace ${dias} ${dias === 1 ? 'día' : 'días'}`
}

/**
 * La agenda de seguimiento: a quién hay que llamar, escribir o visitar.
 *
 * Es la lista detrás del aviso de la campanita ("3 contactos vencidos"): los vencidos primero, después los de hoy
 * y los de los próximos días. Cuenta lo mismo que el aviso, así que los números coinciden.
 */
export function AgendaSeguimiento({
  puedeVerTodos,
  alElegir,
}: {
  /** Quien ve todos los clientes (sin alcance) puede cambiar entre "Mis contactos" y "Todos". */
  puedeVerTodos: boolean
  alElegir: (item: AgendaItem) => void
}) {
  const [todos, setTodos] = useState(false)
  const [agenda, setAgenda] = useState<Agenda | null>(null)
  const [error, setError] = useState('')

  const cargar = useCallback(async () => {
    try {
      setAgenda(await crmApi.agenda(todos))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No se pudo cargar la agenda')
    }
  }, [todos])

  useEffect(() => {
    void cargar()
  }, [cargar])

  // Se programó, se cumplió o se reprogramó un contacto en otra PC.
  useRealtime(['seguimientos'], cargar)

  if (error) return <Alert tone="warning">{error}</Alert>

  const grupos = agenda
    ? [
        { clave: 'vencidos', titulo: 'Vencidos', items: agenda.items.filter((i) => i.vencida) },
        { clave: 'hoy', titulo: 'Hoy', items: agenda.items.filter((i) => i.esHoy) },
        { clave: 'proximos', titulo: `Próximos ${agenda.dias} días`, items: agenda.items.filter((i) => !i.vencida && !i.esHoy) },
      ]
    : []

  return (
    <div className="space-y-4">
      <div className="grid gap-3 sm:grid-cols-3">
        <StatCard
          label="Vencidos"
          value={String(agenda?.vencidos ?? 0)}
          hint="ya debieron hacerse"
          icon={<CalendarClock size={18} />}
          tono={agenda && agenda.vencidos > 0 ? 'danger' : 'neutral'}
        />
        <StatCard label="Para hoy" value={String(agenda?.hoy ?? 0)} hint="todavía a tiempo" icon={<CalendarCheck size={18} />} tono="warning" />
        <StatCard label="Próximos" value={String(agenda?.proximos ?? 0)} hint={`en los próximos ${agenda?.dias ?? 14} días`} icon={<CalendarClock size={18} />} />
      </div>

      {puedeVerTodos && (
        <Tabs
          items={[
            { id: 'mios', label: 'Mis contactos' },
            { id: 'todos', label: 'Todos' },
          ]}
          active={todos ? 'todos' : 'mios'}
          onChange={(id) => setTodos(id === 'todos')}
        />
      )}

      {!agenda ? (
        <div className="h-48 animate-pulse rounded-panel bg-surface-alt" aria-busy="true" />
      ) : agenda.items.length === 0 ? (
        <div className="rounded-panel border border-dashed border-line bg-white px-4 py-12 text-center">
          <p className="font-medium text-ink">No hay contactos programados</p>
          <p className="mt-1 text-sm text-ink-soft">
            Cuando registres una gestión y dejes programado el siguiente contacto, aparecerá aquí.
          </p>
        </div>
      ) : (
        grupos
          .filter((g) => g.items.length > 0)
          .map((g) => (
            <section key={g.clave} className="space-y-2">
              <h2 className="text-sm font-semibold text-ink">
                {g.titulo} <span className="font-normal text-ink-soft">· {g.items.length}</span>
              </h2>
              <ul className="space-y-2">
                {g.items.map((i) => (
                  <li key={i.gestionId}>
                    <div
                      role="button"
                      tabIndex={0}
                      onClick={() => alElegir(i)}
                      onKeyDown={(e) => (e.key === 'Enter' || e.key === ' ') && alElegir(i)}
                      className={`flex cursor-pointer flex-wrap items-center gap-3 rounded-panel border bg-white p-3 transition-shadow hover:shadow-md ${
                        i.vencida ? 'border-red-200' : 'border-line'
                      }`}
                    >
                      <IconoContacto tipo={i.tipoContacto} />

                      <div className="min-w-0 flex-1">
                        <p className="truncate font-medium text-ink">{i.cliente}</p>
                        <p className="truncate text-xs text-ink-soft">
                          {[i.codigo, i.mercado, i.ruta].filter(Boolean).join(' · ')}
                        </p>
                        <p className="mt-0.5 text-sm text-ink-muted">
                          {i.tipoEtiqueta}
                          {i.proximaAccion ? ` — ${i.proximaAccion}` : ''}
                        </p>
                      </div>

                      <div className="flex flex-col items-end gap-1 text-right">
                        <span className={`text-sm font-semibold ${i.vencida ? 'text-red-600' : 'text-ink'}`}>
                          {i.vencida ? atraso(i.proximo) : `${fechaCorta(i.proximo)} · ${hora(i.proximo)}`}
                        </span>
                        <span className="flex items-center gap-2">
                          {i.vencida && <Badge tone="danger">Vencido</Badge>}
                          <EtiquetaResultado tono={i.tono} texto={i.resultadoEtiqueta} />
                        </span>
                      </div>

                      {i.telefono && (
                        // Llamar o escribir sin abrir la ficha: lo que se hace con la agenda en la mano.
                        <div className="flex gap-1" onClick={(e) => e.stopPropagation()} onKeyDown={(e) => e.stopPropagation()}>
                          <a
                            href={`tel:${i.telefono}`}
                            title="Llamar"
                            aria-label={`Llamar a ${i.cliente}`}
                            className="rounded-md p-2 text-emerald-600 hover:bg-emerald-50"
                          >
                            <Phone size={16} />
                          </a>
                          <a
                            href={`https://wa.me/${whatsapp(i.telefono)}`}
                            target="_blank"
                            rel="noreferrer"
                            title="WhatsApp"
                            aria-label={`Escribir por WhatsApp a ${i.cliente}`}
                            className="rounded-md p-2 text-emerald-600 hover:bg-emerald-50"
                          >
                            <MessageCircle size={16} />
                          </a>
                        </div>
                      )}
                    </div>
                  </li>
                ))}
              </ul>
            </section>
          ))
      )}
    </div>
  )
}
