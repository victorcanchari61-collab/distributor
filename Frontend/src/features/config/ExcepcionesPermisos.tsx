import { useCallback, useEffect, useMemo, useState } from 'react'
import { MatrizPermisos, clave } from './MatrizPermisos'
import { rolApi } from './rolApi'
import type { RolResponse } from './rolApi'
import { fechaHora, fechaCorta } from '../../lib/fechas'
import { Ban, CalendarClock, Infinity as InfinityIcon, Plus, Search, ShieldPlus, Zap } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Modal,
  PageSection,
  Desplegable,
  SysDataTable,
  cn,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { resolveNav } from '../../components/layout'
import { ApiError } from '../../lib/apiClient'
import { catalogoPermisos } from '../../lib/permisos'
import type { SubmoduloCatalogo } from '../../lib/permisos'
import { usuarioApi } from './usuarioApi'
import type { UsuarioResponse } from './usuarioApi'
import { ALCANCE, ALCANCE_LABEL, permisoApi } from './permisoApi'
import { AlcanceDatosEditor } from './AlcanceDatosEditor'
import type { Alcance, UsuarioPermisoResponse } from './permisoApi'

const ICONO_ALCANCE: Record<Alcance, React.ReactNode> = {
  [ALCANCE.unaVez]: <Zap size={13} />,
  [ALCANCE.temporal]: <CalendarClock size={13} />,
  [ALCANCE.permanente]: <InfinityIcon size={13} />,
}

/** Cómo se lee una acción en pantalla. */
const ACCION_LABEL: Record<string, string> = {
  ver: 'Ver',
  crear: 'Crear',
  editar: 'Editar',
  anular: 'Anular',
  eliminar: 'Eliminar',
  exportar: 'Exportar',
  importar: 'Importar',
  confirmar: 'Confirmar',
  cobrar: 'Cobrar',
  ingreso: 'Ingreso',
  egreso: 'Egreso',
  transferir: 'Mover plata',
}

const nombrePantalla = (submodulo: string) => resolveNav(submodulo).item?.label ?? submodulo

/**
 * Permisos que tiene una persona y su rol no le da.
 *
 * El rol resuelve el caso general — todos los vendedores hacen lo mismo — pero
 * no el particular: uno concreto tiene que corregir hoy un pedido suyo. Antes
 * la única salida era subirlo de rol, que le daba de golpe todo lo que ese rol
 * puede hacer y ya no se lo quitaba nadie.
 *
 * Por eso lo concedido lleva alcance: una sola vez (lo normal — se pide para
 * un documento concreto y se gasta), por un tiempo, o para siempre.
 */
