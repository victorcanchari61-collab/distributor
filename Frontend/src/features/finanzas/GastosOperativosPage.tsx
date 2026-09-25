import { useCallback, useEffect, useState } from 'react'
import {
  AlertTriangle,
  Ban,
  CalendarClock,
  Coins,
  Pencil,
  Plus,
  Receipt,
  Repeat,
  Tags,
  Trash2,
} from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Checkbox,
  Desplegable,
  Input,
  ListPage,
  Modal,
  RowAction,
  StatCard,
  Tabs,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { desplazarDias, fechaCorta, hoyLocal } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { cuentaFinancieraApi } from './cuentaFinancieraApi'
import type { CuentaFinancieraResponse } from './cuentaFinancieraApi'
import { gastoOperativoApi, ORIGENES, origenLabel } from './gastoOperativoApi'
import type {
  CategoriaMovimientoResponse,
  GastoPendienteResponse,
  GastoRecurrenteResponse,
  MovimientoOperativoResponse,
  OrigenMovimiento,
  TipoMovimientoOperativo,
} from './gastoOperativoApi'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

type Pestana = 'pendientes' | 'recurrentes' | 'movimientos' | 'categorias'

/**
 * Lo que entra o sale del negocio sin ser una venta ni una compra: planilla,
 * alquiler, servicios, aportes de capital, retiros. Cada movimiento lleva una
 * categoría que dice si es operativo (del giro del negocio) o no. Lo mensual
 * (luz, agua, alquiler) se define una vez como plantilla recurrente.
 */
