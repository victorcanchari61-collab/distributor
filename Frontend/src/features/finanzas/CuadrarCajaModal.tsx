import { useCallback, useEffect, useMemo, useState } from 'react'
import { Banknote, Coins, History, Plus, Smartphone, Trash2 } from 'lucide-react'
import {
  Alert,
  Badge,
  BuscadorCampo,
  Button,
  Desplegable,
  Input,
  Modal,
} from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { clienteApi } from '../maestros'
import type { ClienteResponse } from '../maestros'
import { metodoPagoApi } from './finanzasApi'
import type { MetodoPagoResponse } from './finanzasApi'
import { arqueoApi, motivoGastoApi } from './arqueoApi'
import type { CobroDelDiaResponse, DetalleCuadreResponse, MotivoGastoResponse } from './arqueoApi'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

/** Fila de gasto en edición: el id local sobrevive a reordenar y borrar. */
interface FilaGasto {
  clave: string
  motivoGastoId: number
  monto: string
  descripcion: string
}

interface FilaPago {
  clave: string
  clienteId: number | null
  metodoPagoId: number
  numeroOperacion: string
  monto: string
}

export interface CuadrarCajaModalProps {
  open: boolean
  fecha: string
  usuarioId: number
  usuario: string
  onClose: () => void
  onGuardado: () => void | Promise<void>
}

/**
 * El cuadre de una persona en un día: a la izquierda el efectivo que trae, a
 * la derecha lo que dice haber recibido por Yape o transferencia.
 *
 * La lista de cobros del sistema se muestra cobro a cobro y no solo como total:
 * cuando falta dinero, la única forma de encontrarlo es ver de qué cliente
 * salió cada sol.
 */
