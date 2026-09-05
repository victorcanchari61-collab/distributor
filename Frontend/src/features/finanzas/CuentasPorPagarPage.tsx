import { useCallback, useEffect, useState } from 'react'
import { Check, CreditCard, HandCoins, Pencil, Plus, Undo2, X } from 'lucide-react'
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

const NOTA_TIPO: Record<TipoMetodoPago, string> = {
  EFECTIVO: 'Efectivo',
  BILLETERA_DIGITAL: 'Billetera digital',
  TRANSFERENCIA: 'Transferencia',
}

const TIPOS_METODO_PAGO: { value: TipoMetodoPago; label: string }[] = [
  { value: 'EFECTIVO', label: 'Efectivo' },
  { value: 'BILLETERA_DIGITAL', label: 'Billetera digital' },
  { value: 'TRANSFERENCIA', label: 'Transferencia' },
]

/** Clave de la fila nueva, todavía sin guardar. */
const NUEVA = 'nueva'

interface FilaPago extends PagoCompraResponse {
  clave: string
}

/** Filas de Compra a las que ya se les puede calcular el saldo. */
function saldo(c: CompraResponse) {
  return Math.round((c.total - c.totalPagado) * 100) / 100
}

/**
 * Lo que se le debe a los proveedores: compras a crédito con saldo pendiente.
 *
 * Igual que Cuentas por cobrar: al abrir una cuenta se ven TODOS sus pagos en
 * la misma tabla reutilizable, "Agregar pago" mete una fila nueva editable
 * ahí mismo, y "Editar" convierte una fila existente en editable. "Anular" no
 * borra el pago: queda en el historial marcado como anulado.
 */
