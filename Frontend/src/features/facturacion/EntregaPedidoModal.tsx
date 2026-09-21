import { useEffect, useMemo, useState } from 'react'
import { Alert, Badge, Button, Desplegable, Input, Modal, Tabs } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { motivoNovedadApi } from '../tms/motivoNovedadApi'
import type { MotivoNovedadOpcion } from '../tms/motivoNovedadApi'
import { metodoPagoApi } from '../finanzas/finanzasApi'
import type { MetodoPagoOpcion } from '../finanzas/finanzasApi'
import { stockApi } from '../inventario'
import type { AlmacenOpcion } from '../inventario'
import { PagoEntrega, resumenPago } from './PagoEntrega'
import type { FilaPagoEntrega } from './PagoEntrega'
import { pedidoApi } from './ventasApi'
import type { LineaEntregaRequest, LineaVentaResponse, PedidoResponse } from './ventasApi'

/** Lo tecleado para una línea, tal cual: se convierte a número solo al calcular. */
interface Entrega {
  /** Cajas (o la unidad misma cuando la presentación es la base). */
  pres: string
  /** Unidades sueltas sobre las cajas, en unidad base. */
  sueltas: string
  motivoId: number
  observacion: string
}

const redondear = (n: number) => Math.round(n * 10000) / 10000
const numero = (texto: string) => (texto.trim() === '' ? 0 : Number(texto))
const cantidadTexto = (n: number) => String(redondear(n))
const soles = (n: number) => `S/ ${n.toFixed(2)}`

/** Cuántas unidades base trae una presentación de esa línea. */
const factorDe = (l: LineaVentaResponse) =>
  l.cantidadPresentacion > 0 ? l.cantidad / l.cantidadPresentacion : 1

/** Lo pedido, partido en cajas enteras y unidades sueltas: 10 cajas de 12 son "10" y "0". */
function entregaCompleta(l: LineaVentaResponse): Entrega {
  const factor = factorDe(l)
  if (factor <= 1) {
    return { pres: cantidadTexto(l.cantidad), sueltas: '0', motivoId: 0, observacion: '' }
  }
  const cajas = Math.floor(l.cantidadPresentacion + 1e-6)
  return {
    pres: String(cajas),
    sueltas: cantidadTexto(l.cantidad - cajas * factor),
    motivoId: 0,
    observacion: '',
  }
}

/** Lo entregado, en unidad base. */
function entregadaBase(l: LineaVentaResponse, e: Entrega) {
  const factor = factorDe(l)
  return redondear(factor <= 1 ? numero(e.pres) : numero(e.pres) * factor + numero(e.sueltas))
}

/** Una cantidad en unidad base, dicha como se cuenta en el almacén: "4 Saco 50 kg y 48 KG". */
function enPresentaciones(base: number, factor: number, presentacion: string, unidadBase: string) {
  if (factor <= 1) return `${cantidadTexto(base)} ${unidadBase}`
  const enteras = Math.floor(base / factor + 1e-6)
  const resto = redondear(base - enteras * factor)
  const partes = []
  if (enteras > 0) partes.push(`${enteras} ${presentacion}`)
  if (resto > 0 || partes.length === 0) partes.push(`${cantidadTexto(resto)} ${unidadBase}`)
  return partes.join(' y ')
}

/** Lo entregado, partido en presentaciones enteras y sueltas: 248 kg son "4" y "48". */
function partirBase(l: LineaVentaResponse, base: number): Pick<Entrega, 'pres' | 'sueltas'> {
  const factor = factorDe(l)
  if (factor <= 1) return { pres: cantidadTexto(base), sueltas: '0' }
  const enteras = Math.floor(base / factor + 1e-6)
  return { pres: String(enteras), sueltas: cantidadTexto(base - enteras * factor) }
}

type Pestana = 'entrega' | 'pago'

interface EntregaPedidoModalProps {
  /** El pedido que se va a convertir en venta; null lo deja cerrado. */
  pedido: PedidoResponse | null
  almacenes: AlmacenOpcion[]
  onClose: () => void
  /** Ya se convirtió: quien lo abrió recarga su lista. Recibe qué pasó con el cobro. */
  onHecho: (mensaje: string) => void
}

