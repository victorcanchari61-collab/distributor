import { useEffect, useMemo, useState } from 'react'
import { Desplegable } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { ubicacionApi } from './inventarioApi'
import type { UbicacionResponse } from './inventarioApi'

/** Lo que eligió quien recibe: un piso y, adentro, un cuarto. Cero es "ninguno". */
export interface LugarElegido {
  pisoId: number
  cuartoId: number
}

export const SIN_LUGAR: LugarElegido = { pisoId: 0, cuartoId: 0 }

/** El lugar donde queda lo que llega: el cuarto si se eligió; si no, el piso; si no, ninguno (0). */
export const lugarFinal = (e: LugarElegido) => e.cuartoId || e.pisoId || 0

/**
 * Los lugares de un almacén, para elegir dónde se guarda lo que llega o lo que se transfiere.
 *
 * Los pide al elegir el almacén. Si el almacén no tiene pisos ni cuartos, o no se pudieron leer, la lista queda
 * vacía y los selectores aparecen desactivados con un aviso: la operación sigue igual, solo sin lugar.
 */
export function useLugares(almacenId: number, activo: boolean) {
  const [lugares, setLugares] = useState<UbicacionResponse[]>([])
  const [cargando, setCargando] = useState(false)

  useEffect(() => {
    setLugares([])
    if (!activo || !almacenId) return

    let vigente = true
    setCargando(true)
    ubicacionApi
      .listar(almacenId)
      .then((l) => vigente && setLugares(l.filter((x) => x.activo)))
      .catch((e) => {
        // Sin permiso o sin red: se sigue sin lugar.
        if (!(e instanceof ApiError)) console.error(e)
      })
      .finally(() => vigente && setCargando(false))
    return () => {
      vigente = false
    }
  }, [almacenId, activo])

  return { lugares, cargando }
}

/**
 * Dos selectores en cascada: primero el piso y, adentro de ese piso, el cuarto.
 *
 * Si el almacén no usa pisos (los cuartos están directo en él), con "Sin piso" salen esos cuartos.
 */
export function SelectorLugar({
  lugares,
  cargando,
  valor,
  onChange,
  etiquetaPiso = 'Piso',
  etiquetaCuarto = 'Cuarto',
}: {
  lugares: UbicacionResponse[]
  cargando?: boolean
  valor: LugarElegido
  onChange: (valor: LugarElegido) => void
  etiquetaPiso?: string
  etiquetaCuarto?: string
}) {
  const pisos = useMemo(() => lugares.filter((l) => l.tipo === 'PISO'), [lugares])
  const cuartos = useMemo(
    () =>
      lugares.filter(
        (l) => l.tipo === 'CUARTO' && (valor.pisoId ? l.padreId === valor.pisoId : l.padreId === null),
      ),
    [lugares, valor.pisoId],
  )

  const sinLugares = lugares.length === 0

  return (
    <>
      <Desplegable
        label={etiquetaPiso}
        optional
        disabled={pisos.length === 0}
        value={valor.pisoId}
        onChange={(v) => onChange({ pisoId: Number(v), cuartoId: 0 })}
        options={[
          { value: 0, label: pisos.length === 0 ? 'Sin pisos' : 'Sin piso' },
          ...pisos.map((p) => ({ value: p.id, label: p.nombre ? `${p.codigo} · ${p.nombre}` : p.codigo })),
        ]}
      />
      <Desplegable
        label={etiquetaCuarto}
        optional
        disabled={cuartos.length === 0}
        value={valor.cuartoId}
        onChange={(v) => onChange({ ...valor, cuartoId: Number(v) })}
        options={[
          { value: 0, label: cuartos.length === 0 ? 'Sin cuartos' : 'Sin cuarto' },
          ...cuartos.map((c) => ({ value: c.id, label: c.nombre ? `${c.codigo} · ${c.nombre}` : c.codigo })),
        ]}
      />
      {sinLugares && !cargando && (
        <p className="text-xs text-ink-soft sm:col-span-2">
          Este almacén todavía no tiene pisos ni cuartos. Créalos en Almacenes → Ubicaciones para poder elegir dónde se
          guarda.
        </p>
      )}
    </>
  )
}