export function ExcepcionesPermisos() {
  const toast = useToast()
  const [usuarios, setUsuarios] = useState<UsuarioResponse[]>([])
  const [catalogo, setCatalogo] = useState<SubmoduloCatalogo[]>([])
  const [roles, setRoles] = useState<RolResponse[]>([])
  const [usuarioId, setUsuarioId] = useState<number | null>(null)
  const [permisos, setPermisos] = useState<UsuarioPermisoResponse[]>([])
  const [cargando, setCargando] = useState(false)
  const [error, setError] = useState('')
  const [abierto, setAbierto] = useState(false)
  const { confirmar, dialogo } = useConfirmacion()

  // Qué filas ve ESTA persona. Vacío en una pantalla = igual que su rol.
  const [pantallasAlcance, setPantallasAlcance] = useState<string[]>([])
  const [alcances, setAlcances] = useState<Record<string, string>>({})
  const [alcancesBase, setAlcancesBase] = useState<Record<string, string>>({})
  const [guardandoAlcance, setGuardandoAlcance] = useState(false)

  useEffect(() => {
    void usuarioApi
      .getAll()
      .then((lista) => {
        setUsuarios(lista)
        setUsuarioId((actual) => actual ?? lista[0]?.id ?? null)
      })
      .catch(() => setError('No pudimos cargar los usuarios.'))

    // Lo que ya le da su rol se muestra marcado en gris al conceder: no tiene sentido dárselo otra vez.
    void rolApi
      .getAll()
      .then(setRoles)
      .catch(() => setRoles([]))

    void catalogoPermisos()
      .then(setCatalogo)
      .catch(() => setError('No pudimos cargar el catálogo de permisos.'))
  }, [])

  useEffect(() => {
    void permisoApi
      .catalogoAlcances()
      .then((c) => setPantallasAlcance(c.submodulos))
      .catch(() => setPantallasAlcance([]))
  }, [])

  useEffect(() => {
    if (usuarioId === null) return
    let vigente = true
    void permisoApi
      .alcancesDeUsuario(usuarioId)
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
  }, [usuarioId])

  const alcancesSucios = JSON.stringify(alcances) !== JSON.stringify(alcancesBase)

  const guardarAlcances = async () => {
    if (usuarioId === null) return
    setGuardandoAlcance(true)
    try {
      // Lo que se deja en "igual que su rol" no viaja: sin fila la persona sigue a su rol.
      const propios = Object.fromEntries(Object.entries(alcances).filter(([, nivel]) => nivel !== ''))
      await permisoApi.guardarAlcancesUsuario(usuarioId, propios)
      setAlcancesBase(propios)
      setAlcances(propios)
      toast.exito('Alcance guardado')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos guardar el alcance.')
    } finally {
      setGuardandoAlcance(false)
    }
  }

  const cargar = useCallback(async () => {
    if (usuarioId === null) return
    setCargando(true)
    try {
      setPermisos(await permisoApi.deUsuario(usuarioId))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los permisos.')
    } finally {
      setCargando(false)
    }
  }, [usuarioId])

  useEffect(() => {
    void cargar()
  }, [cargar])

  const usuario = usuarios.find((u) => u.id === usuarioId) ?? null

  const revocar = (p: UsuarioPermisoResponse) => {
    confirmar({
      titulo: 'Retirar el permiso',
      mensaje: `${usuario?.nombre} dejará de poder ${(
        ACCION_LABEL[p.accion] ?? p.accion
      ).toLowerCase()} en ${nombrePantalla(p.submodulo)}.`,
      confirmar: 'Retirar',
      tono: 'danger',
      accion: async () => {
        try {
          await permisoApi.revocar(p.id)
          await cargar()
          toast.exito('Permiso retirado')
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos retirar el permiso.')
        }
      },
    })
  }

  const columns: DataTableColumn<UsuarioPermisoResponse>[] = [
    {
      key: 'submodulo',
      label: 'Pantalla',
      value: (p) => nombrePantalla(p.submodulo),
      render: (p) => <span className="font-medium text-ink">{nombrePantalla(p.submodulo)}</span>,
    },
    {
      key: 'accion',
      label: 'Acción',
      filterType: 'select',
      // Las opciones son las claves crudas de la fila; la etiqueta es la del render.
      filterOptions: Object.entries(ACCION_LABEL).map(([value, label]) => ({ value, label })),
      render: (p) => ACCION_LABEL[p.accion] ?? p.accion,
    },
    {
      key: 'alcance',
      label: 'Alcance',
      filterType: 'select',
      // El alcance viaja como numero, asi que se compara contra la etiqueta
      // que `value` expone.
      filterOptions: Object.values(ALCANCE_LABEL).map((label) => ({ value: label, label })),
      value: (p) => ALCANCE_LABEL[p.alcance],
      render: (p) => (
        <span className="inline-flex items-center gap-1.5">
          {ICONO_ALCANCE[p.alcance]}
          {ALCANCE_LABEL[p.alcance]}
        </span>
      ),
    },
    {
      key: 'expiraEn',
      label: 'Vence',
      filterable: false,
      // Solo los permisos temporales vencen; sin fecha queda en 0 para ordenar.
      value: (p) => (p.alcance === ALCANCE.temporal && p.expiraEn ? new Date(p.expiraEn).getTime() : 0),
      render: (p) =>
        p.alcance === ALCANCE.temporal && p.expiraEn ? fechaHora(p.expiraEn) : <span className="text-ink-soft">—</span>,
    },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      // El Badge distingue por que termino (retirado, usado, vencido), pero la
      // fila solo guarda si sigue vigente: eso es lo que se puede filtrar.
      filterOptions: [
        { value: 'Vigente', label: 'Vigente' },
        { value: 'Terminado', label: 'Terminado' },
      ],
      value: (p) => (p.vigente ? 'Vigente' : 'Terminado'),
      render: (p) => {
        // Vale mas decir POR QUE ya no sirve que un "inactivo" que obliga a
        // adivinar entre gastado, vencido y retirado a mano.
        if (p.vigente) return <Badge tone="success">Vigente</Badge>
        if (p.revocado) return <Badge tone="danger">Retirado</Badge>
        if (p.alcance === ALCANCE.unaVez && p.usos > 0) return <Badge>Ya usado</Badge>
        return <Badge>Vencido</Badge>
      },
    },
    {
      key: 'motivo',
      label: 'Motivo',
      render: (p) => p.motivo ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'fechaOtorgado',
      label: 'Concedido',
      filterType: 'date',
      // La tabla filtra en memoria y el rango compara en epoch: sin esto se
      // descartarian filas ya cargadas y saldria "sin registros".
      value: (p) => new Date(p.fechaOtorgado).getTime(),
      render: (p) => fechaCorta(p.fechaOtorgado),
    },
  ]

  return (
    <PageSection>
      {error && <Alert>{error}</Alert>}

      <div className="mb-4 flex flex-wrap items-end gap-3">
        <div className="min-w-56">
          <Desplegable
            label="Usuario"
            value={usuarioId ?? 0}
            onChange={(v) => setUsuarioId(Number(v))}
            placeholder="Elige un usuario"
            options={usuarios.map((u) => ({ value: u.id, label: u.nombre, detalle: u.rol }))}
          />
        </div>

        <Button size="sm" disabled={usuarioId === null} onClick={() => setAbierto(true)}>
          <Plus size={15} />
          Conceder permiso
        </Button>
      </div>

      <SysDataTable
        columns={columns}
        rows={permisos}
        cardIcon={ShieldPlus}
        searchPlaceholder="Buscar por pantalla, acción, motivo..."
        empty={
          cargando
            ? 'Cargando...'
            : `${usuario?.nombre ?? 'Este usuario'} no tiene permisos aparte de los de su rol.`
        }
        actions={(p) =>
          p.vigente ? (
            <button
              type="button"
              onClick={() => revocar(p)}
              title="Retirar el permiso"
              className={cn(
                'cursor-pointer rounded-md p-1.5 text-ink-muted transition-colors',
                'hover:bg-rose-50 hover:text-rose-600',
              )}
            >
              <Ban size={15} />
            </button>
          ) : null
        }
      />

      <p className="mt-3 text-xs text-ink-soft">
        Lo que se concede aquí <b>se suma</b> a lo del rol, nunca lo quita.
      </p>

      {/*
        El alcance sí puede cambiar lo del rol en cualquier sentido: el supervisor del rol Vendedor que
        debe verlo todo, o el dueño que solo atiende su ruta. Por eso aquí manda sobre el rol.
      */}
      {pantallasAlcance.length > 0 && usuarioId !== null && (
        <div className="mt-6 border-t border-line pt-5">
          <div className="mb-3 flex flex-wrap items-start justify-between gap-3">
            <div>
              <h3 className="text-base font-bold text-ink">Qué clientes y ventas ve</h3>
              <p className="mt-0.5 text-sm text-ink-muted">
                Manda sobre el alcance de su rol. Déjalo en <b>Igual que su rol</b> para no cambiar nada.
                {usuario && !usuario.rutaIds?.length && ' Esta persona todavía no tiene ruta asignada (se asigna en Usuarios).'}
              </p>
            </div>
            <Button
              size="sm"
              disabled={!alcancesSucios}
              loading={guardandoAlcance}
              onClick={() => void guardarAlcances()}
            >
              Guardar alcance
            </Button>
          </div>
          <AlcanceDatosEditor
            submodulos={pantallasAlcance}
            valores={alcances}
            onChange={(sub, nivel) => setAlcances((prev) => ({ ...prev, [sub]: nivel }))}
            heredable
          />
        </div>
      )}

      {abierto && usuarioId !== null && (
        <ModalConceder
          usuario={usuario}
          catalogo={catalogo}
          roles={roles}
          vigentes={permisos.filter((p) => p.vigente)}
          onCerrar={() => setAbierto(false)}
          onConcedido={async (n) => {
            setAbierto(false)
            await cargar()
            toast.exito(n === 1 ? 'Permiso concedido' : `${n} permisos concedidos`)
          }}
          usuarioId={usuarioId}
        />
      )}

      {dialogo}
    </PageSection>
  )
}

