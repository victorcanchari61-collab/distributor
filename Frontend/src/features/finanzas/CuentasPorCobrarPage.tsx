import { useCallback, useEffect, useState } from 'react'
import { HandCoins, Pencil, Undo2, Wallet } from 'lucide-react'
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
import { notaVentaApi } from '../facturacion/ventasApi'
import type { NotaVentaResponse, PagoVentaResponse } from '../facturacion/ventasApi'
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
 * igual que el stock disponible se calcula de los pedidos vivos. Al abrir una
 * cuenta se ven TODOS sus pagos (con la misma tabla reutilizable del resto del
 * sistema) y se pueden editar o anular uno por uno, además de agregar uno
 * nuevo. Si la venta se anula, la cuenta entera desaparece de esta lista.
 */
export function CuentasPorCobrarPage() {
  const [cuentas, setCuentas] = useState<NotaVentaResponse[]>([])
  const [metodosPago, setMetodosPago] = useState<MetodoPagoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [gestionando, setGestionando] = useState<NotaVentaResponse | null>(null)
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

  // Trae la lista fresca y, con ella, la cuenta que se está gestionando: si ya
  // no aparece (se saldó por completo) el modal se cierra solo.
  const refrescar = useCallback(async (id: number) => {
    const lista = await notaVentaApi.cuentasPorCobrar()
    setCuentas(lista)
    setGestionando(lista.find((n) => n.id === id) ?? null)
  }, [])

  const limpiarForm = () => {
    setEditandoPagoId(null)
    setTipo('')
    setMetodoPagoId(0)
    setMonto('')
    setErrorForm('')
  }

  const abrirGestion = (n: NotaVentaResponse) => {
    setGestionando(n)
    limpiarForm()
  }

  const editarPago = (pago: PagoVentaResponse) => {
    setEditandoPagoId(pago.id)
    setTipo(metodosPago.find((m) => m.id === pago.metodoPagoId)?.tipo ?? '')
    setMetodoPagoId(pago.metodoPagoId)
    setMonto(String(pago.monto))
    setErrorForm('')
  }

  const anularPago = (pago: PagoVentaResponse) =>
    confirmar({
      titulo: `Quitar pago de S/ ${pago.monto.toFixed(2)}`,
      mensaje: 'Ese monto vuelve al saldo pendiente de la cuenta. No se puede deshacer.',
      confirmar: 'Quitar pago',
      tono: 'danger',
      accion: async () => {
        if (!gestionando) return
        setErrorForm('')
        try {
          await notaVentaApi.anularPago(gestionando.id, pago.id)
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
        await notaVentaApi.actualizarPago(gestionando.id, editandoPagoId, { metodoPagoId, monto: valor })
      } else {
        await notaVentaApi.registrarPago(gestionando.id, { metodoPagoId, monto: valor })
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

  const columns: DataTableColumn<NotaVentaResponse>[] = [
    { key: 'numero', label: 'Número', render: (row) => <Badge>{row.numero}</Badge> },
    { key: 'cliente', label: 'Cliente' },
    { key: 'fecha', label: 'Fecha', render: (row) => new Date(row.fecha).toLocaleDateString('es-PE') },
    {
      key: 'estado',
      label: 'Estado',
      render: () => <Badge tone="success">Vigente</Badge>,
    },
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

  const columnasPagos: DataTableColumn<PagoVentaResponse>[] = [
    { key: 'fecha', label: 'Fecha', render: (row) => new Date(row.fecha).toLocaleString('es-PE') },
    { key: 'metodoPago', label: 'Método' },
    { key: 'usuario', label: 'Cobrado por', render: (row) => row.usuario ?? <span className="text-ink-soft">—</span> },
    { key: 'monto', label: 'Monto', align: 'right', render: (row) => `S/ ${row.monto.toFixed(2)}` },
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
            ? `${gestionando.cliente} · Saldo pendiente: S/ ${saldo(gestionando).toFixed(2)}`
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

            <SysDataTable<PagoVentaResponse>
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