export function CuadrarCajaModal({
  open,
  fecha,
  usuarioId,
  usuario,
  onClose,
  onGuardado,
}: CuadrarCajaModalProps) {
  const [detalle, setDetalle] = useState<DetalleCuadreResponse | null>(null)
  const [motivos, setMotivos] = useState<MotivoGastoResponse[]>([])
  const [metodos, setMetodos] = useState<MetodoPagoResponse[]>([])
  const [clientes, setClientes] = useState<ClienteResponse[]>([])

  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [guardando, setGuardando] = useState(false)

  const [billetes, setBilletes] = useState('')
  const [monedas, setMonedas] = useState('')
  const [observacion, setObservacion] = useState('')
  const [gastos, setGastos] = useState<FilaGasto[]>([])
  const [pagos, setPagos] = useState<FilaPago[]>([])

  // Lo que se está por agregar a la derecha, antes de pasar a la tabla.
  const [nuevoPago, setNuevoPago] = useState<FilaPago>({
    clave: '',
    clienteId: null,
    metodoPagoId: 0,
    numeroOperacion: '',
    monto: '',
  })

  const cargar = useCallback(async () => {
    setCargando(true)
    setError('')
    try {
      const [d, m, mp, cs] = await Promise.all([
        arqueoApi.detalle(fecha, usuarioId),
        motivoGastoApi.getAll(),
        metodoPagoApi.getAll(),
        clienteApi.getAll(),
      ])

      setDetalle(d)
      setMotivos(m)
      setMetodos(mp)
      setClientes(cs)

      // Reabrir un cuadre ya registrado precarga lo que se declaró entonces:
      // corregirlo es ajustar un número, no volver a escribirlo todo.
      const a = d.arqueo
      setBilletes(a ? String(a.billetes) : '')
      setMonedas(a ? String(a.monedas) : '')
      setObservacion(a?.observacion ?? '')
      setGastos(
        (a?.gastos ?? []).map((g) => ({
          clave: crypto.randomUUID(),
          motivoGastoId: g.motivoGastoId,
          monto: String(g.monto),
          descripcion: g.descripcion ?? '',
        })),
      )
      setPagos(
        (a?.pagosDigitales ?? []).map((p) => ({
          clave: crypto.randomUUID(),
          clienteId: p.clienteId,
          metodoPagoId: p.metodoPagoId,
          numeroOperacion: p.numeroOperacion ?? '',
          monto: String(p.monto),
        })),
      )
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los cobros del día.')
    } finally {
      setCargando(false)
    }
  }, [fecha, usuarioId])

  useEffect(() => {
    if (open) void cargar()
  }, [open, cargar])

  /** Solo los que no son efectivo: el efectivo se cuenta a mano, no se declara aquí. */
  const metodosDigitales = useMemo(
    () => metodos.filter((m) => m.tipo !== 'EFECTIVO' && m.activo),
    [metodos],
  )

  const motivosActivos = useMemo(() => motivos.filter((m) => m.activo), [motivos])

  const numero = (texto: string) => {
    const n = Number(String(texto).replace(',', '.'))
    return Number.isFinite(n) ? n : 0
  }

  const totalGastos = gastos.reduce((s, g) => s + numero(g.monto), 0)
  const totalEfectivoReal = numero(billetes) + numero(monedas) + totalGastos
  const totalDigitalReal = pagos.reduce((s, p) => s + numero(p.monto), 0)

  const efectivoSistema = detalle?.efectivoSistema ?? 0
  const bancosSistema = detalle?.bancosSistema ?? 0

  const diferenciaEfectivo = totalEfectivoReal - efectivoSistema
  const diferenciaBancos = totalDigitalReal - bancosSistema

  // Los faltantes de cada lado se suman sin dejar que un sobrante compense,
  // igual que en el backend: un Yape que nunca llegó es dinero perdido aunque
  // ese día trajera efectivo de más.
  const faltante =
    (diferenciaEfectivo < 0 ? -diferenciaEfectivo : 0) +
    (diferenciaBancos < 0 ? -diferenciaBancos : 0)
  const sobrante =
    (diferenciaEfectivo > 0 ? diferenciaEfectivo : 0) + (diferenciaBancos > 0 ? diferenciaBancos : 0)

  const agregarGasto = () =>
    setGastos((f) => [
      ...f,
      {
        clave: crypto.randomUUID(),
        motivoGastoId: motivosActivos[0]?.id ?? 0,
        monto: '',
        descripcion: '',
      },
    ])

  const agregarPago = () => {
    if (!nuevoPago.metodoPagoId) return setError('Elige el método del pago digital.')
    if (numero(nuevoPago.monto) <= 0) return setError('El pago digital necesita un importe.')

    setError('')
    setPagos((f) => [...f, { ...nuevoPago, clave: crypto.randomUUID() }])
    setNuevoPago({
      clave: '',
      clienteId: null,
      metodoPagoId: metodosDigitales[0]?.id ?? 0,
      numeroOperacion: '',
      monto: '',
    })
  }

  const guardar = async () => {
    if (gastos.some((g) => !g.motivoGastoId)) return setError('Elige el motivo de cada gasto.')
    if (gastos.some((g) => numero(g.monto) <= 0)) return setError('Cada gasto necesita un importe.')

    setGuardando(true)
    setError('')
    try {
      await arqueoApi.registrar({
        fecha,
        usuarioId,
        billetes: numero(billetes),
        monedas: numero(monedas),
        observacion: observacion.trim() || null,
        gastos: gastos.map((g) => ({
          motivoGastoId: g.motivoGastoId,
          monto: numero(g.monto),
          descripcion: g.descripcion.trim() || null,
        })),
        pagosDigitales: pagos.map((p) => ({
          clienteId: p.clienteId,
          metodoPagoId: p.metodoPagoId,
          numeroOperacion: p.numeroOperacion.trim() || null,
          monto: numero(p.monto),
        })),
      })

      await onGuardado()
      onClose()
    } catch (e) {
      setError(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos guardar el cuadre.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const opcionesCliente = clientes.map((c) => ({
    item: c,
    label: c.nombre,
    detalle: c.documento,
  }))

  return (
    <Modal
      open={open}
      size="2xl"
      title={`Cuadrar caja — ${usuario} — ${new Date(`${fecha}T00:00:00`).toLocaleDateString('es-PE')}`}
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} disabled={cargando} onClick={() => void guardar()}>
            Guardar cuadre
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        {error && <Alert>{error}</Alert>}

        {cargando ? (
          <p className="py-8 text-center text-sm text-ink-soft">Cargando los cobros del día...</p>
        ) : (
          <>
            {/* Una sola columna en móvil: los dos lados se leen de arriba a
                abajo sin que ninguno quede en 150px de ancho. */}
            <div className="grid gap-5 lg:grid-cols-2">
              {/* --- Izquierda: el efectivo --- */}
              <section className="flex flex-col gap-4">
                <Titulo icono={<Banknote size={15} />}>Control de efectivo</Titulo>

                <ListaCobros
                  cobros={detalle?.efectivo ?? []}
                  vacio="No cobró nada en efectivo este día."
                />

                <div className="grid gap-3 sm:grid-cols-2">
                  <Input
                    label="Billetes"
                    type="number"
                    step="0.01"
                    placeholder="0.00"
                    value={billetes}
                    onChange={(e) => setBilletes(e.target.value)}
                  />
                  <Input
                    label="Monedas"
                    type="number"
                    step="0.01"
                    placeholder="0.00"
                    value={monedas}
                    onChange={(e) => setMonedas(e.target.value)}
                  />
                </div>

                <div className="flex flex-col gap-2">
                  <div className="flex items-center justify-between">
                    <span className="ui-label">Gastos realizados</span>
                    <Button
                      variant="ghost"
                      onClick={agregarGasto}
                      disabled={motivosActivos.length === 0}
                      iconRight={<Plus size={14} />}
                    >
                      Agregar
                    </Button>
                  </div>

                  {motivosActivos.length === 0 && (
                    <p className="text-xs text-ink-soft">
                      No hay motivos de gasto activos: créalos en la pestaña «Motivos de gasto».
                    </p>
                  )}

                  {gastos.map((g) => (
                    <div key={g.clave} className="flex items-end gap-2">
                      <Desplegable
                        className="flex-1"
                        value={g.motivoGastoId}
                        onChange={(v) =>
                          setGastos((f) =>
                            f.map((x) =>
                              x.clave === g.clave ? { ...x, motivoGastoId: Number(v) } : x,
                            ),
                          )
                        }
                        options={motivosActivos.map((m) => ({ value: m.id, label: m.nombre }))}
                      />
                      <Input
                        className="w-28"
                        type="number"
                        step="0.01"
                        placeholder="0.00"
                        value={g.monto}
                        onChange={(e) =>
                          setGastos((f) =>
                            f.map((x) => (x.clave === g.clave ? { ...x, monto: e.target.value } : x)),
                          )
                        }
                      />
                      <Input
                        className="flex-1"
                        placeholder="Detalle..."
                        value={g.descripcion}
                        onChange={(e) =>
                          setGastos((f) =>
                            f.map((x) =>
                              x.clave === g.clave ? { ...x, descripcion: e.target.value } : x,
                            ),
                          )
                        }
                      />
                      <button
                        type="button"
                        aria-label="Quitar gasto"
                        onClick={() => setGastos((f) => f.filter((x) => x.clave !== g.clave))}
                        className="mb-1 cursor-pointer rounded-md p-1.5 text-red-600 transition-colors hover:bg-red-50"
                      >
                        <Trash2 size={15} />
                      </button>
                    </div>
                  ))}
                </div>

                <Totales
                  filas={[
                    { label: 'Total efectivo real', valor: totalEfectivoReal, fuerte: true },
                    { label: 'Sistema (debe traer)', valor: efectivoSistema },
                    { label: 'Diferencia', valor: diferenciaEfectivo, diferencia: true },
                  ]}
                />
              </section>

              {/* --- Derecha: lo digital --- */}
              <section className="flex flex-col gap-4">
                <Titulo icono={<Smartphone size={15} />}>Pagos digitales</Titulo>

                <ListaCobros
                  cobros={detalle?.digital ?? []}
                  vacio="El sistema no registra cobros digitales este día."
                />

                <div className="flex flex-col gap-3 rounded-panel border border-line p-3">
                  <BuscadorCampo
                    label="Cliente"
                    optional
                    placeholder="Buscar cliente..."
                    value={clientes.find((c) => c.id === nuevoPago.clienteId) ?? null}
                    onChange={(c) => setNuevoPago((p) => ({ ...p, clienteId: c?.id ?? null }))}
                    opciones={opcionesCliente}
                  />

                  <div className="grid gap-3 sm:grid-cols-2">
                    <Desplegable
                      label="Método de pago"
                      value={nuevoPago.metodoPagoId}
                      onChange={(v) => setNuevoPago((p) => ({ ...p, metodoPagoId: Number(v) }))}
                      placeholder="Elegir"
                      options={metodosDigitales.map((m) => ({ value: m.id, label: m.nombre }))}
                    />
                    <Input
                      label="N° de operación"
                      optional
                      placeholder="00123456"
                      value={nuevoPago.numeroOperacion}
                      onChange={(e) =>
                        setNuevoPago((p) => ({ ...p, numeroOperacion: e.target.value }))
                      }
                    />
                  </div>

                  <div className="flex items-end gap-2">
                    <Input
                      label="Monto"
                      type="number"
                      step="0.01"
                      placeholder="0.00"
                      value={nuevoPago.monto}
                      onChange={(e) => setNuevoPago((p) => ({ ...p, monto: e.target.value }))}
                    />
                    <Button size="sm" onClick={agregarPago} iconRight={<Plus size={15} />}>
                      Agregar
                    </Button>
                  </div>
                </div>

                {pagos.length > 0 && (
                  <div className="overflow-hidden rounded-panel border border-line">
                    {pagos.map((p) => (
                      <div
                        key={p.clave}
                        className="flex items-center justify-between gap-3 border-b border-line px-3 py-2 last:border-b-0"
                      >
                        <div className="min-w-0">
                          <p className="truncate text-[13px] text-ink">
                            {metodos.find((m) => m.id === p.metodoPagoId)?.nombre ?? 'Método'}
                            {p.numeroOperacion && (
                              <span className="ml-1.5 text-ink-soft">#{p.numeroOperacion}</span>
                            )}
                          </p>
                          <p className="truncate text-[11px] text-ink-soft">
                            {clientes.find((c) => c.id === p.clienteId)?.nombre ?? 'Sin cliente'}
                          </p>
                        </div>
                        <div className="flex shrink-0 items-center gap-2">
                          <span className="text-sm font-semibold text-ink tabular-nums">
                            {soles(numero(p.monto))}
                          </span>
                          <button
                            type="button"
                            aria-label="Quitar pago"
                            onClick={() => setPagos((f) => f.filter((x) => x.clave !== p.clave))}
                            className="cursor-pointer rounded-md p-1.5 text-red-600 transition-colors hover:bg-red-50"
                          >
                            <Trash2 size={15} />
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}

                <Totales
                  filas={[
                    { label: 'Total digital real', valor: totalDigitalReal, fuerte: true },
                    { label: 'Sistema (bancos)', valor: bancosSistema },
                    { label: 'Diferencia', valor: diferenciaBancos, diferencia: true },
                  ]}
                />
              </section>
            </div>

            {faltante > 0 ? (
              <div className="rounded-field border border-red-600 bg-red-50 p-3 text-sm text-red-700">
                <strong>Falta {soles(faltante)}.</strong> Queda como deuda de {usuario} hasta que se
                le descuente o lo reponga.
              </div>
            ) : sobrante > 0 ? (
              <div className="rounded-field border border-line bg-surface-alt p-3 text-sm text-ink-muted">
                Trae {soles(sobrante)} de más. Solo se informa: casi siempre es un cobro registrado
                mal, no dinero suyo.
              </div>
            ) : (
              <div className="rounded-field border border-emerald-200 bg-emerald-50 p-3 text-sm font-semibold text-emerald-700">
                Cuadra perfecto.
              </div>
            )}

            <Input
              label="Observación"
              optional
              placeholder="Alguna razón de la diferencia..."
              value={observacion}
              onChange={(e) => setObservacion(e.target.value)}
            />
          </>
        )}
      </div>
    </Modal>
  )
}

function Titulo({ icono, children }: { icono: React.ReactNode; children: React.ReactNode }) {
  return (
    <h3 className="flex items-center gap-2 text-sm font-bold text-ink">
      <span className="text-[rgb(var(--sys-ink-rgb))]">{icono}</span>
      {children}
    </h3>
  )
}

/** Los cobros que el sistema le atribuye: de quién, qué documento y cuánto. */
function ListaCobros({ cobros, vacio }: { cobros: CobroDelDiaResponse[]; vacio: string }) {
  if (cobros.length === 0) {
    return <p className="rounded-field border border-line px-3 py-4 text-center text-xs text-ink-soft">{vacio}</p>
  }

  return (
    <div className="max-h-56 overflow-y-auto rounded-panel border border-line">
      {cobros.map((c) => (
        <div
          key={c.pagoId}
          className="flex items-center justify-between gap-3 border-b border-line px-3 py-2 last:border-b-0"
        >
          <div className="min-w-0">
            <p className="flex items-center gap-1.5 truncate text-[13px] text-ink">
              {c.cliente}
              {c.esDeudaAnterior && (
                <Badge tone="warning">
                  <History size={11} className="mr-1" />
                  deuda anterior
                </Badge>
              )}
            </p>
            <p className="truncate text-[11px] text-ink-soft">
              {c.documento} · {c.metodoPago}
            </p>
          </div>
          <span className="shrink-0 text-sm font-semibold text-ink tabular-nums">
            {soles(c.monto)}
          </span>
        </div>
      ))}
    </div>
  )
}

interface FilaTotal {
  label: string
  valor: number
  /** El total contado: se destaca sobre las demás filas. */
  fuerte?: boolean
  /** Se colorea según cuadre, sobre o falte. */
  diferencia?: boolean
}

function Totales({ filas }: { filas: FilaTotal[] }) {
  return (
    <div className="rounded-panel border border-line">
      {filas.map((f) => (
        <div
          key={f.label}
          className="flex items-center justify-between gap-3 border-b border-line px-3 py-2 last:border-b-0"
        >
          <span className="text-xs font-semibold tracking-wide text-ink-soft uppercase">
            {f.label}
          </span>
          <span
            className={
              f.diferencia
                ? f.valor === 0
                  ? 'text-sm font-bold text-emerald-600 tabular-nums'
                  : f.valor > 0
                    ? 'text-sm font-bold text-ink-muted tabular-nums'
                    : 'text-sm font-bold text-red-600 tabular-nums'
                : f.fuerte
                  ? 'text-sm font-bold text-ink tabular-nums'
                  : 'text-sm text-ink-muted tabular-nums'
            }
          >
            {f.diferencia && f.valor > 0 ? '+' : ''}
            {soles(f.valor)}
          </span>
        </div>
      ))}
    </div>
  )
}

export { Coins }
