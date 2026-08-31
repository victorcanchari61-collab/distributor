import { useState } from 'react'
import { RotateCcw, Save, ShieldCheck } from 'lucide-react'
import { Badge, Button, cn, PageSection } from '../../components/ui'
import { NAV_GROUPS } from '../../components/layout'
import { ACCESOS_INICIALES, PERMISOS, ROLES, ROLES_LIST } from './roles'
import type { MatrizAccesos, Permiso, Rol } from './roles'

/**
 * Matriz de permisos: que puede hacer cada rol en cada modulo.
 * Los roles se definen en la vista Roles; aqui solo se conceden accesos.
 */
export function AccesosPage() {
  const [rol, setRol] = useState<Rol>(1)
  const [accesos, setAccesos] = useState<MatrizAccesos>(ACCESOS_INICIALES)
  const [sucio, setSucio] = useState(false)

  const actual = accesos[rol]

  const toggle = (modulo: string, permiso: Permiso) => {
    setSucio(true)
    setAccesos((prev) => {
      const concedidos = prev[rol][modulo] ?? []
      const tiene = concedidos.includes(permiso)

      // Quitar "ver" apaga todo el modulo; conceder cualquier otro permiso lo enciende.
      let siguiente: Permiso[]
      if (permiso === 'ver') {
        siguiente = tiene ? [] : ['ver']
      } else {
        siguiente = tiene
          ? concedidos.filter((p) => p !== permiso)
          : [...new Set<Permiso>([...concedidos, 'ver', permiso])]
      }

      return { ...prev, [rol]: { ...prev[rol], [modulo]: siguiente } }
    })
  }

  const marcarTodo = (modulo: string, todo: boolean) => {
    setSucio(true)
    setAccesos((prev) => ({
      ...prev,
      [rol]: { ...prev[rol], [modulo]: todo ? PERMISOS.map((p) => p.id) : [] },
    }))
  }

  const restablecer = () => {
    setAccesos(ACCESOS_INICIALES)
    setSucio(false)
  }

  const modulosActivos = NAV_GROUPS.filter((g) => (actual[g.id] ?? []).length > 0).length

  return (
    <PageSection
      title={`Accesos de ${ROLES[rol].label}`}
      description={`${modulosActivos} de ${NAV_GROUPS.length} módulos habilitados. ${ROLES[rol].description}`}
      icon={<ShieldCheck size={18} />}
      actions={
        <>
          <Button variant="secondary" size="sm" disabled={!sucio} onClick={restablecer}>
            <RotateCcw size={15} />
            Restablecer
          </Button>
          <Button size="sm" disabled={!sucio} iconRight={<Save size={15} />}>
            Guardar
          </Button>
        </>
      }
    >
      {/* Selector de rol */}
      <div
        role="tablist"
        aria-label="Rol a configurar"
        className="mb-4 inline-flex flex-wrap gap-1 rounded-full bg-surface-alt p-1"
      >
        {ROLES_LIST.map((r) => (
          <button
            key={r.id}
            type="button"
            role="tab"
            aria-selected={rol === r.id}
            onClick={() => setRol(r.id)}
            className={cn(
              'cursor-pointer rounded-full px-4 py-1.5 text-sm font-semibold transition-colors',
              rol === r.id
                ? 'bg-white text-[rgb(var(--sys-ink-rgb))] shadow-sm'
                : 'text-ink-muted hover:text-ink',
            )}
          >
            {r.label}
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
              const concedidos = actual[group.id] ?? []
              const completo = concedidos.length === PERMISOS.length
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
                      {concedidos.length === 0 && <Badge>sin acceso</Badge>}
                    </span>
                  </td>
                  {PERMISOS.map((p) => (
                    <td key={p.id} className="px-2 py-2.5 text-center">
                      <input
                        type="checkbox"
                        checked={concedidos.includes(p.id)}
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
  )
}
