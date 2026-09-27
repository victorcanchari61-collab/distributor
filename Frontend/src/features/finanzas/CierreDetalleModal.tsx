import { useCallback, useEffect, useState } from 'react'
import type { ReactNode } from 'react'
import { Banknote, CheckCircle2, Smartphone, Undo2, UserX, Wallet, XCircle } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  FilaStats,
  Input,
  Modal,
  RowAction,
  StatCard,
  SysDataTable,
  Tabs,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { BadgeTone, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaHora } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { cierreCajaApi } from './cierreCajaApi'
import type {
  CierreDetalleResponse,
  CobroDigitalResponse,
  EstadoVerificacionCobro,
  MovimientoCierreResponse,
} from './cierreCajaApi'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

const DOCUMENTOS: Record<string, string> = {
  PAGO_VENTA: 'Cobro de venta',
  PAGO_COMPRA: 'Pago a proveedor',
  MOVIMIENTO_OPERATIVO: 'Ingreso o egreso',
  CIERRE_CAJA: 'Cierre de caja',
  FALTANTE_CAJA: 'Faltante de cierre',
  SOBRANTE_CAJA: 'Sobrante de cierre',
  REVERSION: 'Anulación',
  SALDO_INICIAL: 'Saldo inicial',
  TRANSFERENCIA_INTERNA: 'Transferencia',
  RECUPERO_FALTANTE: 'Recupero de faltante',
}

const ESTADOS_DIGITAL: Record<EstadoVerificacionCobro, { label: string; tono: BadgeTone }> = {
  PENDIENTE: { label: 'Por verificar', tono: 'warning' },
  VERIFICADO: { label: 'Verificado', tono: 'success' },
  RECHAZADO: { label: 'Rechazado', tono: 'danger' },
}

const DESCUENTO: Record<string, string> = {
  PENDIENTE: 'Se descuenta en planilla',
  DESCONTADO: 'Ya descontado en planilla',
  ANULADO: 'Descuento anulado',
}

/**
 * Un cierre entero, para revisar si cuadra.
 *
 * El efectivo que pasó por la caja desde el cierre anterior (y que da lo que
 * "debía tener"), los billetes y monedas que se contaron, y lo cobrado por
 * Yape o transferencia, que no pasa por la caja: se busca en el banco por su
 * número de operación y se verifica o se rechaza aquí mismo.
 */
