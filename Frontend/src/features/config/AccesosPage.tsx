import { useCallback, useEffect, useMemo, useState } from 'react'
import { Inbox, RotateCcw, Save, ShieldCheck, ShieldPlus, Users } from 'lucide-react'
import { Alert, Button, cn, PageHeader, PageSection, Tabs, useToast } from '../../components/ui'
import { ExcepcionesPermisos } from './ExcepcionesPermisos'
import { permisoApi } from './permisoApi'
import { BandejaSolicitudes } from './BandejaSolicitudes'
import { ESTADO_SOLICITUD, solicitudApi } from './solicitudApi'
import { MatrizPermisos, clave } from './MatrizPermisos'
import { ApiError } from '../../lib/apiClient'
import { catalogoPermisos } from '../../lib/permisos'
import type { SubmoduloCatalogo } from '../../lib/permisos'
import { rolApi } from './rolApi'
import type { RolPermisoResponse, RolResponse } from './rolApi'
import { useRealtime } from '../../lib/realtime'

/** Lo concedido, como claves "submodulo:accion" — igual que lo guarda el backend. */
type Marcas = Set<string>

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
  const toast = useToast()
  const [roles, setRoles] = useState<RolResponse[]>([])
  const [catalogo, setCatalogo] = useState<SubmoduloCatalogo[]>([])
  const [rolId, setRolId] = useState<number | null>(null)
  const [marcas, setMarcas] = useState<Marcas>(() => new Set())
  const [sucio, setSucio] = useState(false)
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')
  const [ok, setOk] = useState('')
  // Qué filas ve el rol (todos / solo su ruta / solo lo que registró) y en qué pantallas aplica.
  const [pantallasAlcance, setPantallasAlcance] = useState<string[]>([])
  const [alcances, setAlcances] = useState<Record<string, string>>({})
  const [alcancesBase, setAlcancesBase] = useState<Record<string, string>>({})

  /*
   * Dos pestañas porque son dos preguntas distintas: "que hace este rol" se
   * configura una vez y vale para todos, "que le falta a esta persona" se
   * resuelve caso por caso. Mezclarlas en una sola pantalla haria que quien
   * viene a soltar una accion puntual tuviera que pasar por la matriz entera.
   */
  // Se entra por la bandeja cuando la alerta de la campanita manda aqui.
  const [pestana, setPestana] = useState(() =>
    window.location.hash === '#solicitudes' ? 'solicitudes' : 'rol',
  )

  /*
   * Tambien si ya se estaba en esta pantalla.
   *
   * Ahi no hay montaje que lea el hash inicial: el componente sigue vivo y la
   * alerta no haria nada, que es peor que no llevar a ningun lado —parece que
   * el clic no funciona—.
   */
  useEffect(() => {
    const alCambiar = () => {
      if (window.location.hash === '#solicitudes') setPestana('solicitudes')
    }
    window.addEventListener('hashchange', alCambiar)
    return () => window.removeEventListener('hashchange', alCambiar)
  }, [])

  /*
   * Cuantas solicitudes esperan respuesta, para el numero de la pestaña: sin
   * el, quien no entra a la bandeja no se entera de que alguien esta esperando.
   */
  const [pendientes, setPendientes] = useState(0)

  const contarPendientes = useCallback(async () => {
    try {
      const abiertas = await solicitudApi.bandeja(true)
      setPendientes(abiertas.filter((s) => s.estado === ESTADO_SOLICITUD.pendiente).length)
    } catch {
      // El contador es un adorno: si falla, la bandeja se abre igual.
    }
  }, [])

  useEffect(() => {
    void contarPendientes()
  }, [contarPendientes])

  useRealtime('permisos', contarPendientes)

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

  useEffect(() => {
    void permisoApi
      .catalogoAlcances()
      .then((c) => setPantallasAlcance(c.submodulos))
      .catch(() => setPantallasAlcance([]))
  }, [])

  const rol = useMemo(() => roles.find((r) => r.id === rolId) ?? null, [roles, rolId])

  const deRol = (permisos: RolPermisoResponse[]) =>
    new Set(permisos.map((p) => clave(p.submodulo, p.accion)))

  // Al cambiar de rol se recarga su matriz y se descartan cambios sin guardar.
  useEffect(() => {
    setMarcas(rol ? deRol(rol.permisos) : new Set())
    setSucio(false)
    setOk('')
  }, [rol])

  // Los alcances del rol viven aparte de la matriz: se leen al elegir el rol.
  const rolIdActual = rol?.id
  useEffect(() => {
    if (rolIdActual === undefined) return
    let vigente = true
    void permisoApi
      .alcancesDeRol(rolIdActual)
      .then((a) => {
        if (!vigente) return
        setAlcances(a)
        setAlcancesBase(a)
      })
      .catch(() => {
        if (!vigente) return
        setAlcances({})
        setAlcancesBase({})
      })
    return () => {
      vigente = false
    }
  }, [rolIdActual])

  const cambiarAlcance = (submodulo: string, nivel: string) => {
    setSucio(true)
    setOk('')
    setAlcances((prev) => ({ ...prev, [submodulo]: nivel }))
  }

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
    setAlcances(alcancesBase)
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
      // Solo lo que limita algo: "todos" es no restringir y el backend ni lo guarda.
      const restringidos = Object.fromEntries(
        Object.entries(alcances).filter(([, nivel]) => nivel !== '' && nivel !== 'todos'),
      )
      await permisoApi.guardarAlcancesRol(rol.id, restringidos)
      setAlcancesBase(restringidos)
      await cargar()
      toast.exito(`Accesos de ${rol.nombre} guardados`)
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
        title={
          pestana === 'rol'
            ? rol
              ? `Accesos de ${rol.nombre}`
              : 'Accesos'
            : pestana === 'usuario'
              ? 'Permisos por persona'
              : 'Solicitudes de permiso'
        }
        description={
          pestana === 'solicitudes'
            ? 'Lo que la gente pidió al toparse con una acción bloqueada.'
            : pestana === 'usuario'
            ? 'Permisos extra para una persona, sin cambiarle el rol.'
            : rol
              ? `${pantallasActivas} de ${catalogo.length} pantallas habilitadas. ${rol.descripcion ?? ''}`
              : 'Elige un rol para configurar sus permisos.'
        }
        actions={
          pestana === 'rol' ? (
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
          ) : undefined
        }
      />

      <Tabs
        active={pestana}
        onChange={setPestana}
        items={[
          { id: 'rol', label: 'Por rol', icon: <Users size={15} /> },
          { id: 'usuario', label: 'Por persona', icon: <ShieldPlus size={15} /> },
          {
            id: 'solicitudes',
            label: 'Solicitudes',
            icon: <Inbox size={15} />,
            badge: pendientes || undefined,
          },
        ]}
      />

      {pestana === 'usuario' && <ExcepcionesPermisos />}
      {pestana === 'solicitudes' && <BandejaSolicitudes />}

      {pestana === 'rol' && (
      <>
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

        <MatrizPermisos
          catalogo={catalogo}
          marcadas={marcas}
          onToggle={toggle}
          onMarcarSubmodulo={marcarSubmodulo}
          onMarcarModulo={marcarModulo}
          /*
            Qué FILAS ve, no qué botones tiene: el permiso dice si entra a Pedidos; esto dice de qué clientes. Va en
            la misma fila de la pantalla para configurarla entera en un solo sitio. "Solo mis rutas" limita a los
            clientes de las rutas que la persona tiene a cargo (se asigna en Usuarios); sin ruta no ve ninguno.
          */
          alcance={{
            pantallas: pantallasAlcance,
            valores: alcances,
            onChange: cambiarAlcance,
            // El Administrador ve siempre todo.
            disabled: rol?.protegido,
          }}
        />

        <p className="mt-3 text-xs text-ink-soft">
          Quitar <b>Ver</b> retira la pantalla por completo. Conceder cualquier otra acción activa{' '}
          <b>Ver</b> automáticamente. Un <b>·</b> significa que esa acción no existe en esa
          pantalla. <b>Qué ve</b> dice de qué clientes y ventas: todos, solo los de su ruta o solo
          lo que registró.
        </p>
      </PageSection>
      </>
      )}
    </div>
  )
}
