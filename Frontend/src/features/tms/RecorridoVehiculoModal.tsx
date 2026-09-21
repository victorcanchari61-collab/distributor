import { useEffect, useState } from 'react'
import { Alert, Button, cn, Modal, useToast } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { vehiculoApi } from './flotaApi'
import type { VehiculoResponse } from './flotaApi'
import { rutaApi } from './rutaApi'
import type { RutaResponse } from './rutaApi'

/** Los días como los guarda el backend, en orden de semana. */
export const DIAS_SEMANA: { id: string; label: string }[] = [
  { id: 'LUNES', label: 'Lunes' },
  { id: 'MARTES', label: 'Martes' },
  { id: 'MIERCOLES', label: 'Miércoles' },
  { id: 'JUEVES', label: 'Jueves' },
  { id: 'VIERNES', label: 'Viernes' },
  { id: 'SABADO', label: 'Sábado' },
  { id: 'DOMINGO', label: 'Domingo' },
]

interface RecorridoVehiculoModalProps {
  /** El vehículo cuyo recorrido se edita; null lo deja cerrado. */
  vehiculo: VehiculoResponse | null
  onClose: () => void
}

/**
 * Qué rutas recorre un vehículo cada día de la semana.
 *
 * Es el "camión 1, los lunes: rutas 1 y 7" que el sistema anterior tenía escrito en el código. Al armar
 * un despacho, elegir el vehículo y la fecha llena las rutas desde aquí; se pueden corregir para ese día.
 * Un día sin rutas es un día en que el camión no sale.
 */
export function RecorridoVehiculoModal({ vehiculo, onClose }: RecorridoVehiculoModalProps) {
  const toast = useToast()
  const [rutas, setRutas] = useState<RutaResponse[]>([])
  const [dias, setDias] = useState<Record<string, number[]>>({})
  const [cargando, setCargando] = useState(false)
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!vehiculo) return
    let vivo = true
    setCargando(true)
    setError('')
    void Promise.all([rutaApi.getAll(), vehiculoApi.recorrido(vehiculo.id)])
      .then(([rts, rec]) => {
        if (!vivo) return
        setRutas(rts.filter((r) => r.activo))
        setDias(rec.dias)
      })
      .catch((e) => {
        if (vivo) setError(e instanceof ApiError ? e.message : 'No pudimos cargar el recorrido.')
      })
      .finally(() => {
        if (vivo) setCargando(false)
      })
    return () => {
      vivo = false
    }
  }, [vehiculo])

  const alternar = (dia: string, rutaId: number) =>
    setDias((prev) => {
      const actuales = prev[dia] ?? []
      const siguientes = actuales.includes(rutaId) ? actuales.filter((id) => id !== rutaId) : [...actuales, rutaId]
      return { ...prev, [dia]: siguientes }
    })

  const guardar = async () => {
    if (!vehiculo) return
    setGuardando(true)
    try {
      await vehiculoApi.guardarRecorrido(vehiculo.id, dias)
      toast.exito(`Recorrido de ${vehiculo.placa} guardado`)
      onClose()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos guardar el recorrido.')
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal
      open={vehiculo !== null}
      size="lg"
      title={vehiculo ? `Recorrido de ${vehiculo.placa}` : ''}
      description="Qué rutas hace cada día. Al armar un despacho se proponen solas."
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} disabled={cargando} onClick={() => void guardar()}>
            Guardar
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        {error && <Alert>{error}</Alert>}

        {cargando ? (
          <p className="py-6 text-center text-sm text-ink-soft">Cargando...</p>
        ) : rutas.length === 0 ? (
          <p className="py-6 text-center text-sm text-ink-soft">
            Todavía no hay rutas. Se crean en TMS → Rutas.
          </p>
        ) : (
          <div className="divide-y divide-line rounded-field border border-line">
            {DIAS_SEMANA.map((d) => {
              const elegidas = dias[d.id] ?? []
              return (
                <div key={d.id} className="grid gap-2 px-3 py-2.5 sm:grid-cols-[7rem_minmax(0,1fr)] sm:items-center">
                  <div>
                    <p className="text-sm font-semibold text-ink">{d.label}</p>
                    <p className="text-xs text-ink-soft">
                      {elegidas.length === 0 ? 'No sale' : `${elegidas.length} ruta${elegidas.length === 1 ? '' : 's'}`}
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-1.5">
                    {rutas.map((r) => {
                      const puesta = elegidas.includes(r.id)
                      return (
                        <button
                          key={r.id}
                          type="button"
                          aria-pressed={puesta}
                          onClick={() => alternar(d.id, r.id)}
                          className={cn(
                            'min-w-9 cursor-pointer rounded-full border px-3 py-1 text-sm font-semibold transition-colors',
                            puesta
                              ? 'border-[rgb(var(--sys-rgb))] bg-[rgb(var(--sys-rgb)/0.12)] text-[rgb(var(--sys-ink-rgb))]'
                              : 'border-line text-ink-muted hover:border-ink-soft',
                          )}
                        >
                          {r.nombre}
                        </button>
                      )
                    })}
                  </div>
                </div>
              )
            })}
          </div>
        )}

        <p className="text-xs text-ink-soft">
          Marca las rutas que el vehículo atiende ese día. Un despacho de ese día las trae como propuesta y se
          pueden cambiar.
        </p>
      </div>
    </Modal>
  )
}
