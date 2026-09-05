import { useCallback, useEffect, useState } from 'react'
import { HandCoins, Wallet } from 'lucide-react'
import { Alert, Badge, Button, Desplegable, Input, ListPage, Modal, RowAction, StatCard } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { useRealtime } from '../../lib/realtime'
import { notaVentaApi } from '../facturacion/ventasApi'
import type { NotaVentaResponse } from '../facturacion/ventasApi'
import { metodoPagoApi } from './finanzasApi'
import type { MetodoPagoResponse, TipoMetodoPago } from './finanzasApi'

const TIPOS_METODO_PAGO: { value: TipoMetodoPago; label: string }[] = [
  { value: 'EFECTIVO', label: 'Efectivo' },
  { value: 'BILLETERA_DIGITAL', label: 'Billetera digital' },
  { value: 'TRANSFERENCIA', label: 'Transferencia' },
]

/** Filas de NotaVenta a las que ya se les puede calcular el saldo. */
function saldo(n: NotaVentaResponse) {
  return Math.round((n.total - n.totalPagado) * 100) / 100
}

/**
 * Lo que los clientes deben: notas de venta a crédito con saldo pendiente.
 *
 * No es una tabla propia — se calcula de las notas de venta que ya existen,
 * igual que el stock disponible se calcula de los pedidos vivos. Registrar un
 * abono aquí solo agrega un pago más a la nota; no hay edición ni anulación,
 * eso se hace desde Notas de venta.
 */
export function CuentasPorCobrarPage() {
  const [cuentas, setCuentas] = useState<NotaVentaResponse[]>([])
  const [metodosPago, setMetodosPago] = useState<MetodoPagoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abonando, setAbonando] = useState<NotaVentaResponse | null>(null)
  const [tipo, setTipo] = useState<TipoMetodoPago | ''>('')
  const [metodoPagoId, setMetodoPagoId] = useState(0)
  const [monto, setMonto] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [ctas, metodos] = await Promise.all([
        notaVentaApi.cuentasPorCobrar(),
        metodoPagoApi.getAll(),
      ])
      setCuentas(ctas)
      setMetodosPago(metodos.filter((m) => m.activo))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las cuentas por cobrar.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['notasventa'], cargar)

  const abrirAbono = (n: NotaVentaResponse) => {
    setAbonando(n)
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
      await notaVentaApi.registrarPago(abonando.id, { metodoPagoId, monto: valor })
      setAbonando(null)
      await cargar()
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos registrar el abono.')
    } finally {
      setGuardando(false)
    }
  }

  const columns: DataTableColumn<NotaVentaResponse>[] = [
    { key: 'numero', label: 'Número', render: (row) => <Badge>{row.numero}</Badge> },
    { key: 'cliente', label: 'Cliente' },
    { key: 'fecha', label: 'Fecha', render: (row) => new Date(row.fecha).toLocaleDateString('es-PE') },
    { key: 'total', label: 'Total', align: 'right', render: (row) => `S/ ${row.total.toFixed(2)}` },
    { key: 'totalPagado', label: 'Cobrado', align: 'right', render: (row) => `S/ ${row.totalPagado.toFixed(2)}` },
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
      icon={<Wallet size={20} />}
      title="Cuentas por cobrar"
      description="Notas de venta al crédito que todavía tienen saldo pendiente de cobro."
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Cuentas pendientes" value={String(cuentas.length)} icon={<Wallet size={18} />} />
          <StatCard
            label="Por cobrar"
            value={`S/ ${totalPendiente.toFixed(2)}`}
            icon={<HandCoins size={18} />}
            tono="warning"
          />
        </>
      }
      columns={columns}
      rows={cuentas}
      cardIcon={Wallet}
      searchPlaceholder="Buscar por número, cliente..."
      empty={cargando ? 'Cargando cuentas por cobrar...' : 'No hay cuentas pendientes de cobro.'}
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
            ? `${abonando.cliente} · Saldo pendiente: S/ ${saldo(abonando).toFixed(2)}`
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
