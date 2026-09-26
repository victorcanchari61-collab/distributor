import { useCallback, useEffect, useState } from 'react'
import { Building2, CheckCircle2, CreditCard, History, Landmark, Plus, Scale, ShieldCheck, ShieldOff } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Desplegable,
  Input,
  ListPage,
  Modal,
  RowAction,
  StatCard,
  SysDataTable,
  Tabs,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { desplazarDias, fechaCorta, fechaHora, hoyLocal } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { bancoApi } from './bancoApi'
import type { BancoResponse } from './bancoApi'
import { BancosPage } from './BancosPage'
import { cuentaFinancieraApi, conciliacionBancariaApi } from './cuentaFinancieraApi'
import type {
  CuentaFinancieraResponse,
  MovimientoCuentaResponse,
  NaturalezaCuenta,
  ConciliacionBancariaResponse,
} from './cuentaFinancieraApi'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

const VACIO = {
  nombre: '',
  bancoId: 0,
  numeroCuenta: '',
  cci: '',
  titular: '',
  montoInicial: '',
}

type Pestana = 'bancos' | 'cuentas'

/**
 * Bancos (catálogo) y Cuentas Bancarias (las que sí tienen saldo real) son
 * cosas separadas: un banco puede tener varias cuentas. Ver docs/finanzas-tesoreria.md.
 */
export function CuentasFinancierasPage() {
  const [pestana, setPestana] = useState<Pestana>('bancos')

  const cabecera = (
    <Tabs
      className="mb-5"
      active={pestana}
      onChange={(id) => setPestana(id as Pestana)}
      items={[
        { id: 'bancos', label: 'Bancos', icon: <Landmark size={15} /> },
        { id: 'cuentas', label: 'Cuentas Bancarias', icon: <CreditCard size={15} /> },
      ]}
    />
  )

  return (
    <>
      {cabecera}
      {pestana === 'bancos' ? <BancosPage /> : <CuentasBancariasTab />}
    </>
  )
}

/**
 * Las cuentas que sí tienen saldo real: la Caja General (única, fija) y las
 * cuentas bancarias, cada una ligada a un Banco del catálogo. Un método de
 * pago (Efectivo, Yape, Transferencia) es solo un canal que apunta a una de
 * estas — la plata de verdad vive aquí.
 */
