import { useContext, useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { usePermisos } from '../../lib/permisos'
import { AccesoRapidoContexto } from './AccesoRapidoContexto'
import { ACCESOS_RAPIDOS, pulsarAccesoRapido } from './accesosRapidos'
import type { AccesoRapido } from './accesosRapidos'
import { PanelAccesos } from './PanelAccesos'
import type { AccesosAbiertos } from './PanelAccesos'

/** Al salir de la lista hacia el panel de accesos el mouse cruza un hueco: se espera un poco antes de cerrarlo. */
const GRACIA_CIERRE = 180

/**
 * Los accesos rápidos al pasar el mouse por una vista del menú: al lado sale un panel con los botones de cabecera de
 * esa vista (Nuevo cliente, Importar…). Lo usan el submenú flotante y el sider abierto.
 *
 * Quien lo usa llama a `entrar` al pasar por un renglón y a `salir` al dejar la lista, y pinta `panel`.
 */
export function useAccesosAlPasar({
  onAbrirVista,
  onElegido,
}: {
  /** Abre la vista, para cuando no hay panel de pestañas que monte la vista en el fondo. */
  onAbrirVista: (id: string) => void
  /** Tras elegir un acceso (el submenú se cierra). */
  onElegido?: () => void
}) {
  const { puede } = usePermisos()
  const usarAcceso = useContext(AccesoRapidoContexto)
  const refPanel = useRef<HTMLDivElement>(null)
  const [abierto, setAbierto] = useState<AccesosAbiertos | null>(null)

  const temporizador = useRef<number | undefined>(undefined)
  const seguir = () => window.clearTimeout(temporizador.current)
  const salir = () => {
    seguir()
    temporizador.current = window.setTimeout(() => setAbierto(null), GRACIA_CIERRE)
  }
  useEffect(() => () => window.clearTimeout(temporizador.current), [])

  // Si la página o la lista se mueven, el renglón ya no está donde se midió.
  useEffect(() => {
    if (!abierto) return
    const soltar = () => setAbierto(null)
    window.addEventListener('scroll', soltar, true)
    window.addEventListener('resize', soltar)
    return () => {
      window.removeEventListener('scroll', soltar, true)
      window.removeEventListener('resize', soltar)
    }
  }, [abierto])

  /** Los accesos de una vista que esta persona puede usar. */
  const accesosDe = (id: string): AccesoRapido[] =>
    (ACCESOS_RAPIDOS[id] ?? []).filter((a) => !a.permiso || puede(a.submodulo ?? id, a.permiso))

  const entrar = (item: AccesosAbiertos['item'], sys: string, fila: DOMRect, borde: DOMRect) => {
    seguir()
    setAbierto(accesosDe(item.id).length > 0 ? { item, sys, fila, borde } : null)
  }

  const elegir = (acceso: AccesoRapido) => {
    if (!abierto) return
    const vista = abierto.item.id
    setAbierto(null)
    onElegido?.()
    // Con el panel de pestañas, el modal sale sobre la vista actual; sin él, se abre la vista y se pulsa ahí.
    if (usarAcceso) usarAcceso(vista, acceso)
    else {
      onAbrirVista(vista)
      pulsarAccesoRapido(vista, acceso, () => {})
    }
  }

  const accesos = abierto ? accesosDe(abierto.item.id) : []
  const panel =
    abierto && accesos.length > 0
      ? createPortal(
          <PanelAccesos
            refPanel={refPanel}
            abierto={abierto}
            accesos={accesos}
            onEntrar={seguir}
            onSalir={salir}
            onElegir={elegir}
          />,
          document.body,
        )
      : null

  return {
    /** Si la vista tiene accesos para esta persona (para marcar su renglón). */
    tieneAccesos: (id: string) => accesosDe(id).length > 0,
    /** Si el panel abierto es el de esta vista. */
    mostrando: (id: string) => abierto?.item.id === id,
    entrar,
    salir,
    /** El panel, para que un clic dentro no cuente como "fuera" del submenú. */
    refPanel,
    panel,
  }
}
