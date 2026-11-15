import { useMemo, useState } from 'react'
import { Alert, Modal, Tabs } from '../../../components/ui'
import type { LugarElegido } from '../SelectorLugar'
import { PlanoLienzo } from './PlanoLienzo'
import { figurasDe, idDeClave, pisosDe, usePlanoAlmacen } from './datosPlano'

/**
 * Elegir dónde se guarda lo que llega tocando el lugar en el plano, en vez de buscarlo en dos listas. Devuelve lo
 * mismo que el selector de piso y lugar.
 */
export function ElegirLugarPlanoModal({
  open,
  almacenId,
  onClose,
  onElegir,
}: {
  open: boolean
  almacenId: number
  onClose: () => void
  onElegir: (lugar: LugarElegido) => void
}) {
  const { lugares, plano, cargando, error } = usePlanoAlmacen(open ? almacenId : 0)
  const [pisoElegido, setPisoElegido] = useState<number | null>(null)

  const pisos = useMemo(() => pisosDe(lugares), [lugares])
  const pisoId = pisos.length ? (pisos.some((p) => p.id === pisoElegido) ? pisoElegido : pisos[0].id) : null
  const figuras = useMemo(
    () => figurasDe(lugares, plano, pisoId).filter((f) => f.tipo !== 'LUGAR' || !f.inactivo),
    [lugares, plano, pisoId],
  )

  const elegir = (clave: string | null) => {
    if (!clave?.startsWith('L')) return
    const lugar = lugares.find((l) => l.id === idDeClave(clave))
    if (!lugar || !lugar.activo) return
    onElegir({ pisoId: lugar.padreId ?? 0, cuartoId: lugar.id })
    onClose()
  }

  return (
    <Modal open={open} size="2xl" title="Elegir dónde se guarda" description="Toca el lugar en el plano." onClose={onClose}>
      <div className="flex flex-col gap-3">
        {error && <Alert>{error}</Alert>}
        {pisos.length > 0 && (
          <Tabs
            active={String(pisoId)}
            onChange={(id) => setPisoElegido(Number(id))}
            items={pisos.map((p) => ({ id: String(p.id), label: p.nombre ? `${p.codigo} · ${p.nombre}` : p.codigo }))}
          />
        )}
        {cargando && !plano ? (
          <p className="py-10 text-center text-sm text-ink-soft">Cargando el plano...</p>
        ) : figuras.some((f) => f.tipo === 'LUGAR') ? (
          <PlanoLienzo columnas={plano?.columnas ?? 24} filas={plano?.filas ?? 14} figuras={figuras} soloLugares onSeleccionar={elegir} />
        ) : (
          <p className="py-10 text-center text-sm text-ink-soft">Este piso todavía no tiene lugares dibujados.</p>
        )}
      </div>
    </Modal>
  )
}
