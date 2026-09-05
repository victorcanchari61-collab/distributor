import { useCallback, useEffect, useState } from 'react'
import { CreditCard, HandCoins, Pencil, Undo2 } from 'lucide-react'
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
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { useRealtime } from '../../lib/realtime'
import { compraApi } from '../compras/comprasApi'
import type { CompraResponse, PagoCompraResponse } from '../compras/comprasApi'
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
 * compras que ya existen. Al abrir una cuenta se ven TODOS sus pagos (con la
 * misma tabla reutilizable) y se pueden editar o anular uno por uno, además de
 * agregar uno nuevo.
 */
export function CuentasPorPagarPage() {
  const [cuentas, setCuentas] = useState<CompraResponse[]>([])
  const [metodosPago, setMetodosPago] = useState<MetodoPagoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [gestionando, setGestionando] = useState<CompraResponse | null>(null)
  const [editandoPagoId, setEditandoPagoId] = useState<number | null>(null)
  const [tipo, setTipo] = useState<TipoMetodoPago | ''>('')
  const [metodoPagoId, setMetodoPagoId] = useState(0)
  const [monto, setMonto] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')

  const { confirmar, dialogo } = useConfirmacion()

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

  // Trae la lista fresca y, con ella, la cuenta que se está gestionando: si ya
  // no aparece (se saldó por completo) el modal se cierra solo.
  const refrescar = useCallback(async (id: number) => {
    const lista = await compraApi.cuentasPorPagar()
    setCuentas(lista)
    setGestionando(lista.find((c) => c.id === id) ?? null)
  }, [])

  const limpiarForm = () => {
    setEditandoPagoId(null)
    setTipo('')
    setMetodoPagoId(0)
    setMonto('')
    setErrorForm('')
  }

  const abrirGestion = (c: CompraResponse) => {
    setGestionando(c)
    limpiarForm()
  }

  const editarPago = (pago: PagoCompraResponse) => {
    setEditandoPagoId(pago.id)
    setTipo(metodosPago.find((m) => m.id === pago.metodoPagoId)?.tipo ?? '')
    setMetodoPagoId(pago.metodoPagoId)
    setMonto(String(pago.monto))
    setErrorForm('')
  }

  const anularPago = (pago: PagoCompraResponse) =>
    confirmar({
      titulo: `Quitar pago de S/ ${pago.monto.toFixed(2)}`,
      mensaje: 'Ese monto vuelve al saldo pendiente de la cuenta. No se puede deshacer.',
      confirmar: 'Quitar pago',
      tono: 'danger',
      accion: async () => {
        if (!gestionando) return
        setErrorForm('')
        try {
          await compraApi.anularPago(gestionando.id, pago.id)
          await refrescar(gestionando.id)
          await cargar()
        } catch (e) {
          setErrorForm(e instanceof ApiError ? e.message : 'No pudimos quitar el pago.')
        }
      },
    })

  const guardarPago = async () => {
    if (!gestionando) return
    if (!metodoPagoId) return setErrorForm('Elige el método de pago.')
    const valor = Number(monto)
    if (!valor || valor <= 0) return setErrorForm('Ingresa el monto.')

    setGuardando(true)
    setErrorForm('')
    try {
      if (editandoPagoId) {
        await compraApi.actualizarPago(gestionando.id, editandoPagoId, { metodoPagoId, monto: valor })
      } else {
        await compraApi.registrarPago(gestionando.id, { metodoPagoId, monto: valor })
      }
      await refrescar(gestionando.id)
      await cargar()
      limpiarForm()
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos guardar el pago.')
    } finally {
      setGuardando(false)
    }
  }

  const columns: DataTableColumn<CompraResponse>[] = [
    { key: 'numero', label: 'Número', render: (row) => <Badge>{row.numero}</Badge> },
    { key: 'proveedor', label: 'Proveedor' },
    { key: 'fecha', label: 'Fecha', render: (row) => new Date(row.fecha).toLocaleDateString('es-PE') },
    {
      key: 'estado',
      label: 'Estado',
      render: (row) => <Badge tone="success">{row.estado === 'RECIBIDA_TOTAL' ? 'Recibida' : 'Vigente'}</Badge>,
    },
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

  const columnasPagos: DataTableColumn<PagoCompraResponse>[] = [
    { key: 'metodoPago', label: 'Método' },
    { key: 'monto', label: 'Monto', align: 'right', render: (row) => `S/ ${row.monto.toFixed(2)}` },
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
        <RowAction label={`Gestionar pagos de ${row.numero}`} tone="success" onClick={() => abrirGestion(row)}>
          <HandCoins size={15} />
        </RowAction>
      )}
    >
      <Modal
        open={gestionando !== null}
        title={gestionando ? `Pagos de ${gestionando.numero}` : ''}
        description={
          gestionando
            ? `${gestionando.proveedor} · Saldo pendiente: S/ ${saldo(gestionando).toFixed(2)}`
            : undefined
        }
        onClose={() => setGestionando(null)}
        size="lg"
        footer={
          <Button variant="secondary" size="sm" onClick={() => setGestionando(null)}>
            Cerrar
          </Button>
        }
      >
        {gestionando && (
          <div className="flex flex-col gap-4">
            {errorForm && <Alert>{errorForm}</Alert>}

            <SysDataTable<PagoCompraResponse>
              columns={columnasPagos}
              rows={gestionando.pagos}
              rowKey="id"
              toolbar={false}
              empty="Todavía no hay pagos registrados."
              actions={(pago) => (
                <>
                  <RowAction label={`Editar pago de S/ ${pago.monto.toFixed(2)}`} tone="edit" onClick={() => editarPago(pago)}>
                    <Pencil size={15} />
                  </RowAction>
                  <RowAction label={`Quitar pago de S/ ${pago.monto.toFixed(2)}`} tone="danger" onClick={() => void anularPago(pago)}>
                    <Undo2 size={15} />
                  </RowAction>
                </>
              )}
            />

            <div className="flex flex-col gap-3 rounded-field border border-line p-4">
              <p className="ui-label">{editandoPagoId ? 'Editar pago' : 'Agregar pago'}</p>

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

              <div className="flex justify-end gap-2">
                {editandoPagoId && (
                  <Button variant="secondary" size="sm" onClick={limpiarForm}>
                    Cancelar edición
                  </Button>
                )}
                <Button size="sm" loading={guardando} onClick={() => void guardarPago()}>
                  {editandoPagoId ? 'Guardar cambios' : 'Agregar pago'}
                </Button>
              </div>
            </div>
          </div>
        )}
      </Modal>

      {dialogo}
    </ListPage>
  )
}