/**
 * Convertir un pedido en venta, con lo que de verdad se entregó y se cobró.
 *
 * Dos pestañas. En "Entrega": por defecto sale todo lo pedido; si el cliente
 * recibió menos —una caja de menos, unas unidades sueltas, un producto que no
 * estaba— se corrige la línea y se pide el motivo: la venta lleva y cobra solo
 * lo entregado, y lo que quedó corto queda registrado como novedad.
 *
 * En "Pago": lo que el cliente pagó al recibir. La condición de pago del
 * pedido es solo lo acordado; manda lo cobrado. Si cubre el total la venta es
 * al contado, y si no queda a crédito con ese adelanto.
 */
export function EntregaPedidoModal({ pedido, almacenes, onClose, onHecho }: EntregaPedidoModalProps) {
  const [pestana, setPestana] = useState<Pestana>('entrega')
  const [almacenId, setAlmacenId] = useState(0)
  const [entregas, setEntregas] = useState<Record<number, Entrega>>({})
  const [motivos, setMotivos] = useState<MotivoNovedadOpcion[]>([])
  // Sin esto el aviso de "no hay motivos" parpadea mientras la lista carga.
  const [motivosListos, setMotivosListos] = useState(false)
  const [metodos, setMetodos] = useState<MetodoPagoOpcion[]>([])
  const [metodosListos, setMetodosListos] = useState(false)
  const [pagos, setPagos] = useState<FilaPagoEntrega[]>([])
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')
  /** Lo que se puede prometer por producto en el almacén de donde sale; null mientras carga. */
  const [disponible, setDisponible] = useState<Record<number, number> | null>(null)

  const lineas = useMemo(() => pedido?.detalle.filter((l) => !l.anulado) ?? [], [pedido])

  useEffect(() => {
    if (!pedido) return
    // Con reserva, el stock ya está apartado en un almacén: de ahí sale, y
    // preguntarlo otra vez invita a elegir otro y dejar la reserva colgada.
    setAlmacenId(pedido.reservaStock ? (pedido.almacenId ?? 0) : 0)
    setEntregas(Object.fromEntries(lineas.map((l) => [l.id, entregaCompleta(l)])))
    setPagos([])
    setPestana('entrega')
    setError('')

    setMotivosListos(false)
    setMetodosListos(false)
    let cancelado = false

    void motivoNovedadApi
      .opciones()
      .then((m) => {
        if (!cancelado) setMotivos(m)
      })
      .catch(() => {
        if (!cancelado) setMotivos([])
      })
      .finally(() => {
        if (!cancelado) setMotivosListos(true)
      })

    void metodoPagoApi
      .opciones()
      .then((m) => {
        if (!cancelado) setMetodos(m)
      })
      .catch(() => {
        if (!cancelado) setMetodos([])
      })
      .finally(() => {
        if (!cancelado) setMetodosListos(true)
      })

    return () => {
      cancelado = true
    }
  }, [pedido, lineas])

  // Sin reserva se sale del almacén principal, salvo que se elija otro: quien tiene un solo depósito
  // (o casi siempre despacha del mismo) no debería tener que buscarlo en cada conversión. Va aparte
  // del efecto de arriba para no borrar lo entregado si la lista de almacenes se recarga.
  useEffect(() => {
    if (!pedido || pedido.reservaStock || almacenId) return
    setAlmacenId(almacenes.find((a) => a.esPrincipal)?.id ?? almacenes[0]?.id ?? 0)
  }, [pedido, almacenes, almacenId])

  // De dónde sale la mercadería: el almacén de la reserva, o el elegido.
  const almacenDeSalida = pedido?.reservaStock ? (pedido.almacenId ?? 0) : almacenId

  useEffect(() => {
    setDisponible(null)
    if (!pedido || !almacenDeSalida) return
    let cancelado = false
    void stockApi
      .disponible(almacenDeSalida)
      .then((filas) => {
        if (!cancelado) setDisponible(Object.fromEntries(filas.map((f) => [f.productoId, f.disponible])))
      })
      .catch(() => {
        // Sin stock a la vista no se bloquea: el servidor lo vuelve a validar al convertir.
        if (!cancelado) setDisponible(null)
      })
    return () => {
      cancelado = true
    }
  }, [pedido, almacenDeSalida])

  const cambiar = (id: number, parcial: Partial<Entrega>) => {
    setError('')
    setEntregas((prev) => ({ ...prev, [id]: { ...prev[id], ...parcial } }))
  }

  /*
   * Cuánto se puede entregar de cada producto.
   *
   * Es lo disponible en el almacén; si el pedido apartó stock, esa reserva ya está descontada de
   * lo disponible y es justamente lo que este pedido puede sacar, así que se le suma de vuelta.
   */
  const tope = (productoId: number): number | null => {
    if (!disponible) return null
    const reservado = pedido?.reservaStock
      ? lineas.filter((l) => l.productoId === productoId).reduce((s, l) => s + l.cantidad, 0)
      : 0
    return redondear((disponible[productoId] ?? 0) + reservado)
  }

  // Lo que sale de cada línea, ya calculado: lo usan la pantalla y el envío.
  const base = lineas.map((l) => {
    const e = entregas[l.id] ?? entregaCompleta(l)
    const entregada = entregadaBase(l, e)
    const factor = factorDe(l)
    return {
      linea: l,
      entrega: e,
      entregada,
      factor,
      reducida: entregada < l.cantidad - 1e-6,
      excede: entregada > l.cantidad + 1e-6,
      subtotal: (entregada / factor) * l.precioPresentacion,
    }
  })

  // Dos líneas del mismo producto comparten el mismo stock: se compara la suma.
  const calculo = base.map((c) => {
    const hay = tope(c.linea.productoId)
    const pedidoDelProducto = base
      .filter((o) => o.linea.productoId === c.linea.productoId)
      .reduce((s, o) => s + o.entregada, 0)
    return {
      ...c,
      hay,
      sinStock: hay !== null && pedidoDelProducto > hay + 1e-6,
    }
  })

  const total = calculo.reduce((suma, c) => suma + c.subtotal, 0)
  const hayRecortes = calculo.some((c) => c.reducida)
  const cobro = resumenPago(pagos, total)

  /** Un fallo de validación: se muestra arriba y se lleva a la pestaña donde se arregla. */
  const fallar = (mensaje: string, en: Pestana) => {
    setPestana(en)
    setError(mensaje)
  }

  const convertir = async () => {
    if (!pedido) return
    if (!pedido.reservaStock && !almacenId) return fallar('Elige el almacén.', 'entrega')

    for (const c of calculo) {
      if (c.excede) return fallar(`${c.linea.producto}: no se puede entregar más de lo pedido.`, 'entrega')
      if (c.sinStock) {
        return fallar(
          `${c.linea.producto}: no alcanza el stock (hay ${enPresentaciones(c.hay ?? 0, c.factor, c.linea.presentacion ?? c.linea.unidadBase, c.linea.unidadBase)}). Baja la cantidad o usa "Entregar lo que hay".`,
          'entrega',
        )
      }
      if (c.reducida && !c.entrega.motivoId) {
        return fallar(`Elige el motivo por el que ${c.linea.producto} se entrega en menos.`, 'entrega')
      }
    }
    if (calculo.every((c) => c.entregada <= 0)) {
      return fallar(
        'No queda nada por entregar. Si el cliente no recibió nada, márcalo como "No entregado".',
        'entrega',
      )
    }

    if (cobro.pendiente) {
      return fallar('Hay un pago sin guardar: guárdalo con el visto o cancélalo antes de convertir.', 'pago')
    }
    if (cobro.sobra) {
      return fallar(`Lo cobrado (${soles(cobro.pagado)}) supera el total de la venta (${soles(total)}).`, 'pago')
    }

    const lineasEntrega: LineaEntregaRequest[] = calculo
      .filter((c) => c.reducida)
      .map((c) => ({
        pedidoDetalleId: c.linea.id,
        cantidad: c.entregada,
        motivoId: c.entrega.motivoId,
        observacion: c.entrega.observacion.trim() || null,
      }))

    setGuardando(true)
    setError('')
    try {
      await pedidoApi.confirmar(pedido.id, {
        almacenId: pedido.reservaStock ? null : almacenId,
        lineas: lineasEntrega,
        pagos: cobro.usadas.map((f) => ({ metodoPagoId: f.metodoPagoId, monto: Number(f.monto) })),
      })

      onHecho(
        cobro.completo
          ? `Pedido convertido: venta al contado, cobrada (${soles(cobro.pagado)}).`
          : cobro.pagado > 0
            ? `Pedido convertido: cobrado ${soles(cobro.pagado)}, quedan ${soles(cobro.saldo)} a crédito.`
            : `Pedido convertido: venta a crédito por ${soles(total)}.`,
      )
    } catch (e) {
      setError(
        e instanceof ApiError ? (e.errors.length ? e.errors.join(' ') : e.message) : 'No pudimos convertir el pedido.',
      )
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal
      open={pedido !== null}
      onClose={onClose}
      size="xl"
      title={pedido ? `Convertir ${pedido.numero} en venta` : ''}
      description={pedido ? pedido.cliente : undefined}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void convertir()}>
            Convertir en venta
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        {error && <Alert>{error}</Alert>}

        <Tabs
          items={[
            { id: 'entrega', label: 'Entrega' },
            { id: 'pago', label: 'Pago', badge: cobro.usadas.length || undefined },
          ]}
          active={pestana}
          onChange={(id) => setPestana(id as Pestana)}
        />

        {pestana === 'entrega' && (
          <>
            {pedido?.reservaStock ? (
              <div>
                <span className="ui-label mb-1.5 block">Almacén</span>
                <div className="flex items-center gap-2 rounded-field border border-line px-3 py-2 text-sm">
                  <span className="text-ink">{pedido.almacen}</span>
                  <Badge tone="sys">stock reservado</Badge>
                </div>
              </div>
            ) : (
              <Desplegable
                label="Almacén"
                value={almacenId}
                onChange={(v) => {
                  setAlmacenId(Number(v))
                  setError('')
                }}
                placeholder="Elige de dónde sale la mercadería"
                options={almacenes.map((a) => ({ value: a.id, label: a.nombre }))}
              />
            )}

            <div>
              <span className="ui-label mb-1.5 block">Lo que se entregó</span>
              <p className="mb-2 text-xs text-ink-soft">
                Por defecto sale todo lo pedido. Si el cliente recibió menos, corrige la cantidad y elige el motivo: la
                venta cobra solo lo entregado.
              </p>

              <div className="divide-y divide-line rounded-field border border-line">
                {calculo.map((c) => {
                  const l = c.linea
                  const conSueltas = c.factor > 1
                  const nombrePres = l.presentacion ?? l.unidadBase
                  const alcanzaTodo = c.hay === null || c.hay >= l.cantidad - 1e-6
                  return (
                    <div key={l.id} className="flex flex-col gap-2 px-3 py-2.5">
                      <div className="flex flex-wrap items-start justify-between gap-x-4 gap-y-2">
                        <div className="min-w-0 flex-1 basis-56">
                          <p className="truncate text-sm font-semibold text-ink">{l.producto}</p>
                          <p className="text-xs text-ink-soft">
                            {l.codigo} · Pedido: {cantidadTexto(l.cantidadPresentacion)} {nombrePres}
                            {conSueltas && ` (${cantidadTexto(l.cantidad)} ${l.unidadBase})`}
                          </p>
                          {c.hay !== null && (
                            <p className={alcanzaTodo ? 'text-xs text-ink-soft' : 'text-xs font-medium text-red-600'}>
                              Hay en el almacén: {enPresentaciones(c.hay, c.factor, nombrePres, l.unidadBase)}
                              {conSueltas && c.hay > 0 && ` (${cantidadTexto(c.hay)} ${l.unidadBase})`}
                            </p>
                          )}
                        </div>

                        <div className="flex items-end gap-2">
                          <div className="w-24">
                            <Input
                              label={conSueltas ? nombrePres : l.unidadBase}
                              size="sm"
                              type="number"
                              min={0}
                              step={conSueltas ? 1 : 'any'}
                              value={c.entrega.pres}
                              onChange={(e) => cambiar(l.id, { pres: e.target.value })}
                            />
                          </div>
                          {conSueltas && (
                            <>
                              <span className="pb-2 text-sm text-ink-soft">+</span>
                              <div className="w-24">
                                <Input
                                  label={`${l.unidadBase} sueltos`}
                                  size="sm"
                                  type="number"
                                  min={0}
                                  step="any"
                                  value={c.entrega.sueltas}
                                  onChange={(e) => cambiar(l.id, { sueltas: e.target.value })}
                                />
                              </div>
                            </>
                          )}
                          <div className="w-24 pb-2 text-right text-sm font-semibold text-ink">
                            {soles(c.subtotal)}
                          </div>
                        </div>
                      </div>

                      {/* Lo que se entrega, dicho de una vez: cuenta lo que sale sin que haya que multiplicar. */}
                      {conSueltas && !c.excede && !c.sinStock && c.entregada > 0 && (
                        <p className="text-xs text-ink-soft">
                          Entrega {enPresentaciones(c.entregada, c.factor, nombrePres, l.unidadBase)} ={' '}
                          {cantidadTexto(c.entregada)} {l.unidadBase}
                        </p>
                      )}

                      {c.excede && (
                        <p className="text-xs font-medium text-red-600">
                          No puede ser más de lo pedido ({cantidadTexto(l.cantidad)} {l.unidadBase}).
                        </p>
                      )}

                      {c.sinStock && !c.excede && (
                        <div className="flex flex-wrap items-center justify-between gap-2 text-xs font-medium text-red-600">
                          <span>
                            No alcanza el stock: se quieren entregar {cantidadTexto(c.entregada)} {l.unidadBase} y hay{' '}
                            {cantidadTexto(c.hay ?? 0)}.
                          </span>
                          <Button
                            variant="secondary"
                            size="sm"
                            onClick={() =>
                              cambiar(l.id, { ...partirBase(l, Math.min(l.cantidad, c.hay ?? 0)) })
                            }
                          >
                            Entregar lo que hay
                          </Button>
                        </div>
                      )}

                      {c.reducida && !c.excede && (
                        <div className="flex flex-col gap-2 rounded-field border border-line bg-slate-50 p-2.5">
                          <p className="text-xs text-ink-muted">
                            {c.entregada <= 0 ? (
                              'No se entrega este producto.'
                            ) : (
                              <>
                                Se entrega {cantidadTexto(c.entregada)} de {cantidadTexto(l.cantidad)} {l.unidadBase}
                              </>
                            )}{' '}
                            ·{' '}
                            <span className="font-semibold text-ink">
                              falta {cantidadTexto(l.cantidad - c.entregada)} {l.unidadBase}
                            </span>
                            . Se registra como novedad: elige el motivo.
                          </p>
                          <div className="grid gap-2 sm:grid-cols-2">
                            <Desplegable
                              label="Motivo"
                              size="sm"
                              value={c.entrega.motivoId}
                              onChange={(v) => cambiar(l.id, { motivoId: Number(v) })}
                              placeholder="¿Por qué se entrega menos?"
                              options={motivos.map((m) => ({
                                value: m.id,
                                label: m.nombre,
                                nota: m.descripcion ?? undefined,
                              }))}
                            />
                            <Input
                              label="Observación"
                              optional
                              size="sm"
                              maxLength={250}
                              value={c.entrega.observacion}
                              onChange={(e) => cambiar(l.id, { observacion: e.target.value })}
                            />
                          </div>
                        </div>
                      )}
                    </div>
                  )
                })}
              </div>

              {hayRecortes && motivosListos && motivos.length === 0 && (
                <div className="mt-2">
                  <Alert tone="info">
                    Todavía no hay motivos de novedad. Pídele a quien administra que los cree en TMS → Motivos de
                    novedad.
                  </Alert>
                </div>
              )}
            </div>

            <p className="text-xs text-ink-soft">
              El cobro se registra en la pestaña Pago. Si no se cobra nada, la venta queda a crédito.
            </p>
          </>
        )}

        {pestana === 'pago' && (
          <PagoEntrega
            pedido={pedido}
            metodos={metodos}
            metodosListos={metodosListos}
            filas={pagos}
            total={total}
            onFilas={(filas) => {
              setError('')
              setPagos(filas)
            }}
          />
        )}

        {/* En Pago el total ya está en el card "A cobrar": repetirlo sobra. */}
        {pestana === 'entrega' && (
          <div className="flex flex-col gap-1 border-t border-line pt-3 text-sm">
            {hayRecortes && (
              <div className="flex items-center justify-between text-ink-soft">
                <span>Total del pedido</span>
                <span>{soles(pedido?.total ?? 0)}</span>
              </div>
            )}
            <div className="flex items-center justify-between font-semibold">
              <span>{hayRecortes ? 'Total a cobrar' : 'Total'}</span>
              <span className="text-ink">{soles(total)}</span>
            </div>
          </div>
        )}
      </div>
    </Modal>
  )
}

