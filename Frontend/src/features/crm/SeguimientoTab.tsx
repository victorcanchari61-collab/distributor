import { useCallback, useEffect, useState } from 'react'
import { CalendarClock, Check, RotateCcw, Trash2 } from 'lucide-react'
import { Alert, Badge, Button, Input, RowAction, Select, useConfirmacion, useToast } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta, fechaHora, hoyLocal } from '../../lib/fechas'
import { ACCION, usePermisos } from '../../lib/permisos'
import { seguimientoApi } from './crmApi'
import type { GestionCrm, ResultadoGestion, TipoGestion } from './crmApi'
import { RESULTADOS_GESTION, TIPOS_GESTION } from './formato'

const SUBMODULO = 'crm.seguimiento'

const vacio = {
  tipo: 'LLAMADA' as TipoGestion,
  resultado: 'CONTACTADO' as ResultadoGestion,
  nota: '',
  proximaAccion: '',
  proximaFecha: '',
}

/**
 * Las gestiones con un cliente: lo que se habló y qué toca hacer después.
 *
 * Es un historial. Una gestión no se reescribe: se agrega otra. Lo único que se cambia es dar por
 * hecha la próxima acción que dejó anotada.
 */
export function SeguimientoTab({ clienteId, onCambio }: { clienteId: number; onCambio: () => void }) {
  const { puede, puedeVer } = usePermisos()
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()

  const [gestiones, setGestiones] = useState<GestionCrm[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [form, setForm] = useState(vacio)
  const [guardando, setGuardando] = useState(false)

  const verPermitido = puedeVer(SUBMODULO)

  const cargar = useCallback(async () => {
    try {
      setGestiones(await seguimientoApi.listar(clienteId))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar el seguimiento.')
    } finally {
      setCargando(false)
    }
  }, [clienteId])

  useEffect(() => {
    if (verPermitido) void cargar()
    else setCargando(false)
  }, [cargar, verPermitido])

  if (!verPermitido) {
    return <Alert tone="info">No tienes permiso para ver el seguimiento de los clientes.</Alert>
  }

  const cambio = async () => {
    await cargar()
    onCambio()
  }

  const guardar = async () => {
    if (!form.nota.trim()) return toast.error('Anota qué se habló con el cliente.')
    if (!!form.proximaAccion.trim() !== !!form.proximaFecha) {
      return toast.error('La próxima acción lleva su día: llena los dos o ninguno.')
    }

    setGuardando(true)
    try {
      await seguimientoApi.registrar(clienteId, {
        tipo: form.tipo,
        resultado: form.resultado,
        nota: form.nota.trim(),
        proximaAccion: form.proximaAccion.trim() || undefined,
        proximaFecha: form.proximaFecha || undefined,
      })
      setForm(vacio)
      toast.exito('Gestión registrada.')
      await cambio()
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos guardar la gestión.')
    } finally {
      setGuardando(false)
    }
  }

  const cumplir = async (g: GestionCrm) => {
    try {
      await seguimientoApi.cumplir(g.id, !g.cumplida)
      await cambio()
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos actualizar la acción.')
    }
  }

  const eliminar = (g: GestionCrm) =>
    confirmar({
      titulo: 'Eliminar gestión',
      mensaje: 'Se borra del historial del cliente. Úsalo solo si la anotaste por error.',
      confirmar: 'Eliminar',
      tono: 'danger',
      accion: async () => {
        try {
          await seguimientoApi.eliminar(g.id)
          await cambio()
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos eliminar la gestión.')
        }
      },
    })

  return (
    <div className="space-y-5">
      {error && <Alert>{error}</Alert>}

      {puede(SUBMODULO, ACCION.crear) && (
        <section className="space-y-3 rounded-panel border border-line bg-white p-4">
          <h3 className="text-sm font-semibold text-ink">Nueva gestión</h3>

          <div className="grid gap-3 sm:grid-cols-2">
            <Select
              label="Cómo fue el contacto"
              value={form.tipo}
              onChange={(e) => setForm({ ...form, tipo: e.target.value as TipoGestion })}
            >
              {Object.entries(TIPOS_GESTION).map(([valor, label]) => (
                <option key={valor} value={valor}>
                  {label}
                </option>
              ))}
            </Select>
            <Select
              label="En qué quedó"
              value={form.resultado}
              onChange={(e) => setForm({ ...form, resultado: e.target.value as ResultadoGestion })}
            >
              {Object.entries(RESULTADOS_GESTION).map(([valor, { label }]) => (
                <option key={valor} value={valor}>
                  {label}
                </option>
              ))}
            </Select>
          </div>

          <label className="block">
            <span className="mb-1.5 block text-sm font-medium text-ink">Qué se habló</span>
            <textarea
              value={form.nota}
              onChange={(e) => setForm({ ...form, nota: e.target.value })}
              maxLength={500}
              rows={3}
              placeholder="Dice que compra el viernes; le falta el pago de la nota anterior."
              className="w-full rounded-field border border-line px-3 py-2 text-sm"
            />
          </label>

          <div className="grid gap-3 sm:grid-cols-[1fr_11rem]">
            <Input
              label="Próxima acción"
              optional
              value={form.proximaAccion}
              maxLength={150}
              placeholder="Volver a llamar, llevar muestra..."
              onChange={(e) => setForm({ ...form, proximaAccion: e.target.value })}
            />
            <Input
              label="Para el día"
              optional
              type="date"
              min={hoyLocal()}
              value={form.proximaFecha}
              onChange={(e) => setForm({ ...form, proximaFecha: e.target.value })}
            />
          </div>

          <div className="flex justify-end">
            <Button loading={guardando} onClick={guardar}>
              Registrar gestión
            </Button>
          </div>
        </section>
      )}

      <section className="space-y-2">
        <h3 className="text-sm font-semibold text-ink">Historial</h3>

        {cargando ? (
          <p className="py-6 text-center text-sm text-ink-soft">Cargando seguimiento...</p>
        ) : gestiones.length === 0 ? (
          <p className="rounded-panel border border-dashed border-line px-4 py-8 text-center text-sm text-ink-soft">
            Todavía no hay gestiones con este cliente.
          </p>
        ) : (
          <ul className="space-y-2">
            {gestiones.map((g) => (
              <li key={g.id} className="rounded-panel border border-line bg-white p-3">
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <div className="flex flex-wrap items-center gap-2 text-sm">
                    <span className="font-semibold text-ink">{TIPOS_GESTION[g.tipo]}</span>
                    <Badge tone={RESULTADOS_GESTION[g.resultado].tone}>{RESULTADOS_GESTION[g.resultado].label}</Badge>
                    <span className="text-xs text-ink-soft">
                      {fechaHora(g.fecha)}
                      {g.usuario ? ` · ${g.usuario}` : ''}
                    </span>
                  </div>

                  {puede(SUBMODULO, ACCION.eliminar) && (
                    <RowAction label="Eliminar gestión" tone="danger" onClick={() => eliminar(g)}>
                      <Trash2 size={15} />
                    </RowAction>
                  )}
                </div>

                <p className="mt-1.5 text-sm whitespace-pre-line text-ink-muted">{g.nota}</p>

                {g.proximaAccion && g.proximaFecha && (
                  <div
                    className={`mt-2 flex flex-wrap items-center justify-between gap-2 rounded-field px-3 py-2 text-sm ${
                      g.cumplida
                        ? 'bg-emerald-50 text-emerald-700'
                        : g.vencida
                          ? 'bg-red-50 text-red-700'
                          : 'bg-amber-50 text-amber-800'
                    }`}
                  >
                    <span className="flex items-center gap-2">
                      <CalendarClock size={15} />
                      <span className={g.cumplida ? 'line-through' : 'font-medium'}>{g.proximaAccion}</span>
                      <span>· {fechaCorta(g.proximaFecha)}</span>
                      {g.vencida && <Badge tone="danger">Vencida</Badge>}
                      {g.cumplida && g.cumplidaEn && <span className="text-xs">hecha {fechaCorta(g.cumplidaEn)}</span>}
                    </span>

                    {puede(SUBMODULO, ACCION.editar) && (
                      <Button size="sm" variant="secondary" onClick={() => cumplir(g)}>
                        {g.cumplida ? (
                          <>
                            <RotateCcw size={14} /> Reabrir
                          </>
                        ) : (
                          <>
                            <Check size={14} /> Hecha
                          </>
                        )}
                      </Button>
                    )}
                  </div>
                )}
              </li>
            ))}
          </ul>
        )}
      </section>

      {dialogo}
    </div>
  )
}
