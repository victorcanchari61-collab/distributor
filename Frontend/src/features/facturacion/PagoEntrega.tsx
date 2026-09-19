import { useState } from 'react'
import { Check, CheckCircle2, Pencil, Plus, Trash2, Wallet, X } from 'lucide-react'
import { Alert, Badge, Button, Desplegable, Input, RowAction, SysDataTable } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import type { MetodoPagoOpcion, TipoMetodoPago } from '../finanzas/finanzasApi'
import type { PedidoResponse } from './ventasApi'

/**
 * Un pago de la tabla. Mientras `guardado` es falso la fila se está escribiendo:
 * no cuenta para el total y hay que guardarla o cancelarla antes de convertir.
 */
export interface FilaPagoEntrega {
  clave: number
  tipo: TipoMetodoPago | ''
  metodoPagoId: number
  monto: string
  guardado: boolean
  /** Lo que valía antes de empezar a editarla, para poder cancelar. */
  previo?: Omit<FilaPagoEntrega, 'previo'>
}

const TIPOS: { value: TipoMetodoPago; label: string }[] = [
  { value: 'EFECTIVO', label: 'Efectivo' },
  { value: 'BILLETERA_DIGITAL', label: 'Billetera digital' },
  { value: 'TRANSFERENCIA', label: 'Transferencia' },
]

const NOMBRE_TIPO: Record<TipoMetodoPago, string> = {
  EFECTIVO: 'Efectivo',
  BILLETERA_DIGITAL: 'Billetera digital',
  TRANSFERENCIA: 'Transferencia',
}

let contador = 0
const nuevaClave = () => ++contador

const redondear = (n: number) => Math.round(n * 100) / 100
const monto = (fila: FilaPagoEntrega) => (fila.monto.trim() === '' ? 0 : Number(fila.monto))
const soles = (n: number) => `S/ ${n.toFixed(2)}`

/**
 * Lo que dicen los pagos guardados frente al total a cobrar.
 *
 * Solo cuentan las filas guardadas; una que todavía se está escribiendo
 * (`pendiente`) impide convertir hasta que se guarde o se cancele.
 */
