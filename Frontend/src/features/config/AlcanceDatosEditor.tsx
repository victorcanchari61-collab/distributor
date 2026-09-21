import { Desplegable } from '../../components/ui'
import { resolveNav } from '../../components/layout'

/**
 * Los niveles de alcance de datos, tal como los guarda el backend (`AlcanceDatos`).
 *
 * El texto de pantalla no es el nombre interno: "misclientes" se lee "Solo mi ruta" porque eso es lo
 * que hace ahora — los clientes de la ruta que la persona tiene a cargo—.
 */
export const NIVELES_ALCANCE: { value: string; label: string; nota: string }[] = [
  { value: 'todos', label: 'Todos', nota: 'Sin restricción: ve lo de todas las rutas' },
  {
    value: 'misclientes',
    label: 'Solo mi ruta',
    nota: 'Los clientes de la ruta que tiene a cargo, más lo que él mismo registró. Sin ruta no ve ninguno',
  },
  { value: 'propios', label: 'Solo lo que registré', nota: 'Únicamente lo que registró él, de cualquier cliente' },
]

/** Cómo se llama lo que se restringe en cada pantalla. */
const QUE_VE: Record<string, string> = {
  'maestros.clientes': 'Clientes que puede modificar',
  'fact.pedidos': 'Pedidos que ve y clientes que puede vender',
  'fact.notaventa': 'Notas de venta que ve y clientes que puede vender',
  'finanzas.ganancias': 'Ganancias que ve',
}

export interface AlcanceDatosEditorProps {
  submodulos: string[]
  /** Nivel de cada pantalla. En un usuario, '' significa "igual que su rol". */
  valores: Record<string, string>
  onChange: (submodulo: string, nivel: string) => void
  /** Ofrece "Igual que su rol": solo tiene sentido al configurar a una persona. */
  heredable?: boolean
  disabled?: boolean
}

/**
 * Qué FILAS ve alguien en cada pantalla: todas, solo las de su ruta, o solo las que registró.
 *
 * Es distinto de los permisos de la matriz: el permiso dice si entra y qué botones tiene; esto dice de
 * qué clientes y ventas. Se configura por rol y, si hace falta, por persona (el supervisor que es del rol
 * Vendedor pero sí debe verlo todo).
 */
export function AlcanceDatosEditor({
  submodulos,
  valores,
  onChange,
  heredable,
  disabled,
}: AlcanceDatosEditorProps) {
  return (
    <div className="divide-y divide-line rounded-field border border-line">
      {submodulos.map((sub) => {
        const nombre = resolveNav(sub).item?.label ?? sub
        const valor = valores[sub] ?? (heredable ? '' : 'todos')
        const nota =
          valor === '' ? 'Usa el alcance que le da su rol' : NIVELES_ALCANCE.find((n) => n.value === valor)?.nota

        return (
          <div key={sub} className="grid gap-2 px-3 py-3 sm:grid-cols-[minmax(0,1fr)_minmax(0,16rem)] sm:items-center">
            <div className="min-w-0">
              <p className="text-sm font-semibold text-ink">{nombre}</p>
              <p className="text-xs text-ink-soft">{QUE_VE[sub] ?? 'Qué filas ve'}</p>
              {nota && <p className="mt-0.5 text-xs text-ink-muted">{nota}</p>}
            </div>
            <Desplegable
              value={valor}
              onChange={(v) => onChange(sub, String(v))}
              disabled={disabled}
              options={[
                ...(heredable ? [{ value: '', label: 'Igual que su rol' }] : []),
                ...NIVELES_ALCANCE.map((n) => ({ value: n.value, label: n.label })),
              ]}
            />
          </div>
        )
      })}
    </div>
  )
}