export function GastosOperativosPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const [pestana, setPestana] = useState<Pestana>('pendientes')

  const [pendientes, setPendientes] = useState<GastoPendienteResponse[]>([])
  const [recurrentes, setRecurrentes] = useState<GastoRecurrenteResponse[]>([])
  const [movimientos, setMovimientos] = useState<MovimientoOperativoResponse[]>([])
  const [motivos, setMotivos] = useState<CategoriaMovimientoResponse[]>([])
  const [cuentas, setCuentas] = useState<CuentaFinancieraResponse[]>([])

  const [desde, setDesde] = useState(desplazarDias(-30))
  const [hasta, setHasta] = useState(hoyLocal())
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [pagando, setPagando] = useState<GastoPendienteResponse | null>(null)
  const [nuevoAbierto, setNuevoAbierto] = useState(false)
  const [recurrenteAbierto, setRecurrenteAbierto] = useState(false)
  const [editandoRecurrente, setEditandoRecurrente] = useState<GastoRecurrenteResponse | null>(null)

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [p, r, m, mot, cta] = await Promise.all([
        gastoOperativoApi.getPendientes(),
        gastoOperativoApi.getRecurrentes(),
        gastoOperativoApi.listar(desde, hasta),
        gastoOperativoApi.getCategorias(),
        cuentaFinancieraApi.getAll(),
      ])
      setPendientes(p)
      setRecurrentes(r)
      setMovimientos(m)
      setMotivos(mot)
      setCuentas(cta.filter((c) => c.activo))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los gastos operativos.')
    } finally {
      setCargando(false)
    }
  }, [desde, hasta])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('gastosoperativos', cargar)

  const anular = (m: MovimientoOperativoResponse) =>
    confirmar({
      titulo: `Anular movimiento de ${m.motivoGasto}`,
      mensaje: `Revierte ${soles(m.monto)} en ${m.cuentaFinanciera}. No se puede deshacer.`,
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        try {
          await gastoOperativoApi.anular(m.id)
          await cargar()
          toast.exito('Movimiento anulado')
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos anular el movimiento.')
        }
      },
    })

  const cabecera = (
    <Tabs
      className="mb-5"
      active={pestana}
      onChange={(id) => setPestana(id as Pestana)}
      items={[
        { id: 'pendientes', label: 'Pendientes', icon: <AlertTriangle size={15} />, badge: pendientes.length },
        { id: 'recurrentes', label: 'Recurrentes', icon: <Repeat size={15} />, badge: recurrentes.length },
        { id: 'movimientos', label: 'Movimientos', icon: <Receipt size={15} />, badge: movimientos.length },
        { id: 'categorias', label: 'Categorías', icon: <Tags size={15} />, badge: motivos.length },
      ]}
    />
  )

  if (pestana === 'categorias') {
    return (
      <>
        {cabecera}
        <CategoriasTabla categorias={motivos} onRecargar={cargar} />
      </>
    )
  }

  if (pestana === 'recurrentes') {
    return (
      <>
        {cabecera}
        <RecurrentesTabla
          recurrentes={recurrentes}
          motivos={motivos}
          cuentas={cuentas}
          abierto={recurrenteAbierto}
          editando={editandoRecurrente}
          onAbrirNuevo={() => {
            setEditandoRecurrente(null)
            setRecurrenteAbierto(true)
          }}
          onAbrirEdicion={(r) => {
            setEditandoRecurrente(r)
            setRecurrenteAbierto(true)
          }}
          onCerrar={() => setRecurrenteAbierto(false)}
          onRecargar={cargar}
        />
      </>
    )
  }

  if (pestana === 'pendientes') {
    const vencidos = pendientes.filter((p) => p.vencido)

    return (
      <>
        {cabecera}
        <div className="space-y-5">
          {error && <Alert>{error}</Alert>}

          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <StatCard
              label="Vencidos"
              value={String(vencidos.length)}
              icon={<AlertTriangle size={18} />}
              tono={vencidos.length > 0 ? 'danger' : 'success'}
            />
            <StatCard label="Por vencer este mes" value={String(pendientes.length - vencidos.length)} icon={<CalendarClock size={18} />} tono="warning" />
          </div>

          {cargando ? (
            <p className="rounded-panel border border-line bg-white px-3 py-8 text-center text-sm text-ink-soft">Cargando...</p>
          ) : pendientes.length === 0 ? (
            <p className="rounded-panel border border-line bg-white px-3 py-8 text-center text-sm text-ink-soft">
              Nada pendiente este mes: todos los gastos recurrentes ya están pagados.
            </p>
          ) : (
            <div className="overflow-hidden rounded-panel border border-line bg-white">
              {pendientes.map((p) => (
                <div key={p.gastoRecurrenteId} className="flex items-center justify-between gap-3 border-b border-line px-4 py-3 last:border-b-0">
                  <div className="min-w-0">
                    <p className="flex items-center gap-2 text-sm font-semibold text-ink">
                      {p.nombre}
                      <Badge tone={p.vencido ? 'danger' : 'warning'}>
                        {p.vencido ? 'Vencido' : 'Por vencer'} · {fechaCorta(p.proximoVencimiento)}
                      </Badge>
                    </p>
                    <p className="text-xs text-ink-soft">{p.motivoGasto} · estimado {soles(p.montoEstimado)}</p>
                  </div>
                  {puede('finanzas.operativos', 'crear') && (
                    <Button size="sm" onClick={() => setPagando(p)}>
                      Pagar
                    </Button>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>

        {pagando && (
          <PagarPendienteModal
            pendiente={pagando}
            cuentas={cuentas}
            onClose={() => setPagando(null)}
            onGuardado={async () => {
              setPagando(null)
              await cargar()
              toast.exito('Gasto registrado')
            }}
          />
        )}
        {dialogo}
      </>
    )
  }

  // --- Movimientos ---

  const columns: DataTableColumn<MovimientoOperativoResponse>[] = [
    { key: 'fecha', label: 'Fecha', filterType: 'date', render: (row) => fechaCorta(row.fecha) },
    {
      key: 'tipo',
      label: 'Tipo',
      filterType: 'select',
      filterOptions: [
        { value: 'INGRESO', label: 'Ingreso' },
        { value: 'EGRESO', label: 'Egreso' },
      ],
      render: (row) => <Badge tone={row.tipo === 'INGRESO' ? 'success' : 'danger'}>{row.tipo === 'INGRESO' ? 'Ingreso' : 'Egreso'}</Badge>,
    },
    { key: 'motivoGasto', label: 'Categoría', filterable: false },
    {
      key: 'origen',
      label: 'Origen',
      filterType: 'select',
      filterOptions: ORIGENES,
      value: (row) => row.origen,
      render: (row) => <Badge tone={row.origen === 'OPERATIVO' ? 'sys' : 'warning'}>{origenLabel(row.origen)}</Badge>,
    },
    { key: 'cuentaFinanciera', label: 'Cuenta', filterable: false },
    {
      key: 'monto',
      label: 'Monto',
      align: 'right',
      filterable: false,
      render: (row) => (row.tipo === 'INGRESO' ? `+${soles(row.monto)}` : `-${soles(row.monto)}`),
    },
    { key: 'descripcion', label: 'Descripción', filterable: false, render: (row) => row.descripcion ?? '—' },
    {
      key: 'anulado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'Activo', label: 'Activo' },
        { value: 'Anulado', label: 'Anulado' },
      ],
      value: (row) => (row.anulado ? 'Anulado' : 'Activo'),
      render: (row) => <Badge tone={row.anulado ? 'neutral' : 'success'}>{row.anulado ? 'Anulado' : 'Activo'}</Badge>,
    },
  ]

  return (
    <>
      {cabecera}
      <ListPage
        icon={<Coins size={20} />}
        title="Ingresos y egresos"
        description="Lo que entra o sale a mano, fuera de ventas y compras. La categoría dice si es operativo o no operativo."
        actions={
          puede('finanzas.operativos', 'crear') ? (
            <Button size="sm" onClick={() => setNuevoAbierto(true)} iconRight={<Plus size={15} />}>
              Nuevo movimiento
            </Button>
          ) : undefined
        }
        alert={error ? <Alert>{error}</Alert> : undefined}
        columns={columns}
        rows={movimientos}
        onConsulta={(q) => {
          const fecha = q.filtros.find((f) => f.columna === 'fecha')
          setDesde(fecha?.valor || desplazarDias(-30))
          setHasta(fecha?.valorHasta || fecha?.valor || hoyLocal())
        }}
        cardIcon={Coins}
        searchPlaceholder="Buscar por categoría..."
        empty={cargando ? 'Cargando movimientos...' : 'No hay movimientos en este período.'}
        rowActions={(row) =>
          !row.anulado && puede('finanzas.operativos', 'anular') ? (
            <RowAction label="Anular" tone="danger" onClick={() => anular(row)}>
              <Ban size={15} />
            </RowAction>
          ) : null
        }
      >
        {nuevoAbierto && (
          <NuevoMovimientoModal
            cuentas={cuentas}
            motivos={motivos}
            onClose={() => setNuevoAbierto(false)}
            onGuardado={async () => {
              setNuevoAbierto(false)
              await cargar()
              toast.exito('Movimiento registrado')
            }}
          />
        )}
        {dialogo}
      </ListPage>
    </>
  )
}

/** Paga una plantilla pendiente: pre-llena categoría y cuenta, solo confirma el monto real. */
function PagarPendienteModal({
  pendiente,
  cuentas,
  onClose,
  onGuardado,
}: {
  pendiente: GastoPendienteResponse
  cuentas: CuentaFinancieraResponse[]
  onClose: () => void
  onGuardado: () => void | Promise<void>
}) {
  const [monto, setMonto] = useState(String(pendiente.montoEstimado))
  const [cuentaFinancieraId, setCuentaFinancieraId] = useState(pendiente.cuentaFinancieraSugeridaId ?? 0)
  const [fecha, setFecha] = useState(hoyLocal())
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  const guardar = async () => {
    const numero = Number(monto.replace(',', '.'))
    if (!Number.isFinite(numero) || numero <= 0) return setError('Ingresa un monto mayor a cero.')
    if (!cuentaFinancieraId) return setError('Elige de qué cuenta sale.')

    setGuardando(true)
    setError('')
    try {
      await gastoOperativoApi.crear({
        cuentaFinancieraId,
        tipo: 'EGRESO',
        motivoGastoId: pendiente.motivoGastoId,
        monto: numero,
        fecha,
        gastoRecurrenteId: pendiente.gastoRecurrenteId,
      })
      await onGuardado()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos registrar el pago.')
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal
      open
      size="sm"
      title={`Pagar ${pendiente.nombre}`}
      description={`Vence el ${fechaCorta(pendiente.proximoVencimiento)} · ${pendiente.motivoGasto}`}
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            Registrar pago
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        {error && <Alert>{error}</Alert>}
        <Desplegable
          label="Cuenta"
          value={cuentaFinancieraId}
          onChange={(v) => setCuentaFinancieraId(Number(v))}
          placeholder="De dónde sale"
          options={cuentas.map((c) => ({ value: c.id, label: c.nombre }))}
        />
        <Input label="Monto" type="number" step="0.01" value={monto} onChange={(e) => setMonto(e.target.value)} />
        <Input label="Fecha" type="date" value={fecha} onChange={(e) => setFecha(e.target.value)} />
      </div>
    </Modal>
  )
}

/** Un movimiento suelto: aporte de capital, préstamo recibido, o un gasto sin plantilla. */
function NuevoMovimientoModal({
  cuentas,
  motivos,
  onClose,
  onGuardado,
}: {
  cuentas: CuentaFinancieraResponse[]
  motivos: CategoriaMovimientoResponse[]
  onClose: () => void
  onGuardado: () => void | Promise<void>
}) {
  const [tipo, setTipo] = useState<TipoMovimientoOperativo>('EGRESO')
  const [cuentaFinancieraId, setCuentaFinancieraId] = useState(0)
  const [motivoGastoId, setMotivoGastoId] = useState(0)
  const [monto, setMonto] = useState('')
  const [fecha, setFecha] = useState(hoyLocal())
  const [descripcion, setDescripcion] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  const guardar = async () => {
    const numero = Number(monto.replace(',', '.'))
    if (!cuentaFinancieraId) return setError('Elige la cuenta.')
    if (!motivoGastoId) return setError('Elige la categoría.')
    if (!Number.isFinite(numero) || numero <= 0) return setError('Ingresa un monto mayor a cero.')

    setGuardando(true)
    setError('')
    try {
      await gastoOperativoApi.crear({
        cuentaFinancieraId,
        tipo,
        motivoGastoId,
        monto: numero,
        fecha,
        descripcion: descripcion.trim() || null,
      })
      await onGuardado()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos registrar el movimiento.')
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal
      open
      size="sm"
      title="Nuevo movimiento operativo"
      description="Un ingreso (aporte de capital, venta de un activo) o un egreso sin plantilla."
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            Registrar
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        {error && <Alert>{error}</Alert>}
        <Desplegable
          label="Tipo"
          value={tipo}
          onChange={(v) => {
            setTipo(v as TipoMovimientoOperativo)
            setMotivoGastoId(0)
          }}
          options={[
            { value: 'INGRESO', label: 'Ingreso' },
            { value: 'EGRESO', label: 'Egreso' },
          ]}
        />
        <Desplegable
          label="Cuenta"
          value={cuentaFinancieraId}
          onChange={(v) => setCuentaFinancieraId(Number(v))}
          placeholder="De dónde sale o a dónde entra"
          options={cuentas.map((c) => ({ value: c.id, label: c.nombre }))}
        />
        <Desplegable
          label="Categoría"
          value={motivoGastoId}
          onChange={(v) => setMotivoGastoId(Number(v))}
          placeholder="Elige una categoría"
          options={motivos
            .filter((m) => m.activo && m.tipo === tipo)
            .map((m) => ({ value: m.id, label: m.nombre, detalle: origenLabel(m.origen) }))}
        />
        <Input label="Monto" type="number" step="0.01" value={monto} onChange={(e) => setMonto(e.target.value)} />
        <Input label="Fecha" type="date" value={fecha} onChange={(e) => setFecha(e.target.value)} />
        <Input label="Descripción" optional value={descripcion} onChange={(e) => setDescripcion(e.target.value)} />
      </div>
    </Modal>
  )
}

/** Plantillas de gastos mensuales: alquiler, luz, agua, internet. */
function RecurrentesTabla({
  recurrentes,
  motivos,
  cuentas,
  abierto,
  editando,
  onAbrirNuevo,
  onAbrirEdicion,
  onCerrar,
  onRecargar,
}: {
  recurrentes: GastoRecurrenteResponse[]
  motivos: CategoriaMovimientoResponse[]
  cuentas: CuentaFinancieraResponse[]
  abierto: boolean
  editando: GastoRecurrenteResponse | null
  onAbrirNuevo: () => void
  onAbrirEdicion: (r: GastoRecurrenteResponse) => void
  onCerrar: () => void
  onRecargar: () => Promise<void>
}) {
  const { puede } = usePermisos()
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()
  const [form, setForm] = useState({
    nombre: '',
    motivoGastoId: 0,
    montoEstimado: '',
    diaVencimiento: '1',
    cuentaFinancieraSugeridaId: 0,
    activo: true,
  })
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!abierto) return
    setError('')
    if (editando) {
      setForm({
        nombre: editando.nombre,
        motivoGastoId: editando.motivoGastoId,
        montoEstimado: String(editando.montoEstimado),
        diaVencimiento: String(editando.diaVencimiento),
        cuentaFinancieraSugeridaId: editando.cuentaFinancieraSugeridaId ?? 0,
        activo: editando.activo,
      })
    } else {
      setForm({ nombre: '', motivoGastoId: 0, montoEstimado: '', diaVencimiento: '1', cuentaFinancieraSugeridaId: 0, activo: true })
    }
  }, [abierto, editando])

  const guardar = async () => {
    const monto = Number(form.montoEstimado.replace(',', '.'))
    const dia = Number(form.diaVencimiento)
    if (!form.nombre.trim()) return setError('Ponle un nombre.')
    if (!form.motivoGastoId) return setError('Elige la categoría.')
    if (!Number.isFinite(monto) || monto <= 0) return setError('El monto estimado tiene que ser mayor a cero.')
    if (!Number.isInteger(dia) || dia < 1 || dia > 31) return setError('El día de vencimiento va de 1 a 31.')

    setGuardando(true)
    setError('')
    try {
      const cuerpo = {
        nombre: form.nombre.trim(),
        motivoGastoId: form.motivoGastoId,
        montoEstimado: monto,
        diaVencimiento: dia,
        cuentaFinancieraSugeridaId: form.cuentaFinancieraSugeridaId || null,
        activo: form.activo,
      }
      if (editando) await gastoOperativoApi.actualizarRecurrente(editando.id, cuerpo)
      else await gastoOperativoApi.crearRecurrente(cuerpo)
      onCerrar()
      await onRecargar()
      toast.exito(editando ? 'Plantilla actualizada' : 'Plantilla creada')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos guardar la plantilla.')
    } finally {
      setGuardando(false)
    }
  }

  const eliminar = (r: GastoRecurrenteResponse) =>
    confirmar({
      titulo: `Eliminar ${r.nombre}`,
      mensaje: 'Se borra definitivamente. Si ya tiene pagos registrados, desactívala en vez de eliminarla.',
      confirmar: 'Eliminar',
      tono: 'danger',
      accion: async () => {
        try {
          await gastoOperativoApi.eliminarRecurrente(r.id)
          await onRecargar()
          toast.exito('Plantilla eliminada')
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos eliminar la plantilla.')
        }
      },
    })

  const columns: DataTableColumn<GastoRecurrenteResponse>[] = [
    { key: 'nombre', label: 'Nombre', filterable: false },
    { key: 'motivoGasto', label: 'Categoría', filterable: false },
    { key: 'montoEstimado', label: 'Monto estimado', align: 'right', filterable: false, render: (row) => soles(row.montoEstimado) },
    { key: 'diaVencimiento', label: 'Día de vencimiento', align: 'right', filterable: false },
    {
      key: 'activo',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'Activo', label: 'Activo' },
        { value: 'Inactivo', label: 'Inactivo' },
      ],
      value: (row) => (row.activo ? 'Activo' : 'Inactivo'),
      render: (row) => <Badge tone={row.activo ? 'success' : 'neutral'}>{row.activo ? 'Activo' : 'Inactivo'}</Badge>,
    },
  ]

  return (
    <ListPage
      icon={<Repeat size={20} />}
      title="Gastos recurrentes"
      description="Lo que se paga cada mes: alquiler, luz, agua, internet. Se define una vez y el sistema lo recuerda."
      actions={
        puede('finanzas.operativos', 'crear') ? (
          <Button size="sm" onClick={onAbrirNuevo} iconRight={<Plus size={15} />}>
            Nueva plantilla
          </Button>
        ) : undefined
      }
      columns={columns}
      rows={recurrentes}
      cardIcon={Repeat}
      searchPlaceholder="Buscar plantilla..."
      empty="Todavía no hay gastos recurrentes."
      rowActions={(row) => (
        <>
          {puede('finanzas.operativos', 'editar') && (
            <RowAction label={`Editar ${row.nombre}`} onClick={() => onAbrirEdicion(row)}>
              <Pencil size={15} />
            </RowAction>
          )}
          {puede('finanzas.operativos', 'eliminar') && (
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
        title={editando ? `Editar ${editando.nombre}` : 'Nueva plantilla recurrente'}
        onClose={onCerrar}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={onCerrar}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Crear plantilla'}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {error && <Alert>{error}</Alert>}
          <Input label="Nombre" placeholder="Alquiler local" value={form.nombre} onChange={(e) => setForm({ ...form, nombre: e.target.value })} />
          <Desplegable
            label="Categoría"
            value={form.motivoGastoId}
            onChange={(v) => setForm({ ...form, motivoGastoId: Number(v) })}
            placeholder="Elige una categoría"
            options={motivos
              .filter((m) => m.activo && m.tipo === 'EGRESO')
              .map((m) => ({ value: m.id, label: m.nombre, detalle: origenLabel(m.origen) }))}
          />
          <Input
            label="Monto estimado"
            type="number"
            step="0.01"
            value={form.montoEstimado}
            onChange={(e) => setForm({ ...form, montoEstimado: e.target.value })}
          />
          <Input
            label="Día de vencimiento"
            type="number"
            min={1}
            max={31}
            value={form.diaVencimiento}
            onChange={(e) => setForm({ ...form, diaVencimiento: e.target.value })}
          />
          <Desplegable
            label="Cuenta sugerida"
            optional
            value={form.cuentaFinancieraSugeridaId}
            onChange={(v) => setForm({ ...form, cuentaFinancieraSugeridaId: Number(v) })}
            placeholder="De dónde suele salir"
            options={cuentas.map((c) => ({ value: c.id, label: c.nombre }))}
          />
          {editando && (
            <Checkbox
              label="Activa (se recuerda cada mes)"
              checked={form.activo}
              onChange={(e) => setForm({ ...form, activo: e.target.checked })}
            />
          )}
        </div>
      </Modal>

      {dialogo}
    </ListPage>
  )
}

const TIPOS_CATEGORIA: { value: TipoMovimientoOperativo; label: string }[] = [
  { value: 'EGRESO', label: 'Egreso' },
  { value: 'INGRESO', label: 'Ingreso' },
]

const CATEGORIA_VACIA = {
  nombre: '',
  descripcion: '',
  tipo: 'EGRESO' as TipoMovimientoOperativo,
  origen: 'OPERATIVO' as OrigenMovimiento,
  activo: true,
}

/** El catálogo de categorías: con qué tipo de movimiento se usa cada una y si es operativa o no. */
function CategoriasTabla({
  categorias,
  onRecargar,
}: {
  categorias: CategoriaMovimientoResponse[]
  onRecargar: () => Promise<void>
}) {
  const { puede } = usePermisos()
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()
  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<CategoriaMovimientoResponse | null>(null)
  const [form, setForm] = useState(CATEGORIA_VACIA)
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  const abrir = (c: CategoriaMovimientoResponse | null) => {
    setEditando(c)
    setError('')
    setForm(
      c
        ? { nombre: c.nombre, descripcion: c.descripcion ?? '', tipo: c.tipo, origen: c.origen, activo: c.activo }
        : CATEGORIA_VACIA,
    )
    setAbierto(true)
  }

  const guardar = async () => {
    if (!form.nombre.trim()) return setError('Ponle un nombre.')

    setGuardando(true)
    setError('')
    try {
      const cuerpo = {
        nombre: form.nombre.trim(),
        descripcion: form.descripcion.trim() || null,
        tipo: form.tipo,
        origen: form.origen,
        activo: form.activo,
      }
      if (editando) await gastoOperativoApi.actualizarCategoria(editando.id, cuerpo)
      else await gastoOperativoApi.crearCategoria(cuerpo)
      setAbierto(false)
      await onRecargar()
      toast.exito(editando ? 'Categoría actualizada' : 'Categoría creada')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos guardar la categoría.')
    } finally {
      setGuardando(false)
    }
  }

  const eliminar = (c: CategoriaMovimientoResponse) =>
    confirmar({
      titulo: `Eliminar ${c.nombre}`,
      mensaje: 'Se borra definitivamente. Si ya se usó, desactívala en vez de eliminarla.',
      confirmar: 'Eliminar',
      tono: 'danger',
      accion: async () => {
        try {
          await gastoOperativoApi.eliminarCategoria(c.id)
          await onRecargar()
          toast.exito('Categoría eliminada')
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos eliminar la categoría.')
        }
      },
    })

  const columns: DataTableColumn<CategoriaMovimientoResponse>[] = [
    { key: 'nombre', label: 'Nombre', filterable: false },
    {
      key: 'tipo',
      label: 'Tipo',
      filterType: 'select',
      filterOptions: TIPOS_CATEGORIA,
      value: (row) => row.tipo,
      render: (row) => <Badge tone={row.tipo === 'INGRESO' ? 'success' : 'danger'}>{row.tipo === 'INGRESO' ? 'Ingreso' : 'Egreso'}</Badge>,
    },
    {
      key: 'origen',
      label: 'Origen',
      filterType: 'select',
      filterOptions: ORIGENES,
      value: (row) => row.origen,
      render: (row) => <Badge tone={row.origen === 'OPERATIVO' ? 'sys' : 'warning'}>{origenLabel(row.origen)}</Badge>,
    },
    { key: 'usos', label: 'Usos', align: 'right', filterable: false },
    {
      key: 'activo',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'Activo', label: 'Activo' },
        { value: 'Inactivo', label: 'Inactivo' },
      ],
      value: (row) => (row.activo ? 'Activo' : 'Inactivo'),
      render: (row) => <Badge tone={row.activo ? 'success' : 'neutral'}>{row.activo ? 'Activo' : 'Inactivo'}</Badge>,
    },
  ]

  return (
    <ListPage
      icon={<Tags size={20} />}
      title="Categorías"
      description="Con qué se clasifica cada ingreso o egreso. Operativo: del giro del negocio. No operativo: aportes, retiros, compra o venta de activos."
      actions={
        puede('finanzas.operativos', 'crear') ? (
          <Button size="sm" onClick={() => abrir(null)} iconRight={<Plus size={15} />}>
            Nueva categoría
          </Button>
        ) : undefined
      }
      columns={columns}
      rows={categorias}
      cardIcon={Tags}
      searchPlaceholder="Buscar categoría..."
      empty="Todavía no hay categorías."
      rowActions={(row) => (
        <>
          {puede('finanzas.operativos', 'editar') && (
            <RowAction label={`Editar ${row.nombre}`} onClick={() => abrir(row)}>
              <Pencil size={15} />
            </RowAction>
          )}
          {puede('finanzas.operativos', 'eliminar') && (
            <RowAction
              label={`Eliminar ${row.nombre}`}
              tone="danger"
              disabled={row.usos > 0}
              disabledReason="Ya se usó: desactívala en vez de eliminarla"
              onClick={() => eliminar(row)}
            >
              <Trash2 size={15} />
            </RowAction>
          )}
        </>
      )}
    >
      <Modal
        open={abierto}
        size="sm"
        title={editando ? `Editar ${editando.nombre}` : 'Nueva categoría'}
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Crear categoría'}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {error && <Alert>{error}</Alert>}
          <Input label="Nombre" placeholder="Planilla, Aporte de capital..." value={form.nombre} onChange={(e) => setForm({ ...form, nombre: e.target.value })} />
          <Desplegable
            label="Tipo"
            value={form.tipo}
            onChange={(v) => setForm({ ...form, tipo: v as TipoMovimientoOperativo })}
            options={TIPOS_CATEGORIA}
            disabled={!!editando && editando.usos > 0}
            hint={
              editando && editando.usos > 0 ? (
                <span className="text-xs text-ink-soft">Ya se usó: no cambia de tipo</span>
              ) : undefined
            }
          />
          <Desplegable
            label="Origen"
            value={form.origen}
            onChange={(v) => setForm({ ...form, origen: v as OrigenMovimiento })}
            options={ORIGENES}
          />
          <Input label="Descripción" optional value={form.descripcion} onChange={(e) => setForm({ ...form, descripcion: e.target.value })} />
          {editando && (
            <Checkbox label="Activa" checked={form.activo} onChange={(e) => setForm({ ...form, activo: e.target.checked })} />
          )}
        </div>
      </Modal>

      {dialogo}
    </ListPage>
  )
}