export function resumenPago(filas: FilaPagoEntrega[], total: number) {
  const usadas = filas.filter((f) => f.guardado)
  const pagado = redondear(usadas.reduce((suma, f) => suma + monto(f), 0))
  const totalRedondo = redondear(total)

  return {
    usadas,
    pendiente: filas.some((f) => !f.guardado),
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
 * La pestaña de pago al entregar, con el mismo diseño que el modal de pagos de
 * Cuentas por cobrar: una tabla de pagos que se escribe en la propia fila.
 *
 * La condición de pago del pedido es solo lo acordado: al repartir, quien iba a
 * pagar a crédito a veces paga todo o una parte, y quien iba al contado a veces
 * paga solo una parte o nada. Aquí se registra lo que de verdad se cobra, en
 * uno o varios métodos, y la venta queda al contado si eso cubre el total o a
 * crédito con ese adelanto si no.
 */
export function PagoEntrega({ pedido, metodos, metodosListos, filas, total, onFilas }: PagoEntregaProps) {
  const r = resumenPago(filas, total)
  const [aviso, setAviso] = useState('')

  const editando = filas.find((f) => !f.guardado)

  const cambiar = (clave: number, parcial: Partial<FilaPagoEntrega>) => {
    setAviso('')
    onFilas(filas.map((f) => (f.clave === clave ? { ...f, ...parcial } : f)))
  }

  const agregar = () => {
    setAviso('')
    onFilas([...filas, { clave: nuevaClave(), tipo: '', metodoPagoId: 0, monto: '', guardado: false }])
  }

  /** Pasa una fila guardada a modo edición, recordando lo que tenía. */
  const editar = (fila: FilaPagoEntrega) => {
    setAviso('')
    const { previo: _descartado, ...copia } = fila
    void _descartado
    cambiar(fila.clave, { guardado: false, previo: copia })
  }

  const cancelar = (fila: FilaPagoEntrega) => {
    setAviso('')
    // Una fila que ya existía vuelve a lo que tenía; una nueva se descarta.
    onFilas(
      fila.previo
        ? filas.map((f) => (f.clave === fila.clave ? { ...fila.previo!, previo: undefined } : f))
        : filas.filter((f) => f.clave !== fila.clave),
    )
  }

  const guardar = (fila: FilaPagoEntrega) => {
    if (!fila.tipo || !fila.metodoPagoId) return setAviso('Elige el tipo y el método de pago.')
    if (!(monto(fila) > 0)) return setAviso('El monto debe ser mayor que cero.')

    // Lo ya guardado más esta fila no puede pasarse del total.
    const otros = filas.filter((f) => f.guardado && f.clave !== fila.clave).reduce((s, f) => s + monto(f), 0)
    if (redondear(otros + monto(fila)) > redondear(total) + 0.001) {
      return setAviso(
        `Con este pago se cobraría ${soles(redondear(otros + monto(fila)))} y la venta es de ${soles(total)}. Baja el monto.`,
      )
    }

    setAviso('')
    onFilas(filas.map((f) => (f.clave === fila.clave ? { ...fila, guardado: true, previo: undefined } : f)))
  }

  const quitar = (fila: FilaPagoEntrega) => {
    setAviso('')
    onFilas(filas.filter((f) => f.clave !== fila.clave))
  }

  /*
   * "Cobrar todo": un pago con lo que falta, en efectivo si hay un método así,
   * que es lo que se cobra casi siempre en la puerta del cliente. Si no hay
   * efectivo queda la fila para elegir el método.
   */
  const cobrarTodo = () => {
    setAviso('')
    const efectivo = metodos.find((m) => m.tipo === 'EFECTIVO')
    const falta = Math.max(r.saldo, 0)
    onFilas([
      ...filas,
      {
        clave: nuevaClave(),
        tipo: efectivo ? 'EFECTIVO' : '',
        metodoPagoId: efectivo?.id ?? 0,
        monto: falta > 0 ? falta.toFixed(2) : '',
        guardado: !!efectivo && falta > 0,
      },
    ])
  }

  const columnas: DataTableColumn<FilaPagoEntrega>[] = [
    {
      key: 'tipo',
      label: 'Tipo de pago',
      render: (fila) =>
        !fila.guardado ? (
          <Desplegable
            value={fila.tipo}
            onChange={(v) => {
              const tipoElegido = v as TipoMetodoPago
              const delTipo = metodos.filter((m) => m.tipo === tipoElegido)
              // Con un solo método de ese tipo —el efectivo casi siempre— no hay
              // nada que elegir: se completa solo. Con varios, se elige a mano.
              cambiar(fila.clave, {
                tipo: tipoElegido,
                metodoPagoId: delTipo.length === 1 ? delTipo[0].id : 0,
              })
            }}
            placeholder="Elige el tipo"
            options={TIPOS}
          />
        ) : fila.tipo ? (
          <Badge tone="sys">{NOMBRE_TIPO[fila.tipo]}</Badge>
        ) : (
          <span className="text-ink-soft">—</span>
        ),
    },
    {
      key: 'metodo',
      label: 'Método',
      render: (fila) =>
        !fila.guardado ? (
          <Desplegable
            value={fila.metodoPagoId}
            onChange={(v) => cambiar(fila.clave, { metodoPagoId: Number(v) })}
            placeholder={fila.tipo ? 'Elige el método' : 'Elige el tipo primero'}
            disabled={!fila.tipo}
            options={metodos.filter((m) => m.tipo === fila.tipo).map((m) => ({ value: m.id, label: m.nombre }))}
          />
        ) : (
          (metodos.find((m) => m.id === fila.metodoPagoId)?.nombre ?? '—')
        ),
    },
    {
      key: 'monto',
      label: 'Monto',
      align: 'right',
      render: (fila) =>
        !fila.guardado ? (
          <Input
            size="sm"
            type="number"
            min={0}
            step="0.01"
            placeholder="0.00"
            value={fila.monto}
            onChange={(e) => cambiar(fila.clave, { monto: e.target.value })}
          />
        ) : (
          soles(monto(fila))
        ),
    },
  ]

  const acordado = pedido?.condicionPago === 'CREDITO' ? 'Crédito' : 'Contado'

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-2 rounded-field bg-surface-alt px-3 py-2 text-xs text-ink-soft">
        <span>Acordado con el cliente:</span>
        <Badge tone={pedido?.condicionPago === 'CREDITO' ? 'warning' : 'success'}>{acordado}</Badge>
        <span>Es solo una referencia: manda lo que se cobre ahora. Lo que no se cobre queda a crédito.</span>
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

      {/* Sin cobro no se dice nada: los cards ya muestran que todo queda a crédito. */}
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
      ) : null}

      {metodosListos && metodos.length === 0 && (
        <Alert tone="warning">
          No hay métodos de pago activos. Créalos en Finanzas → Métodos de pago para poder registrar un cobro.
        </Alert>
      )}

      {aviso && <Alert>{aviso}</Alert>}

      <div className="flex flex-col gap-3">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <p className="text-sm font-semibold text-ink">Pagos</p>
          <div className="flex flex-wrap gap-2">
            <Button
              variant="secondary"
              size="sm"
              iconRight={<Wallet size={15} />}
              disabled={editando !== undefined || r.saldo <= 0 || !metodosListos || metodos.length === 0}
              onClick={cobrarTodo}
            >
              Cobrar todo
            </Button>
            <Button size="sm" disabled={editando !== undefined || metodos.length === 0} onClick={agregar}>
              <Plus size={15} />
              Agregar pago
            </Button>
          </div>
        </div>

        <SysDataTable<FilaPagoEntrega>
          columns={columnas}
          rows={filas}
          rowKey="clave"
          toolbar={false}
          empty="Todavía no se cobró nada. Si el cliente pagó algo, agrégalo; si no, la venta queda a crédito."
          actions={(fila) =>
            !fila.guardado ? (
              <>
                <RowAction label="Guardar pago" tone="success" onClick={() => guardar(fila)}>
                  <Check size={15} />
                </RowAction>
                <RowAction label="Cancelar" tone="neutral" onClick={() => cancelar(fila)}>
                  <X size={15} />
                </RowAction>
              </>
            ) : (
              <>
                <RowAction
                  label={`Editar pago de ${soles(monto(fila))}`}
                  tone="edit"
                  disabled={editando !== undefined}
                  onClick={() => editar(fila)}
                >
                  <Pencil size={15} />
                </RowAction>
                <RowAction
                  label={`Quitar pago de ${soles(monto(fila))}`}
                  tone="danger"
                  disabled={editando !== undefined}
                  onClick={() => quitar(fila)}
                >
                  <Trash2 size={15} />
                </RowAction>
              </>
            )
          }
        />
      </div>
    </div>
  )
}
