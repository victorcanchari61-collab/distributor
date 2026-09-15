import { useEffect, useMemo, useState } from 'react'
import { Check, Clock, Lock } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { NAV_GROUPS, navPath } from '../../components/layout'
import type { NavGroup } from '../../components/layout'
import { Badge, Card, Modal, useToast } from '../../components/ui'
import { cn } from '../../components/ui'
import type { UsuarioResponse } from '../auth/authApi'
import { getUsuario } from '../../lib/authStorage'
import { catalogoPermisos, usePermisos } from '../../lib/permisos'
import type { Accion, SubmoduloCatalogo } from '../../lib/permisos'
import { solicitudApi } from '../config/solicitudApi'
import { ESTADO_SOLICITUD } from '../config/solicitudApi'

/** Cómo se lee cada acción cuando va sola, sin la pantalla al lado. */
const ACCION_LABEL: Record<string, string> = {
  ver: 'Entrar',
  crear: 'Crear',
  editar: 'Editar',
  anular: 'Anular',
  eliminar: 'Eliminar',
  exportar: 'Exportar',
  importar: 'Importar',
  confirmar: 'Confirmar',
  cobrar: 'Cobrar',
}

/**
 * La pantalla en la que se cae al entrar, y desde la que se piden accesos.
 *
 * Antes esto era un redirect a la primera vista que la persona pudiera abrir.
 * Servía para no recibir a un almacenero con un "no tienes acceso", pero dejaba
 * fuera lo demás: quien no ve un módulo no sabe que existe, y quien lo necesita
 * tiene que adivinar el nombre de la pantalla para pedirla.
 *
 * Aquí están los módulos completos, se puedan abrir o no. Los que no, con el
 * candado y el botón para pedirlos —que es el punto de tenerlos a la vista—.
 */
export function InicioPage() {
  const usuario = getUsuario<UsuarioResponse>()
  const { puedeVer } = usePermisos()
  const [abierto, setAbierto] = useState<NavGroup | null>(null)

  const [catalogo, setCatalogo] = useState<SubmoduloCatalogo[]>([])
  /** Claves "submodulo:accion" ya pedidas y todavía sin respuesta. */
  const [pendientes, setPendientes] = useState<Set<string>>(new Set())

  useEffect(() => {
    void catalogoPermisos().then(setCatalogo).catch(() => setCatalogo([]))
    void solicitudApi
      .mias()
      .then((mias) =>
        setPendientes(
          new Set(
            mias
              .filter((s) => s.estado === ESTADO_SOLICITUD.pendiente)
              .map((s) => `${s.submodulo}:${s.accion}`),
          ),
        ),
      )
      .catch(() => setPendientes(new Set()))
  }, [])

  const acciones = useMemo(() => {
    const mapa = new Map<string, Accion[]>()
    for (const c of catalogo) mapa.set(c.submodulo, c.acciones)
    return mapa
  }, [catalogo])

  return (
    <div className="space-y-5">
      <Card className="flex items-center gap-4 p-5">
        <span className="flex size-12 shrink-0 items-center justify-center rounded-full bg-[rgb(var(--sys-rgb))] text-lg font-bold text-white">
          {usuario?.nombre?.trim().charAt(0).toUpperCase() ?? '?'}
        </span>
        <div className="min-w-0">
          <p className="text-xs text-ink-soft">Hola,</p>
          <p className="truncate text-lg font-extrabold text-ink">{usuario?.nombre}</p>
          {usuario?.rol && (
            <span className="mt-1 inline-block">
              <Badge tone="sys">{usuario.rol}</Badge>
            </span>
          )}
        </div>
      </Card>

      <div>
        <h2 className="mb-3 text-[15px] font-bold text-ink">Módulos</h2>

        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          {NAV_GROUPS.map((grupo) => {
            /*
              Solo cuentan las pantallas que el backend controla.

              "Notas de crédito" está en el menú pero no en el catálogo de
              permisos: nadie puede tenerla y pedirla daría error. Contarla
              dejaba a un administrador viendo "4 de 5" y un candado, como si
              le faltara algo que en realidad todavía no existe.
            */
            const controladas = acciones.size
              ? grupo.items.filter((i) => acciones.has(i.id))
              : grupo.items
            const abiertas = controladas.filter((i) => puedeVer(i.id)).length
            const Icono = grupo.icon

            return (
              <button
                key={grupo.id}
                type="button"
                data-sys={grupo.sys}
                onClick={() => setAbierto(grupo)}
                className="flex cursor-pointer flex-col items-start justify-between gap-6 rounded-panel border border-line bg-white p-4 text-left transition-colors hover:bg-surface-alt"
              >
                <span className="flex size-10 items-center justify-center rounded-lg bg-[rgb(var(--sys-rgb)/0.12)] text-[rgb(var(--sys-ink-rgb))]">
                  <Icono size={20} />
                </span>

                <span className="min-w-0">
                  <span className="block truncate text-sm font-bold text-ink">{grupo.label}</span>
                  <span className="flex items-center gap-1 text-[11px] text-ink-soft">
                    {abiertas === controladas.length
                      ? `${controladas.length} vistas`
                      : `${abiertas} de ${controladas.length} vistas`}
                    {abiertas < controladas.length && <Lock size={10} />}
                  </span>
                </span>
              </button>
            )
          })}
        </div>
      </div>

      <ModuloModal
        grupo={abierto}
        acciones={acciones}
        pendientes={pendientes}
        onPedido={(clave) => setPendientes((p) => new Set(p).add(clave))}
        onClose={() => setAbierto(null)}
      />
    </div>
  )
}

