import { useCallback, useEffect, useState } from 'react'
import { fechaCorta, fechaHora } from '../../lib/fechas'
import { HandCoins, PackageX, Plus, RefreshCcw, TicketPercent, Undo2, Wallet } from 'lucide-react'
import { FaEye, FaHandHoldingDollar, FaListUl, FaRotateLeft } from 'react-icons/fa6'
import {
  Alert,
  Badge,
  Button,
  CifrasPago,
  Desplegable,
  Input,
  ListPage,
  Modal,
  PestanasVista,
  RowAction,
  StatCard,
  SysDataTable,
  Tabs,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { opcional } from '../../lib/apoyo'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { etiquetaMetodo, metodoPagoApi } from '../finanzas/finanzasApi'
import type { MetodoPagoResponse, TipoMetodoPago } from '../finanzas/finanzasApi'
import { almacenApi } from '../inventario'
import type { AlmacenOpcion } from '../inventario'
import { OPCION_BOVEDA, aPagoCompra, compraApi, devolucionProveedorApi } from './comprasApi'
import type {
  CompraResponse,
  DevolucionProveedorResponse,
  LineaDevolucionProveedor,
  MovimientoSaldoProveedor,
  SaldoFavorProveedor,
} from './comprasApi'
import { NuevaDevolucionModal } from './NuevaDevolucionModal'

type Pestana = 'devoluciones' | 'saldos'

const soles = (n: number) => `S/ ${n.toFixed(2)}`

const TIPOS_METODO: { value: TipoMetodoPago; label: string }[] = [
  { value: 'EFECTIVO', label: 'Efectivo' },
  { value: 'BILLETERA_DIGITAL', label: 'Billetera digital' },
  { value: 'TRANSFERENCIA', label: 'Transferencia' },
]

const TEXTO_MOVIMIENTO: Record<MovimientoSaldoProveedor['tipo'], string> = {
  GENERADO: 'Generado',
  COBRADO: 'Devolvió la plata',
  APLICADO: 'Usado en una compra',
}

/** Qué da el proveedor a cambio, de un vistazo: descuento, reposición o las dos. */
function resolucionBadges(d: DevolucionProveedorResponse) {
  const descuento = d.detalle.some((l) => l.resolucion === 'DESCUENTO')
  const reposicion = d.detalle.some((l) => l.resolucion === 'REPOSICION')
  return (
    <span className="flex flex-wrap gap-1">
      {descuento && <Badge tone="warning">Descuento</Badge>}
      {reposicion && <Badge tone="sys">Reposición</Badge>}
    </span>
  )
}

/**
 * Lo que todavía falta que llegue de la reposición. Si ya no falta nada (llegó, o el proveedor no lo trajo y se
 * descontó en otra devolución) lo dice en vez de mostrar cero.
 */
function aReponer(d: DevolucionProveedorResponse) {
  if (d.montoPorReponer > 0) return <span className="font-semibold text-amber-700">{soles(d.montoPorReponer)}</span>
  if (d.montoReposicion > 0 && d.estado !== 'ANULADA') return <span className="text-xs font-medium text-emerald-700">Nada pendiente</span>
  return <span className="text-ink-soft">—</span>
}

/**
 * Devoluciones a proveedor: lo que llegó mal o no llegó, y qué dio el proveedor a cambio.
 *
 * Dos pestañas: el historial de devoluciones, y los saldos a favor —lo que los proveedores deben devolver porque se
 * les había pagado algo que después se descontó—. Ahí se registra cuando devuelven la plata; usarlo en otra compra se
 * hace al pagar esa compra (Cuentas por pagar).
 */
export function DevolucionesProveedorPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()

  const [pestana, setPestana] = useState<Pestana>('devoluciones')
  const [devoluciones, setDevoluciones] = useState<DevolucionProveedorResponse[]>([])
  const [saldos, setSaldos] = useState<SaldoFavorProveedor[]>([])
  const [compras, setCompras] = useState<CompraResponse[]>([])
  const [almacenes, setAlmacenes] = useState<AlmacenOpcion[]>([])
  const [metodos, setMetodos] = useState<MetodoPagoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [nuevaAbierta, setNuevaAbierta] = useState(false)
  const [detalle, setDetalle] = useState<DevolucionProveedorResponse | null>(null)
  const [estadoFiltro, setEstadoFiltro] = useState('')

  // Saldo a favor: registrar que devolvió la plata, o ver su libro.
  const [cobrando, setCobrando] = useState<SaldoFavorProveedor | null>(null)
  const [cobroMonto, setCobroMonto] = useState('')
  const [cobroTipo, setCobroTipo] = useState<TipoMetodoPago | ''>('')
  const [cobroMetodo, setCobroMetodo] = useState(0)
  const [cobroNota, setCobroNota] = useState('')
  const [guardandoCobro, setGuardandoCobro] = useState(false)
  const [libro, setLibro] = useState<{ saldo: SaldoFavorProveedor; movimientos: MovimientoSaldoProveedor[] } | null>(null)

  const cargar = useCallback(async () => {
    try {
      const [devs, sals] = await Promise.all([devolucionProveedorApi.getAll(), opcional(devolucionProveedorApi.saldos(), [])])
      setDevoluciones(devs)
      setSaldos(sals)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las devoluciones.')
    } finally {
      setCargando(false)
    }
  }, [])

  const cargarApoyo = useCallback(async () => {
    const [comps, alms, mets] = await Promise.all([
      opcional(compraApi.getAll(), []),
      opcional(almacenApi.opciones(), []),
      opcional(metodoPagoApi.getAll(), []),
    ])
    // Solo las que tienen algo que devolver: algo recibido, o algo que todavía no llegó.
    setCompras(comps.filter((c) => c.estado !== 'ANULADA' && c.detalle.some((d) => d.cantidadRecibida > 0 || d.cantidadPendiente > 0)))
    setAlmacenes(alms)
    setMetodos(mets.filter((m) => m.activo))
  }, [])

  useEffect(() => {
    void cargar()
    void cargarApoyo()
  }, [cargar, cargarApoyo])

  useRealtime(['devolucionesproveedor', 'saldosproveedor', 'compras'], () => {
    void cargar()
    void cargarApoyo()
  })

  const anular = (d: DevolucionProveedorResponse) =>
    confirmar({
      titulo: `Anular ${d.numero}`,
      mensaje:
        'Lo devuelto vuelve al stock, la compra queda como estaba y el saldo a favor que dio se retira. ' +
        'No se puede si ya se recibió la reposición o si ya se cobró o usó ese saldo.',
      confirmar: 'Anular devolución',
      tono: 'danger',
      accion: async () => {
        try {
          await devolucionProveedorApi.anular(d.id)
          await cargar()
          toast.exito(`${d.numero} anulada`)
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos anular la devolución.')
        }
      },
    })

  const abrirCobro = (s: SaldoFavorProveedor) => {
    setCobrando(s)
    setCobroMonto(s.saldo.toFixed(2))
    setCobroTipo('')
    setCobroMetodo(0)
    setCobroNota('')
  }

  const guardarCobro = async () => {
    if (!cobrando) return
    const monto = Number(cobroMonto)
    if (!monto || monto <= 0) return toast.error('Ingresa cuánto devolvió.')
    if (monto > cobrando.saldo + 0.001) return toast.error(`Te debe ${soles(cobrando.saldo)}: no puede devolver más.`)
    if (!cobroMetodo) return toast.error('Elige con qué devolvió la plata.')

    setGuardandoCobro(true)
    try {
      const efectivoId = metodos.find((m) => m.tipo === 'EFECTIVO')?.id
      await devolucionProveedorApi.cobrar(cobrando.proveedorId, {
        ...aPagoCompra(cobroMetodo, monto, efectivoId),
        observacion: cobroNota.trim() || null,
      })
      setCobrando(null)
      await cargar()
      toast.exito(`Registrado: ${cobrando.proveedor} devolvió ${soles(monto)}`)
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos registrar la devolución de la plata.')
    } finally {
      setGuardandoCobro(false)
    }
  }

  const abrirLibro = async (s: SaldoFavorProveedor) => {
    try {
      setLibro({ saldo: s, movimientos: await devolucionProveedorApi.movimientos(s.proveedorId) })
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos abrir los movimientos.')
    }
  }

  const anularCobro = (m: MovimientoSaldoProveedor) =>
    confirmar({
      titulo: `Anular el cobro de ${soles(m.monto)}`,
      mensaje: 'La plata sale de la cuenta donde entró y el monto vuelve al saldo a favor.',
      confirmar: 'Anular cobro',
      tono: 'danger',
      accion: async () => {
        if (!libro) return
        try {
          await devolucionProveedorApi.anularCobro(m.id)
          await cargar()
          setLibro({ ...libro, movimientos: await devolucionProveedorApi.movimientos(libro.saldo.proveedorId) })
          toast.exito('Cobro anulado')
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos anular el cobro.')
        }
      },
    })

  const vigentes = devoluciones.filter((d) => d.estado === 'CONFIRMADA')
  const totalDescontado = vigentes.reduce((s, d) => s + d.montoDescuento, 0)
  // Solo lo que todavía no llega: una reposición que ya llegó con una recepción ya no se espera.
  const totalReposicion = vigentes.reduce((s, d) => s + d.montoPorReponer, 0)
  const totalSaldo = saldos.reduce((s, x) => s + x.saldo, 0)
  const visibles = estadoFiltro ? devoluciones.filter((d) => d.estado === estadoFiltro) : devoluciones

  const cabecera = (
    <Tabs
      active={pestana}
      onChange={(id) => setPestana(id as Pestana)}
      items={[
        { id: 'devoluciones', label: 'Devoluciones', icon: <Undo2 size={15} />, badge: vigentes.length },
        { id: 'saldos', label: 'Saldos a favor', icon: <Wallet size={15} />, badge: saldos.length },
      ]}
    />
  )

  const columnas: DataTableColumn<DevolucionProveedorResponse>[] = [
    { key: 'numero', label: 'Número', filterable: false, render: (row) => <Badge>{row.numero}</Badge> },
    { key: 'fecha', label: 'Fecha', filterType: 'date', render: (row) => fechaCorta(row.fecha) },
    { key: 'compraNumero', label: 'Compra', render: (row) => <Badge tone="neutral">{row.compraNumero}</Badge> },
    {
      key: 'proveedor',
      label: 'Proveedor',
      filterType: 'select',
      filterOptions: [...new Set(devoluciones.map((d) => d.proveedor))].sort().map((p) => ({ value: p, label: p })),
    },
    { key: 'motivo', label: 'Motivo' },
    { key: 'resolucion', label: 'A cambio', filterable: false, render: resolucionBadges },
    { key: 'montoDescuento', label: 'Descuento', align: 'right', filterable: false, render: (row) => soles(row.montoDescuento) },
    { key: 'montoPorReponer', label: 'A reponer', align: 'right', filterable: false, render: aReponer },
    {
      key: 'saldoFavorGenerado',
      label: 'Saldo a favor',
      align: 'right',
      filterable: false,
      render: (row) =>
        row.saldoFavorGenerado > 0 ? (
          <span className="font-semibold text-emerald-700">{soles(row.saldoFavorGenerado)}</span>
        ) : (
          <span className="text-ink-soft">—</span>
        ),
    },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'CONFIRMADA', label: 'Vigente' },
        { value: 'ANULADA', label: 'Anulada' },
      ],
      render: (row) => (
        <Badge tone={row.estado === 'ANULADA' ? 'danger' : 'success'}>{row.estado === 'ANULADA' ? 'Anulada' : 'Vigente'}</Badge>
      ),
    },
  ]

  const columnasLineas: DataTableColumn<LineaDevolucionProveedor>[] = [
    {
      key: 'producto',
      label: 'Producto',
      render: (l) => (
        <div className="flex flex-col">
          <span className="text-sm font-medium text-ink">{l.producto}</span>
          <span className="text-xs text-ink-soft">{l.codigo}</span>
        </div>
      ),
    },
    { key: 'cantidad', label: 'Cantidad', align: 'right', render: (l) => `${Number(l.cantidad.toFixed(4))} ${l.unidadBase}` },
    {
      key: 'origen',
      label: 'De',
      render: (l) => <Badge tone="neutral">{l.origen === 'RECIBIDO' ? 'Lo que llegó' : 'Lo que no llegó'}</Badge>,
    },
    {
      key: 'resolucion',
      label: 'A cambio',
      render: (l) =>
        l.resolucion === 'DESCUENTO' ? (
          <Badge tone="warning">Descuento</Badge>
        ) : (
          <div className="flex flex-col items-start gap-0.5">
            <Badge tone="sys">Reposición</Badge>
            {detalle?.estado !== 'ANULADA' && (
              <span className={`text-xs ${l.cantidadPorReponer > 0 ? 'text-amber-700' : 'text-emerald-700'}`}>
                {l.cantidadPorReponer <= 0
                  ? 'Nada pendiente'
                  : l.cantidadPorReponer < l.cantidad
                    ? `Falta ${Number(l.cantidadPorReponer.toFixed(4))} ${l.unidadBase}`
                    : 'Por llegar'}
              </span>
            )}
          </div>
        ),
    },
    { key: 'importe', label: 'Importe', align: 'right', render: (l) => soles(l.importe) },
  ]

  if (pestana === 'saldos') {
    const columnasSaldo: DataTableColumn<SaldoFavorProveedor>[] = [
      { key: 'proveedor', label: 'Proveedor' },
      {
        key: 'saldo',
        label: 'Te debe',
        align: 'right',
        filterable: false,
        render: (row) => <span className="font-semibold text-emerald-700">{soles(row.saldo)}</span>,
      },
      { key: 'totalGenerado', label: 'Generado en total', align: 'right', filterable: false, render: (row) => soles(row.totalGenerado) },
      { key: 'ultimoMovimiento', label: 'Último movimiento', filterType: 'date', render: (row) => fechaCorta(row.ultimoMovimiento) },
    ]

    return (
      <PestanasVista pestanas={cabecera}>
        <ListPage
          icon={<Wallet size={20} />}
          title="Saldos a favor"
          description="Lo que los proveedores deben devolver de compras ya pagadas que después se descontaron."
          alert={error ? <Alert>{error}</Alert> : undefined}
          stats={
            <>
              <StatCard label="Proveedores que deben" value={String(saldos.length)} icon={<Wallet size={18} />} />
              <StatCard
                label="Total a favor"
                value={soles(totalSaldo)}
                icon={<HandCoins size={18} />}
                tono="success"
                progreso={totalSaldo > 0 ? 1 : 0}
              />
            </>
          }
          columns={columnasSaldo}
          rows={saldos}
          cardIcon={Wallet}
          searchPlaceholder="Buscar proveedor..."
          empty={cargando ? 'Cargando...' : 'Ningún proveedor te debe nada.'}
          rowActions={(row) => (
            <>
              <RowAction label={`Movimientos de ${row.proveedor}`} tone="view" onClick={() => void abrirLibro(row)}>
                <FaListUl size={15} />
              </RowAction>
              <RowAction
                label={`Registrar que ${row.proveedor} devolvió la plata`}
                tone="success"
                onClick={() => abrirCobro(row)}
                sinPermiso={!puede('compras.devoluciones', 'cobrar')}>
                <FaHandHoldingDollar size={15} />
              </RowAction>
            </>
          )}
        >
          <Modal
            open={cobrando !== null}
            title={cobrando ? `${cobrando.proveedor} devolvió plata` : ''}
            description="Entra a la caja o cuenta del método. Si devuelve en partes, regístralas una por una."
            onClose={() => setCobrando(null)}
            size="md"
            footer={
              <>
                <Button variant="secondary" size="sm" onClick={() => setCobrando(null)}>
                  Cancelar
                </Button>
                <Button size="sm" loading={guardandoCobro} onClick={() => void guardarCobro()}>
                  Registrar
                </Button>
              </>
            }
          >
            {cobrando && (
              <div className="flex flex-col gap-4">
                <CifrasPago
                  cifras={[
                    { label: 'Te debe', monto: cobrando.saldo, tono: 'exito' },
                    {
                      label: 'Queda',
                      monto: Math.max(0, cobrando.saldo - (Number(cobroMonto) || 0)),
                      tono: cobrando.saldo - (Number(cobroMonto) || 0) > 0.001 ? 'pendiente' : 'normal',
                    },
                  ]}
                />
                <Input label="Monto" type="number" step="0.01" min={0} value={cobroMonto} onChange={(e) => setCobroMonto(e.target.value)} />
                <div className="grid gap-4 sm:grid-cols-2">
                  <Desplegable
                    label="Tipo"
                    value={cobroTipo}
                    onChange={(v) => {
                      setCobroTipo(v as TipoMetodoPago)
                      setCobroMetodo(0)
                    }}
                    placeholder="Elige el tipo"
                    options={TIPOS_METODO}
                  />
                  <Desplegable
                    label="Método"
                    value={cobroMetodo}
                    onChange={(v) => setCobroMetodo(Number(v))}
                    placeholder={cobroTipo ? 'Elige el método' : 'Elige el tipo primero'}
                    disabled={!cobroTipo}
                    options={[
                      ...metodos.filter((m) => m.tipo === cobroTipo).map((m) => ({ value: m.id, label: etiquetaMetodo(m) })),
                      // En efectivo, la plata puede entrar a la Bóveda en vez de a la caja de quien la recibe.
                      ...(cobroTipo === 'EFECTIVO' ? [OPCION_BOVEDA] : []),
                    ]}
                  />
                </div>
                <Input label="Observación" optional value={cobroNota} onChange={(e) => setCobroNota(e.target.value)} />
              </div>
            )}
          </Modal>

          <Modal
            open={libro !== null}
            title={libro ? `Saldo a favor de ${libro.saldo.proveedor}` : ''}
            description={libro ? `Te debe ${soles(libro.saldo.saldo)}` : undefined}
            onClose={() => setLibro(null)}
            size="xl"
          >
            {libro && (
              <SysDataTable<MovimientoSaldoProveedor>
                columns={[
                  { key: 'fecha', label: 'Fecha', render: (m) => fechaHora(m.fecha) },
                  {
                    key: 'tipo',
                    label: 'Movimiento',
                    render: (m) => (
                      <Badge tone={m.anulado ? 'neutral' : m.tipo === 'GENERADO' ? 'success' : 'sys'}>{TEXTO_MOVIMIENTO[m.tipo]}</Badge>
                    ),
                  },
                  { key: 'documento', label: 'Documento', render: (m) => m.documento ?? m.metodoPago ?? '—' },
                  {
                    key: 'monto',
                    label: 'Monto',
                    align: 'right',
                    render: (m) => (
                      <span className={m.anulado ? 'text-ink-soft line-through' : m.tipo === 'GENERADO' ? 'text-emerald-700' : ''}>
                        {m.tipo === 'GENERADO' ? '+' : '−'} {soles(m.monto)}
                      </span>
                    ),
                  },
                  { key: 'usuario', label: 'Por', render: (m) => m.usuario ?? '—' },
                ]}
                rows={libro.movimientos}
                rowKey="id"
                toolbar={false}
                paginacion={false}
                empty="Sin movimientos."
                actions={(m) =>
                  m.tipo === 'COBRADO' && !m.anulado ? (
                    <RowAction
                      label={`Anular el cobro de ${soles(m.monto)}`}
                      tone="danger"
                      onClick={() => void anularCobro(m)}
                      sinPermiso={!puede('compras.devoluciones', 'cobrar')}>
                      <FaRotateLeft size={15} />
                    </RowAction>
                  ) : null
                }
              />
            )}
          </Modal>

          {dialogo}
        </ListPage>
      </PestanasVista>
    )
  }

  return (
    <PestanasVista pestanas={cabecera}>
      <ListPage
        icon={<Undo2 size={20} />}
        title="Devoluciones a proveedor"
        description="Lo que llegó mal o no llegó, y qué dio el proveedor a cambio."
        actions={
          <Button size="sm" onClick={() => setNuevaAbierta(true)} iconRight={<Plus size={15} />} sinPermiso={!puede('compras.devoluciones', 'crear')}>
            Nueva devolución
          </Button>
        }
        alert={error ? <Alert>{error}</Alert> : undefined}
        stats={
          <>
            <StatCard
              label="Devoluciones"
              value={String(vigentes.length)}
              icon={<PackageX size={18} />}
              progreso={devoluciones.length > 0 ? vigentes.length / devoluciones.length : 0}
              accion={{ label: 'Ver todas', onClick: () => setEstadoFiltro('') }}
            />
            <StatCard
              label="Descontado"
              value={soles(totalDescontado)}
              icon={<TicketPercent size={18} />}
              tono="warning"
              progreso={totalDescontado > 0 ? 1 : 0}
            />
            <StatCard
              label="A reponer"
              value={soles(totalReposicion)}
              icon={<RefreshCcw size={18} />}
              progreso={totalReposicion > 0 ? 1 : 0}
            />
            <StatCard
              label="Saldo a favor"
              value={soles(totalSaldo)}
              icon={<Wallet size={18} />}
              tono="success"
              progreso={totalSaldo > 0 ? 1 : 0}
              accion={{ label: 'Ver saldos', onClick: () => setPestana('saldos') }}
            />
          </>
        }
        columns={columnas}
        rows={visibles}
        cardIcon={Undo2}
        searchPlaceholder="Buscar por número, compra, proveedor..."
        empty={cargando ? 'Cargando devoluciones...' : 'Todavía no hay devoluciones a proveedor.'}
        rowActions={(row) => (
          <>
            <RowAction label={`Ver ${row.numero}`} tone="view" onClick={() => setDetalle(row)}>
              <FaEye size={15} />
            </RowAction>
            <RowAction
              label={`Anular ${row.numero}`}
              tone="danger"
              disabled={row.estado === 'ANULADA'}
              disabledReason="Ya está anulada"
              onClick={() => void anular(row)}
              sinPermiso={!puede('compras.devoluciones', 'anular')}>
              <FaRotateLeft size={15} />
            </RowAction>
          </>
        )}
      >
        <Modal
          open={detalle !== null}
          title={detalle ? `${detalle.numero} · ${detalle.proveedor}` : ''}
          description={detalle ? `Compra ${detalle.compraNumero} · ${fechaCorta(detalle.fecha)} · ${detalle.motivo}` : undefined}
          onClose={() => setDetalle(null)}
          size="lg"
        >
          {detalle && (
            <div className="flex flex-col gap-3">
              <CifrasPago
                cifras={[
                  { label: 'Descuento', monto: detalle.montoDescuento, tono: detalle.montoDescuento > 0 ? 'pendiente' : 'normal' },
                  { label: 'A reponer', monto: detalle.montoPorReponer, tono: detalle.montoPorReponer > 0 ? 'pendiente' : 'normal' },
                  { label: 'Saldo a favor', monto: detalle.saldoFavorGenerado, tono: detalle.saldoFavorGenerado > 0 ? 'exito' : 'normal' },
                ]}
              />
              <div className="grid gap-x-6 gap-y-1 text-sm sm:grid-cols-2">
                {detalle.almacen && (
                  <p>
                    <span className="text-ink-soft">Salió de: </span>
                    {detalle.almacen} {detalle.documentoInventario && <Badge tone="neutral">{detalle.documentoInventario}</Badge>}
                  </p>
                )}
                {detalle.fechaReposicion && (
                  <p>
                    <span className="text-ink-soft">Lo repone el: </span>
                    {fechaCorta(detalle.fechaReposicion)}
                  </p>
                )}
                {(detalle.serieNotaCredito || detalle.numeroNotaCredito) && (
                  <p>
                    <span className="text-ink-soft">Nota de crédito: </span>
                    {[detalle.serieNotaCredito, detalle.numeroNotaCredito].filter(Boolean).join('-')}
                  </p>
                )}
                {detalle.usuario && (
                  <p>
                    <span className="text-ink-soft">Registró: </span>
                    {detalle.usuario}
                  </p>
                )}
                {detalle.estado === 'ANULADA' && (
                  <p>
                    <Badge tone="danger">Anulada</Badge>
                  </p>
                )}
              </div>
              <SysDataTable<LineaDevolucionProveedor>
                columns={columnasLineas}
                rows={detalle.detalle}
                rowKey="id"
                toolbar={false}
                paginacion={false}
              />
              {detalle.observacion && (
                <p className="text-sm text-ink-soft">
                  <span className="font-semibold text-ink-muted">Observación: </span>
                  {detalle.observacion}
                </p>
              )}
            </div>
          )}
        </Modal>

        <NuevaDevolucionModal
          open={nuevaAbierta}
          onClose={() => setNuevaAbierta(false)}
          compras={compras}
          almacenes={almacenes}
          onCreada={() => {
            void cargar()
            void cargarApoyo()
          }}
        />

        {dialogo}
      </ListPage>
    </PestanasVista>
  )
}
