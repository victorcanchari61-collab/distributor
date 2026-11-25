/**
 * Estado de las pestañas de trabajo: funciones puras, sin React ni router.
 *
 * Una pestaña se identifica por la "clave" de la vista que muestra: el id del menú ("inv.plano"), "perfil" para Mi
 * perfil y "" para Inicio. Una vista vive en una sola pestaña a la vez: abrirla de nuevo enfoca la que ya existe.
 */
export interface EstadoPestanas {
  claves: string[]
  activa: string
}

export type AccionPestanas =
  /** Navegar: enfoca la pestaña que ya muestra la vista o, si no hay, cambia la vista de la activa. */
  | { tipo: 'ir'; clave: string }
  /** Abrir en una pestaña nueva (o enfocar la que ya existe). */
  | { tipo: 'abrir'; clave: string }
  | { tipo: 'cerrar'; clave: string }
  | { tipo: 'cerrarOtras'; clave: string }
  | { tipo: 'cerrarDerecha'; clave: string }
  /** Llevar una pestaña a otra posición (arrastrándola). No cambia cuál está activa. */
  | { tipo: 'mover'; clave: string; a: number }

export function reductorPestanas(maximo: number) {
  return (estado: EstadoPestanas, accion: AccionPestanas): EstadoPestanas => {
    const { claves, activa } = estado

    switch (accion.tipo) {
      case 'ir': {
        if (accion.clave === activa) return estado
        if (claves.includes(accion.clave)) return { claves, activa: accion.clave }
        return { claves: claves.map((c) => (c === activa ? accion.clave : c)), activa: accion.clave }
      }

      case 'abrir': {
        if (claves.includes(accion.clave)) return accion.clave === activa ? estado : { claves, activa: accion.clave }
        if (claves.length >= maximo) return estado
        return { claves: [...claves, accion.clave], activa: accion.clave }
      }

      case 'cerrar': {
        const en = claves.indexOf(accion.clave)
        // Siempre queda al menos una pestaña abierta.
        if (en === -1 || claves.length <= 1) return estado
        const resto = claves.filter((c) => c !== accion.clave)
        if (accion.clave !== activa) return { claves: resto, activa }
        // Al cerrar la activa pasa a la vecina de la derecha o, si era la última, a la de la izquierda.
        return { claves: resto, activa: resto[en] ?? resto[en - 1] }
      }

      case 'cerrarOtras':
        return claves.includes(accion.clave) ? { claves: [accion.clave], activa: accion.clave } : estado

      case 'cerrarDerecha': {
        const en = claves.indexOf(accion.clave)
        if (en === -1 || en === claves.length - 1) return estado
        const resto = claves.slice(0, en + 1)
        return { claves: resto, activa: resto.includes(activa) ? activa : accion.clave }
      }

      case 'mover': {
        const desde = claves.indexOf(accion.clave)
        const a = Math.max(0, Math.min(claves.length - 1, accion.a))
        if (desde === -1 || desde === a) return estado
        const resto = claves.filter((c) => c !== accion.clave)
        resto.splice(a, 0, accion.clave)
        return { claves: resto, activa }
      }
    }
  }
}

/** Las pestañas con las que se arranca: las guardadas, más la que pida la URL (que queda activa). */
export function pestanasIniciales({
  guardadas,
  claveRuta,
  esValida,
  maximo,
  inicio,
}: {
  /** Lo último guardado (puede ser de otra versión del menú: se filtra). */
  guardadas: EstadoPestanas | null
  /** La vista que pide la URL ahora. */
  claveRuta: string
  esValida: (clave: string) => boolean
  maximo: number
  /** Con qué pestaña se empieza si no hay nada guardado ni la URL es válida. */
  inicio: string
}): EstadoPestanas {
  const claves = [...new Set((guardadas?.claves ?? []).filter(esValida))].slice(0, maximo)
  let activa = guardadas && claves.includes(guardadas.activa) ? guardadas.activa : claves[0]

  if (esValida(claveRuta)) {
    if (!claves.includes(claveRuta)) {
      if (claves.length < maximo) claves.push(claveRuta)
      else claves[claves.indexOf(activa)] = claveRuta
    }
    activa = claveRuta
  }

  if (claves.length === 0) return { claves: [inicio], activa: inicio }
  return { claves, activa: activa ?? claves[0] }
}

/** Ids del DOM que enlazan cada pestaña con su panel (aria-controls / aria-labelledby). */
const claveDom = (clave: string) => (clave ? clave.replace(/[^\w-]/g, '-') : 'inicio')
export const idPestana = (clave: string) => `pestana-${claveDom(clave)}`
export const idPanel = (clave: string) => `panel-${claveDom(clave)}`

/** Pestañas guardadas en este navegador. Si no se pueden leer, se empieza de cero. */
export function leerPestanas(clave: string): EstadoPestanas | null {
  try {
    const crudo = localStorage.getItem(clave)
    if (!crudo) return null
    const dato: unknown = JSON.parse(crudo)
    if (typeof dato !== 'object' || dato === null) return null
    const { claves, activa } = dato as Partial<EstadoPestanas>
    if (!Array.isArray(claves) || typeof activa !== 'string') return null
    return { claves: claves.filter((c): c is string => typeof c === 'string'), activa }
  } catch {
    return null
  }
}

export function guardarPestanas(clave: string, estado: EstadoPestanas): void {
  try {
    localStorage.setItem(clave, JSON.stringify(estado))
  } catch {
    // Modo privado o almacenamiento lleno: las pestañas siguen funcionando, solo no se recuerdan.
  }
}