export function CuentasPorPagarPage() {
  const [cuentas, setCuentas] = useState<CompraResponse[]>([])
  const [metodosPago, setMetodosPago] = useState<MetodoPagoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [gestionando, setGestionando] = useState<CompraResponse | null>(null)
  const [editandoClave, setEditandoClave] = useState<string | null>(null)
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

  const cancelarEdicion = () => {
    setEditandoClave(null)
    setTipo('')
    setMetodoPagoId(0)
    setMonto('')
    setErrorForm('')
  }

  const abrirGestion = (c: CompraResponse) => {
    setGestionando(c)
    cancelarEdicion()
  }

  const agregarFila = () => {
    setEditandoClave(NUEVA)
    setTipo('')
    setMetodoPagoId(0)
    setMonto('')
    setErrorForm('')
  }

  const editarFila = (pago: FilaPago) => {
    setEditandoClave(pago.clave)
    setTipo(metodosPago.find((m) => m.id === pago.metodoPagoId)?.tipo ?? '')
    setMetodoPagoId(pago.metodoPagoId)
    setMonto(String(pago.monto))
    setErrorForm('')
  }

  const anularFila = (pago: FilaPago) =>
    confirmar({
      titulo: `Anular pago de S/ ${pago.monto.toFixed(2)}`,
      mensaje: 'Queda en el historial marcado como anulado y su monto vuelve al saldo pendiente. No se puede revertir.',
      confirmar: 'Anular pago',
      tono: 'danger',
      accion: async () => {
        if (!gestionando) return
        setErrorForm('')
        try {
          await compraApi.anularPago(gestionando.id, pago.id)
          await refrescar(gestionando.id)
          await cargar()
        } catch (e) {
          setErrorForm(e instanceof ApiError ? e.message : 'No pudimos anular el pago.')
        }
      },
    })

  const guardarFila = async () => {
    if (!gestionando || !editandoClave) return
    if (!metodoPagoId) return setErrorForm('Elige el método de pago.')
    const valor = Number(monto)
    if (!valor || valor <= 0) return setErrorForm('Ingresa el monto.')

    setGuardando(true)
    setErrorForm('')
    try {
      if (editandoClave === NUEVA) {
        await compraApi.registrarPago(gestionando.id, { metodoPagoId, monto: valor })
      } else {
        await compraApi.actualizarPago(gestionando.id, Number(editandoClave), { metodoPagoId, monto: valor })
      }
      await refrescar(gestionando.id)
      await cargar()
      cancelarEdicion()
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

  const filasPagos: FilaPago[] = gestionando
    ? [
        ...gestionando.pagos.map((p) => ({ ...p, clave: String(p.id) })),
        ...(editandoClave === NUEVA
          ? [{ id: 0, clave: NUEVA, metodoPagoId: 0, metodoPago: '', monto: 0, anulado: false }]
          : []),
      ]
    : []

  const columnasPagos: DataTableColumn<FilaPago>[] = [
    {
      key: 'tipo',
      label: 'Tipo de pago',
      render: (fila) => {
        if (fila.clave === editandoClave) {
          return (
            <Desplegable
              value={tipo}
              onChange={(v) => {
                setTipo(v as TipoMetodoPago)
                setMetodoPagoId(0)
              }}
              placeholder="Elige el tipo"
              options={TIPOS_METODO_PAGO}
            />
          )
        }
        const tipoFila = metodosPago.find((m) => m.id === fila.metodoPagoId)?.tipo
        return tipoFila ? (
          <Badge tone={fila.anulado ? 'neutral' : 'sys'}>{NOTA_TIPO[tipoFila]}</Badge>
        ) : (
          <span className="text-ink-soft">—</span>
        )
      },
    },
    {
      key: 'metodoPago',
      label: 'Método',
      render: (fila) =>
        fila.clave === editandoClave ? (
          <Desplegable
            value={metodoPagoId}
            onChange={(v) => setMetodoPagoId(Number(v))}
            placeholder={tipo ? 'Elige el método' : 'Elige el tipo primero'}
            disabled={!tipo}
            options={metodosPago.filter((m) => m.tipo === tipo).map((m) => ({ value: m.id, label: m.nombre }))}
          />
        ) : fila.anulado ? (
          <span className="text-ink-soft line-through">{fila.metodoPago}</span>
        ) : (
          fila.metodoPago
        ),
    },
    {
      key: 'monto',
      label: 'Monto',
      align: 'right',
      render: (fila) =>
        fila.clave === editandoClave ? (
          <Input
            size="sm"
            type="number"
            step="0.01"
            placeholder="0.00"
            value={monto}
            onChange={(e) => setMonto(e.target.value)}
          />
        ) : fila.anulado ? (
          <span className="text-ink-soft line-through">S/ {fila.monto.toFixed(2)}</span>
        ) : (
          `S/ ${fila.monto.toFixed(2)}`
        ),
    },
    {
      key: 'anulado',
      label: 'Estado',
      render: (fila) =>
        fila.clave === NUEVA ? (
          <span className="text-ink-soft">—</span>
        ) : fila.anulado ? (
          <Badge tone="danger">Anulado</Badge>
        ) : (
          <Badge tone="success">Válido</Badge>
        ),
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
        size="2xl"
        footer={
          <Button variant="secondary" size="sm" onClick={() => setGestionando(null)}>
            Cerrar
          </Button>
        }
      >
        {gestionando && (
          <div className="flex flex-col gap-3">
            {errorForm && <Alert>{errorForm}</Alert>}

            <div className="flex items-center justify-between">
              <p className="text-sm font-semibold text-ink">Pagos</p>
              <Button
                size="sm"
                variant="secondary"
                disabled={editandoClave !== null}
                onClick={agregarFila}
              >
                <Plus size={15} />
                Agregar pago
              </Button>
            </div>

            <SysDataTable<FilaPago>
              columns={columnasPagos}
              rows={filasPagos}
              rowKey="clave"
              toolbar={false}
              empty="Todavía no hay pagos registrados."
              actions={(fila) =>
                fila.clave === editandoClave ? (
                  <>
                    <RowAction
                      label="Guardar pago"
                      tone="success"
                      disabled={guardando}
                      onClick={() => void guardarFila()}
                    >
                      <Check size={15} />
                    </RowAction>
                    <RowAction label="Cancelar" tone="neutral" disabled={guardando} onClick={cancelarEdicion}>
                      <X size={15} />
                    </RowAction>
                  </>
                ) : fila.anulado ? null : (
                  <>
                    <RowAction
                      label={`Editar pago de S/ ${fila.monto.toFixed(2)}`}
                      tone="edit"
                      disabled={editandoClave !== null}
                      onClick={() => editarFila(fila)}
                    >
                      <Pencil size={15} />
                    </RowAction>
                    <RowAction
                      label={`Anular pago de S/ ${fila.monto.toFixed(2)}`}
                      tone="danger"
                      disabled={editandoClave !== null}
                      onClick={() => void anularFila(fila)}
                    >
                      <Undo2 size={15} />
                    </RowAction>
                  </>
                )
              }
            />
          </div>
        )}
      </Modal>

      {dialogo}
    </ListPage>
  )
}