export function CierreDetalleModal({
  cierreId,
  onClose,
  onCambio,
}: {
  cierreId: number
  onClose: () => void
  /** Verificar o rechazar cambia los números de la lista de cierres. */
  onCambio: () => void | Promise<void>
}) {
  const { puede } = usePermisos()
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()
  const [detalle, setDetalle] = useState<CierreDetalleResponse | null>(null)
  const [error, setError] = useState('')
  const [pestana, setPestana] = useState<'efectivo' | 'digital' | 'billetes'>('efectivo')
  const [rechazando, setRechazando] = useState<CobroDigitalResponse | null>(null)
  const [motivo, setMotivo] = useState('')
  const [guardando, setGuardando] = useState(false)

  const cargar = useCallback(async () => {
    try {
      setDetalle(await cierreCajaApi.detalle(cierreId))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar el cierre.')
    }
  }, [cierreId])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['cierrescaja', 'notasventa'], cargar)

  const recargarTodo = async () => {
    await cargar()
    await onCambio()
  }

  const puedeConfirmar = puede('finanzas.cierres', 'confirmar')

  const verificar = async (c: CobroDigitalResponse) => {
    try {
      await cierreCajaApi.verificar(c.id)
      await recargarTodo()
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
          await recargarTodo()
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
      await recargarTodo()
      toast.exito('Cobro rechazado')
      cerrarRechazo()
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos rechazar el cobro.')
    } finally {
      setGuardando(false)
    }
  }

  const c = detalle?.cierre
  const vigentes = (detalle?.efectivo ?? []).filter((m) => !m.anulado && !m.esReversa)
  const ingresos = vigentes.filter((m) => m.tipo === 'INGRESO').reduce((s, m) => s + m.monto, 0)
  const egresos = vigentes.filter((m) => m.tipo === 'EGRESO').reduce((s, m) => s + m.monto, 0)
  const resultado = !c ? null : c.diferencia < 0 ? 'Faltante' : c.diferencia > 0 ? 'Sobrante' : 'Cuadró'

  const columnasEfectivo: DataTableColumn<MovimientoCierreResponse>[] = [
    { key: 'fecha', label: 'Fecha', render: (row) => fechaHora(row.fecha) },
    {
      key: 'documentoOrigen',
      label: 'Concepto',
      render: (row) => (
        <div>
          <p>{DOCUMENTOS[row.documentoOrigen] ?? row.documentoOrigen}</p>
          {row.detalle && <p className="text-xs text-ink-soft">{row.detalle}</p>}
        </div>
      ),
    },
    {
      key: 'monto',
      label: 'Monto',
      align: 'right',
      render: (row) => (
        <span
          className={
            row.anulado || row.esReversa ? 'text-ink-soft line-through' : row.tipo === 'INGRESO' ? 'text-emerald-700' : 'text-red-600'
          }
        >
          {row.tipo === 'INGRESO' ? '+' : '-'}
          {soles(row.monto)}
        </span>
      ),
    },
    {
      key: 'anulado',
      label: 'Estado',
      render: (row) =>
        row.esReversa ? (
          <Badge tone="neutral">Reversa</Badge>
        ) : row.anulado ? (
          <Badge tone="neutral">Anulado</Badge>
        ) : (
          <Badge tone="success">Vigente</Badge>
        ),
    },
  ]

  const columnasDigital: DataTableColumn<CobroDigitalResponse>[] = [
    { key: 'fecha', label: 'Fecha', render: (row) => fechaHora(row.fecha) },
    {
      key: 'documento',
      label: 'Venta',
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
      render: (row) => (
        <div>
          <p>{row.metodoPago}</p>
          {row.cuenta && <p className="text-xs text-ink-soft">a {row.cuenta}</p>}
        </div>
      ),
    },
    {
      key: 'numeroOperacion',
      label: 'N° operación',
      render: (row) =>
        row.numeroOperacion ? (
          <span className="font-mono font-semibold text-ink">{row.numeroOperacion}</span>
        ) : (
          <span className="text-ink-soft">Sin número</span>
        ),
    },
    { key: 'monto', label: 'Monto', align: 'right', render: (row) => soles(row.monto) },
    {
      key: 'estado',
      label: 'Estado',
      render: (row) => (
        <div>
          <Badge tone={ESTADOS_DIGITAL[row.estado].tono}>{ESTADOS_DIGITAL[row.estado].label}</Badge>
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
      ),
    },
  ]

  return (
    <Modal
      open
      size="2xl"
      title={c ? `Cierre de ${c.usuario}` : 'Cierre de caja'}
      description={
        c
          ? `${c.caja} · ${detalle?.desde ? `del ${fechaHora(detalle.desde)} ` : 'desde el inicio '}al ${fechaHora(c.fecha)}`
          : undefined
      }
      onClose={onClose}
    >
      {error && <Alert>{error}</Alert>}
      {!detalle && !error && <p className="py-8 text-center text-sm text-ink-soft">Cargando el cierre...</p>}

      {detalle && c && (
        <div className="flex flex-col gap-5">
          {c.anulado && <Alert tone="warning">Este cierre está anulado: la plata volvió a la caja y entra en el siguiente.</Alert>}
          {c.sinEmpleado && (
            <Alert tone="warning">
              <span className="inline-flex items-center gap-1.5">
                <UserX size={14} /> {c.usuario} no tiene empleado vinculado: su faltante no entra en ninguna planilla.
              </span>
            </Alert>
          )}

          <FilaStats>
            <StatCard
              label="Debía tener"
              value={soles(c.saldoSistema)}
              icon={<Wallet size={18} />}
              tono="sys"
              hint={
                detalle.saldoAnterior !== 0
                  ? `Venía ${soles(detalle.saldoAnterior)} de antes`
                  : `Entró ${soles(ingresos)} · salió ${soles(egresos)}`
              }
            />
            <StatCard
              label="Contado"
              value={soles(c.contado)}
              icon={<Banknote size={18} />}
              tono="sys"
              hint={`Entregado a ${c.cuentaDestino}`}
            />
            <StatCard
              label={resultado ?? 'Diferencia'}
              value={c.diferencia === 0 ? soles(0) : `${c.diferencia > 0 ? '+' : '-'}${soles(Math.abs(c.diferencia))}`}
              icon={c.diferencia < 0 ? <XCircle size={18} /> : <CheckCircle2 size={18} />}
              tono={c.diferencia < 0 ? 'danger' : c.diferencia > 0 ? 'warning' : 'success'}
              hint={c.descuento ? `${DESCUENTO[c.descuento.estado]}` : c.observacion ?? undefined}
            />
            <StatCard
              label="Cobrado digital"
              value={soles(c.digital)}
              icon={<Smartphone size={18} />}
              tono={c.digitalPorVerificar > 0 ? 'warning' : 'success'}
              hint={
                c.digitalPorVerificar > 0
                  ? `${c.digitalPorVerificar} por verificar en el banco`
                  : detalle.digitales.length > 0
                    ? 'Todo revisado en el banco'
                    : 'Sin cobros digitales'
              }
            />
          </FilaStats>

          <Tabs
            active={pestana}
            onChange={(id) => setPestana(id as 'efectivo' | 'digital' | 'billetes')}
            items={[
              { id: 'efectivo', label: 'Efectivo', icon: <Wallet size={15} />, badge: detalle.efectivo.length },
              { id: 'digital', label: 'Cobros digitales', icon: <Smartphone size={15} />, badge: detalle.digitales.length },
              { id: 'billetes', label: 'Billetes y monedas', icon: <Banknote size={15} /> },
            ]}
          />

          {pestana === 'efectivo' && (
            <Seccion
              titulo="Efectivo"
              detalle={`Lo que pasó por la caja: entró ${soles(ingresos)} y salió ${soles(egresos)}`}
            >
              <SysDataTable
                columns={columnasEfectivo}
                rows={detalle.efectivo}
                toolbar={false}
                paginacion={false}
                cardIcon={Wallet}
                empty="No hubo movimientos de efectivo en este periodo."
              />
            </Seccion>
          )}

          {pestana === 'digital' && (
            <Seccion
              titulo="Cobros digitales"
              detalle="Por Yape o transferencia: no pasan por la caja. Búscalos en el banco por su número de operación."
            >
              <SysDataTable
                columns={columnasDigital}
                rows={detalle.digitales}
                toolbar={false}
                paginacion={false}
                cardIcon={Smartphone}
                empty="No cobró nada por Yape o transferencia en este periodo."
                actions={(row) =>
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
              />
            </Seccion>
          )}

          {pestana === 'billetes' && (
            <Seccion titulo="Billetes y monedas" detalle="Lo que contó al cerrar.">
              <div className="max-w-md">
                <Conteo detalle={detalle} />
              </div>
            </Seccion>
          )}
        </div>
      )}

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
            autoComplete="off"
            placeholder="No aparece en el banco, llegó otro monto..."
            value={motivo}
            onChange={(e) => setMotivo(e.target.value)}
          />
        </div>
      </Modal>
    </Modal>
  )
}

