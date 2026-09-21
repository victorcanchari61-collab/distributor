import { useCallback, useEffect, useMemo, useState } from 'react'
import { fechaHora, fechaCorta } from '../../lib/fechas'
import { Ban, CalendarClock, Infinity as InfinityIcon, Plus, ShieldPlus, Zap } from 'lucide-react'
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
          {p.alcance === ALCANCE.temporal && p.expiraEn && (
            <span className="text-xs text-ink-soft">
              hasta {fechaHora(p.expiraEn)}
            </span>
          )}
        </span>
      ),
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
                {usuario && !usuario.rutaId && ' Esta persona todavía no tiene ruta asignada (se asigna en Usuarios).'}
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
          onCerrar={() => setAbierto(false)}
          onConcedido={async () => {
            setAbierto(false)
            await cargar()
            toast.exito('Permiso concedido')
          }}
          usuarioId={usuarioId}
        />
      )}

      {dialogo}
    </PageSection>
  )
}

/** Elegir pantalla, acción y hasta cuándo vale. */
function ModalConceder({
  usuario,
  usuarioId,
  catalogo,
  onCerrar,
  onConcedido,
}: {
  usuario: UsuarioResponse | null
  usuarioId: number
  catalogo: SubmoduloCatalogo[]
  onCerrar: () => void
  onConcedido: () => Promise<void>
}) {
  const [submodulo, setSubmodulo] = useState('')
  const [accion, setAccion] = useState('')
  const [alcance, setAlcance] = useState<Alcance>(ALCANCE.unaVez)
  const [expiraEn, setExpiraEn] = useState('')
  const [motivo, setMotivo] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  const acciones = useMemo(
    () => catalogo.find((s) => s.submodulo === submodulo)?.acciones ?? [],
    [catalogo, submodulo],
  )

  // Al cambiar de pantalla la accion elegida puede ya no existir en ella.
  useEffect(() => {
    if (accion && !acciones.includes(accion as never)) setAccion('')
  }, [acciones, accion])

  const guardar = async () => {
    setGuardando(true)
    setError('')
    try {
      await permisoApi.conceder({
        usuarioId,
        submodulo,
        accion,
        alcance,
        // El input da hora local; el backend guarda en UTC.
        expiraEn: alcance === ALCANCE.temporal ? new Date(expiraEn).toISOString() : null,
        motivo: motivo.trim() || null,
      })
      await onConcedido()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos conceder el permiso.')
    } finally {
      setGuardando(false)
    }
  }

  const listo =
    submodulo !== '' && accion !== '' && (alcance !== ALCANCE.temporal || expiraEn !== '')

  return (
    <Modal
      open
      onClose={onCerrar}
      title={`Conceder un permiso a ${usuario?.nombre ?? ''}`}
      size="md"
      footer={
        <>
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

        <Desplegable
          label="Pantalla"
          value={submodulo}
          onChange={(v) => setSubmodulo(String(v))}
          placeholder="Elige una pantalla"
          options={catalogo.map((s) => ({ value: s.submodulo, label: nombrePantalla(s.submodulo) }))}
        />

        <Desplegable
          label="Acción"
          value={accion}
          onChange={(v) => setAccion(String(v))}
          disabled={submodulo === ''}
          placeholder="Elige una acción"
          options={acciones.map((a) => ({ value: a, label: ACCION_LABEL[a] ?? a }))}
        />

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
            {alcance === ALCANCE.unaVez &&
              'Se gasta al usarlo una vez. Si la operación falla, no se gasta.'}
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
            placeholder="Anular la NV-0042 que emitió con el cliente equivocado"
            className="w-full rounded-field border border-line px-3 py-2 text-sm"
          />
        </label>
      </div>
    </Modal>
  )
}
