import { useState } from 'react'
import { Save, ShieldCheck } from 'lucide-react'
import { Badge, Button, cn, PageSection } from '../../components/ui'
import { NAV_GROUPS } from '../../components/layout'
import { ACCESOS_INICIALES, PERMISOS, ROLES_LIST } from './roles'
import type { MatrizAccesos, Permiso, Rol } from './roles'

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

  const modulosActivos = NAV_GROUPS.filter((g) => (actual[g.id] ?? []).length > 0).length

  return (
    <div className="space-y-5">
      {/* Selector de rol */}
      <PageSection
        title="Roles"
        description="Elige un rol para revisar y ajustar qué puede hacer en cada módulo."
        icon={<ShieldCheck size={18} />}
      >
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          {ROLES_LIST.map((r) => (
            <button
              key={r.id}
              type="button"
              onClick={() => setRol(r.id)}
              aria-pressed={rol === r.id}
              className={cn(
                'cursor-pointer rounded-panel border p-4 text-left transition-all',
                rol === r.id
                  ? 'border-[rgb(var(--sys-rgb))] bg-[rgb(var(--sys-rgb)/0.06)] ring-2 ring-[rgb(var(--sys-rgb)/0.2)]'
                  : 'border-line hover:border-line-strong hover:bg-surface-alt',
              )}
            >
              <div className="flex items-center justify-between gap-2">
                <span className="font-semibold text-ink">{r.label}</span>
                {rol === r.id && <Badge tone="sys">Editando</Badge>}
              </div>
              <p className="mt-1 text-xs leading-relaxed text-ink-muted">{r.description}</p>
            </button>
          ))}
        </div>
      </PageSection>

      {/* Matriz de permisos */}
      <PageSection
        title="Permisos por módulo"
        description={`${modulosActivos} de ${NAV_GROUPS.length} módulos habilitados para este rol.`}
        icon={<ShieldCheck size={18} />}
        actions={
          <Button size="sm" disabled={!sucio} iconRight={<Save size={15} />}>
            Guardar cambios
          </Button>
        }
      >
        <div className="overflow-x-auto">
          <table className="w-full min-w-[560px] border-collapse text-sm">
            <thead>
              <tr className="border-b border-line">
                <th className="py-2 pr-3 text-left text-[11px] font-semibold tracking-wider text-ink-muted uppercase">
                  Módulo
                </th>
                {PERMISOS.map((p) => (
                  <th
                    key={p.id}
                    className="w-24 px-2 py-2 text-center text-[11px] font-semibold tracking-wider text-ink-muted uppercase"
                  >
                    {p.label}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {NAV_GROUPS.map((group) => {
                const concedidos = actual[group.id] ?? []
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
                        {concedidos.length === 0 && (
                          <span className="text-[11px] text-ink-soft">sin acceso</span>
                        )}
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
