import { useCallback, useEffect, useMemo, useReducer, useRef } from 'react'
import { guardarPestanas, leerPestanas, pestanasIniciales, reductorPestanas } from './estadoPestanas'

const cualquiera = () => true

/**
 * Las pestañas de trabajo, sincronizadas con la URL en los dos sentidos:
 *  - la URL manda: llegar a una vista (un enlace, atrás, Inicio) la enfoca o la muestra en la pestaña activa;
 *  - la pestaña activa manda sobre la URL: abrir, cerrar o enfocar una pestaña cambia la dirección.
 *
 * Se recuerdan entre recargas, por usuario (`claveGuardado`).
 */
export function usePestanasTrabajo({
  claveRuta,
  onNavegar,
  claveGuardado,
  esValida = cualquiera,
  maximo = 12,
  inicio = '',
}: {
  /** La vista que indica la URL ahora (el hook no sabe de rutas: se la dan). */
  claveRuta: string
  /** Cambia la URL a la vista indicada (sin llenar el historial). */
  onNavegar: (clave: string) => void
  claveGuardado: string
  /** Debe ser estable (definida fuera del componente). */
  esValida?: (clave: string) => boolean
  maximo?: number
  inicio?: string
}) {
  const reductor = useMemo(() => reductorPestanas(maximo), [maximo])
  const [estado, despachar] = useReducer(reductor, undefined, () =>
    pestanasIniciales({ guardadas: leerPestanas(claveGuardado), claveRuta, esValida, maximo, inicio }),
  )

  // Lo último que dijo la URL, para que el efecto de abajo no dependa de ella.
  const ruta = useRef({ claveRuta, onNavegar })
  useEffect(() => {
    ruta.current = { claveRuta, onNavegar }
  })

  // URL → pestañas
  useEffect(() => {
    if (esValida(claveRuta)) despachar({ tipo: 'ir', clave: claveRuta })
  }, [claveRuta, esValida])

  // Pestañas → URL
  useEffect(() => {
    if (estado.activa !== ruta.current.claveRuta) ruta.current.onNavegar(estado.activa)
  }, [estado.activa])

  useEffect(() => guardarPestanas(claveGuardado, estado), [claveGuardado, estado])

  const abrir = useCallback((clave: string) => despachar({ tipo: 'abrir', clave }), [])
  const cerrar = useCallback((clave: string) => despachar({ tipo: 'cerrar', clave }), [])
  const cerrarOtras = useCallback((clave: string) => despachar({ tipo: 'cerrarOtras', clave }), [])
  const cerrarDerecha = useCallback((clave: string) => despachar({ tipo: 'cerrarDerecha', clave }), [])
  const mover = useCallback((clave: string, a: number) => despachar({ tipo: 'mover', clave, a }), [])

  return {
    claves: estado.claves,
    activa: estado.activa,
    maximo,
    caben: estado.claves.length < maximo,
    abrir,
    cerrar,
    cerrarOtras,
    cerrarDerecha,
    mover,
  }
}
