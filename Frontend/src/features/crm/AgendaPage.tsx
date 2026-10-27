import { useCallback, useEffect, useMemo, useState } from 'react'
import { CalendarCheck, CalendarClock, CalendarDays, Check, ClipboardList, MessageCircle, TriangleAlert } from 'lucide-react'
import { Alert, Badge, ListPage, RowAction, StatCard, Tabs, useToast } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta } from '../../lib/fechas'
import { ACCION, usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { seguimientoApi } from './crmApi'
import { agendaApi } from './crmAgendaApi'
import type { AgendaCrm, EstadoTarea, TareaCrm } from './crmAgendaApi'
import { FichaClienteModal } from './FichaClienteModal'
import { RESULTADOS_GESTION, TIPOS_GESTION } from './formato'

type Quien = 'mias' | 'todas'

const ESTADOS: Record<EstadoTarea, { label: string; tone: 'danger' | 'warning' | 'neutral' }> = {
  VENCIDA: { label: 'Vencida', tone: 'danger' },
  HOY: { label: 'Hoy', tone: 'warning' },
  PROXIMA: { label: 'Próxima', tone: 'neutral' },
}

/** El número para wa.me: solo dígitos y con el 51 de Perú si vino de 9 cifras. */
const whatsapp = (telefono: string) => {
  const digitos = telefono.replace(/\D/g, '')
  return digitos.length === 9 ? `51${digitos}` : digitos
}

/**
 * Agenda de seguimiento: las acciones que se anotaron al registrar una gestión y siguen abiertas.
 *
 * Las vencidas salen primero. Es la otra mitad de la pestaña Seguimiento de la ficha del cliente:
 * allí se anota qué hay que hacer; aquí se ve qué toca y se da por hecho.
 */
export function AgendaPage() {
  const { puede } = usePermisos()
  const toast = useToast()

  const [quien, setQuien] = useState<Quien>('mias')
  const [agenda, setAgenda] = useState<AgendaCrm | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [abierto, setAbierto] = useState<number | null>(null)

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setAgenda(await agendaApi.tareas(quien))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar la agenda.')
    } finally {
      setCargando(false)
    }
  }, [quien])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['seguimientos', 'clientes'], cargar)

  const hecha = useCallback(
    async (t: TareaCrm) => {
      try {
        await seguimientoApi.cumplir(t.gestionId, true)
        toast.exito('Acción dada por hecha.')
        await cargar()
      } catch (e) {
        toast.error(e instanceof ApiError ? e.message : 'No pudimos actualizar la acción.')
      }
    },
    [cargar, toast],
  )

  const columns: DataTableColumn<TareaCrm>[] = useMemo(
    () => [
      {
        key: 'estado',
        label: 'Estado',
        filterType: 'select',
        filterOptions: Object.entries(ESTADOS).map(([value, { label }]) => ({ value, label })),
        value: (row) => row.estado,
        render: (row) => <Badge tone={ESTADOS[row.estado].tone}>{ESTADOS[row.estado].label}</Badge>,
      },
      {
        key: 'fecha',
        label: 'Día',
        filterable: false,
        value: (row) => new Date(row.fecha).getTime(),
        render: (row) => (
          <span className="flex flex-col">
            <span>{fechaCorta(row.fecha)}</span>
            {row.diasAtraso > 0 && (
              <span className="text-xs text-red-600">
                hace {row.diasAtraso} {row.diasAtraso === 1 ? 'día' : 'días'}
              </span>
            )}
          </span>
        ),
      },
      {
        key: 'accion',
        label: 'Qué hay que hacer',
        filterable: false,
        render: (row) => (
          <span className="flex flex-col">
            <span className="font-medium text-ink">{row.accion}</span>
            <span className="text-xs text-ink-soft">
              {TIPOS_GESTION[row.tipo]} · {RESULTADOS_GESTION[row.resultado].label}
              {row.registradaPor ? ` · ${row.registradaPor}` : ''}
            </span>
          </span>
        ),
      },
      {
        key: 'cliente',
        label: 'Cliente',
        filterable: false,
        render: (row) => (
          <span className="flex flex-col">
            <span className="font-medium text-ink">{row.cliente}</span>
            <span className="text-xs text-ink-soft">
              {row.codigo}
              {row.mercado ? ` · ${row.mercado}` : ''}
            </span>
          </span>
        ),
      },
      {
        key: 'ruta',
        label: 'Ruta',
        filterType: 'select',
        filterOptions: [...new Set((agenda?.items ?? []).map((t) => t.ruta).filter((r): r is string => !!r))]
          .sort((a, b) => a.localeCompare(b, 'es'))
          .map((r) => ({ value: r, label: r })),
        value: (row) => row.ruta ?? '',
        render: (row) => row.ruta ?? '—',
      },
      {
        key: 'nota',
        label: 'Lo que se habló',
        filterable: false,
        render: (row) => <span className="line-clamp-2 max-w-xs text-sm text-ink-muted">{row.nota}</span>,
      },
    ],
    [agenda],
  )

  const resumen = agenda?.resumen

  return (
    <ListPage
      icon={<ClipboardList size={20} />}
      title="Agenda de seguimiento"
      description="Lo que quedó anotado para hacer con los clientes, las acciones vencidas primero."
      alert={
        error ? (
          <Alert>{error}</Alert>
        ) : agenda?.soloPropios && quien === 'todas' ? (
          <Alert tone="info">Ves solo los clientes de tus rutas y los que tienes asignados.</Alert>
        ) : undefined
      }
      banner={
        <Tabs
          items={[
            { id: 'mias', label: 'Mías' },
            { id: 'todas', label: 'Todas' },
          ]}
          active={quien}
          onChange={(id) => setQuien(id as Quien)}
        />
      }
      stats={
        <>
          <StatCard
            label="Vencidas"
            value={String(resumen?.vencidas ?? 0)}
            hint={resumen?.vencidaDesde ? `la más antigua, del ${fechaCorta(resumen.vencidaDesde)}` : 'al día'}
            icon={<TriangleAlert size={18} />}
            tono={resumen && resumen.vencidas > 0 ? 'danger' : 'neutral'}
          />
          <StatCard
            label="Para hoy"
            value={String(resumen?.hoy ?? 0)}
            icon={<CalendarClock size={18} />}
            tono="warning"
          />
          <StatCard label="Próximas" value={String(resumen?.proximas ?? 0)} icon={<CalendarDays size={18} />} />
        </>
      }
      columns={columns}
      rows={agenda?.items ?? []}
      rowKey="gestionId"
      onRowClick={(row) => setAbierto(row.clienteId)}
      cardIcon={CalendarCheck}
      searchPlaceholder="Buscar cliente, acción..."
      empty={cargando ? 'Cargando agenda...' : 'No hay acciones pendientes. Las que anotes en el seguimiento aparecen aquí.'}
      rowActions={(row) => (
        <>
          {row.telefono && (
            <a
              href={`https://wa.me/${whatsapp(row.telefono)}`}
              target="_blank"
              rel="noreferrer"
              title="WhatsApp"
              aria-label="WhatsApp"
              onClick={(e) => e.stopPropagation()}
              className="inline-flex rounded-md p-1.5 text-emerald-600 transition-colors hover:bg-emerald-50"
            >
              <MessageCircle size={16} />
            </a>
          )}
          {puede('crm.seguimiento', ACCION.editar) && (
            <RowAction label="Dar por hecha" tone="success" onClick={() => void hecha(row)}>
              <Check size={16} />
            </RowAction>
          )}
        </>
      )}
      note="Toca una fila para abrir la ficha del cliente y anotar la nueva gestión."
    >
      {abierto !== null && (
        <FichaClienteModal clienteId={abierto} periodo="mes" onClose={() => setAbierto(null)} onCambio={cargar} />
      )}
    </ListPage>
  )
}

