import { useCallback, useEffect, useState } from 'react'
import {
  Ban,
  Calculator,
  ChevronDown,
  ChevronRight,
  HandCoins,
  Pencil,
  Plus,
  Receipt,
  Scale,
  Tags,
  Trash2,
  Wallet,
} from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Input,
  ListPage,
  Modal,
  PageHeader,
  RowAction,
  StatCard,
  Tabs,
  useConfirmacion,
} from '../../components/ui'
import type { ConsultaTabla, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { arqueoApi, motivoGastoApi } from './arqueoApi'
import type {
  ArqueoCajaResponse,
  CuadrePendienteResponse,
  DeudaUsuarioResponse,
  EstadoCuadre,
  MotivoGastoResponse,
} from './arqueoApi'
import { CuadrarCajaModal } from './CuadrarCajaModal'

type Pestana = 'cuadres' | 'registrados' | 'deudas' | 'motivos'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

/** Solo la parte de fecha: el backend devuelve el día con hora en cero. */
const soloFecha = (iso: string) => iso.slice(0, 10)

const fechaCorta = (iso: string) =>
  new Date(`${soloFecha(iso)}T00:00:00`).toLocaleDateString('es-PE')

function desplazarDias(dias: number) {
  const d = new Date()
  d.setDate(d.getDate() + dias)
  return d.toISOString().slice(0, 10)
}

const ETIQUETA_ESTADO: Record<EstadoCuadre, string> = {
  pendiente: 'Pendiente',
  cuadrado: 'Cuadrado',
  conDiferencia: 'Con diferencia',
  anulado: 'Anulado',
}

const TONO_ESTADO = {
  pendiente: 'warning',
  cuadrado: 'success',
  conDiferencia: 'danger',
  anulado: 'neutral',
} as const

/** A quién y por qué día se está cuadrando. */
interface Cuadrando {
  fecha: string
  usuarioId: number
  usuario: string
}

/**
 * El cuadre del reparto, por día y por persona.
 *
 * No es un cierre global de caja: quien salió a cobrar declara qué trae —
 * efectivo contado, gastos de la ruta y los Yape que dice haber recibido— y el
 * sistema le pone enfrente, cobro a cobro, lo que los documentos dicen que
 * cobró. Lo que falta queda como deuda suya hasta que se le descuente.
 */
export function ArqueoDiarioPage() {
  const { puede } = usePermisos()
  const [pestana, setPestana] = useState<Pestana>('cuadres')

  const [desde, setDesde] = useState(desplazarDias(-1))
  const [hasta, setHasta] = useState(desplazarDias(0))
  const [cuadres, setCuadres] = useState<CuadrePendienteResponse[]>([])
  const [cargandoCuadres, setCargandoCuadres] = useState(true)

  const [registrados, setRegistrados] = useState<ArqueoCajaResponse[]>([])
  const [consulta, setConsulta] = useState<ConsultaTabla | null>(null)
  const [totalRegistrados, setTotalRegistrados] = useState(0)
  const [cargandoRegistrados, setCargandoRegistrados] = useState(true)

  const [deudas, setDeudas] = useState<DeudaUsuarioResponse[]>([])
  const [motivos, setMotivos] = useState<MotivoGastoResponse[]>([])

  const [error, setError] = useState('')
  const [cuadrando, setCuadrando] = useState<Cuadrando | null>(null)
  const { confirmar, dialogo } = useConfirmacion()

  const cargarCuadres = useCallback(async (inicio: string, fin: string) => {
    setCargandoCuadres(true)
    try {
      setCuadres(await arqueoApi.cuadres(inicio, fin))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los cobros del período.')
    } finally {
      setCargandoCuadres(false)
    }
  }, [])

  /*
   * El rango sale del filtro de Fecha del panel, no de un bloque aparte: los
   * filtros de una tabla se ponen todos en el mismo sitio, y tener la fecha
   * fuera obligaba a buscarla en un lado y el resto en otro.
   *
   * Es el unico filtro que viaja al backend, porque decide QUE dias se traen;
   * usuario y estado se aplican sobre lo ya traido.
   */
  const aplicarConsultaCuadres = useCallback(
    (q: ConsultaTabla) => {
      const fecha = q.filtros.find((f) => f.columna === 'fecha')
      const inicio = fecha?.valor || desplazarDias(-1)
      const fin = fecha?.valorHasta || fecha?.valor || desplazarDias(0)

      if (inicio === desde && fin === hasta) return

      setDesde(inicio)
      setHasta(fin)
      void cargarCuadres(inicio, fin)
    },
    [cargarCuadres, desde, hasta],
  )

  const cargarRegistrados = useCallback(async (q: ConsultaTabla) => {
    setCargandoRegistrados(true)
    try {
      const pagina = await arqueoApi.listar(q)
      setRegistrados(pagina.items)
      setTotalRegistrados(pagina.total)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los cuadres registrados.')
    } finally {
      setCargandoRegistrados(false)
    }
  }, [])

  const cargarApoyo = useCallback(async () => {
    try {
      const [d, m] = await Promise.all([arqueoApi.deudas(), motivoGastoApi.getAll()])
      setDeudas(d)
      setMotivos(m)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar deudas y motivos.')
    }
  }, [])

  const recargarTodo = useCallback(async () => {
    await Promise.all([
      cargarCuadres(desde, hasta),
      consulta ? cargarRegistrados(consulta) : Promise.resolve(),
      cargarApoyo(),
    ])
  }, [cargarCuadres, cargarRegistrados, cargarApoyo, consulta, desde, hasta])

  // La primera carga usa el rango por defecto; a partir de ahi manda el filtro.
  useEffect(() => {
    void cargarCuadres(desplazarDias(-1), desplazarDias(0))
  }, [cargarCuadres])

  useEffect(() => {
    void cargarApoyo()
  }, [cargarApoyo])

  useRealtime('arqueo', recargarTodo)

  const anular = (id: number, quien: string) =>
    confirmar({
      titulo: `Anular el cuadre de ${quien}`,
      mensaje:
        'El cuadre deja de contar y su faltante deja de reclamarse, pero no se borra: queda como constancia de lo que se declaró.',
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await arqueoApi.anular(id)
          await recargarTodo()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos anular el cuadre.')
        }
      },
    })

  const cabecera = (
    <Tabs
      className="mb-5"
      active={pestana}
      onChange={(id) => setPestana(id as Pestana)}
      items={[
        { id: 'cuadres', label: 'Cuadres', icon: <Scale size={15} />, badge: cuadres.length },
        { id: 'registrados', label: 'Registrados', icon: <Receipt size={15} />, badge: totalRegistrados },
        { id: 'deudas', label: 'Deudas', icon: <Wallet size={15} />, badge: deudas.length },
        { id: 'motivos', label: 'Motivos de gasto', icon: <Tags size={15} />, badge: motivos.length },
      ]}
    />
  )

  const modal = cuadrando && (
    <CuadrarCajaModal
      open
      fecha={cuadrando.fecha}
      usuarioId={cuadrando.usuarioId}
      usuario={cuadrando.usuario}
      onClose={() => setCuadrando(null)}
      onGuardado={recargarTodo}
    />
  )

  if (pestana === 'deudas') {
    return (
      <>
        {cabecera}
        <DeudasPanel
          deudas={deudas}
          error={error}
          onError={setError}
          onRecargar={recargarTodo}
        />
        {modal}
      </>
    )
  }

  if (pestana === 'motivos') {
    return (
      <>
        {cabecera}
        <MotivosGastoTabla motivos={motivos} onRecargar={cargarApoyo} />
        {modal}
      </>
    )
  }

  if (pestana === 'registrados') {
    const columns: DataTableColumn<ArqueoCajaResponse>[] = [
      { key: 'fecha', label: 'Fecha', filterType: 'date', render: (row) => fechaCorta(row.fecha) },
      { key: 'usuario', label: 'Usuario' },
      // Los importes quedan fuera del panel: solo hay buscador de texto y "9"
      // contra "S/ 9.00" no encuentra lo que la persona espera.
      {
        key: 'totalEfectivoReal',
        label: 'Efectivo real',
        align: 'right',
        filterable: false,
        render: (row) => soles(row.totalEfectivoReal),
      },
      {
        key: 'totalDigitalReal',
        label: 'Digital real',
        align: 'right',
        filterable: false,
        render: (row) => soles(row.totalDigitalReal),
      },
      {
        key: 'faltante',
        label: 'Faltante',
        align: 'right',
        filterable: false,
        value: (row) => row.faltante,
        render: (row) =>
          row.faltante > 0 ? (
            <Badge tone="danger">{soles(row.faltante)}</Badge>
          ) : (
            <span className="text-ink-soft">—</span>
          ),
      },
      {
        key: 'sobrante',
        label: 'Sobrante',
        align: 'right',
        filterable: false,
        value: (row) => row.sobrante,
        render: (row) =>
          row.sobrante > 0 ? (
            <Badge tone="warning">{soles(row.sobrante)}</Badge>
          ) : (
            <span className="text-ink-soft">—</span>
          ),
      },
      {
        key: 'estado',
        label: 'Estado',
        filterType: 'select',
        filterOptions: [
          { value: 'cuadrado', label: 'Cuadrado' },
          { value: 'anulado', label: 'Anulado' },
        ],
        render: (row) => (
          <Badge tone={row.estado === 'anulado' ? 'neutral' : 'success'}>
            {row.estado === 'anulado' ? 'Anulado' : 'Cuadrado'}
          </Badge>
        ),
      },
    ]

    return (
      <>
        {cabecera}
        <ListPage
          icon={<Receipt size={20} />}
          title="Cuadres registrados"
          description="El historial de lo que cada persona declaró al volver de la ruta."
          alert={error ? <Alert>{error}</Alert> : undefined}
          columns={columns}
          rows={registrados}
          servidor={{
            total: totalRegistrados,
            cargando: cargandoRegistrados,
            onConsulta: (q) => {
              setConsulta(q)
              void cargarRegistrados(q)
            },
          }}
          cardIcon={Receipt}
          searchPlaceholder="Buscar por usuario..."
          empty={cargandoRegistrados ? 'Cargando cuadres...' : 'Todavía no se registró ningún cuadre.'}
          rowActions={(row) => (
            <>
              {puede('finanzas.arqueo', 'editar') && (
                <RowAction
                  label={`Editar el cuadre de ${row.usuario}`}
                  disabled={row.estado === 'anulado'}
                  disabledReason="El cuadre está anulado"
                  onClick={() =>
                    setCuadrando({
                      fecha: soloFecha(row.fecha),
                      usuarioId: row.usuarioId,
                      usuario: row.usuario,
                    })
                  }
                >
                  <Pencil size={15} />
                </RowAction>
              )}
              {puede('finanzas.arqueo', 'anular') && (
                <RowAction
                  label={`Anular el cuadre de ${row.usuario}`}
                  tone="danger"
                  disabled={row.estado === 'anulado'}
                  disabledReason="Ya está anulado"
                  onClick={() => anular(row.id, row.usuario)}
                >
                  <Ban size={15} />
                </RowAction>
              )}
            </>
          )}
        >
          {modal}
          {dialogo}
        </ListPage>
      </>
    )
  }

  // --- Pestaña Cuadres ---

  const pendientes = cuadres.filter((c) => c.estado === 'pendiente')
  const conDiferencia = cuadres.filter((c) => c.estado === 'conDiferencia')
  const efectivoPeriodo = cuadres.reduce((s, c) => s + c.efectivo, 0)

  const columns: DataTableColumn<CuadrePendienteResponse>[] = [
    {
      key: 'fecha',
      label: 'Fecha',
      filterType: 'date',
      // El filtro de rango compara en epoch, no en texto: sin esto la tabla
      // descartaba en memoria filas que el servidor sí había traído y salía
      // "sin registros" con datos cargados.
      value: (row) => new Date(row.fecha).getTime(),
      render: (row) => fechaCorta(row.fecha),
    },
    { key: 'usuario', label: 'Usuario' },
    /*
     * Los importes no entran al panel de filtros: el unico control que hay es
     * un buscador de texto, y "9" contra "S/ 9.00" no encuentra lo que la
     * persona espera. Para acotar por dinero esta el rango de fechas y el
     * estado, que es como se busca de verdad ("quien no cuadro esta semana").
     */
    {
      key: 'efectivo',
      label: 'Efectivo',
      align: 'right',
      filterable: false,
      render: (row) => soles(row.efectivo),
    },
    {
      key: 'bancos',
      label: 'Bancos',
      align: 'right',
      filterable: false,
      render: (row) => soles(row.bancos),
    },
    {
      key: 'total',
      label: 'Total',
      align: 'right',
      filterable: false,
      render: (row) => <span className="font-semibold">{soles(row.total)}</span>,
    },
    {
      key: 'diferenciaEfectivo',
      label: 'Diferencia Efectivo',
      align: 'right',
      filterable: false,
      value: (row) => row.diferenciaEfectivo ?? 0,
      render: (row) =>
        row.diferenciaEfectivo == null ? (
          <span className="text-ink-soft">—</span>
        ) : (
          <Badge
            tone={
              row.diferenciaEfectivo === 0
                ? 'success'
                : row.diferenciaEfectivo > 0
                  ? 'neutral'
                  : 'danger'
            }
          >
            {row.diferenciaEfectivo > 0 ? '+' : ''}
            {soles(row.diferenciaEfectivo)}
          </Badge>
        ),
    },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'pendiente', label: 'Pendiente' },
        { value: 'cuadrado', label: 'Cuadrado' },
        { value: 'conDiferencia', label: 'Con diferencia' },
        { value: 'anulado', label: 'Anulado' },
      ],
      value: (row) => ETIQUETA_ESTADO[row.estado],
      render: (row) => <Badge tone={TONO_ESTADO[row.estado]}>{ETIQUETA_ESTADO[row.estado]}</Badge>,
    },
  ]

  return (
    <>
      {cabecera}
      <ListPage
        icon={<Calculator size={20} />}
        title="Arqueo de caja"
        description="Quién cobró qué en la ruta y cuánto trajo de vuelta, día por día."
        alert={error ? <Alert>{error}</Alert> : undefined}
        stats={
          <>
            <StatCard
              label="Por cuadrar"
              value={String(pendientes.length)}
              icon={<Scale size={18} />}
              tono={pendientes.length > 0 ? 'warning' : 'success'}
              hint="personas sin declarar"
            />
            <StatCard
              label="Con diferencia"
              value={String(conDiferencia.length)}
              icon={<Ban size={18} />}
              tono={conDiferencia.length > 0 ? 'danger' : 'neutral'}
            />
            <StatCard
              label="Efectivo del período"
              value={soles(efectivoPeriodo)}
              icon={<HandCoins size={18} />}
              tono="success"
            />
          </>
        }
        columns={columns}
        rows={cuadres}
        onConsulta={aplicarConsultaCuadres}
        cardIcon={Calculator}
        searchPlaceholder="Buscar por usuario..."
        empty={
          cargandoCuadres
            ? 'Cargando cobros...'
            : 'Nadie cobró nada en este período. Cambia el rango en Filtros.'
        }
        rowActions={(row) =>
          puede('finanzas.arqueo', row.arqueoId ? 'editar' : 'crear') ? (
            <Button
              variant="ghost"
              onClick={() =>
                setCuadrando({
                  fecha: soloFecha(row.fecha),
                  usuarioId: row.usuarioId,
                  usuario: row.usuario,
                })
              }
            >
              {row.arqueoId ? 'Corregir' : 'Cuadrar'}
            </Button>
          ) : null
        }
      >
        {modal}
        {dialogo}
      </ListPage>
    </>
  )
}

