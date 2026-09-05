import { useCallback, useEffect, useState } from 'react'
import { CreditCard, HandCoins } from 'lucide-react'
import { Alert, Badge, Button, Desplegable, Input, ListPage, Modal, RowAction, StatCard } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { useRealtime } from '../../lib/realtime'
import { compraApi } from '../compras/comprasApi'
import type { CompraResponse } from '../compras/comprasApi'
import { metodoPagoApi } from './finanzasApi'
import type { MetodoPagoResponse, TipoMetodoPago } from './finanzasApi'

const TIPOS_METODO_PAGO: { value: TipoMetodoPago; label: string }[] = [
  { value: 'EFECTIVO', label: 'Efectivo' },
  { value: 'BILLETERA_DIGITAL', label: 'Billetera digital' },
  { value: 'TRANSFERENCIA', label: 'Transferencia' },
]

/** Filas de Compra a las que ya se les puede calcular el saldo. */
function saldo(c: CompraResponse) {
  return Math.round((c.total - c.totalPagado) * 100) / 100
}

/**
 * Lo que se le debe a los proveedores: compras a crédito con saldo pendiente.
 *
 * Igual que Cuentas por cobrar, no es una tabla propia: se calcula de las
 * compras que ya existen. Registrar un abono aquí solo agrega un pago más a
 * la compra; la edición y la recepción de mercadería siguen en sus pantallas.
 */
export function CuentasPorPagarPage() {
  const [cuentas, setCuentas] = useState<CompraResponse[]>([])
  const [metodosPago, setMetodosPago] = useState<MetodoPagoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abonando, setAbonando] = useState<CompraResponse | null>(null)
  const [tipo, setTipo] = useState<TipoMetodoPago | ''>('')
  const [metodoPagoId, setMetodoPagoId] = useState(0)
  const [monto, setMonto] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [ctas, metodos] = await Promise.all([
        compraApi.cuentasPorPagar(),
        metodoPagoApi.getAll(),
      ])
      setCuentas(ctas)
      setMetodosPago(metodos.filter((m) => m.activo))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las cuentas por pagar.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['compras'], cargar)

  const abrirAbono = (c: CompraResponse) => {
    setAbonando(c)
    setTipo('')
    setMetodoPagoId(0)
    setMonto('')
    setErrorForm('')
  }

  const registrarAbono = async () => {
    if (!abonando) return
    if (!metodoPagoId) return setErrorForm('Elige el método de pago.')
    const valor = Number(monto)
    if (!valor || valor <= 0) return setErrorForm('Ingresa el monto del abono.')
    if (valor > saldo(abonando) + 0.001) {
      return setErrorForm(`El abono no puede superar el saldo pendiente (S/ ${saldo(abonando).toFixed(2)}).`)
    }

    setGuardando(true)
    setErrorForm('')
    try {
      await compraApi.registrarPago(abonando.id, { metodoPagoId, monto: valor })
      setAbonando(null)
      await cargar()
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos registrar el abono.')
    } finally {
      setGuardando(false)
    }
  }

  const columns: DataTableColumn<CompraResponse>[] = [
    { key: 'numero', label: 'Número', render: (row) => <Badge>{row.numero}</Badge> },
    { key: 'proveedor', label: 'Proveedor' },
    { key: 'fecha', label: 'Fecha', render: (row) => new Date(row.fecha).toLocaleDateString('es-PE') },
    { key: 'total', label: 'Total', align: 'right', render: (row) => `S/ ${row.total.toFixed(2)}` },
    { key: 'totalPagado', label: 'Pagado', align: 'right', render: (row) => `S/ ${row.totalPagado.toFixed(2)}` },
    {
      key: 'saldo',
      label: 'Saldo',
      align: 'right',
      value: (row) => saldo(row),
      render: (row) => <span className="font-semibold text-amber-600">S/ {saldo(row).toFixed(2)}</span>,
    },
  ]

  const totalPendiente = cuentas.reduce((n, c) => n + saldo(c), 0)

  return (
    <ListPage
      icon={<CreditCard size={20} />}
      title="Cuentas por pagar"
      description="Compras al crédito que todavía tienen saldo pendiente de pago a los proveedores."
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Cuentas pendientes" value={String(cuentas.length)} icon={<CreditCard size={18} />} />
          <StatCard
            label="Por pagar"
            value={`S/ ${totalPendiente.toFixed(2)}`}
            icon={<HandCoins size={18} />}
            tono="warning"
          />
        </>
      }
      columns={columns}
      rows={cuentas}
      cardIcon={CreditCard}
      searchPlaceholder="Buscar por número, proveedor..."
      empty={cargando ? 'Cargando cuentas por pagar...' : 'No hay cuentas pendientes de pago.'}
      rowActions={(row) => (
        <RowAction label={`Registrar abono de ${row.numero}`} tone="success" onClick={() => abrirAbono(row)}>
          <HandCoins size={15} />
        </RowAction>
      )}
    >
      <Modal
        open={abonando !== null}
        title={abonando ? `Abono a ${abonando.numero}` : ''}
        description={
          abonando
            ? `${abonando.proveedor} · Saldo pendiente: S/ ${saldo(abonando).toFixed(2)}`
            : undefined
        }
        onClose={() => setAbonando(null)}
        size="sm"
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbonando(null)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void registrarAbono()}>
              Registrar abono
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {errorForm && <Alert>{errorForm}</Alert>}

          <Desplegable
            label="Tipo"
            value={tipo}
            onChange={(v) => {
              setTipo(v as TipoMetodoPago)
              setMetodoPagoId(0)
            }}
            placeholder="Elige el tipo"
            options={TIPOS_METODO_PAGO}
          />

          <Desplegable
            label="Método de pago"
            value={metodoPagoId}
            onChange={(v) => setMetodoPagoId(Number(v))}
            placeholder={tipo ? 'Elige el método' : 'Elige el tipo primero'}
            disabled={!tipo}
            options={metodosPago.filter((m) => m.tipo === tipo).map((m) => ({ value: m.id, label: m.nombre }))}
          />

          <Input
            label="Monto"
            type="number"
            step="0.01"
            placeholder="0.00"
            value={monto}
            onChange={(e) => setMonto(e.target.value)}
          />
        </div>
      </Modal>
    </ListPage>
  )
}
