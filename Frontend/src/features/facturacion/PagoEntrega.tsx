import { CheckCircle2, Plus, Trash2, Wallet } from 'lucide-react'
import { Alert, Badge, Button, Desplegable, Input, RowAction } from '../../components/ui'
import type { MetodoPagoOpcion, TipoMetodoPago } from '../finanzas/finanzasApi'
import type { PedidoResponse } from './ventasApi'

/** Un pago tal como se teclea: el monto queda como texto hasta que se calcula. */
export interface FilaPagoEntrega {
  clave: number
  tipo: TipoMetodoPago | ''
  metodoPagoId: number
  monto: string
}

const TIPOS: { value: TipoMetodoPago; label: string }[] = [
  { value: 'EFECTIVO', label: 'Efectivo' },
  { value: 'BILLETERA_DIGITAL', label: 'Billetera digital' },
  { value: 'TRANSFERENCIA', label: 'Transferencia' },
]

let contador = 0
const nuevaClave = () => ++contador

const redondear = (n: number) => Math.round(n * 100) / 100
const monto = (fila: FilaPagoEntrega) => (fila.monto.trim() === '' ? 0 : Number(fila.monto))
const soles = (n: number) => `S/ ${n.toFixed(2)}`

/** Una fila en blanco, lista para llenar. */
export const filaPagoVacia = (): FilaPagoEntrega => ({ clave: nuevaClave(), tipo: '', metodoPagoId: 0, monto: '' })

/**
 * Lo que dicen los pagos tecleados frente al total a cobrar.
 *
 * Una fila sin método ni monto es una fila que nadie llenó y no cuenta; una a
 * medias —solo el monto, o solo el método— sí es un error y se avisa.
 */
export function resumenPago(filas: FilaPagoEntrega[], total: number) {
  const usadas = filas.filter((f) => f.metodoPagoId !== 0 || monto(f) > 0)
  const incompletas = usadas.some((f) => f.metodoPagoId === 0 || !(monto(f) > 0))
  const pagado = redondear(usadas.reduce((suma, f) => suma + (monto(f) > 0 ? monto(f) : 0), 0))
  const totalRedondo = redondear(total)

  return {
    usadas,
    incompletas,
    pagado,
    saldo: redondear(totalRedondo - pagado),
    sobra: pagado > totalRedondo + 0.001,
    completo: pagado > 0 && pagado >= totalRedondo - 0.001,
  }
}

interface PagoEntregaProps {
  pedido: PedidoResponse | null
  metodos: MetodoPagoOpcion[]
  metodosListos: boolean
  filas: FilaPagoEntrega[]
  /** Lo que se cobra: lo entregado, ya con los recortes. */
  total: number
  onFilas: (filas: FilaPagoEntrega[]) => void
}

/**
 * La pestaña de pago al entregar.
 *
 * La condición de pago del pedido es solo lo acordado: al repartir, quien iba a
 * pagar a crédito a veces paga todo o una parte, y quien iba al contado a veces
 * paga solo una parte o nada. Aquí se registra lo que de verdad se cobra, en
 * uno o varios métodos, y la venta queda al contado si eso cubre el total o a
 * crédito con ese adelanto si no.
 */
