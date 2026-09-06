import { useCallback, useEffect, useMemo, useState } from 'react'
import { ChevronDown, RotateCcw, Save, ShieldCheck } from 'lucide-react'
import { Alert, Badge, Button, cn, PageHeader, PageSection } from '../../components/ui'
import { NAV_GROUPS, resolveNav } from '../../components/layout'
import { ApiError } from '../../lib/apiClient'
import { catalogoPermisos } from '../../lib/permisos'
import type { Accion, SubmoduloCatalogo } from '../../lib/permisos'
import { rolApi } from './rolApi'
import type { RolPermisoResponse, RolResponse } from './rolApi'
import { useRealtime } from '../../lib/realtime'

/** Como se nombra cada accion en pantalla, y en que orden se leen. */
const ACCIONES: { id: Accion; label: string }[] = [
  { id: 'ver', label: 'Ver' },
  { id: 'crear', label: 'Crear' },
  { id: 'editar', label: 'Editar' },
  { id: 'confirmar', label: 'Confirmar' },
  { id: 'cobrar', label: 'Cobrar' },
  { id: 'anular', label: 'Anular' },
  { id: 'eliminar', label: 'Eliminar' },
  { id: 'exportar', label: 'Exportar' },
  { id: 'importar', label: 'Importar' },
]

/** Lo concedido, como claves "submodulo:accion" — igual que lo guarda el backend. */
type Marcas = Set<string>

const clave = (submodulo: string, accion: string) => `${submodulo}:${accion}`

/**
 * Quién puede hacer qué, por submódulo y acción.
 *
 * La matriz antigua era por módulo: marcar "Inventario: editar" concedía de
 * golpe ajustes, transferencias y préstamos. Ahora cada pantalla se concede
 * por separado, y solo con las acciones que esa pantalla admite — el kardex no
 * se anula, la auditoría no se crea. Por eso las columnas vienen del catálogo
 * del backend y no de una lista escrita aquí: si estuvieran duplicadas, un
 * submódulo nuevo quedaría invisible en esta pantalla aunque el servidor ya lo
 * estuviera exigiendo.
 */
