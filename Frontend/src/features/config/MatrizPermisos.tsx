import { useMemo, useState } from 'react'
import { ChevronDown } from 'lucide-react'
import { Badge, Desplegable, cn } from '../../components/ui'
import { NAV_GROUPS, resolveNav } from '../../components/layout'
import type { Accion, SubmoduloCatalogo } from '../../lib/permisos'
import { opcionesAlcance, queVe } from './alcanceDatos'

/** Qué filas ve en cada pantalla que lo admite (todas, solo su ruta, solo lo suyo). */
export interface AlcanceEnMatriz {
  /** Las pantallas donde se puede limitar. */
  pantallas: string[]
  valores: Record<string, string>
  onChange: (submodulo: string, nivel: string) => void
  disabled?: boolean
  /**
   * Para una persona: ofrece "Igual que su rol" (valor ''), que es lo que tiene mientras no se le cambie. Trae lo
   * que su rol ve en cada pantalla, para decirlo en esa opción.
   */
  heredado?: Record<string, string>
}

/** Como se nombra cada accion en pantalla, y en que orden se leen. */
export const ACCIONES: { id: Accion; label: string }[] = [
  { id: 'ver', label: 'Ver' },
  { id: 'crear', label: 'Crear' },
  { id: 'editar', label: 'Editar' },
  { id: 'confirmar', label: 'Confirmar' },
  { id: 'cobrar', label: 'Cobrar' },
  { id: 'anular', label: 'Anular' },
  { id: 'eliminar', label: 'Eliminar' },
  { id: 'exportar', label: 'Exportar' },
  { id: 'importar', label: 'Importar' },
  { id: 'ingreso', label: 'Ingreso' },
  { id: 'egreso', label: 'Egreso' },
  { id: 'transferir', label: 'Mover plata' },
]

/** Un permiso como lo guarda el backend: "submodulo:accion". */
export const clave = (submodulo: string, accion: string) => `${submodulo}:${accion}`

/**
 * Los permisos ordenados como el menú: un bloque plegable por módulo y, dentro, una fila por pantalla con sus
 * acciones.
 *
 * La usan las dos preguntas de Accesos: qué hace un rol y qué le falta a una persona. Así se busca igual en las
 * dos — por donde está en el menú — en vez de tener que adivinar el nombre interno de la pantalla.
 */