function CuentasBancariasTab() {
  const { puede } = usePermisos()
  const toast = useToast()
  const [cuentas, setCuentas] = useState<CuentaFinancieraResponse[]>([])
  const [bancos, setBancos] = useState<BancoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<CuentaFinancieraResponse | null>(null)
  const [form, setForm] = useState(VACIO)
  const [guardando, setGuardando] = useState(false)

  const [movimientosDe, setMovimientosDe] = useState<CuentaFinancieraResponse | null>(null)
  const [conciliarDe, setConciliarDe] = useState<CuentaFinancieraResponse | null>(null)

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      // Las cajas (Caja General y las de vendedores/repartidores) viven en
      // "Cajas": aquí solo las cuentas bancarias.
      const [todas, bcos] = await Promise.all([cuentaFinancieraApi.getAll(), bancoApi.getAll()])
      setCuentas(todas.filter((c) => c.naturaleza === 'BANCO'))
      setBancos(bcos)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las cuentas bancarias.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('cuentasfinancieras', cargar)
  useRealtime('bancos', cargar)

  const abrirNuevo = () => {
    setEditando(null)
    setForm(VACIO)
    setAbierto(true)
  }

  const abrirEdicion = (c: CuentaFinancieraResponse) => {
    setEditando(c)
    setForm({
      nombre: c.nombre,
      bancoId: c.bancoId ?? 0,
      numeroCuenta: c.numeroCuenta ?? '',
      cci: c.cci ?? '',
      titular: c.titular ?? '',
      montoInicial: '',
    })
    setAbierto(true)
  }

  const guardar = async () => {
    if (!form.nombre.trim()) return toast.error('Ponle un nombre a la cuenta.')
    if (!form.bancoId) return toast.error('Elige a qué banco pertenece.')
    if (!form.numeroCuenta.trim()) return toast.error('Indica el número de cuenta.')

    const montoInicial = form.montoInicial.trim() ? Number(form.montoInicial.replace(',', '.')) : 0
    if (!editando && (!Number.isFinite(montoInicial) || montoInicial < 0)) {
      return toast.error('El monto inicial no puede ser negativo.')
    }

    setGuardando(true)
    try {
      const cuerpo = {
        nombre: form.nombre.trim(),
        naturaleza: 'BANCO' as NaturalezaCuenta,
        bancoId: form.bancoId,
        numeroCuenta: form.numeroCuenta.trim() || null,
        cci: form.cci.trim() || null,
        titular: form.titular.trim() || null,
        // Solo cuenta al crear: ya creada, el saldo se mueve con movimientos.
        montoInicial: editando ? 0 : Math.round(montoInicial * 100) / 100,
        activo: editando?.activo ?? true,
      }
      if (editando) await cuentaFinancieraApi.update(editando.id, cuerpo)
      else await cuentaFinancieraApi.create(cuerpo)

      setAbierto(false)
      await cargar()
      toast.exito(editando ? 'Cuenta actualizada' : 'Cuenta creada')
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos guardar la cuenta.')
    } finally {
      setGuardando(false)
    }
  }

  const cambiarEstado = (c: CuentaFinancieraResponse) =>
    confirmar({
      titulo: `${c.activo ? 'Desactivar' : 'Activar'} ${c.nombre}`,
      mensaje: c.activo
        ? 'Deja de ofrecerse para enlazar métodos de pago nuevos. Los movimientos ya hechos se conservan.'
        : 'Vuelve a estar disponible.',
      confirmar: c.activo ? 'Desactivar' : 'Activar',
      tono: c.activo ? 'warning' : 'pregunta',
      accion: async () => {
        try {
          await cuentaFinancieraApi.update(c.id, {
            nombre: c.nombre,
            naturaleza: 'BANCO',
            bancoId: c.bancoId,
            numeroCuenta: c.numeroCuenta,
            cci: c.cci,
            titular: c.titular,
            activo: !c.activo,
          })
          await cargar()
          toast.exito(`${c.nombre} ${c.activo ? 'desactivada' : 'activada'}`)
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  const saldoTotal = cuentas.filter((c) => c.activo).reduce((s, c) => s + c.saldoActual, 0)

  const columns: DataTableColumn<CuentaFinancieraResponse>[] = [
    { key: 'nombre', label: 'Nombre', filterable: false },
    {
      key: 'banco',
      label: 'Banco',
      filterType: 'select',
      filterOptions: bancos.map((b) => ({ value: b.nombre, label: b.nombre })),
      render: (row) => row.banco ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'numeroCuenta',
      label: 'Número',
      filterable: false,
      render: (row) => row.numeroCuenta ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'saldoActual',
      label: 'Saldo',
      align: 'right',
      filterable: false,
      render: (row) => <span className="font-semibold">{soles(row.saldoActual)}</span>,
    },
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
      icon={<CreditCard size={20} />}
      title="Cuentas Bancarias"
      description="Las cuentas bancarias, cada una ligada a un banco del catálogo. Un método de pago solo apunta a una de estas."
      actions={
        puede('finanzas.bancos', 'crear') ? (
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nueva cuenta
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Saldo total" value={soles(saldoTotal)} icon={<Landmark size={18} />} tono="sys" />
          <StatCard label="Cuentas activas" value={String(cuentas.filter((c) => c.activo).length)} icon={<Building2 size={18} />} />
        </>
      }
      columns={columns}
      rows={cuentas}
      cardIcon={CreditCard}
      searchPlaceholder="Buscar cuenta..."
      empty={cargando ? 'Cargando cuentas...' : 'Todavía no hay cuentas registradas.'}
      rowActions={(row) => (
        <>
          <RowAction label={`Movimientos de ${row.nombre}`} tone="view" onClick={() => setMovimientosDe(row)}>
            <History size={15} />
          </RowAction>
          {puede('finanzas.bancos', 'crear') && (
            <RowAction label={`Conciliar ${row.nombre}`} onClick={() => setConciliarDe(row)}>
              <Scale size={15} />
            </RowAction>
          )}
          {puede('finanzas.bancos', 'editar') && (
            <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)}>
              <Building2 size={15} />
            </RowAction>
          )}
          {puede('finanzas.bancos', 'editar') && (
            <RowAction
              label={`${row.activo ? 'Desactivar' : 'Activar'} ${row.nombre}`}
              tone={row.activo ? 'warning' : 'success'}
              onClick={() => cambiarEstado(row)}
            >
              {row.activo ? <ShieldOff size={15} /> : <ShieldCheck size={15} />}
            </RowAction>
          )}
        </>
      )}
    >
      <Modal
        open={abierto}
        size="sm"
        title={editando ? `Editar ${editando.nombre}` : 'Nueva cuenta bancaria'}
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Crear cuenta'}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          <Desplegable
            label="Banco"
            value={form.bancoId}
            onChange={(v) => setForm({ ...form, bancoId: Number(v) })}
            placeholder="Elige el banco"
            options={bancos.filter((b) => b.activo).map((b) => ({ value: b.id, label: b.nombre }))}
          />
          <Input
            label="Nombre"
            placeholder="BCP Cuenta Corriente Soles"
            value={form.nombre}
            onChange={(e) => setForm({ ...form, nombre: e.target.value })}
          />
          <Input
            label="Número de cuenta"
            value={form.numeroCuenta}
            onChange={(e) => setForm({ ...form, numeroCuenta: e.target.value })}
          />
          <Input
            label="CCI"
            optional
            placeholder="Código de cuenta interbancario"
            value={form.cci}
            onChange={(e) => setForm({ ...form, cci: e.target.value })}
          />
          <Input
            label="Titular"
            optional
            value={form.titular}
            onChange={(e) => setForm({ ...form, titular: e.target.value })}
          />
          {!editando && (
            <Input
              label="Monto inicial"
              optional
              type="number"
              step="0.01"
              placeholder="0.00"
              value={form.montoInicial}
              onChange={(e) => setForm({ ...form, montoInicial: e.target.value })}
            />
          )}
        </div>
      </Modal>

      {movimientosDe && <MovimientosModal cuenta={movimientosDe} onClose={() => setMovimientosDe(null)} />}
      {conciliarDe && <ConciliarModal cuenta={conciliarDe} onClose={() => setConciliarDe(null)} />}

      {dialogo}
    </ListPage>
  )
}

function MovimientosModal({ cuenta, onClose }: { cuenta: CuentaFinancieraResponse; onClose: () => void }) {
  const [movimientos, setMovimientos] = useState<MovimientoCuentaResponse[]>([])
  const [cargando, setCargando] = useState(true)
  // Por rango, el último mes por defecto: una cuenta junta movimientos todos los días.
  const [desde, setDesde] = useState(desplazarDias(-30))
  const [hasta, setHasta] = useState(hoyLocal())
  const toast = useToast()

  useEffect(() => {
    let activo = true
    setCargando(true)
    cuentaFinancieraApi
      .movimientos(cuenta.id, desde, hasta)
      .then((m) => activo && setMovimientos(m))
      .catch((e) => toast.error(e instanceof ApiError ? e.message : 'No pudimos cargar los movimientos.'))
      .finally(() => activo && setCargando(false))
    return () => {
      activo = false
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [cuenta.id, desde, hasta])

  const columns: DataTableColumn<MovimientoCuentaResponse>[] = [
    { key: 'fecha', label: 'Fecha', filterType: 'date', render: (row) => fechaHora(row.fecha) },
    {
      key: 'tipo',
      label: 'Tipo',
      filterable: false,
      render: (row) => <Badge tone={row.tipo === 'INGRESO' ? 'success' : 'danger'}>{row.tipo === 'INGRESO' ? 'Ingreso' : 'Egreso'}</Badge>,
    },
    {
      key: 'monto',
      label: 'Monto',
      align: 'right',
      filterable: false,
      render: (row) => (row.tipo === 'INGRESO' ? `+${soles(row.monto)}` : `-${soles(row.monto)}`),
    },
    { key: 'saldoResultante', label: 'Saldo', align: 'right', filterable: false, render: (row) => soles(row.saldoResultante) },
    { key: 'documentoOrigen', label: 'Origen', filterable: false },
    { key: 'usuario', label: 'Usuario', filterable: false, render: (row) => row.usuario ?? '—' },
  ]

  return (
    <Modal open title={`Movimientos de ${cuenta.nombre}`} description={`Saldo actual: ${soles(cuenta.saldoActual)}`} onClose={onClose} size="xl">
      <SysDataTable
        columns={columns}
        rows={movimientos}
        onConsulta={(q) => {
          const fecha = q.filtros.find((f) => f.columna === 'fecha')
          setDesde(fecha?.valor || desplazarDias(-30))
          setHasta(fecha?.valorHasta || fecha?.valor || hoyLocal())
        }}
        empty={cargando ? 'Cargando movimientos...' : 'No hay movimientos en esta cuenta en estas fechas.'}
      />
    </Modal>
  )
}

function ConciliarModal({ cuenta, onClose }: { cuenta: CuentaFinancieraResponse; onClose: () => void }) {
  const toast = useToast()
  const [historial, setHistorial] = useState<ConciliacionBancariaResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [fecha, setFecha] = useState(hoyLocal())
  const [saldoExtracto, setSaldoExtracto] = useState('')
  const [observacion, setObservacion] = useState('')
  const [guardando, setGuardando] = useState(false)

  const cargar = useCallback(() => {
    setCargando(true)
    conciliacionBancariaApi
      .listar(cuenta.id)
      .then(setHistorial)
      .catch((e) => toast.error(e instanceof ApiError ? e.message : 'No pudimos cargar las conciliaciones.'))
      .finally(() => setCargando(false))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [cuenta.id])

  useEffect(() => {
    cargar()
  }, [cargar])

  const guardar = async () => {
    const numero = Number(saldoExtracto.replace(',', '.'))
    if (!Number.isFinite(numero)) return toast.error('Ingresa el saldo del extracto.')

    setGuardando(true)
    try {
      await conciliacionBancariaApi.crear({
        cuentaFinancieraId: cuenta.id,
        fecha,
        saldoExtracto: numero,
        observacion: observacion.trim() || null,
      })
      setSaldoExtracto('')
      setObservacion('')
      cargar()
      toast.exito('Conciliación registrada')
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos registrar la conciliación.')
    } finally {
      setGuardando(false)
    }
  }

  const marcarConciliada = async (id: number) => {
    try {
      await conciliacionBancariaApi.marcarConciliada(id)
      cargar()
      toast.exito('Marcada como conciliada')
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos marcarla.')
    }
  }

  return (
    <Modal
      open
      title={`Conciliación bancaria — ${cuenta.nombre}`}
      description="Compara el saldo que el sistema cree tener contra lo que dice el extracto, a una fecha de corte."
      onClose={onClose}
      size="lg"
    >
      <div className="space-y-4">
        <div className="grid grid-cols-1 gap-3 rounded-field border border-line bg-surface-alt p-3 sm:grid-cols-3">
          <Input label="Fecha de corte" type="date" value={fecha} onChange={(e) => setFecha(e.target.value)} />
          <Input
            label="Saldo del extracto"
            type="number"
            step="0.01"
            placeholder="0.00"
            value={saldoExtracto}
            onChange={(e) => setSaldoExtracto(e.target.value)}
          />
          <Input
            label="Observación"
            optional
            className="sm:col-span-1"
            value={observacion}
            onChange={(e) => setObservacion(e.target.value)}
          />
          <div className="sm:col-span-3">
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              Registrar conciliación
            </Button>
          </div>
        </div>

        <div className="overflow-hidden rounded-panel border border-line">
          {cargando ? (
            <p className="p-4 text-center text-sm text-ink-soft">Cargando...</p>
          ) : historial.length === 0 ? (
            <p className="p-4 text-center text-sm text-ink-soft">Todavía no hay conciliaciones para esta cuenta.</p>
          ) : (
            historial.map((c) => (
              <div key={c.id} className="flex items-center justify-between gap-3 border-b border-line px-3 py-2.5 last:border-b-0">
                <div className="min-w-0">
                  <p className="text-[13px] text-ink">{fechaCorta(c.fecha)}</p>
                  <p className="truncate text-[11px] text-ink-soft">
                    Extracto {soles(c.saldoExtracto)} · Sistema {soles(c.saldoContable)}
                    {c.observacion ? ` · ${c.observacion}` : ''}
                  </p>
                </div>
                <div className="flex shrink-0 items-center gap-2">
                  <Badge tone={c.diferencia === 0 ? 'success' : 'danger'}>
                    {c.diferencia > 0 ? '+' : ''}
                    {soles(c.diferencia)}
                  </Badge>
                  {c.estado === 'CONCILIADO' ? (
                    <Badge tone="neutral">
                      <CheckCircle2 size={11} className="mr-1" />
                      Conciliada
                    </Badge>
                  ) : (
                    <Button variant="secondary" size="sm" onClick={() => void marcarConciliada(c.id)}>
                      Marcar conciliada
                    </Button>
                  )}
                </div>
              </div>
            ))
          )}
        </div>
      </div>
    </Modal>
  )
}
