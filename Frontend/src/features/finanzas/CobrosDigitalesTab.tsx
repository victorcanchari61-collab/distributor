import { useCallback, useEffect, useState } from 'react'
import type { ReactNode } from 'react'
import { BadgeCheck, CheckCircle2, Clock, Smartphone, Undo2, UserX, XCircle } from 'lucide-react'
import { Alert, Badge, Button, Input, ListPage, Modal, RowAction, StatCard, useConfirmacion, useToast } from '../../components/ui'
import type { BadgeTone, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { desplazarDias, fechaHora, hoyLocal } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { cierreCajaApi } from './cierreCajaApi'
import type { CobroDigitalResponse, EstadoVerificacionCobro } from './cierreCajaApi'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

const ESTADOS: { value: EstadoVerificacionCobro; label: string; tono: BadgeTone }[] = [
  { value: 'PENDIENTE', label: 'Por verificar', tono: 'warning' },
  { value: 'VERIFICADO', label: 'Verificado', tono: 'success' },
  { value: 'RECHAZADO', label: 'Rechazado', tono: 'danger' },
]

const DESCUENTO: Record<string, string> = {
  PENDIENTE: 'Se descuenta en planilla',
  DESCONTADO: 'Ya descontado en planilla',
  ANULADO: 'Descuento anulado',
}

/**
 * El cuadre de lo que no pasa por la caja.
 *
 * El efectivo se cuadra contando en el cierre; un Yape o una transferencia
 * entra directo al banco, así que se busca ahí por su número de operación.
 * Si aparece se verifica; si no, se rechaza: sale del banco y se le descuenta
 * en planilla a quien dijo que lo cobró.
 */
export function CobrosDigitalesTab({ cabecera }: { cabecera: ReactNode }) {
  const { puede } = usePermisos()
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()
  const [cobros, setCobros] = useState<CobroDigitalResponse[]>([])
  const [desde, setDesde] = useState(desplazarDias(-30))
  const [hasta, setHasta] = useState(hoyLocal())
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [rechazando, setRechazando] = useState<CobroDigitalResponse | null>(null)
  const [motivo, setMotivo] = useState('')
  const [guardando, setGuardando] = useState(false)

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setCobros(await cierreCajaApi.cobrosDigitales(desde, hasta))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los cobros digitales.')
    } finally {
      setCargando(false)
    }
  }, [desde, hasta])

  useEffect(() => {
    void cargar()
  }, [cargar])

  // Un cobro nuevo, editado o anulado en una venta cambia la bandeja.
  useRealtime(['cierrescaja', 'notasventa', 'planillas'], cargar)

  const puedeConfirmar = puede('finanzas.cierres', 'confirmar')

  const verificar = async (c: CobroDigitalResponse) => {
    try {
      await cierreCajaApi.verificar(c.id)
      await cargar()
      toast.exito(`Operación ${c.numeroOperacion ?? ''} verificada`)
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos verificar el cobro.')
    }
  }

  const quitarVerificacion = (c: CobroDigitalResponse) =>
    confirmar({
      titulo: 'Quitar la verificación',
      mensaje: `El cobro de ${soles(c.monto)} de la ${c.documento} vuelve a quedar por verificar.`,
      confirmar: 'Quitar',
      tono: 'pregunta',
      accion: async () => {
        try {
          await cierreCajaApi.quitarVerificacion(c.id)
          await cargar()
          toast.exito('Vuelve a quedar por verificar')
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos quitar la verificación.')
        }
      },
    })

  const cerrarRechazo = () => {
    setRechazando(null)
    setMotivo('')
  }

  const rechazar = async () => {
    if (!rechazando) return
    if (!motivo.trim()) return toast.error('Di por qué se rechaza.')

    setGuardando(true)
    try {
      await cierreCajaApi.rechazar(rechazando.id, motivo.trim())
      await cargar()
      toast.exito('Cobro rechazado')
      cerrarRechazo()
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos rechazar el cobro.')
    } finally {
      setGuardando(false)
    }
  }

  const suma = (estado: EstadoVerificacionCobro) => cobros.filter((c) => c.estado === estado)
  const total = (lista: CobroDigitalResponse[]) => lista.reduce((s, c) => s + c.monto, 0)
  const pendientes = suma('PENDIENTE')
  const verificados = suma('VERIFICADO')
  const rechazados = suma('RECHAZADO')
  const sinEmpleado = rechazados.filter((c) => c.sinEmpleado && c.descuento?.estado === 'PENDIENTE').length
  const trabajadores = [...new Set(cobros.map((c) => c.usuario ?? '—'))].sort((a, b) => a.localeCompare(b, 'es'))
  const metodos = [...new Set(cobros.map((c) => c.metodoPago))].sort((a, b) => a.localeCompare(b, 'es'))

  const columns: DataTableColumn<CobroDigitalResponse>[] = [
    { key: 'fecha', label: 'Fecha', filterType: 'date', render: (row) => fechaHora(row.fecha) },
    {
      key: 'usuario',
      label: 'Cobrado por',
      filterType: 'select',
      filterOptions: trabajadores.map((t) => ({ value: t, label: t })),
      value: (row) => row.usuario ?? '—',
      render: (row) => (
        <span className="inline-flex items-center gap-1.5">
          {row.usuario ?? <span className="text-ink-soft">—</span>}
          {row.sinEmpleado && (
            <span title="Sin empleado vinculado: su descuento no entra en la planilla">
              <UserX size={14} className="text-amber-600" />
            </span>
          )}
        </span>
      ),
    },
    {
      key: 'documento',
      label: 'Venta',
      filterable: false,
      render: (row) => (
        <div>
          <Badge>{row.documento}</Badge>
          {row.cliente && <div className="mt-0.5 text-xs text-ink-soft">{row.cliente}</div>}
        </div>
      ),
    },
    {
      key: 'metodoPago',
      label: 'Método',
      filterType: 'select',
      filterOptions: metodos.map((m) => ({ value: m, label: m })),
    },
    { key: 'cuenta', label: 'Cuenta', filterable: false, render: (row) => row.cuenta ?? '—' },
    {
      key: 'numeroOperacion',
      label: 'N° operación',
      filterable: false,
      render: (row) =>
        row.numeroOperacion ? (
          <span className="font-mono font-semibold text-ink">{row.numeroOperacion}</span>
        ) : (
          <span className="text-ink-soft" title="Se registró antes de pedir el número">
            Sin número
          </span>
        ),
    },
    { key: 'monto', label: 'Monto', align: 'right', filterable: false, render: (row) => soles(row.monto) },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: ESTADOS.map(({ value, label }) => ({ value, label })),
      render: (row) => {
        const e = ESTADOS.find((x) => x.value === row.estado)!
        return (
          <div>
            <Badge tone={e.tono}>{e.label}</Badge>
            {row.verificadoPor && (
              <div className="mt-0.5 text-xs text-ink-soft">
                {row.verificadoPor}
                {row.verificadoEn && ` · ${fechaHora(row.verificadoEn)}`}
              </div>
            )}
            {row.observacion && <div className="mt-0.5 text-xs text-ink-soft">{row.observacion}</div>}
            {row.descuento && (
              <div className="mt-0.5 text-xs font-medium text-red-600">
                {DESCUENTO[row.descuento.estado]}
                {row.descuento.estado === 'PENDIENTE' && ` · ${soles(row.descuento.saldo)}`}
              </div>
            )}
          </div>
        )
      },
    },
  ]

  return (
    <>
      {cabecera}
      <ListPage
        icon={<Smartphone size={20} />}
        title="Cobros digitales"
        description="Lo cobrado por Yape, Plin o transferencia. Búscalo en el banco por su número de operación: si aparece, verifícalo; si no, recházalo y se le descuenta a quien lo cobró. Los pendientes salen siempre, de cualquier fecha."
        alert={
          error ? (
            <Alert>{error}</Alert>
          ) : sinEmpleado > 0 ? (
            <Alert tone="warning">
              {sinEmpleado} cobro(s) rechazado(s) de usuarios sin empleado vinculado: no entran en ninguna planilla hasta
              vincularlos en Configuración → Usuarios.
            </Alert>
          ) : undefined
        }
        stats={
          <>
            <StatCard
              label="Por verificar"
              value={soles(total(pendientes))}
              icon={<Clock size={18} />}
              tono="warning"
              hint={`${pendientes.length} ${pendientes.length === 1 ? 'cobro' : 'cobros'}, de cualquier fecha`}
            />
            <StatCard
              label="Verificado"
              value={soles(total(verificados))}
              icon={<BadgeCheck size={18} />}
              tono="success"
              hint={`${verificados.length} en estas fechas`}
            />
            <StatCard
              label="Rechazado"
              value={soles(total(rechazados))}
              icon={<XCircle size={18} />}
              tono="danger"
              hint="Se descuenta a quien lo cobró"
            />
          </>
        }
        columns={columns}
        rows={cobros}
        onConsulta={(q) => {
          const fecha = q.filtros.find((f) => f.columna === 'fecha')
          setDesde(fecha?.valor || desplazarDias(-30))
          setHasta(fecha?.valorHasta || fecha?.valor || hoyLocal())
        }}
        cardIcon={Smartphone}
        searchPlaceholder="Buscar por número de operación o venta..."
        empty={cargando ? 'Cargando cobros...' : 'No hay cobros digitales en este periodo.'}
        rowActions={(row) =>
          !puedeConfirmar ? null : row.estado === 'PENDIENTE' ? (
            <>
              <RowAction label="Verificar: apareció en el banco" tone="success" onClick={() => void verificar(row)}>
                <CheckCircle2 size={15} />
              </RowAction>
              <RowAction label="Rechazar: no apareció" tone="danger" onClick={() => setRechazando(row)}>
                <XCircle size={15} />
              </RowAction>
            </>
          ) : row.estado === 'VERIFICADO' ? (
            <RowAction label="Quitar la verificación" tone="neutral" onClick={() => quitarVerificacion(row)}>
              <Undo2 size={15} />
            </RowAction>
          ) : null
        }
      >
        {dialogo}

        <Modal
          open={rechazando !== null}
          size="sm"
          title={rechazando ? `Rechazar el cobro de ${soles(rechazando.monto)}` : ''}
          description={
            rechazando
              ? `${rechazando.usuario ?? 'Alguien'} registró ${soles(rechazando.monto)} por ${rechazando.metodoPago} en la ${rechazando.documento}${rechazando.numeroOperacion ? `, operación ${rechazando.numeroOperacion}` : ''}.`
              : undefined
          }
          onClose={cerrarRechazo}
          footer={
            <>
              <Button size="sm" variant="secondary" onClick={cerrarRechazo}>
                Cancelar
              </Button>
              <Button size="sm" onClick={rechazar} disabled={guardando}>
                Rechazar
              </Button>
            </>
          }
        >
          <div className="flex flex-col gap-3">
            <Alert tone="warning">
              Sale de {rechazando?.cuenta ?? 'la cuenta'} y{' '}
              {rechazando?.usuarioId
                ? `se le descuenta a ${rechazando.usuario} en su planilla`
                : 'no se sabe quién lo cobró: no se le descuenta a nadie'}
              . La venta sigue cobrada. No se puede deshacer.
            </Alert>
            <Input
              label="Motivo"
              placeholder="No aparece en el banco, llegó otro monto..."
              value={motivo}
              onChange={(e) => setMotivo(e.target.value)}
            />
          </div>
        </Modal>
      </ListPage>
    </>
  )
}
