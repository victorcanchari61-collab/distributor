import { useCallback, useEffect, useMemo, useState } from 'react'
import { RotateCcw, Save, ShieldCheck } from 'lucide-react'
import { Alert, Badge, Button, cn, PageHeader, PageSection } from '../../components/ui'
import { NAV_GROUPS } from '../../components/layout'
import { ApiError } from '../../lib/apiClient'
import { rolApi } from './rolApi'
import type { RolPermisoResponse, RolResponse } from './rolApi'
import { useRealtime } from '../../lib/realtime'

type Permiso = 'ver' | 'crear' | 'editar' | 'eliminar'

const PERMISOS: { id: Permiso; label: string }[] = [
  { id: 'ver', label: 'Ver' },
  { id: 'crear', label: 'Crear' },
  { id: 'editar', label: 'Editar' },
  { id: 'eliminar', label: 'Eliminar' },
]

/** Matriz en pantalla: modulo -> permisos concedidos. */
type Matriz = Record<string, Record<Permiso, boolean>>

const VACIA = (): Matriz =>
  Object.fromEntries(
    NAV_GROUPS.map((g) => [g.id, { ver: false, crear: false, editar: false, eliminar: false }]),
  )

/** Lo que devuelve el backend, completado con los modulos que no tienen fila. */
function aMatriz(permisos: RolPermisoResponse[]): Matriz {
  const matriz = VACIA()
  for (const p of permisos) {
    if (matriz[p.modulo]) {
      matriz[p.modulo] = { ver: p.ver, crear: p.crear, editar: p.editar, eliminar: p.eliminar }
    }
  }
  return matriz
}

export function AccesosPage() {
  const [roles, setRoles] = useState<RolResponse[]>([])
  const [rolId, setRolId] = useState<number | null>(null)
  const [matriz, setMatriz] = useState<Matriz>(VACIA)
  const [sucio, setSucio] = useState(false)
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')
  const [ok, setOk] = useState('')

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
  }, [cargar])

  useRealtime('roles', cargar)

  const rol = useMemo(() => roles.find((r) => r.id === rolId) ?? null, [roles, rolId])

  // Al cambiar de rol se recarga su matriz y se descartan cambios sin guardar.
  useEffect(() => {
    setMatriz(rol ? aMatriz(rol.permisos) : VACIA())
    setSucio(false)
    setOk('')
  }, [rol])

  const toggle = (modulo: string, permiso: Permiso) => {
    setSucio(true)
    setOk('')
    setMatriz((prev) => {
      const fila = { ...prev[modulo] }

      if (permiso === 'ver') {
        // Quitar Ver retira el modulo entero.
        return {
          ...prev,
          [modulo]: fila.ver
            ? { ver: false, crear: false, editar: false, eliminar: false }
            : { ...fila, ver: true },
        }
      }

      fila[permiso] = !fila[permiso]
      // Cualquier otro permiso implica Ver.
      if (fila[permiso]) fila.ver = true
      return { ...prev, [modulo]: fila }
    })
  }

  const marcarTodo = (modulo: string, todo: boolean) => {
    setSucio(true)
    setOk('')
    setMatriz((prev) => ({
      ...prev,
      [modulo]: { ver: todo, crear: todo, editar: todo, eliminar: todo },
    }))
  }

  const restablecer = () => {
    setMatriz(rol ? aMatriz(rol.permisos) : VACIA())
    setSucio(false)
    setOk('')
  }

  const guardar = async () => {
    if (!rol) return
    setGuardando(true)
    setError('')
    try {
      await rolApi.updatePermisos(
        rol.id,
        NAV_GROUPS.map((g) => ({ modulo: g.id, ...matriz[g.id] })),
      )
      await cargar()
      setSucio(false)
      setOk('Accesos guardados.')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos guardar los accesos.')
    } finally {
      setGuardando(false)
    }
  }

  const modulosActivos = NAV_GROUPS.filter((g) => matriz[g.id]?.ver).length

  return (
    <div className="space-y-5">
      <PageHeader
        icon={<ShieldCheck size={20} />}
        title={rol ? `Accesos de ${rol.nombre}` : 'Accesos'}
        description={
          rol
            ? `${modulosActivos} de ${NAV_GROUPS.length} módulos habilitados. ${rol.descripcion ?? ''}`
            : 'Elige un rol para configurar qué puede hacer en cada módulo.'
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

        <div className="overflow-x-auto">
          <table className="w-full min-w-[640px] border-collapse text-sm">
            <thead>
              <tr className="border-b border-line">
                <th className="py-2 pr-3 text-left text-[11px] font-semibold tracking-wider text-ink-muted uppercase">
                  Módulo
                </th>
                {PERMISOS.map((p) => (
                  <th
                    key={p.id}
                    className="w-20 px-2 py-2 text-center text-[11px] font-semibold tracking-wider text-ink-muted uppercase"
                  >
                    {p.label}
                  </th>
                ))}
                <th className="w-24 px-2 py-2 text-center text-[11px] font-semibold tracking-wider text-ink-muted uppercase">
                  Todo
                </th>
              </tr>
            </thead>
            <tbody>
              {NAV_GROUPS.map((group) => {
                const fila = matriz[group.id] ?? {
                  ver: false,
                  crear: false,
                  editar: false,
                  eliminar: false,
                }
                const completo = PERMISOS.every((p) => fila[p.id])
                const GroupIcon = group.icon
                return (
                  <tr
                    key={group.id}
                    data-sys={group.sys}
                    className="border-b border-line last:border-b-0 hover:bg-surface-alt/60"
                  >
                    <td className="py-2.5 pr-3">
                      <span className="flex items-center gap-2">
                        <GroupIcon size={16} className="text-[rgb(var(--sys-rgb))]" />
                        <span className="font-medium text-ink">{group.label}</span>
                        {!fila.ver && <Badge>sin acceso</Badge>}
                      </span>
                    </td>
                    {PERMISOS.map((p) => (
                      <td key={p.id} className="px-2 py-2.5 text-center">
                        <input
                          type="checkbox"
                          checked={fila[p.id]}
                          onChange={() => toggle(group.id, p.id)}
                          aria-label={`${p.label} en ${group.label}`}
                          className="size-4 cursor-pointer rounded border-line-strong accent-[rgb(var(--sys-rgb))]"
                        />
                      </td>
                    ))}
                    <td className="px-2 py-2.5 text-center">
                      <button
                        type="button"
                        onClick={() => marcarTodo(group.id, !completo)}
                        className="cursor-pointer text-xs font-semibold text-[rgb(var(--sys-ink-rgb))] hover:underline"
                      >
                        {completo ? 'Quitar' : 'Marcar'}
                      </button>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>

        <p className="mt-3 text-xs text-ink-soft">
          Quitar <b>Ver</b> retira el módulo por completo. Conceder cualquier otro permiso activa{' '}
          <b>Ver</b> automáticamente.
        </p>
      </PageSection>
    </div>
  )
}
