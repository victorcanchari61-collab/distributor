import { useCallback, useEffect, useMemo, useState } from 'react'
import { Banknote, History, Plus, Smartphone, Trash2 } from 'lucide-react'
import { Alert, Badge, Button, Checkbox, Desplegable, Input, Modal, Tabs } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { arqueoApi, motivoGastoApi } from './arqueoApi'
import type {
  ArqueoPagoDigitalResponse,
  CobroDelDiaResponse,
  DetalleCuadreResponse,
  MotivoGastoResponse,
} from './arqueoApi'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

/** Fila de gasto en edición: el id local sobrevive a reordenar y borrar. */
interface FilaGasto {
  clave: string
  motivoGastoId: number
  monto: string
  descripcion: string
}

/** Lo único que la persona decide de un cobro digital: si llegó y con qué número. */
interface ConfirmacionDigital {
  recibido: boolean
  numeroOperacion: string
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
 * El cuadre de una persona en un día, en dos pestañas: el efectivo que trae
 * contado a mano y los cobros digitales que confirma haber recibido.
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

  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [pestana, setPestana] = useState('efectivo')

  const [billetes, setBilletes] = useState('')
  const [monedas, setMonedas] = useState('')
  const [observacion, setObservacion] = useState('')
  const [gastos, setGastos] = useState<FilaGasto[]>([])

  // Una entrada por cobro digital del sistema, indexada por su pagoId: la
  // persona no declara pagos, solo confirma los que el sistema ya conoce.
  const [confirmaciones, setConfirmaciones] = useState<Record<number, ConfirmacionDigital>>({})

  // Pagos de un cuadre anterior cuyo cobro ya no existe (se anuló después).
  // Se muestran en solo lectura para que el cuadre guardado no cambie de cifras
  // sin que nadie sepa por qué.
  const [digitalesHuerfanos, setDigitalesHuerfanos] = useState<ArqueoPagoDigitalResponse[]>([])