/** Un bloque del detalle, con su título y una línea que dice qué es. */
function Seccion({ titulo, detalle, children }: { titulo: string; detalle: string; children: ReactNode }) {
  return (
    <section>
      <h3 className="text-sm font-semibold text-ink">{titulo}</h3>
      <p className="mb-2 text-xs text-ink-soft">{detalle}</p>
      {children}
    </section>
  )
}

/** Los billetes y monedas contados, con el mismo formato que al cerrar caja. */
function Conteo({ detalle }: { detalle: CierreDetalleResponse }) {
  const c = detalle.cierre

  if (detalle.denominaciones.length === 0) {
    return (
      <div className="rounded-field border border-line px-3 py-3 text-xs text-ink-soft">
        {c.contado === 0
          ? 'No contó efectivo en este cierre.'
          : 'Este cierre se hizo antes de guardar el desglose: solo se sabe el total.'}
        <div className="mt-2 flex justify-between text-ink">
          <span>Billetes</span>
          <span className="tabular-nums">{soles(c.billetes)}</span>
        </div>
        <div className="flex justify-between text-ink">
          <span>Monedas</span>
          <span className="tabular-nums">{soles(c.monedas)}</span>
        </div>
      </div>
    )
  }

  return (
    <div className="overflow-hidden rounded-field border border-line">
      <table className="w-full text-xs">
        <tbody>
          {detalle.denominaciones.map((d) => (
            <tr key={d.valor} className="border-b border-line/60 even:bg-surface-alt/60">
              <td className="px-3 py-1.5 text-ink">
                {d.esBillete ? 'Billete' : 'Moneda'} S/ {d.valor.toFixed(2)}
              </td>
              <td className="px-3 py-1.5 text-center text-ink-soft tabular-nums">× {d.cantidad}</td>
              <td className="px-3 py-1.5 text-right font-medium text-ink tabular-nums">{d.total.toFixed(2)}</td>
            </tr>
          ))}
        </tbody>
        <tfoot className="text-ink-soft">
          <tr>
            <td colSpan={2} className="px-3 pt-2 text-right">
              Billetes
            </td>
            <td className="px-3 pt-2 text-right tabular-nums">{soles(c.billetes)}</td>
          </tr>
          <tr>
            <td colSpan={2} className="px-3 text-right">
              Monedas
            </td>
            <td className="px-3 text-right tabular-nums">{soles(c.monedas)}</td>
          </tr>
          <tr className="text-ink">
            <td colSpan={2} className="px-3 pt-1 pb-2 text-right font-semibold">
              Total contado
            </td>
            <td className="px-3 pt-1 pb-2 text-right font-bold text-[rgb(var(--sys-rgb))] tabular-nums">{soles(c.contado)}</td>
          </tr>
        </tfoot>
      </table>
    </div>
  )
}
