import { useState } from 'react'
import { CheckCheck } from 'lucide-react'
import { Alert, Button, Input, Modal } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta } from '../../lib/fechas'
import { asistenciaApi } from './asistenciaApi'
import type { AsistenciaResponse, EstadoAsistencia } from './asistenciaApi'
import { trabajaba } from './empleadoApi'
import type { EmpleadoResponse } from './empleadoApi'

const OPCIONES: { value: EstadoAsistencia; label: string; activo: string }[] = [
  { value: 'PRESENTE', label: 'Presente', activo: 'border-emerald-600 bg-emerald-600 text-white' },
  { value: 'TARDANZA', label: 'Tardanza', activo: 'border-amber-500 bg-amber-500 text-white' },
  { value: 'FALTA', label: 'Falta', activo: 'border-red-600 bg-red-600 text-white' },
  { value: 'PERMISO', label: 'Permiso', activo: 'border-[rgb(var(--sys-rgb))] bg-[rgb(var(--sys-rgb))] text-white' },
]

interface Fila {
  estado: EstadoAsistencia | ''
  observacion: string
}

/**
 * El pase de lista de un día: todos los empleados en una lista, cada uno con
 * su estado. Se guarda todo junto; a quien ya tenía marca se le corrige.
 */
export function PaseListaModal({
  fecha,
  feriado,
  empleados,
  marcas,
  puedeCorregir,
  onClose,
  onGuardado,
}: {
  fecha: string
  feriado?: string
  empleados: EmpleadoResponse[]
  /** Las marcas activas de ese día. */
  marcas: AsistenciaResponse[]
  puedeCorregir: boolean
  onClose: () => void
  onGuardado: (mensaje: string) => void | Promise<void>
}) {
  const marcaDe = new Map(marcas.map((m) => [m.empleadoId, m]))
  const lista = empleados
    .filter((e) => trabajaba(e, fecha) || marcaDe.has(e.id))
    .sort((a, b) => a.nombreCompleto.localeCompare(b.nombreCompleto, 'es'))

  const [filas, setFilas] = useState<Record<number, Fila>>(() =>
    Object.fromEntries(
      lista.map((e) => {
        const m = marcaDe.get(e.id)
        return [e.id, { estado: m?.estado ?? '', observacion: m?.observacion ?? '' }]
      }),
    ),
  )
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  const bloqueada = (id: number) => marcaDe.has(id) && !puedeCorregir
  const marcados = lista.filter((e) => filas[e.id]?.estado).length
  const sinMarcar = lista.filter((e) => !filas[e.id]?.estado)

  const cambiar = (id: number, cambios: Partial<Fila>) => setFilas((prev) => ({ ...prev, [id]: { ...prev[id], ...cambios } }))

  // Tocar otra vez el estado elegido lo quita, pero solo si todavía no está
  // guardado: una marca ya registrada se anula desde Registro.
  const elegir = (id: number, estado: EstadoAsistencia) => {
    const actual = filas[id]?.estado
    if (actual === estado && !marcaDe.has(id)) cambiar(id, { estado: '', observacion: '' })
    else cambiar(id, { estado })
  }

  const guardar = async () => {
    const cambios = lista.flatMap((e) => {
      const fila = filas[e.id]
      if (!fila?.estado) return []
      const original = marcaDe.get(e.id)
      const observacion = fila.observacion.trim() || null
      if (original && original.estado === fila.estado && (original.observacion ?? null) === observacion) return []
      return [{ empleadoId: e.id, estado: fila.estado, observacion }]
    })
    if (cambios.length === 0) return setError('No hay cambios para guardar.')

    setGuardando(true)
    setError('')
    try {
      const r = await asistenciaApi.marcarDia({ fecha, marcas: cambios })
      const partes = [
        r.creadas ? `${r.creadas} registrada${r.creadas === 1 ? '' : 's'}` : '',
        r.corregidas ? `${r.corregidas} corregida${r.corregidas === 1 ? '' : 's'}` : '',
      ].filter(Boolean)
      await onGuardado(`Asistencia guardada: ${partes.join(', ')}`)
    } catch (e) {
      setError(e instanceof ApiError ? (e.errors.length ? e.errors.join(' ') : e.message) : 'No pudimos guardar la asistencia.')
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal
      open
      size="lg"
      title={`Asistencia del ${fechaCorta(fecha)}`}
      description="Elige el estado de cada empleado y guarda todo junto. Para quitar una marca ya guardada, anúlala en Registro."
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            Guardar asistencia
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        {error && <Alert>{error}</Alert>}
        {feriado && (
          <Alert tone="info">
            Feriado: {feriado}. A quien trabaje este día se le paga doble en la planilla.
          </Alert>
        )}

        <div className="flex flex-wrap items-center justify-between gap-2">
          <p className="text-sm text-ink-soft">
            Marcados <strong className="text-ink">{marcados}</strong> de {lista.length}
          </p>
          {sinMarcar.length > 0 && (
            <Button
              size="sm"
              variant="secondary"
              iconRight={<CheckCheck size={15} />}
              onClick={() =>
                setFilas((prev) => {
                  const siguiente = { ...prev }
                  for (const e of sinMarcar) siguiente[e.id] = { estado: 'PRESENTE', observacion: '' }
                  return siguiente
                })
              }
            >
              Presentes los que faltan ({sinMarcar.length})
            </Button>
          )}
        </div>

        {lista.length === 0 ? (
          <p className="rounded-panel border border-line p-4 text-center text-sm text-ink-soft">
            Nadie trabajaba en esta fecha según su fecha de ingreso y cese.
          </p>
        ) : (
          <div className="overflow-hidden rounded-panel border border-line">
            {lista.map((e) => {
              const fila = filas[e.id] ?? { estado: '', observacion: '' }
              const cerrada = bloqueada(e.id)
              return (
                <div key={e.id} className="flex flex-col gap-2 border-b border-line px-3 py-2.5 last:border-b-0">
                  <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium text-ink">{e.nombreCompleto}</p>
                      <p className="truncate text-xs text-ink-soft">
                        {e.cargo ?? 'Sin cargo'}
                        {cerrada && ' · ya marcado (corregir pide permiso de editar)'}
                      </p>
                    </div>
                    <div className="grid grid-cols-4 gap-1 sm:w-[22rem]">
                      {OPCIONES.map((o) => (
                        <button
                          key={o.value}
                          type="button"
                          disabled={cerrada}
                          onClick={() => elegir(e.id, o.value)}
                          className={`rounded-field border px-2 py-1.5 text-xs font-semibold transition-colors disabled:cursor-not-allowed disabled:opacity-60 ${
                            fila.estado === o.value ? o.activo : 'border-line bg-white text-ink-soft hover:border-ink-soft'
                          }`}
                        >
                          {o.label}
                        </button>
                      ))}
                    </div>
                  </div>
                  {fila.estado && fila.estado !== 'PRESENTE' && !cerrada && (
                    <Input
                      size="sm"
                      placeholder="Observación: minutos de tardanza, motivo del permiso..."
                      value={fila.observacion}
                      onChange={(ev) => cambiar(e.id, { observacion: ev.target.value })}
                    />
                  )}
                </div>
              )
            })}
          </div>
        )}
      </div>
    </Modal>
  )
}