export function PagoEntrega({ pedido, metodos, metodosListos, filas, total, onFilas }: PagoEntregaProps) {
  const r = resumenPago(filas, total)

  const cambiar = (clave: number, parcial: Partial<FilaPagoEntrega>) =>
    onFilas(filas.map((f) => (f.clave === clave ? { ...f, ...parcial } : f)))

  const quitar = (clave: number) => onFilas(filas.filter((f) => f.clave !== clave))

  /*
   * "Cobrar todo": una fila con lo que falta, en efectivo si hay un método así,
   * que es lo que se cobra casi siempre en la puerta del cliente.
   */
  const cobrarTodo = () => {
    const efectivo = metodos.find((m) => m.tipo === 'EFECTIVO')
    const falta = Math.max(r.saldo, 0)
    // Si ya hay una fila en blanco, se llena esa en vez de sumar otra.
    const vacia = filas.find((f) => f.metodoPagoId === 0 && f.monto.trim() === '')
    const llena: FilaPagoEntrega = {
      clave: vacia?.clave ?? nuevaClave(),
      tipo: efectivo ? 'EFECTIVO' : '',
      metodoPagoId: efectivo?.id ?? 0,
      monto: falta > 0 ? falta.toFixed(2) : '',
    }
    onFilas(vacia ? filas.map((f) => (f.clave === vacia.clave ? llena : f)) : [...filas, llena])
  }

  const acordado = pedido?.condicionPago === 'CREDITO' ? 'Crédito' : 'Contado'

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-2 rounded-field bg-surface-alt px-3 py-2 text-xs text-ink-soft">
        <span>Acordado con el cliente:</span>
        <Badge tone={pedido?.condicionPago === 'CREDITO' ? 'warning' : 'success'}>{acordado}</Badge>
        <span>
          Es solo una referencia: manda lo que se cobre ahora. Lo que no se cobre queda a crédito.
        </span>
      </div>

      <div className="grid grid-cols-3 gap-2 text-center sm:gap-3">
        <div className="rounded-field border border-line px-2 py-2">
          <p className="text-[11px] font-semibold tracking-wide text-ink-soft uppercase">A cobrar</p>
          <p className="text-base font-semibold text-ink">{soles(total)}</p>
        </div>
        <div className="rounded-field border border-line px-2 py-2">
          <p className="text-[11px] font-semibold tracking-wide text-ink-soft uppercase">Cobrado ahora</p>
          <p className="text-base font-semibold text-emerald-700">{soles(r.pagado)}</p>
        </div>
        <div className="rounded-field border border-line px-2 py-2">
          <p className="text-[11px] font-semibold tracking-wide text-ink-soft uppercase">Queda a crédito</p>
          <p className={r.saldo > 0 ? 'text-base font-semibold text-amber-700' : 'text-base font-semibold text-ink'}>
            {soles(Math.max(r.saldo, 0))}
          </p>
        </div>
      </div>

      {r.sobra ? (
        <Alert>Lo cobrado supera el total en {soles(r.pagado - redondear(total))}. Corrige los montos.</Alert>
      ) : r.completo ? (
        <div className="flex items-center gap-2 rounded-field bg-emerald-50 px-3 py-2 text-sm font-medium text-emerald-800">
          <CheckCircle2 size={16} /> Cobrado completo: la venta queda al contado.
        </div>
      ) : r.pagado > 0 ? (
        <div className="rounded-field bg-amber-50 px-3 py-2 text-sm font-medium text-amber-800">
          Cobro parcial: la venta queda a crédito y el cliente debe {soles(r.saldo)}.
        </div>
      ) : (
        <div className="rounded-field bg-amber-50 px-3 py-2 text-sm font-medium text-amber-800">
          Sin cobro: la venta queda a crédito por {soles(total)}.
        </div>
      )}

      {metodosListos && metodos.length === 0 && (
        <Alert tone="warning">
          No hay métodos de pago activos. Créalos en Finanzas → Métodos de pago para poder registrar un cobro.
        </Alert>
      )}

      <div className="flex flex-col gap-3">
        {filas.map((f) => (
          <div
            key={f.clave}
            className="grid items-end gap-2 rounded-field border border-line p-2.5 sm:grid-cols-[1fr_1fr_9rem_auto]"
          >
            <Desplegable
              label="Tipo de pago"
              size="sm"
              value={f.tipo}
              onChange={(v) => cambiar(f.clave, { tipo: v as TipoMetodoPago, metodoPagoId: 0 })}
              placeholder="Elige el tipo"
              options={TIPOS}
            />
            <Desplegable
              label="Método"
              size="sm"
              value={f.metodoPagoId}
              onChange={(v) => cambiar(f.clave, { metodoPagoId: Number(v) })}
              placeholder={f.tipo ? 'Elige el método' : 'Elige el tipo primero'}
              disabled={!f.tipo}
              options={metodos.filter((m) => m.tipo === f.tipo).map((m) => ({ value: m.id, label: m.nombre }))}
            />
            <Input
              label="Monto"
              size="sm"
              type="number"
              min={0}
              step="0.01"
              placeholder="0.00"
              value={f.monto}
              onChange={(e) => cambiar(f.clave, { monto: e.target.value })}
            />
            <div className="pb-1">
              <RowAction label="Quitar este pago" tone="danger" onClick={() => quitar(f.clave)}>
                <Trash2 size={15} />
              </RowAction>
            </div>
          </div>
        ))}

        {filas.length === 0 && (
          <p className="rounded-field border border-dashed border-line px-3 py-4 text-center text-sm text-ink-soft">
            Todavía no se cobró nada. Si el cliente pagó algo, agrégalo aquí; si no, deja la venta a crédito.
          </p>
        )}

        <div className="flex flex-wrap gap-2">
          <Button
            variant="secondary"
            size="sm"
            iconRight={<Plus size={15} />}
            onClick={() => onFilas([...filas, filaPagoVacia()])}
          >
            Agregar pago
          </Button>
          <Button
            variant="secondary"
            size="sm"
            iconRight={<Wallet size={15} />}
            disabled={r.saldo <= 0 || !metodosListos || metodos.length === 0}
            onClick={cobrarTodo}
          >
            Cobrar todo
          </Button>
        </div>
      </div>
    </div>
  )
}