/**
 * Todo lo que se puede hacer dentro de un módulo, y en qué está cada cosa.
 *
 * Las acciones salen del catálogo del backend y no de una lista escrita aquí:
 * si se copiara, una acción nueva quedaría sin poder pedirse aunque el
 * servidor ya la estuviera exigiendo.
 */
function ModuloModal({
  grupo,
  acciones: accionesPorSubmodulo,
  pendientes,
  onPedido,
  onClose,
}: {
  grupo: NavGroup | null
  acciones: Map<string, Accion[]>
  pendientes: Set<string>
  onPedido: (clave: string) => void
  onClose: () => void
}) {
  const navigate = useNavigate()
  const toast = useToast()
  const { puede, puedeVer } = usePermisos()
  const [enviando, setEnviando] = useState('')

  if (!grupo) return null

  const pedir = async (submodulo: string, accion: string) => {
    const clave = `${submodulo}:${accion}`
    setEnviando(clave)
    try {
      await solicitudApi.solicitar({ submodulo, accion })
      onPedido(clave)
      toast.exito('Pedido. Un administrador lo verá en su bandeja.')
    } catch {
      toast.error('No pudimos enviar el pedido. Inténtalo de nuevo.')
    } finally {
      setEnviando('')
    }
  }

  return (
    <div data-sys={grupo.sys}>
      <Modal
        open
        onClose={onClose}
        size="lg"
        title={grupo.label}
        description="Lo que puedes hacer en este módulo. Lo que no, se pide desde aquí."
      >
        <div className="space-y-4">
          {grupo.items.map((item) => {
            const acciones = accionesPorSubmodulo.get(item.id) ?? []
            const Icono = item.icon
            const entra = puedeVer(item.id)

            return (
              <div key={item.id} className="rounded-panel border border-line p-3">
                <div className="mb-2 flex items-center gap-2">
                  <Icono size={16} className="shrink-0 text-[rgb(var(--sys-ink-rgb))]" />

                  {/* Se entra desde aquí si se puede: tener la lista delante y
                      obligar a buscar la misma pantalla en el menú sobra. */}
                  {entra ? (
                    <button
                      type="button"
                      onClick={() => {
                        onClose()
                        navigate(navPath(item.id))
                      }}
                      className="cursor-pointer text-sm font-semibold text-ink hover:underline"
                    >
                      {item.label}
                    </button>
                  ) : (
                    <span className="text-sm font-semibold text-ink-muted">{item.label}</span>
                  )}

                  {item.pending && <Badge tone="neutral">En construcción</Badge>}
                </div>

                {acciones.length === 0 && (
                  <p className="text-xs text-ink-soft">
                    Todavía no se puede pedir: esta pantalla aún no existe.
                  </p>
                )}

                <div className="flex flex-wrap gap-1.5">
                  {acciones.map((accion) => {
                    const clave = `${item.id}:${accion}`
                    const tiene = puede(item.id, accion)
                    const pedida = pendientes.has(clave)

                    return (
                      <button
                        key={accion}
                        type="button"
                        disabled={tiene || pedida || enviando === clave}
                        onClick={() => void pedir(item.id, accion)}
                        title={
                          tiene
                            ? 'Ya lo tienes'
                            : pedida
                              ? 'Pedido, esperando respuesta'
                              : 'Pedir este permiso'
                        }
                        className={cn(
                          'flex items-center gap-1 rounded-full border px-2.5 py-1 text-xs font-semibold',
                          tiene
                            ? 'border-emerald-200 bg-emerald-50 text-emerald-700'
                            : pedida
                              ? 'border-amber-200 bg-amber-50 text-amber-700'
                              : 'cursor-pointer border-line text-ink-muted hover:bg-surface-alt',
                        )}
                      >
                        {tiene ? <Check size={12} /> : pedida ? <Clock size={12} /> : <Lock size={12} />}
                        {ACCION_LABEL[accion] ?? accion}
                      </button>
                    )
                  })}
                </div>
              </div>
            )
          })}
        </div>
      </Modal>
    </div>
  )
}