export function MatrizPermisos({
  catalogo,
  marcadas,
  onToggle,
  fijas,
  onMarcarSubmodulo,
  onMarcarModulo,
  filtro = '',
  nuevas = false,
  alcance,
}: {
  /**
   * Con esto cada pantalla que lo admite lleva, en su misma fila, qué clientes y ventas ve: así se configura todo
   * de una pantalla en un solo sitio.
   */
  alcance?: AlcanceEnMatriz
  catalogo: SubmoduloCatalogo[]
  /** Lo marcado y editable. */
  marcadas: Set<string>
  onToggle: (submodulo: string, accion: string, acciones: string[]) => void
  /**
   * Lo que ya tiene y aquí no se puede tocar (por su rol, o concedido antes), con el porqué. Se ve marcado y en
   * gris.
   */
  fijas?: Map<string, string>
  /** "Marcar / Quitar" por pantalla y "Marcar todo" por módulo. Sin ellos no se muestran. */
  onMarcarSubmodulo?: (submodulo: string, acciones: string[], todo: boolean) => void
  onMarcarModulo?: (submodulos: SubmoduloCatalogo[], todo: boolean) => void
  /** Deja solo las pantallas cuyo nombre lo contiene, con sus módulos abiertos. */
  filtro?: string
  /** En la cabecera de cada módulo cuenta lo marcado ("2 nuevos") en vez de las pantallas que ve. */
  nuevas?: boolean
}) {
  const [abiertos, setAbiertos] = useState<string[]>([])
  const buscado = filtro.trim().toLowerCase()

  /** El catálogo agrupado por módulo, en el orden del menú. */
  const modulos = useMemo(() => {
    const porModulo = new Map<string, SubmoduloCatalogo[]>()
    for (const s of catalogo) {
      const nombre = (resolveNav(s.submodulo).item?.label ?? s.submodulo).toLowerCase()
      if (buscado && !nombre.includes(buscado)) continue
      const lista = porModulo.get(s.modulo) ?? []
      lista.push(s)
      porModulo.set(s.modulo, lista)
    }

    return NAV_GROUPS.map((g) => ({ grupo: g, submodulos: porModulo.get(g.id) ?? [] })).filter(
      (m) => m.submodulos.length > 0,
    )
  }, [catalogo, buscado])

  const tiene = (k: string) => marcadas.has(k) || (fijas?.has(k) ?? false)

  if (modulos.length === 0) {
    return <p className="py-6 text-center text-sm text-ink-soft">Ninguna pantalla se llama así.</p>
  }

  return (
    <div className="space-y-2">
      {modulos.map(({ grupo, submodulos }) => {
        const GroupIcon = grupo.icon
        // Al buscar se abre todo lo que coincide: si no, habría que abrir cada módulo para ver el resultado.
        const abierto = buscado !== '' || abiertos.includes(grupo.id)
        const visibles = submodulos.filter((s) => tiene(clave(s.submodulo, 'ver'))).length
        const marcadasAqui = submodulos.reduce(
          (n, s) => n + s.acciones.filter((a) => marcadas.has(clave(s.submodulo, a))).length,
          0,
        )
        const completo = submodulos.every((s) => s.acciones.every((a) => marcadas.has(clave(s.submodulo, a))))
        // Solo las columnas que existen en este módulo: las demás serían una fila de puntos.
        const columnas = ACCIONES.filter((a) => submodulos.some((s) => s.acciones.includes(a.id)))
        const conAlcance = alcance !== undefined && submodulos.some((s) => alcance.pantallas.includes(s.submodulo))

        return (
          <div key={grupo.id} data-sys={grupo.sys} className="overflow-hidden rounded-panel border border-line">
            <div className="flex items-center gap-2 bg-surface-alt/60 px-3 py-2">
              <button
                type="button"
                onClick={() =>
                  setAbiertos((prev) =>
                    prev.includes(grupo.id) ? prev.filter((g) => g !== grupo.id) : [...prev, grupo.id],
                  )
                }
                aria-expanded={abierto}
                className="flex flex-1 cursor-pointer items-center gap-2 text-left"
              >
                <ChevronDown size={15} className={cn('shrink-0 transition-transform', abierto && 'rotate-180')} />
                <GroupIcon size={16} className="text-[rgb(var(--sys-rgb))]" />
                <span className="font-semibold text-ink">{grupo.label}</span>
                {nuevas ? (
                  marcadasAqui > 0 && (
                    <Badge tone="success">
                      {marcadasAqui} {marcadasAqui === 1 ? 'nuevo' : 'nuevos'}
                    </Badge>
                  )
                ) : (
                  <>
                    <span className="text-xs text-ink-soft">
                      {visibles} de {submodulos.length}
                    </span>
                    {visibles === 0 && <Badge>sin acceso</Badge>}
                  </>
                )}
              </button>

              {onMarcarModulo && (
                <button
                  type="button"
                  onClick={() => onMarcarModulo(submodulos, !completo)}
                  className="cursor-pointer text-xs font-semibold text-[rgb(var(--sys-ink-rgb))] hover:underline"
                >
                  {completo ? 'Quitar todo' : 'Marcar todo'}
                </button>
              )}
            </div>

            {abierto && (
              <div className="overflow-x-auto">
                <table className="w-full border-collapse text-sm">
                  <thead>
                    <tr className="border-b border-line">
                      <th className="py-2 pr-3 pl-3 text-left text-[11px] font-semibold tracking-wider text-ink-muted uppercase">
                        Pantalla
                      </th>
                      {columnas.map((a) => (
                        <th
                          key={a.id}
                          className="w-[74px] px-1 py-2 text-center text-[11px] font-semibold tracking-wider text-ink-muted uppercase"
                        >
                          {a.label}
                        </th>
                      ))}
                      {conAlcance && (
                        <th className="w-56 px-2 py-2 text-left text-[11px] font-semibold tracking-wider text-ink-muted uppercase">
                          Qué ve
                        </th>
                      )}
                      {onMarcarSubmodulo && (
                        <th className="w-20 px-2 py-2 text-center text-[11px] font-semibold tracking-wider text-ink-muted uppercase">
                          Todo
                        </th>
                      )}
                    </tr>
                  </thead>
                  <tbody>
                    {submodulos.map((s) => {
                      const nombre = resolveNav(s.submodulo).item?.label ?? s.submodulo
                      const lleno = s.acciones.every((a) => marcadas.has(clave(s.submodulo, a)))

                      return (
                        <tr key={s.submodulo} className="border-b border-line last:border-b-0 hover:bg-surface-alt/60">
                          <td className="py-2 pr-3 pl-3 whitespace-nowrap">
                            <span className="font-medium text-ink">{nombre}</span>
                          </td>

                          {columnas.map((a) => {
                            // Un punto, no una casilla desactivada: esa acción no existe en esta pantalla, no es que
                            // esté prohibida.
                            if (!s.acciones.includes(a.id)) {
                              return (
                                <td key={a.id} className="px-1 py-2 text-center text-ink-soft">
                                  ·
                                </td>
                              )
                            }

                            const k = clave(s.submodulo, a.id)
                            const porque = fijas?.get(k)

                            return (
                              <td key={a.id} className="px-1 py-2 text-center" title={porque}>
                                <input
                                  type="checkbox"
                                  checked={porque !== undefined || marcadas.has(k)}
                                  disabled={porque !== undefined}
                                  onChange={() => onToggle(s.submodulo, a.id, s.acciones)}
                                  aria-label={`${a.label} en ${nombre}`}
                                  className={cn(
                                    'size-4 rounded border-line-strong accent-[rgb(var(--sys-rgb))]',
                                    porque !== undefined ? 'cursor-not-allowed opacity-40 grayscale' : 'cursor-pointer',
                                  )}
                                />
                              </td>
                            )
                          })}

                          {conAlcance && (
                            <td className="px-2 py-1.5">
                              {alcance.pantallas.includes(s.submodulo) ? (
                                <span title={queVe(s.submodulo)}>
                                  <Desplegable
                                    size="sm"
                                    value={alcance.valores[s.submodulo] ?? (alcance.heredado ? '' : 'todos')}
                                    onChange={(v) => alcance.onChange(s.submodulo, String(v))}
                                    // Sin Ver no entra a la pantalla: qué filas vería da igual.
                                    disabled={alcance.disabled || !tiene(clave(s.submodulo, 'ver'))}
                                    options={opcionesAlcance(s.submodulo, alcance.heredado !== undefined).map((n) => {
                                      if (n.value !== '' || !alcance.heredado) return n
                                      // "Igual que su rol" dice cuál es, para no tener que ir a mirarlo al rol.
                                      const delRol = alcance.heredado[s.submodulo] || 'todos'
                                      const nombre = opcionesAlcance(s.submodulo).find((o) => o.value === delRol)?.label
                                      return { ...n, label: `Igual que su rol${nombre ? ` (${nombre})` : ''}` }
                                    })}
                                  />
                                </span>
                              ) : (
                                <span className="text-ink-soft">—</span>
                              )}
                            </td>
                          )}

                          {onMarcarSubmodulo && (
                            <td className="px-2 py-2 text-center">
                              <button
                                type="button"
                                onClick={() => onMarcarSubmodulo(s.submodulo, s.acciones, !lleno)}
                                className="cursor-pointer text-xs font-semibold text-[rgb(var(--sys-ink-rgb))] hover:underline"
                              >
                                {lleno ? 'Quitar' : 'Marcar'}
                              </button>
                            </td>
                          )}
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )
      })}
    </div>
  )
}