  const cargar = useCallback(async () => {
    setCargando(true)
    setError('')
    setPestana('efectivo')
    try {
      const [d, m] = await Promise.all([arqueoApi.detalle(fecha, usuarioId), motivoGastoApi.getAll()])

      setDetalle(d)
      setMotivos(m)

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

      const guardados = a?.pagosDigitales ?? []
      const porPago = new Map(
        guardados.filter((p) => p.pagoVentaId !== null).map((p) => [p.pagoVentaId as number, p]),
      )

      setConfirmaciones(
        Object.fromEntries(
          d.digital.map((c) => {
            const guardado = porPago.get(c.pagoId)
            return [
              c.pagoId,
              {
                // Sin cuadre previo se asume que el cobro sí llegó: desmarcar es
                // señalar la excepción, no confirmar uno por uno lo normal.
                recibido: a ? guardado !== undefined : true,
                numeroOperacion: guardado?.numeroOperacion ?? '',
              },
            ]
          }),
        ),
      )

      const vigentes = new Set(d.digital.map((c) => c.pagoId))
      setDigitalesHuerfanos(
        guardados.filter((p) => p.pagoVentaId === null || !vigentes.has(p.pagoVentaId)),
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

  const motivosActivos = useMemo(() => motivos.filter((m) => m.activo), [motivos])

  const numero = (texto: string) => {
    const n = Number(String(texto).replace(',', '.'))
    return Number.isFinite(n) ? n : 0
  }

  const cobrosDigitales = detalle?.digital ?? []

  const totalGastos = gastos.reduce((s, g) => s + numero(g.monto), 0)
  const totalEfectivoReal = numero(billetes) + numero(monedas) + totalGastos
  const totalDigitalReal = cobrosDigitales.reduce(
    (s, c) => (confirmaciones[c.pagoId]?.recibido ? s + c.monto : s),
    0,
  )

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

  const cambiarConfirmacion = (pagoId: number, cambio: Partial<ConfirmacionDigital>) =>
    setConfirmaciones((c) => ({
      ...c,
      [pagoId]: { ...(c[pagoId] ?? { recibido: true, numeroOperacion: '' }), ...cambio },
    }))

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
        pagosDigitales: cobrosDigitales
          .filter((c) => confirmaciones[c.pagoId]?.recibido)
          .map((c) => ({
            pagoVentaId: c.pagoId,
            // El cobro ya sabe de quién es; el cliente solo viajaba como rastro.
            clienteId: null,
            metodoPagoId: c.metodoPagoId,
            numeroOperacion: confirmaciones[c.pagoId]?.numeroOperacion.trim() || null,
            monto: c.monto,
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

  /** El estado de una pestaña, en su propia cabecera: dónde está el problema. */
  const rotulo = (nombre: string, diferencia: number) =>
    diferencia === 0
      ? `${nombre} · cuadra`
      : diferencia < 0
        ? `${nombre} · falta ${soles(-diferencia)}`
        : `${nombre} · sobra ${soles(diferencia)}`

  return (
    <Modal
      open={open}
      size="lg"
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
            <Tabs
              active={pestana}
              onChange={setPestana}
              items={[
                {
                  id: 'efectivo',
                  label: rotulo('Efectivo', diferenciaEfectivo),
                  icon: <Banknote size={15} />,
                },
                {
                  id: 'digital',
                  label: rotulo('Digital', diferenciaBancos),
                  icon: <Smartphone size={15} />,
                },
              ]}
            />

            {pestana === 'efectivo' ? (
              <section className="flex flex-col gap-4">
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
            ) : (
              <section className="flex flex-col gap-4">
                <p className="text-xs text-ink-soft">
                  Estos son los cobros digitales que el sistema le atribuye. Desmarca los que no
                  hayan llegado y anota el número de operación de los que sí, para poder buscarlos
                  después en el estado de cuenta.
                </p>

                {cobrosDigitales.length === 0 ? (
                  <p className="rounded-field border border-line px-3 py-4 text-center text-xs text-ink-soft">
                    El sistema no registra cobros digitales este día.
                  </p>
                ) : (
                  <div className="overflow-hidden rounded-panel border border-line">
                    {cobrosDigitales.map((c) => {
                      const conf = confirmaciones[c.pagoId]
                      const recibido = conf?.recibido ?? false
                      return (
                        <div
                          key={c.pagoId}
                          className="flex flex-wrap items-center gap-3 border-b border-line px-3 py-2 last:border-b-0"
                        >
                          <Checkbox
                            label=""
                            aria-label={`Confirmar el cobro de ${c.cliente}`}
                            checked={recibido}
                            onChange={(e) =>
                              cambiarConfirmacion(c.pagoId, { recibido: e.target.checked })
                            }
                          />
                          <div className="min-w-0 flex-1">
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
                          <Input
                            className="w-36"
                            placeholder="N° operación"
                            disabled={!recibido}
                            value={conf?.numeroOperacion ?? ''}
                            onChange={(e) =>
                              cambiarConfirmacion(c.pagoId, { numeroOperacion: e.target.value })
                            }
                          />
                          <span
                            className={
                              recibido
                                ? 'w-24 shrink-0 text-right text-sm font-semibold text-ink tabular-nums'
                                : 'w-24 shrink-0 text-right text-sm text-ink-soft line-through tabular-nums'
                            }
                          >
                            {soles(c.monto)}
                          </span>
                        </div>
                      )
                    })}
                  </div>
                )}

                {digitalesHuerfanos.length > 0 && (
                  <div className="flex flex-col gap-2">
                    <span className="ui-label">Confirmados en su día, ya sin cobro</span>
                    <p className="text-xs text-ink-soft">
                      El cobro se anuló después de cuadrar. Se listan para explicar la diferencia;
                      no suman al total ni se vuelven a guardar.
                    </p>
                    <div className="overflow-hidden rounded-panel border border-line opacity-70">
                      {digitalesHuerfanos.map((p) => (
                        <div
                          key={p.id}
                          className="flex items-center justify-between gap-3 border-b border-line px-3 py-2 last:border-b-0"
                        >
                          <div className="min-w-0">
                            <p className="truncate text-[13px] text-ink">
                              {p.metodoPago}
                              {p.numeroOperacion && (
                                <span className="ml-1.5 text-ink-soft">#{p.numeroOperacion}</span>
                              )}
                            </p>
                            <p className="truncate text-[11px] text-ink-soft">
                              {p.cliente ?? 'Sin cliente'}
                            </p>
                          </div>
                          <span className="shrink-0 text-sm text-ink-soft tabular-nums">
                            {soles(p.monto)}
                          </span>
                        </div>
                      ))}
                    </div>
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
            )}

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

/** Los cobros que el sistema le atribuye: de quién, qué documento y cuánto. */
function ListaCobros({ cobros, vacio }: { cobros: CobroDelDiaResponse[]; vacio: string }) {
  if (cobros.length === 0) {
    return (
      <p className="rounded-field border border-line px-3 py-4 text-center text-xs text-ink-soft">
        {vacio}
      </p>
    )
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

/**
 * Los tres importes del cuadre, en una sola fila.
 *
 * Apilados ocupaban tres renglones para decir una cosa: lo que trajo, lo que
 * debía traer y en cuánto se aparta. Puestos uno junto a otro se leen como la
 * resta que son, y el modal deja de crecer hacia abajo justo donde hay que
 * mirar las dos pestañas.
 *
 * En pantalla estrecha vuelven a apilarse: tres cifras en una fila de móvil se
 * cortan y dejan de leerse.
 */
function Totales({ filas }: { filas: FilaTotal[] }) {
  return (
    <div className="grid gap-px overflow-hidden rounded-panel border border-line bg-line sm:grid-cols-3">
      {filas.map((f) => (
        <div key={f.label} className="flex flex-col gap-0.5 bg-surface px-3 py-2">
          <span className="text-[11px] font-semibold tracking-wide text-ink-soft uppercase">
            {f.label}
          </span>
          <span
            className={
              f.diferencia
                ? f.valor === 0
                  ? 'text-base font-bold text-emerald-600 tabular-nums'
                  : f.valor > 0
                    ? 'text-base font-bold text-ink-muted tabular-nums'
                    : 'text-base font-bold text-red-600 tabular-nums'
                : f.fuerte
                  ? 'text-base font-bold text-ink tabular-nums'
                  : 'text-base text-ink-muted tabular-nums'
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