/** Lo que cada persona debe por faltantes, con el detalle de qué día fue. */
function DeudasPanel({
  deudas,
  error,
  onError,
  onRecargar,
}: {
  deudas: DeudaUsuarioResponse[]
  error: string
  onError: (mensaje: string) => void
  onRecargar: () => Promise<void>
}) {
  const { puede } = usePermisos()
  const [abierto, setAbierto] = useState<number | null>(null)
  const { confirmar, dialogo } = useConfirmacion()

  const saldar = (arqueo: ArqueoCajaResponse) =>
    confirmar({
      titulo: `Descontar ${soles(arqueo.faltante)} a ${arqueo.usuario}`,
      mensaje:
        'Marca que el faltante del ' +
        fechaCorta(arqueo.fecha) +
        ' ya se le descontó o lo repuso. Deja de contarse en su deuda.',
      confirmar: 'Marcar como descontado',
      tono: 'pregunta',
      accion: async () => {
        onError('')
        try {
          await arqueoApi.saldar(arqueo.id)
          await onRecargar()
        } catch (e) {
          onError(e instanceof ApiError ? e.message : 'No pudimos marcar el faltante.')
        }
      },
    })

  const total = deudas.reduce((s, d) => s + d.pendiente, 0)

  return (
    <div className="space-y-5">
      <PageHeader
        icon={<Wallet size={20} />}
        title="Deudas por faltantes"
        description="Lo que cada persona debe reponer, del día en que faltó el dinero."
      />

      {error && <Alert>{error}</Alert>}

      <StatCard
        label="Total por cobrar"
        value={soles(total)}
        icon={<Wallet size={18} />}
        tono={total > 0 ? 'danger' : 'success'}
        hint={`${deudas.length} persona(s)`}
      />

      {deudas.length === 0 ? (
        <p className="rounded-panel border border-line bg-white px-3 py-8 text-center text-sm text-ink-soft">
          Nadie debe nada: todos los cuadres cerraron sin faltante.
        </p>
      ) : (
        <div className="space-y-3">
          {deudas.map((d) => (
            <div key={d.usuarioId} className="overflow-hidden rounded-panel border border-line bg-white">
              <button
                type="button"
                onClick={() => setAbierto((v) => (v === d.usuarioId ? null : d.usuarioId))}
                className="flex w-full cursor-pointer items-center justify-between gap-3 px-4 py-3 text-left transition-colors hover:bg-slate-50"
              >
                <span className="flex min-w-0 items-center gap-2">
                  {abierto === d.usuarioId ? (
                    <ChevronDown size={16} className="shrink-0 text-ink-soft" />
                  ) : (
                    <ChevronRight size={16} className="shrink-0 text-ink-soft" />
                  )}
                  <span className="min-w-0">
                    <span className="block truncate text-sm font-semibold text-ink">{d.usuario}</span>
                    <span className="block text-[11px] text-ink-soft">
                      {d.dias} día(s) con faltante · {soles(d.saldado)} ya descontado
                    </span>
                  </span>
                </span>
                <Badge tone="danger">{soles(d.pendiente)}</Badge>
              </button>

              {abierto === d.usuarioId && (
                <div className="border-t border-line">
                  {d.detalle.map((a) => (
                    <div
                      key={a.id}
                      className="flex items-center justify-between gap-3 border-b border-line px-4 py-2.5 last:border-b-0"
                    >
                      <div className="min-w-0">
                        <p className="text-[13px] text-ink">{fechaCorta(a.fecha)}</p>
                        <p className="truncate text-[11px] text-ink-soft">
                          Debía traer {soles(a.efectivoSistema + a.bancosSistema)} · trajo{' '}
                          {soles(a.totalEfectivoReal + a.totalDigitalReal)}
                        </p>
                      </div>
                      <div className="flex shrink-0 items-center gap-3">
                        <span className="text-sm font-semibold text-red-600 tabular-nums">
                          {soles(a.faltante)}
                        </span>
                        {puede('finanzas.arqueo', 'cobrar') && (
                          <Button variant="secondary" size="sm" onClick={() => saldar(a)}>
                            Marcar como descontado
                          </Button>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {dialogo}
    </div>
  )
}

/** Pasaje, combustible, menú: en qué se puede gastar el dinero de la ruta. */
function MotivosGastoTabla({
  motivos,
  onRecargar,
}: {
  motivos: MotivoGastoResponse[]
  onRecargar: () => Promise<void>
}) {
  const { puede } = usePermisos()
  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<MotivoGastoResponse | null>(null)
  const [form, setForm] = useState({ nombre: '', descripcion: '', activo: true })
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')
  const [error, setError] = useState('')
  const { confirmar, dialogo } = useConfirmacion()

  const abrirNuevo = () => {
    setEditando(null)
    setForm({ nombre: '', descripcion: '', activo: true })
    setErrorForm('')
    setAbierto(true)
  }

  const abrirEdicion = (motivo: MotivoGastoResponse) => {
    setEditando(motivo)
    setForm({ nombre: motivo.nombre, descripcion: motivo.descripcion ?? '', activo: motivo.activo })
    setErrorForm('')
    setAbierto(true)
  }

  const guardar = async () => {
    if (!form.nombre.trim()) return setErrorForm('Ingresa el nombre del motivo.')

    setGuardando(true)
    try {
      const cuerpo = {
        nombre: form.nombre.trim(),
        descripcion: form.descripcion.trim() || null,
        activo: form.activo,
      }
      if (editando) await motivoGastoApi.update(editando.id, cuerpo)
      else await motivoGastoApi.create(cuerpo)

      setAbierto(false)
      await onRecargar()
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos guardar el motivo.')
    } finally {
      setGuardando(false)
    }
  }

  const eliminar = (motivo: MotivoGastoResponse) =>
    confirmar({
      titulo: `Eliminar ${motivo.nombre}`,
      mensaje:
        motivo.usos > 0
          ? `Se usó en ${motivo.usos} gasto(s) ya registrado(s), así que no se podrá eliminar. Desactívalo en su lugar.`
          : 'Se borra definitivamente.',
      confirmar: 'Eliminar',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await motivoGastoApi.remove(motivo.id)
          await onRecargar()
        } catch (e) {
          // El 409 del backend explica en cuántos gastos se usó: se muestra tal
          // cual, que es más útil que un "no se pudo eliminar".
          setError(e instanceof ApiError ? e.message : 'No pudimos eliminar el motivo.')
        }
      },
    })

  const columns: DataTableColumn<MotivoGastoResponse>[] = [
    { key: 'nombre', label: 'Nombre' },
    {
      key: 'descripcion',
      label: 'Descripción',
      render: (row) => row.descripcion ?? <span className="text-ink-soft">—</span>,
    },
    // Un contador no se busca por texto: no hay control numerico en el panel.
    { key: 'usos', label: 'En uso', align: 'right', filterable: false },
    {
      key: 'activo',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'Activo', label: 'Activo' },
        { value: 'Inactivo', label: 'Inactivo' },
      ],
      value: (row) => (row.activo ? 'Activo' : 'Inactivo'),
      render: (row) => (
        <Badge tone={row.activo ? 'success' : 'neutral'}>{row.activo ? 'Activo' : 'Inactivo'}</Badge>
      ),
    },
  ]

  return (
    <ListPage
      icon={<Tags size={20} />}
      title="Motivos de gasto"
      description="En qué se puede gastar el dinero de la ruta: pasaje, combustible, menú."
      actions={
        puede('finanzas.arqueo', 'crear') ? (
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nuevo motivo
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      columns={columns}
      rows={motivos}
      cardIcon={Tags}
      searchPlaceholder="Buscar motivo..."
      empty="Todavía no hay motivos de gasto."
      rowActions={(row) => (
        <>
          {puede('finanzas.arqueo', 'editar') && (
            <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)}>
              <Pencil size={15} />
            </RowAction>
          )}
          {puede('finanzas.arqueo', 'eliminar') && (
            <RowAction label={`Eliminar ${row.nombre}`} tone="danger" onClick={() => eliminar(row)}>
              <Trash2 size={15} />
            </RowAction>
          )}
        </>
      )}
    >
      <Modal
        open={abierto}
        size="sm"
        title={editando ? `Editar ${editando.nombre}` : 'Nuevo motivo de gasto'}
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Crear motivo'}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {errorForm && <Alert>{errorForm}</Alert>}

          <Input
            label="Nombre"
            placeholder="Combustible"
            value={form.nombre}
            onChange={(e) => setForm({ ...form, nombre: e.target.value })}
          />

          <Input
            label="Descripción"
            optional
            placeholder="Petróleo y gasolina de la camioneta"
            value={form.descripcion}
            onChange={(e) => setForm({ ...form, descripcion: e.target.value })}
          />

          <label className="flex items-center gap-2 text-sm text-ink-muted">
            <input
              type="checkbox"
              checked={form.activo}
              onChange={(e) => setForm({ ...form, activo: e.target.checked })}
            />
            Activo (se ofrece al declarar gastos)
          </label>
        </div>
      </Modal>

      {dialogo}
    </ListPage>
  )
}
