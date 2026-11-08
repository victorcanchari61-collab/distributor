/*
 * Qué FILAS ve alguien en cada pantalla: todas, solo las de su ruta, o solo las que registró. Es distinto de los
 * permisos: el permiso dice si entra y qué botones tiene; esto dice de qué clientes y ventas. Se elige en la columna
 * "Qué ve" de la matriz de permisos (MatrizPermisos), por rol y, si hace falta, por persona.
 */

/**
 * Los niveles de alcance de datos, tal como los guarda el backend (`AlcanceDatos`).
 *
 * El texto de pantalla no es el nombre interno: "misclientes" se lee "Solo mis rutas" porque eso es lo
 * que hace ahora — los clientes de las rutas que la persona tiene a cargo—.
 */
export const NIVELES_ALCANCE: { value: string; label: string; nota: string }[] = [
  { value: 'todos', label: 'Todos', nota: 'Sin restricción: ve lo de todas las rutas' },
  {
    value: 'misclientes',
    label: 'Solo mis rutas',
    nota: 'Los clientes de las rutas que tiene a cargo, más lo que él mismo registró. Sin ruta no ve ninguno',
  },
  { value: 'propios', label: 'Solo lo que registré', nota: 'Únicamente lo que registró él, de cualquier cliente' },
]

/** Cómo se llama lo que se restringe en cada pantalla. */
const QUE_VE: Record<string, string> = {
  'maestros.clientes': 'Clientes que puede modificar',
  'fact.pedidos': 'Pedidos que ve y clientes que puede vender',
  'fact.notaventa': 'Notas de venta que ve y clientes que puede vender',
  'finanzas.ganancias': 'Ganancias que ve',
  'finanzas.cierres': 'Cierres de caja y cobros digitales que ve',
}

/**
 * Las pantallas sin clientes de por medio: ahí no hay "mis rutas", solo todo o lo propio. Cada una
 * dice cómo se lee "lo propio".
 */
const SOLO_PROPIOS: Record<string, { label: string; nota: string }> = {
  'finanzas.cierres': { label: 'Solo los suyos', nota: 'Únicamente los cierres de su propia caja y los cobros que él hizo' },
}

/**
 * Los niveles que admite una pantalla, como opciones de un desplegable con su explicación debajo. Con `heredable`
 * empieza por "Igual que su rol" (valor ''), que solo tiene sentido al configurar a una persona.
 */
export function opcionesAlcance(sub: string, heredable?: boolean) {
  const propio = SOLO_PROPIOS[sub]
  const niveles = propio
    ? NIVELES_ALCANCE.filter((n) => n.value !== 'misclientes').map((n) =>
        n.value === 'propios' ? { ...n, label: propio.label, nota: propio.nota } : n,
      )
    : NIVELES_ALCANCE
  return [
    ...(heredable ? [{ value: '', label: 'Igual que su rol', nota: 'Usa el alcance que le da su rol' }] : []),
    ...niveles,
  ]
}

/** Qué se restringe en esa pantalla, dicho para quien configura. */
export const queVe = (sub: string) => QUE_VE[sub] ?? 'Qué filas ve'