interface NoEntregadoModalProps {
  pedido: PedidoResponse | null
  onClose: () => void
  onHecho: () => void
}

/**
 * El pedido entero no se entregó: no había nadie, cerró, no quiso recibirlo.
 * No nace ninguna venta y el pedido sigue Pendiente; queda la novedad con su
 * motivo para revisarla al volver el camión.
 */
export function NoEntregadoModal({ pedido, onClose, onHecho }: NoEntregadoModalProps) {
  const [motivos, setMotivos] = useState<MotivoNovedadOpcion[]>([])
  // Sin esto el aviso de "no hay motivos" parpadea mientras la lista carga.
  const [motivosListos, setMotivosListos] = useState(false)
  const [motivoId, setMotivoId] = useState(0)
  const [observacion, setObservacion] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!pedido) return
    setMotivoId(0)
    setObservacion('')
    setError('')

    setMotivosListos(false)
    let cancelado = false
    void motivoNovedadApi
      .opciones()
      .then((m) => {
        if (!cancelado) setMotivos(m)
      })
      .catch(() => {
        if (!cancelado) setMotivos([])
      })
      .finally(() => {
        if (!cancelado) setMotivosListos(true)
      })
    return () => {
      cancelado = true
    }
  }, [pedido])

  const guardar = async () => {
    if (!pedido) return
    if (!motivoId) return setError('Elige el motivo por el que no se entregó.')

    setGuardando(true)
    setError('')
    try {
      await pedidoApi.noEntregado(pedido.id, { motivoId, observacion: observacion.trim() || null })
      onHecho()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos marcar el pedido como no entregado.')
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal
      open={pedido !== null}
      onClose={onClose}
      size="sm"
      title={pedido ? `${pedido.numero} no se entregó` : ''}
      description={pedido ? pedido.cliente : undefined}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            Marcar como no entregado
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        {error && <Alert>{error}</Alert>}

        <p className="text-xs text-ink-soft">
          No se crea ninguna venta ni sale stock. El pedido sigue pendiente: puedes intentarlo de nuevo o anularlo.
        </p>

        <Desplegable
          label="Motivo"
          value={motivoId}
          onChange={(v) => {
            setMotivoId(Number(v))
            setError('')
          }}
          placeholder="¿Por qué no se entregó?"
          options={motivos.map((m) => ({ value: m.id, label: m.nombre, nota: m.descripcion ?? undefined }))}
        />

        {motivosListos && motivos.length === 0 && (
          <Alert tone="warning">
            Todavía no hay motivos de novedad. Pídele a quien administra que los cree en TMS → Motivos de novedad.
          </Alert>
        )}

        <Input
          label="Observación"
          optional
          maxLength={250}
          value={observacion}
          onChange={(e) => setObservacion(e.target.value)}
        />
      </div>
    </Modal>
  )
}
