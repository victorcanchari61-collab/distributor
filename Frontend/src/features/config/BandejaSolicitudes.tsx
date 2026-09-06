import { useCallback, useEffect, useState } from 'react'
import { CalendarClock, Check, Inbox, Infinity as InfinityIcon, X, Zap } from 'lucide-react'
import { Alert, Badge, Button, Modal, PageSection, SysDataTable, cn } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { resolveNav } from '../../components/layout'
import { ApiError } from '../../lib/apiClient'
import { useRealtime } from '../../lib/realtime'
import { ALCANCE, ALCANCE_LABEL } from './permisoApi'
import type { Alcance } from './permisoApi'
import { ESTADO_SOLICITUD, solicitudApi } from './solicitudApi'
import type { SolicitudPermisoResponse } from './solicitudApi'

const ACCION_LABEL: Record<string, string> = {
  ver: 'Ver',
  crear: 'Crear',
  editar: 'Editar',
  anular: 'Anular',
  eliminar: 'Eliminar',
  exportar: 'Exportar',
  importar: 'Importar',
  confirmar: 'Confirmar',
  cobrar: 'Cobrar',
}

const ICONO_ALCANCE: Record<Alcance, React.ReactNode> = {
  [ALCANCE.unaVez]: <Zap size={13} />,
  [ALCANCE.temporal]: <CalendarClock size={13} />,
  [ALCANCE.permanente]: <InfinityIcon size={13} />,
}

const nombrePantalla = (submodulo: string) => resolveNav(submodulo).item?.label ?? submodulo

/**
 * Lo que la gente pidió al toparse con una acción bloqueada.
 *
 * Quien aprueba elige el alcance, no quien pide: casi siempre lo que hace
 * falta es una vez — anular ESA nota — y concederlo para siempre por comodidad
 * es como se termina con vendedores que pueden anular cualquier cosa.
 *
 * Lo rechazado se guarda igual: que algo se pida mucho y se niegue siempre es
 * la señal de que el rol está mal repartido.
 */
export function BandejaSolicitudes() {
  const [solicitudes, setSolicitudes] = useState<SolicitudPermisoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [aprobando, setAprobando] = useState<SolicitudPermisoResponse | null>(null)

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setSolicitudes(await solicitudApi.bandeja())
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las solicitudes.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  // Alguien pide un permiso desde otra PC y aparece aqui solo: si hubiera que
  // recargar la pagina, quien espera al otro lado no sabe cuanto esperar.
  useRealtime('permisos', cargar)

  const rechazar = async (s: SolicitudPermisoResponse) => {
    try {
      await solicitudApi.rechazar(s.id)
      await cargar()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos rechazar la solicitud.')
    }
  }

  const columns: DataTableColumn<SolicitudPermisoResponse>[] = [
    {
      key: 'usuario',
      label: 'Quién pide',
      render: (s) => <span className="font-medium text-ink">{s.usuario}</span>,
    },
    {
      key: 'submodulo',
      label: 'Pantalla',
      value: (s) => nombrePantalla(s.submodulo),
      render: (s) => nombrePantalla(s.submodulo),
    },
    {
      key: 'accion',
      label: 'Acción',
      render: (s) => ACCION_LABEL[s.accion] ?? s.accion,
    },
    {
      key: 'motivo',
      label: 'Para qué',
      render: (s) =>
        s.motivo ?? <span className="text-ink-soft">no lo escribió</span>,
    },
    {
      key: 'fechaSolicitud',
      label: 'Cuándo',
      render: (s) => new Date(s.fechaSolicitud).toLocaleString('es-PE'),
    },
    {
      key: 'estado',
      label: 'Estado',
      value: (s) =>
        s.estado === ESTADO_SOLICITUD.pendiente
          ? 'Pendiente'
          : s.estado === ESTADO_SOLICITUD.aprobada
            ? 'Aprobada'
            : 'Rechazada',
      render: (s) => {
        if (s.estado === ESTADO_SOLICITUD.pendiente) return <Badge tone="warning">Pendiente</Badge>
        if (s.estado === ESTADO_SOLICITUD.aprobada) return <Badge tone="success">Aprobada</Badge>
        return <Badge tone="danger">Rechazada</Badge>
      },
    },
  ]

  const pendientes = solicitudes.filter((s) => s.estado === ESTADO_SOLICITUD.pendiente).length

  return (
    <PageSection>
      {error && <Alert>{error}</Alert>}

      <p className="mb-3 text-sm text-ink-muted">
        {pendientes === 0
          ? 'No hay nada esperando respuesta.'
          : `${pendientes} ${pendientes === 1 ? 'solicitud espera' : 'solicitudes esperan'} respuesta.`}
      </p>

      <SysDataTable
        columns={columns}
        rows={solicitudes}
        cardIcon={Inbox}
        searchPlaceholder="Buscar por persona, pantalla, motivo..."
        empty={cargando ? 'Cargando...' : 'Nadie ha pedido permisos todavía.'}
        actions={(s) =>
          s.estado === ESTADO_SOLICITUD.pendiente ? (
            <span className="flex gap-1">
              <button
                type="button"
                onClick={() => setAprobando(s)}
                title="Aprobar"
                className={cn(
                  'cursor-pointer rounded-md p-1.5 text-ink-muted transition-colors',
                  'hover:bg-emerald-50 hover:text-emerald-600',
                )}
              >
                <Check size={15} />
              </button>
              <button
                type="button"
                onClick={() => void rechazar(s)}
                title="Rechazar"
                className={cn(
                  'cursor-pointer rounded-md p-1.5 text-ink-muted transition-colors',
                  'hover:bg-rose-50 hover:text-rose-600',
                )}
              >
                <X size={15} />
              </button>
            </span>
          ) : null
        }
      />

      {aprobando && (
        <ModalAprobar
          solicitud={aprobando}
          onCerrar={() => setAprobando(null)}
          onAprobado={async () => {
            setAprobando(null)
            await cargar()
          }}
        />
      )}
    </PageSection>
  )
}