/**
 * Elegir qué se le da, hasta cuándo y por qué.
 *
 * Lo que se le da se busca como en el menú — módulo, pantalla, acción — con la misma matriz de los roles, en vez de
 * dos desplegables con el nombre interno de la pantalla. Lo que su rol ya le da sale marcado en gris, y se pueden
 * dar varias cosas de una vez.
 */
function ModalConceder({
  usuario,
  usuarioId,
  catalogo,
  roles,
  vigentes,
  onCerrar,
  onConcedido,
}: {
  usuario: UsuarioResponse | null
  usuarioId: number
  catalogo: SubmoduloCatalogo[]
  roles: RolResponse[]
  vigentes: UsuarioPermisoResponse[]
  onCerrar: () => void
  onConcedido: (cuantos: number) => Promise<void>
}) {
  const [marcadas, setMarcadas] = useState<Set<string>>(() => new Set())
  const [buscar, setBuscar] = useState('')
  const [alcance, setAlcance] = useState<Alcance>(ALCANCE.unaVez)
  const [expiraEn, setExpiraEn] = useState('')
  const [motivo, setMotivo] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  /** Lo que ya tiene y no se vuelve a dar: lo de sus roles y lo concedido antes que sigue vigente. */
  const fijas = useMemo(() => {
    const m = new Map<string, string>()
    const suyos = roles.filter((r) => usuario?.rolIds.includes(r.id))
    // El Administrador lo tiene todo aunque la matriz de su rol no lo diga.
    if (suyos.some((r) => r.protegido)) {
      for (const s of catalogo)
        for (const a of s.acciones) m.set(clave(s.submodulo, a), 'Ya lo tiene: es Administrador')
      return m
    }
    for (const r of suyos)
      for (const p of r.permisos) m.set(clave(p.submodulo, p.accion), `Ya lo tiene por su rol (${r.nombre})`)
    for (const p of vigentes) {
      const k = clave(p.submodulo, p.accion)
      if (!m.has(k)) m.set(k, 'Ya se le concedió y sigue vigente')
    }
    return m
  }, [roles, usuario, vigentes, catalogo])

  const toggle = (submodulo: string, accion: string, acciones: string[]) => {
    setMarcadas((prev) => {
      const siguiente = new Set(prev)
      const k = clave(submodulo, accion)
      const ver = clave(submodulo, 'ver')

      if (siguiente.has(k)) {
        siguiente.delete(k)
        // Sin Ver lo demás de esa pantalla quedaría dado pero inalcanzable.
        if (accion === 'ver') for (const a of acciones) siguiente.delete(clave(submodulo, a))
      } else {
        siguiente.add(k)
        // Cualquier acción necesita poder entrar a la pantalla.
        if (!fijas.has(ver)) siguiente.add(ver)
      }
      return siguiente
    })
  }

  /** Lo elegido dicho en palabras, para leerlo antes de confirmar. */
  const resumen = useMemo(() => {
    const porPantalla = new Map<string, string[]>()
    for (const k of marcadas) {
      const corte = k.lastIndexOf(':')
      const sub = k.slice(0, corte)
      const accion = k.slice(corte + 1)
      const lista = porPantalla.get(sub) ?? []
      lista.push((ACCION_LABEL[accion] ?? accion).toLowerCase())
      porPantalla.set(sub, lista)
    }
    return [...porPantalla].map(([sub, acciones]) => `${nombrePantalla(sub)}: ${acciones.join(', ')}`)
  }, [marcadas])

  const guardar = async () => {
    setGuardando(true)
    setError('')
    // Uno por uno: si alguno falla se para ahí y se dice cuántos se dieron.
    let dados = 0
    try {
      for (const k of marcadas) {
        const corte = k.lastIndexOf(':')
        await permisoApi.conceder({
          usuarioId,
          submodulo: k.slice(0, corte),
          accion: k.slice(corte + 1),
          alcance,
          // El input da hora local; el backend guarda en UTC.
          expiraEn: alcance === ALCANCE.temporal ? new Date(expiraEn).toISOString() : null,
          motivo: motivo.trim() || null,
        })
        dados++
      }
      await onConcedido(dados)
    } catch (e) {
      const mensaje = e instanceof ApiError ? e.message : 'No pudimos conceder el permiso.'
      setError(dados > 0 ? `Se dieron ${dados} de ${marcadas.size}. ${mensaje}` : mensaje)
    } finally {
      setGuardando(false)
    }
  }

  const listo = marcadas.size > 0 && (alcance !== ALCANCE.temporal || expiraEn !== '')

  return (
    <Modal
      open
      onClose={onCerrar}
      title={`Dar permisos a ${usuario?.nombre ?? ''}`}
      size="xl"
      footer={
        <>
          <span className="mr-auto text-sm text-ink-muted">
            {marcadas.size === 0
              ? 'Marca lo que necesita.'
              : `${marcadas.size} ${marcadas.size === 1 ? 'permiso' : 'permisos'} · ${ALCANCE_LABEL[alcance].toLowerCase()}`}
          </span>
          <Button variant="secondary" onClick={onCerrar}>
            Cancelar
          </Button>
          <Button disabled={!listo} loading={guardando} onClick={() => void guardar()}>
            Conceder
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        {error && <Alert>{error}</Alert>}

        <div>
          <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
            <p className="text-sm font-medium text-ink">
              ¿Qué necesita hacer?{' '}
              <span className="font-normal text-ink-soft">Lo que ya tiene sale marcado en gris.</span>
            </p>
            <label className="relative w-full sm:w-64">
              <Search
                size={15}
                className="pointer-events-none absolute top-1/2 left-2.5 -translate-y-1/2 text-ink-soft"
              />
              <input
                type="search"
                value={buscar}
                onChange={(e) => setBuscar(e.target.value)}
                placeholder="Buscar pantalla: boletas, caja…"
                className="w-full rounded-field border border-line py-1.5 pr-3 pl-8 text-sm"
              />
            </label>
          </div>
          <MatrizPermisos
            catalogo={catalogo}
            marcadas={marcadas}
            onToggle={toggle}
            fijas={fijas}
            filtro={buscar}
            nuevas
          />
          {resumen.length > 0 && (
            <ul className="mt-2 space-y-0.5 rounded-field bg-emerald-50 px-3 py-2 text-xs text-emerald-800">
              {resumen.map((r) => (
                <li key={r}>
                  <b>Podrá</b> · {r}
                </li>
              ))}
            </ul>
          )}
        </div>

        <div>
          <p className="mb-1.5 text-sm font-medium text-ink">¿Hasta cuándo?</p>
          <div className="grid gap-2 sm:grid-cols-3">
            {([ALCANCE.unaVez, ALCANCE.temporal, ALCANCE.permanente] as Alcance[]).map((a) => (
              <button
                key={a}
                type="button"
                onClick={() => setAlcance(a)}
                className={cn(
                  'flex cursor-pointer items-center gap-2 rounded-field border px-3 py-2 text-sm transition-colors',
                  alcance === a
                    ? 'border-[rgb(var(--sys-rgb))] bg-[rgb(var(--sys-rgb)/0.08)] font-semibold text-[rgb(var(--sys-ink-rgb))]'
                    : 'border-line text-ink-muted hover:bg-surface-alt',
                )}
              >
                {ICONO_ALCANCE[a]}
                {ALCANCE_LABEL[a]}
              </button>
            ))}
          </div>
          <p className="mt-1.5 text-xs text-ink-soft">
            {alcance === ALCANCE.unaVez && 'Se gasta al usarlo una vez. Si la operación falla, no se gasta.'}
            {alcance === ALCANCE.temporal && 'Deja de valer solo, sin que nadie tenga que retirarlo.'}
            {alcance === ALCANCE.permanente &&
              'No vence. Si varias personas lo necesitan, es mejor ponerlo en el rol.'}
          </p>
        </div>

        {alcance === ALCANCE.temporal && (
          <label className="block">
            <span className="mb-1.5 block text-sm font-medium text-ink">Vence el</span>
            <input
              type="datetime-local"
              value={expiraEn}
              onChange={(e) => setExpiraEn(e.target.value)}
              className="w-full rounded-field border border-line px-3 py-2 text-sm"
            />
          </label>
        )}

        <label className="block">
          <span className="mb-1.5 block text-sm font-medium text-ink">
            Motivo <span className="font-normal text-ink-soft">(opcional)</span>
          </span>
          <input
            type="text"
            value={motivo}
            onChange={(e) => setMotivo(e.target.value)}
            maxLength={300}
            placeholder="Boleta de la NV-0042 que pidió el cliente"
            className="w-full rounded-field border border-line px-3 py-2 text-sm"
          />
        </label>
      </div>
    </Modal>
  )
}
