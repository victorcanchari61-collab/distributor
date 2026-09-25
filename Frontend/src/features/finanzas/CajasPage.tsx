import { useCallback, useEffect, useState } from 'react'
import { History, ShieldCheck, ShieldOff, UserPlus, Users } from 'lucide-react'
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
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaHora } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { usuarioApi } from '../config/usuarioApi'
import type { UsuarioResponse } from '../config/usuarioApi'
import { cuentaFinancieraApi } from './cuentaFinancieraApi'
import type { CuentaFinancieraResponse, MovimientoCuentaResponse } from './cuentaFinancieraApi'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

/**
 * A quién se le asigna una Caja: ya no se crea sola. Sin caja acá, un
 * vendedor o repartidor no puede cobrar en efectivo (ver VentasService,
 * ValidarPuedeCobrarAsync).
 */
export function CajasPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const [cajas, setCajas] = useState<CuentaFinancieraResponse[]>([])
  const [usuarios, setUsuarios] = useState<UsuarioResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [usuarioId, setUsuarioId] = useState(0)
  const [nombre, setNombre] = useState('')
  const [guardando, setGuardando] = useState(false)

  const [movimientosDe, setMovimientosDe] = useState<CuentaFinancieraResponse | null>(null)

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [todas, u] = await Promise.all([cuentaFinancieraApi.getAll(), usuarioApi.getAll()])
      setCajas(todas.filter((c) => c.naturaleza === 'CAJA' && c.usuarioResponsableId != null))
      setUsuarios(u)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las cajas.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('cuentasfinancieras', cargar)

  const disponibles = usuarios.filter(
    (u) => u.activo && !cajas.some((c) => c.activo && c.usuarioResponsableId === u.id),
  )

  const abrirNuevo = () => {
    setUsuarioId(0)
    setNombre('')
    setAbierto(true)
  }

  const usuarioElegido = usuarios.find((u) => u.id === usuarioId)

  const guardar = async () => {
    if (!usuarioId) return toast.error('Elige a quién se le asigna la caja.')

    setGuardando(true)
    try {
      await cuentaFinancieraApi.create({
        nombre: nombre.trim() || `Caja de ${usuarioElegido?.nombre ?? ''}`,
        naturaleza: 'CAJA',
        usuarioResponsableId: usuarioId,
        activo: true,
      })
      setAbierto(false)
      await cargar()
      toast.exito('Caja creada')
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos crear la caja.')
    } finally {
      setGuardando(false)
    }
  }

  const cambiarEstado = (c: CuentaFinancieraResponse) =>
    confirmar({
      titulo: `${c.activo ? 'Desactivar' : 'Activar'} ${c.nombre}`,
      mensaje: c.activo
        ? 'Deja de poder cobrar en efectivo hasta que se le vuelva a activar.'
        : 'Vuelve a poder cobrar en efectivo.',
      confirmar: c.activo ? 'Desactivar' : 'Activar',
      tono: c.activo ? 'warning' : 'pregunta',
      accion: async () => {
        try {
          await cuentaFinancieraApi.update(c.id, {
            nombre: c.nombre,
            naturaleza: 'CAJA',
            usuarioResponsableId: c.usuarioResponsableId,
            activo: !c.activo,
          })
          await cargar()
          toast.exito(`${c.nombre} ${c.activo ? 'desactivada' : 'activada'}`)
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  const columns: DataTableColumn<CuentaFinancieraResponse>[] = [
    { key: 'usuarioResponsable', label: 'Usuario', filterable: false, render: (row) => row.usuarioResponsable ?? '—' },
    { key: 'nombre', label: 'Nombre', filterable: false },
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
      icon={<Users size={20} />}
      title="Cajas"
      description="A quién se le asigna una Caja: sin una asignada acá, no puede cobrar ventas en efectivo."
      actions={
        puede('finanzas.cajas', 'crear') ? (
          <Button size="sm" onClick={abrirNuevo} iconRight={<UserPlus size={15} />}>
            Asignar caja
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Cajas activas" value={String(cajas.filter((c) => c.activo).length)} icon={<Users size={18} />} tono="sys" />
          <StatCard
            label="Saldo en cajas"
            value={soles(cajas.filter((c) => c.activo).reduce((s, c) => s + c.saldoActual, 0))}
            icon={<Users size={18} />}
          />
        </>
      }
      columns={columns}
      rows={cajas}
      cardIcon={Users}
      searchPlaceholder="Buscar por usuario..."
      empty={cargando ? 'Cargando cajas...' : 'Todavía no hay ninguna caja asignada.'}
      rowActions={(row) => (
        <>
          <RowAction label={`Movimientos de ${row.nombre}`} tone="view" onClick={() => setMovimientosDe(row)}>
            <History size={15} />
          </RowAction>
          {puede('finanzas.cajas', 'editar') && (
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
        title="Asignar una caja"
        description="Se crea con saldo cero: se llena entregándole un fondo de ruta desde Arqueo, o con lo que cobre en efectivo."
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              Crear caja
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          <Desplegable
            label="Usuario"
            value={usuarioId}
            onChange={(v) => setUsuarioId(Number(v))}
            placeholder="Elige a quién se le asigna"
            options={disponibles.map((u) => ({ value: u.id, label: u.nombre }))}
          />
          <Input
            label="Nombre"
            optional
            placeholder={usuarioElegido ? `Caja de ${usuarioElegido.nombre}` : 'Caja de...'}
            value={nombre}
            onChange={(e) => setNombre(e.target.value)}
          />
        </div>
      </Modal>

      {movimientosDe && <MovimientosModal cuenta={movimientosDe} onClose={() => setMovimientosDe(null)} />}

      {dialogo}
    </ListPage>
  )
}

function MovimientosModal({ cuenta, onClose }: { cuenta: CuentaFinancieraResponse; onClose: () => void }) {
  const [movimientos, setMovimientos] = useState<MovimientoCuentaResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const toast = useToast()

  useEffect(() => {
    let activo = true
    setCargando(true)
    cuentaFinancieraApi
      .movimientos(cuenta.id)
      .then((m) => activo && setMovimientos(m))
      .catch((e) => toast.error(e instanceof ApiError ? e.message : 'No pudimos cargar los movimientos.'))
      .finally(() => activo && setCargando(false))
    return () => {
      activo = false
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [cuenta.id])

  const columns: DataTableColumn<MovimientoCuentaResponse>[] = [
    { key: 'fecha', label: 'Fecha', filterable: false, render: (row) => fechaHora(row.fecha) },
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
        toolbar={false}
        empty={cargando ? 'Cargando movimientos...' : 'Todavía no hay movimientos en esta caja.'}
      />
    </Modal>
  )
}