/** Elegir hasta cuándo vale lo que se está concediendo. */
function ModalAprobar({
  solicitud,
  onCerrar,
  onAprobado,
}: {
  solicitud: SolicitudPermisoResponse
  onCerrar: () => void
  onAprobado: () => Promise<void>
}) {
  const [alcance, setAlcance] = useState<Alcance>(ALCANCE.unaVez)
  const [expiraEn, setExpiraEn] = useState('')
  const [respuesta, setRespuesta] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  const aprobar = async () => {
    setGuardando(true)
    setError('')
    try {
      await solicitudApi.aprobar(solicitud.id, {
        alcance,
        expiraEn: alcance === ALCANCE.temporal ? new Date(expiraEn).toISOString() : null,
        respuesta: respuesta.trim() || null,
      })
      await onAprobado()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos aprobar la solicitud.')
    } finally {
      setGuardando(false)
    }
  }

  const listo = alcance !== ALCANCE.temporal || expiraEn !== ''

  return (
    <Modal
      open
      onClose={onCerrar}
      title={`Conceder a ${solicitud.usuario}`}
      size="md"
      footer={
        <>
          <Button variant="secondary" onClick={onCerrar}>
            Cancelar
          </Button>
          <Button disabled={!listo} loading={guardando} onClick={() => void aprobar()}>
            Aprobar
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        {error && <Alert>{error}</Alert>}

        <div className="rounded-field bg-surface-alt px-3 py-2 text-sm">
          <p className="text-ink">
            <b>{ACCION_LABEL[solicitud.accion] ?? solicitud.accion}</b> en{' '}
            <b>{nombrePantalla(solicitud.submodulo)}</b>
          </p>
          {solicitud.motivo && <p className="mt-1 text-ink-muted">«{solicitud.motivo}»</p>}
        </div>

        <div>
          <p className="mb-1.5 text-sm font-medium text-ink">¿Hasta cuándo?</p>
          <div className="grid gap-2 sm:grid-cols-3">
            {([ALCANCE.unaVez, ALCANCE.temporal, ALCANCE.permanente] as Alcance[]).map((a) => (
              <button
                key={a}
                type="button"
                onClick={() => setAlcance(a)}
                className={cn(
                  'flex cursor-pointer items-center gap-2 rounded-field border px-3 py-2 text-sm transition-colors',
                  alcance === a
                    ? 'border-[rgb(var(--sys-rgb))] bg-[rgb(var(--sys-rgb)/0.08)] font-semibold text-[rgb(var(--sys-ink-rgb))]'
                    : 'border-line text-ink-muted hover:bg-surface-alt',
                )}
              >
                {ICONO_ALCANCE[a]}
                {ALCANCE_LABEL[a]}
              </button>
            ))}
          </div>
          <p className="mt-1.5 text-xs text-ink-soft">
            {alcance === ALCANCE.unaVez &&
              'Se gasta al usarlo una vez. Si la operación falla, no se gasta.'}
            {alcance === ALCANCE.temporal && 'Deja de valer solo, sin que nadie tenga que retirarlo.'}
            {alcance === ALCANCE.permanente &&
              'No vence. Si varias personas lo piden, es mejor ponerlo en el rol.'}
          </p>
        </div>

        {alcance === ALCANCE.temporal && (
          <label className="block">
            <span className="mb-1.5 block text-sm font-medium text-ink">Vence el</span>
            <input
              type="datetime-local"
              value={expiraEn}
              onChange={(e) => setExpiraEn(e.target.value)}
              className="w-full rounded-field border border-line px-3 py-2 text-sm"
            />
          </label>
        )}

        <label className="block">
          <span className="mb-1.5 block text-sm font-medium text-ink">
            Respuesta <span className="font-normal text-ink-soft">(opcional)</span>
          </span>
          <input
            type="text"
            value={respuesta}
            onChange={(e) => setRespuesta(e.target.value)}
            maxLength={300}
            className="w-full rounded-field border border-line px-3 py-2 text-sm"
          />
        </label>
      </div>
    </Modal>
  )
}