export function AccesosPage() {
  const [roles, setRoles] = useState<RolResponse[]>([])
  const [catalogo, setCatalogo] = useState<SubmoduloCatalogo[]>([])
  const [rolId, setRolId] = useState<number | null>(null)
  const [marcas, setMarcas] = useState<Marcas>(() => new Set())
  const [sucio, setSucio] = useState(false)
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')
  const [ok, setOk] = useState('')
  const [abiertos, setAbiertos] = useState<string[]>([])

  const cargar = useCallback(async () => {
    setError('')
    try {
      const lista = await rolApi.getAll()
      setRoles(lista)
      setRolId((actual) => actual ?? lista[0]?.id ?? null)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los roles.')
    }
  }, [])

  useEffect(() => {
    void cargar()
    void catalogoPermisos()
      .then(setCatalogo)
      .catch(() => setError('No pudimos cargar el catálogo de permisos.'))
  }, [cargar])

  useRealtime('roles', cargar)

  const rol = useMemo(() => roles.find((r) => r.id === rolId) ?? null, [roles, rolId])

  /** El catálogo agrupado por módulo, en el orden del menú. */
  const modulos = useMemo(() => {
    const porModulo = new Map<string, SubmoduloCatalogo[]>()
    for (const s of catalogo) {
      const lista = porModulo.get(s.modulo) ?? []
      lista.push(s)
      porModulo.set(s.modulo, lista)
    }

    return NAV_GROUPS.map((g) => ({ grupo: g, submodulos: porModulo.get(g.id) ?? [] })).filter(
      (m) => m.submodulos.length > 0,
    )
  }, [catalogo])

  const deRol = (permisos: RolPermisoResponse[]) =>
    new Set(permisos.map((p) => clave(p.submodulo, p.accion)))

  // Al cambiar de rol se recarga su matriz y se descartan cambios sin guardar.
  useEffect(() => {
    setMarcas(rol ? deRol(rol.permisos) : new Set())
    setSucio(false)
    setOk('')
  }, [rol])

  const toggle = (submodulo: string, accion: string, acciones: string[]) => {
    setSucio(true)
    setOk('')
    setMarcas((prev) => {
      const siguiente = new Set(prev)
      const puesta = siguiente.has(clave(submodulo, accion))

      if (accion === 'ver') {
        // Quitar Ver retira la pantalla entera: sin ella el resto de permisos
        // quedarian concedidos pero inalcanzables.
        if (puesta) for (const a of acciones) siguiente.delete(clave(submodulo, a))
        else siguiente.add(clave(submodulo, 'ver'))
        return siguiente
      }

      if (puesta) siguiente.delete(clave(submodulo, accion))
      else {
        siguiente.add(clave(submodulo, accion))
        // Cualquier accion implica poder entrar a la pantalla.
        siguiente.add(clave(submodulo, 'ver'))
      }
      return siguiente
    })
  }

  const marcarSubmodulo = (submodulo: string, acciones: string[], todo: boolean) => {
    setSucio(true)
    setOk('')
    setMarcas((prev) => {
      const siguiente = new Set(prev)
      for (const a of acciones) {
        if (todo) siguiente.add(clave(submodulo, a))
        else siguiente.delete(clave(submodulo, a))
      }
      return siguiente
    })
  }

  const marcarModulo = (submodulos: SubmoduloCatalogo[], todo: boolean) => {
    setSucio(true)
    setOk('')
    setMarcas((prev) => {
      const siguiente = new Set(prev)
      for (const s of submodulos) {
        for (const a of s.acciones) {
          if (todo) siguiente.add(clave(s.submodulo, a))
          else siguiente.delete(clave(s.submodulo, a))
        }
      }
      return siguiente
    })
  }

  const restablecer = () => {
    setMarcas(rol ? deRol(rol.permisos) : new Set())
    setSucio(false)
    setOk('')
  }

  const guardar = async () => {
    if (!rol) return
    setGuardando(true)
    setError('')
    try {
      const permisos = [...marcas].map((k) => {
        const corte = k.lastIndexOf(':')
        return { submodulo: k.slice(0, corte), accion: k.slice(corte + 1) }
      })
      await rolApi.updatePermisos(rol.id, permisos)
      await cargar()
      setSucio(false)
      setOk('Accesos guardados.')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos guardar los accesos.')
    } finally {
      setGuardando(false)
    }
  }

  const pantallasActivas = catalogo.filter((s) => marcas.has(clave(s.submodulo, 'ver'))).length

  return (
    <div className="space-y-5">
      <PageHeader
        icon={<ShieldCheck size={20} />}
        title={rol ? `Accesos de ${rol.nombre}` : 'Accesos'}
        description={
          rol
            ? `${pantallasActivas} de ${catalogo.length} pantallas habilitadas. ${rol.descripcion ?? ''}`
            : 'Elige un rol para configurar qué puede hacer en cada pantalla.'
        }
        actions={
          <>
            <Button variant="secondary" size="sm" disabled={!sucio} onClick={restablecer}>
              <RotateCcw size={15} />
              Restablecer
            </Button>
            <Button
              size="sm"
              disabled={!sucio}
              loading={guardando}
              onClick={() => void guardar()}
              iconRight={<Save size={15} />}
            >
              Guardar
            </Button>
          </>
        }
      />

      {error && <Alert>{error}</Alert>}
      {ok && (
        <p className="rounded-field border border-emerald-200 bg-emerald-50 px-3 py-2 text-sm text-emerald-700">
          {ok}
        </p>
      )}

      {rol?.protegido && (
        <p className="rounded-field border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-800">
          El rol <b>Administrador</b> tiene todo concedido siempre: sin él nadie podría volver a
          configurar el sistema. Lo que marques aquí no le quita nada.
        </p>
      )}

      <PageSection>
        {/* Selector de rol */}
        <div
          role="tablist"
          aria-label="Rol a configurar"
          className="mb-4 inline-flex flex-wrap gap-1 rounded-full bg-surface-alt p-1"
        >
          {roles.map((r) => (
            <button
              key={r.id}
              type="button"
              role="tab"
              aria-selected={rolId === r.id}
              onClick={() => setRolId(r.id)}
              className={cn(
                'cursor-pointer rounded-full px-4 py-1.5 text-sm font-semibold transition-colors',
                rolId === r.id
                  ? 'bg-white text-[rgb(var(--sys-ink-rgb))] shadow-sm'
                  : 'text-ink-muted hover:text-ink',
              )}
            >
              {r.nombre}
            </button>
          ))}
        </div>

        {/*
         * Un módulo por bloque plegable. Con 41 pantallas × 9 acciones, una sola
         * tabla plana sería una pared de casillas que nadie configuraría bien;
         * plegado se ve el resumen y se abre solo lo que se va a tocar.
         */}
        <div className="space-y-2">
          {modulos.map(({ grupo, submodulos }) => {
            const GroupIcon = grupo.icon
            const abierto = abiertos.includes(grupo.id)
            const visibles = submodulos.filter((s) => marcas.has(clave(s.submodulo, 'ver'))).length
            const completo = submodulos.every((s) =>
              s.acciones.every((a) => marcas.has(clave(s.submodulo, a))),
            )

            return (
              <div
                key={grupo.id}
                data-sys={grupo.sys}
                className="overflow-hidden rounded-panel border border-line"
              >
                <div className="flex items-center gap-2 bg-surface-alt/60 px-3 py-2">
                  <button
                    type="button"
                    onClick={() =>
                      setAbiertos((prev) =>
                        prev.includes(grupo.id)
                          ? prev.filter((g) => g !== grupo.id)
                          : [...prev, grupo.id],
                      )
                    }
                    aria-expanded={abierto}
                    className="flex flex-1 cursor-pointer items-center gap-2 text-left"
                  >
                    <ChevronDown
                      size={15}
                      className={cn('shrink-0 transition-transform', abierto && 'rotate-180')}
                    />
                    <GroupIcon size={16} className="text-[rgb(var(--sys-rgb))]" />
                    <span className="font-semibold text-ink">{grupo.label}</span>
                    <span className="text-xs text-ink-soft">
                      {visibles} de {submodulos.length}
                    </span>
                    {visibles === 0 && <Badge>sin acceso</Badge>}
                  </button>

                  <button
                    type="button"
                    onClick={() => marcarModulo(submodulos, !completo)}
                    className="cursor-pointer text-xs font-semibold text-[rgb(var(--sys-ink-rgb))] hover:underline"
                  >
                    {completo ? 'Quitar todo' : 'Marcar todo'}
                  </button>
                </div>

                {abierto && (
                  <div className="overflow-x-auto">
                    <table className="w-full min-w-[720px] border-collapse text-sm">
                      <thead>
                        <tr className="border-b border-line">
                          <th className="py-2 pr-3 pl-3 text-left text-[11px] font-semibold tracking-wider text-ink-muted uppercase">
                            Pantalla
                          </th>
                          {ACCIONES.map((a) => (
                            <th
                              key={a.id}
                              className="w-[74px] px-1 py-2 text-center text-[11px] font-semibold tracking-wider text-ink-muted uppercase"
                            >
                              {a.label}
                            </th>
                          ))}
                          <th className="w-20 px-2 py-2 text-center text-[11px] font-semibold tracking-wider text-ink-muted uppercase">
                            Todo
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        {submodulos.map((s) => {
                          const { item } = resolveNav(s.submodulo)
                          const lleno = s.acciones.every((a) => marcas.has(clave(s.submodulo, a)))

                          return (
                            <tr
                              key={s.submodulo}
                              className="border-b border-line last:border-b-0 hover:bg-surface-alt/60"
                            >
                              <td className="py-2 pr-3 pl-3">
                                <span className="font-medium text-ink">
                                  {item?.label ?? s.submodulo}
                                </span>
                              </td>

                              {ACCIONES.map((a) => {
                                // Una casilla vacia, no una desactivada: esa
                                // accion no existe en esta pantalla, no es que
                                // este prohibida.
                                if (!s.acciones.includes(a.id)) {
                                  return (
                                    <td key={a.id} className="px-1 py-2 text-center text-ink-soft">
                                      ·
                                    </td>
                                  )
                                }

                                return (
                                  <td key={a.id} className="px-1 py-2 text-center">
                                    <input
                                      type="checkbox"
                                      checked={marcas.has(clave(s.submodulo, a.id))}
                                      onChange={() => toggle(s.submodulo, a.id, s.acciones)}
                                      aria-label={`${a.label} en ${item?.label ?? s.submodulo}`}
                                      className="size-4 cursor-pointer rounded border-line-strong accent-[rgb(var(--sys-rgb))]"
                                    />
                                  </td>
                                )
                              })}

                              <td className="px-2 py-2 text-center">
                                <button
                                  type="button"
                                  onClick={() => marcarSubmodulo(s.submodulo, s.acciones, !lleno)}
                                  className="cursor-pointer text-xs font-semibold text-[rgb(var(--sys-ink-rgb))] hover:underline"
                                >
                                  {lleno ? 'Quitar' : 'Marcar'}
                                </button>
                              </td>
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

        <p className="mt-3 text-xs text-ink-soft">
          Quitar <b>Ver</b> retira la pantalla por completo. Conceder cualquier otra acción activa{' '}
          <b>Ver</b> automáticamente. Un <b>·</b> significa que esa acción no existe en esa
          pantalla.
        </p>
      </PageSection>
    </div>
  )
}
