import { useEffect, useMemo, useState } from 'react'
import { FileText, MapPin, MessageCircle, Phone, ShoppingBag, TrendingDown, UserRound } from 'lucide-react'
import { Alert, Badge, Button, Modal, SysDataTable, Tabs } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta } from '../../lib/fechas'
import { crmApi } from './crmApi'
import type {
  CompraCrm,
  ComparativoCrm,
  DevolucionCrm,
  FichaCrm,
  PedidoCrm,
  PeriodoCrm,
  ProductoPerdidoCrm,
} from './crmApi'
import { PERIODOS, colorCambio, porcentaje, rango, soles, solesConSigno } from './formato'
import { CategoriaBadge } from './CategoriaBadge'
import { NivelBadge } from './NivelBadge'
import { SeguimientoTab } from './SeguimientoTab'

type Pestana = 'resumen' | 'seguimiento' | 'compras' | 'documentos'

/** El número para wa.me: solo dígitos y con el 51 de Perú si vino de 9 cifras. */
const whatsapp = (telefono: string) => {
  const digitos = telefono.replace(/\D/g, '')
  return digitos.length === 9 ? `51${digitos}` : digitos
}

/**
 * La ficha de un cliente: cuánto compra ahora contra antes, qué dejó de comprar y sus documentos.
 *
 * Solo lee, salvo la pestaña Seguimiento, donde se anotan las gestiones con el cliente.
 */
export function FichaClienteModal({
  clienteId,
  periodo,
  onClose,
  onCambio,
}: {
  clienteId: number
  periodo: PeriodoCrm
  onClose: () => void
  /** Se anotó o cambió una gestión: la cartera de atrás tiene que reflejarlo. */
  onCambio: () => void
}) {
  const [ficha, setFicha] = useState<FichaCrm | null>(null)
  const [error, setError] = useState('')
  const [pestana, setPestana] = useState<Pestana>('resumen')

  useEffect(() => {
    let vigente = true
    setFicha(null)
    setError('')
    crmApi
      .ficha(clienteId, periodo)
      .then((f) => vigente && setFicha(f))
      .catch((e) => vigente && setError(e instanceof ApiError ? e.message : 'No pudimos cargar la ficha.'))
    return () => {
      vigente = false
    }
  }, [clienteId, periodo])

  // Tras anotar una gestión la ficha se vuelve a pedir sin vaciarla: vaciarla desmontaría la pestaña
  // y perdería lo que se está escribiendo.
  const alCambiar = () => {
    onCambio()
    crmApi
      .ficha(clienteId, periodo)
      .then(setFicha)
      .catch(() => {
        /* Se queda con lo que ya tenía. */
      })
  }

  const cliente = ficha?.cliente
  const elegido = ficha?.comparativos.find((c) => c.periodo === periodo)
  const contra = PERIODOS.find((p) => p.id === periodo)?.contra

  return (
    <Modal
      open
      size="2xl"
      title={cliente?.nombre ?? 'Cliente'}
      description={cliente ? `${cliente.codigo} · ${cliente.tipoDoc} ${cliente.documento}` : undefined}
      onClose={onClose}
      footer={
        <>
          {cliente?.telefono && (
            <a
              href={`https://wa.me/${whatsapp(cliente.telefono)}`}
              target="_blank"
              rel="noreferrer"
              className="inline-flex h-[var(--height-field-md)] items-center gap-2 rounded-field border border-line bg-surface px-5 text-sm font-semibold text-ink hover:bg-surface-alt"
            >
              <MessageCircle size={16} /> WhatsApp
            </a>
          )}
          <Button variant="secondary" onClick={onClose}>
            Cerrar
          </Button>
        </>
      }
    >
      {error && <Alert>{error}</Alert>}
      {!ficha && !error && <p className="py-10 text-center text-sm text-ink-soft">Cargando ficha...</p>}

      {ficha && cliente && (
        <div className="space-y-4">
          {/* Cabecera: dónde está, cómo va y cuánto cayó. */}
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div className="space-y-1.5 text-sm">
              <div className="flex flex-wrap items-center gap-2">
                <NivelBadge nivel={cliente.nivel} />
                {cliente.categoriaCodigo && (
                  <CategoriaBadge codigo={cliente.categoriaCodigo} nombre={cliente.categoria} color={cliente.categoriaColor} />
                )}
                {cliente.inactivo && <Badge tone="danger">Inactivo · {cliente.diasSinComprar} días sin comprar</Badge>}
                {!cliente.activo && <Badge tone="neutral">Dado de baja</Badge>}
                {cliente.distrito && <span className="text-ink-soft">{cliente.distrito}</span>}
              </div>
              {cliente.telefono && (
                <p className="flex items-center gap-1.5 text-ink-muted">
                  <Phone size={14} /> {cliente.telefono}
                </p>
              )}
              {cliente.direccion && (
                <p className="flex items-center gap-1.5 text-ink-muted">
                  <MapPin size={14} /> {cliente.direccion}
                </p>
              )}
            </div>

            {elegido && (
              <div className="text-right">
                <p className={`text-2xl font-bold ${colorCambio(elegido.diferencia)}`}>
                  {solesConSigno(elegido.diferencia)}
                </p>
                <p className={`text-sm font-semibold ${colorCambio(elegido.diferencia)}`}>
                  {porcentaje(elegido.variacion)}
                </p>
                <p className="text-xs text-ink-soft">
                  frente a {contra}
                  <br />
                  {rango(elegido.anterior)}
                </p>
              </div>
            )}
          </div>

          <Tabs
            items={[
              { id: 'resumen', label: 'Resumen', icon: <UserRound size={15} /> },
              { id: 'seguimiento', label: 'Seguimiento', icon: <TrendingDown size={15} /> },
              { id: 'compras', label: 'Compras', icon: <ShoppingBag size={15} />, badge: ficha.compras.length },
              {
                id: 'documentos',
                label: 'Documentos',
                icon: <FileText size={15} />,
                badge: ficha.pedidos.length + ficha.devoluciones.length,
              },
            ]}
            active={pestana}
            onChange={(id) => setPestana(id as Pestana)}
          />

          {pestana === 'resumen' && <Resumen ficha={ficha} />}
          {pestana === 'seguimiento' && <SeguimientoTab clienteId={clienteId} onCambio={alCambiar} />}
          {pestana === 'compras' && <Compras ficha={ficha} />}
          {pestana === 'documentos' && <Documentos ficha={ficha} />}
        </div>
      )}
    </Modal>
  )
}

// ------------------------------------------------------------------ Resumen

function Dato({ etiqueta, valor }: { etiqueta: string; valor: string | null | undefined }) {
  return (
    <div>
      <dt className="text-xs text-ink-soft">{etiqueta}</dt>
      <dd className="text-sm font-medium text-ink">{valor || '—'}</dd>
    </div>
  )
}

function TarjetaComparativo({ c, elegido }: { c: ComparativoCrm; elegido: boolean }) {
  const periodo = PERIODOS.find((p) => p.id === c.periodo)
  return (
    <div
      className={`rounded-panel border p-3 ${elegido ? 'border-[rgb(var(--sys-rgb))] bg-[rgb(var(--sys-rgb)/0.04)]' : 'border-line bg-white'}`}
    >
      <div className="flex items-center justify-between">
        <span className="text-sm font-semibold text-ink">{periodo?.label}</span>
        <NivelBadge nivel={c.nivel} />
      </div>
      <p className={`mt-2 text-lg font-bold ${colorCambio(c.diferencia)}`}>{solesConSigno(c.diferencia)}</p>
      <p className={`text-xs font-semibold ${colorCambio(c.diferencia)}`}>{porcentaje(c.variacion)}</p>
      <dl className="mt-2 space-y-0.5 text-xs text-ink-soft">
        <div className="flex justify-between gap-2">
          <dt>Ahora</dt>
          <dd className="font-medium text-ink">{soles(c.importeActual)}</dd>
        </div>
        <div className="flex justify-between gap-2">
          <dt>Antes</dt>
          <dd className="font-medium text-ink">{soles(c.importeAnterior)}</dd>
        </div>
      </dl>
      <p className="mt-2 text-[11px] leading-tight text-ink-soft">
        {rango(c.actual)}
        <br />
        vs {rango(c.anterior)}
      </p>
    </div>
  )
}

function Resumen({ ficha }: { ficha: FichaCrm }) {
  const { cliente } = ficha
  return (
    <div className="space-y-4">
      <div className="grid gap-3 sm:grid-cols-3">
        {ficha.comparativos.map((c) => (
          <TarjetaComparativo key={c.periodo} c={c} elegido={c.periodo === ficha.periodo} />
        ))}
      </div>

      <dl className="grid grid-cols-2 gap-x-4 gap-y-3 rounded-panel border border-line bg-white p-4 sm:grid-cols-4">
        <Dato etiqueta="Vendedor" valor={cliente.vendedor} />
        <Dato etiqueta="Ruta" valor={cliente.ruta} />
        <Dato etiqueta="Mercado" valor={cliente.mercado} />
        <Dato etiqueta="Día de visita" valor={ficha.diaVisita} />
        <Dato etiqueta="Lista de precios" valor={ficha.listaPrecio} />
        <Dato etiqueta="Correo" valor={ficha.email} />
        <Dato
          etiqueta="Última compra"
          valor={
            cliente.ultimaCompra
              ? `${fechaCorta(cliente.ultimaCompra)} (hace ${cliente.diasSinComprar} días)`
              : 'Nunca ha comprado'
          }
        />
        <Dato etiqueta="Debe" valor={cliente.saldoPorCobrar > 0 ? soles(cliente.saldoPorCobrar) : 'Nada'} />
        <Dato
          etiqueta="Próxima acción"
          valor={
            cliente.proximaAccion && cliente.proximaFecha
              ? `${cliente.proximaAccion} · ${fechaCorta(cliente.proximaFecha)}${cliente.accionVencida ? ' (vencida)' : ''}`
              : null
          }
        />
      </dl>
    </div>
  )
}

// ------------------------------------------------------------------ Compras

const TONO_ESTADO: Record<string, 'success' | 'danger' | 'neutral'> = {
  CONFIRMADA: 'success',
  ANULADA: 'danger',
}

function Compras({ ficha }: { ficha: FichaCrm }) {
  const compras: DataTableColumn<CompraCrm>[] = useMemo(
    () => [
      {
        key: 'fecha',
        label: 'Fecha',
        value: (r) => new Date(r.fecha).getTime(),
        render: (r) => fechaCorta(r.fecha),
      },
      { key: 'numero', label: 'Nota', render: (r) => <span className="font-medium">{r.numero}</span> },
      {
        key: 'formaPago',
        label: 'Pago',
        render: (r) => (r.formaPago === 'CREDITO' ? 'Crédito' : 'Contado'),
      },
      {
        key: 'estado',
        label: 'Estado',
        render: (r) => (
          <Badge tone={TONO_ESTADO[r.estado] ?? 'neutral'}>
            {r.estado.charAt(0) + r.estado.slice(1).toLowerCase()}
          </Badge>
        ),
      },
      { key: 'total', label: 'Total', align: 'right', value: (r) => r.total, render: (r) => soles(r.total) },
      {
        key: 'saldo',
        label: 'Debe',
        align: 'right',
        value: (r) => r.saldo,
        render: (r) => (r.saldo > 0 ? <span className="text-red-600">{soles(r.saldo)}</span> : '—'),
      },
    ],
    [],
  )

  const productos: DataTableColumn<ProductoPerdidoCrm>[] = useMemo(
    () => [
      {
        key: 'producto',
        label: 'Producto',
        render: (r) => (
          <span className="flex flex-col">
            <span className="font-medium text-ink">{r.producto}</span>
            <span className="text-xs text-ink-soft">{r.codigo}</span>
          </span>
        ),
      },
      { key: 'anterior', label: 'Antes', align: 'right', value: (r) => r.anterior, render: (r) => soles(r.anterior) },
      { key: 'actual', label: 'Ahora', align: 'right', value: (r) => r.actual, render: (r) => soles(r.actual) },
      {
        key: 'diferencia',
        label: 'Cambio',
        align: 'right',
        value: (r) => r.diferencia,
        render: (r) => (
          <span className="flex items-center justify-end gap-2">
            {r.dejoDeComprar && <Badge tone="danger">Ya no compra</Badge>}
            <span className={`font-semibold ${colorCambio(r.diferencia)}`}>{solesConSigno(r.diferencia)}</span>
          </span>
        ),
      },
    ],
    [],
  )

  return (
    <div className="space-y-5">
      <section className="space-y-2">
        <h3 className="text-sm font-semibold text-ink">Lo que compraba y compra menos</h3>
        <SysDataTable
          columns={productos}
          rows={ficha.productosPerdidos}
          rowKey="productoId"
          toolbar={false}
          paginacion={false}
          empty="No hay productos que haya dejado de comprar en este periodo."
        />
      </section>

      <section className="space-y-2">
        <h3 className="text-sm font-semibold text-ink">Últimas ventas</h3>
        <SysDataTable
          columns={compras}
          rows={ficha.compras}
          rowKey="notaVentaId"
          toolbar={false}
          paginacion={false}
          empty="Este cliente no tiene ventas."
        />
      </section>
    </div>
  )
}

// ------------------------------------------------------------------ Documentos

function Documentos({ ficha }: { ficha: FichaCrm }) {
  const pedidos: DataTableColumn<PedidoCrm>[] = useMemo(
    () => [
      { key: 'fecha', label: 'Fecha', value: (r) => new Date(r.fecha).getTime(), render: (r) => fechaCorta(r.fecha) },
      { key: 'numero', label: 'Pedido', render: (r) => <span className="font-medium">{r.numero}</span> },
      { key: 'condicionPago', label: 'Pago', render: (r) => (r.condicionPago === 'CREDITO' ? 'Crédito' : 'Contado') },
      {
        key: 'estado',
        label: 'Estado',
        render: (r) => (
          <Badge tone={r.estado === 'CONFIRMADO' ? 'success' : r.estado === 'ANULADO' ? 'danger' : 'warning'}>
            {r.estado.charAt(0) + r.estado.slice(1).toLowerCase()}
          </Badge>
        ),
      },
    ],
    [],
  )

  const devoluciones: DataTableColumn<DevolucionCrm>[] = useMemo(
    () => [
      { key: 'fecha', label: 'Fecha', value: (r) => new Date(r.fecha).getTime(), render: (r) => fechaCorta(r.fecha) },
      { key: 'numero', label: 'Devolución', render: (r) => <span className="font-medium">{r.numero}</span> },
      { key: 'notaVenta', label: 'De la nota' },
      { key: 'motivo', label: 'Motivo', render: (r) => r.motivo ?? '—' },
      {
        key: 'estado',
        label: 'Estado',
        render: (r) => (
          <Badge tone={r.estado === 'APROBADA' ? 'success' : r.estado === 'RECHAZADA' ? 'danger' : 'warning'}>
            {r.estado.charAt(0) + r.estado.slice(1).toLowerCase()}
          </Badge>
        ),
      },
    ],
    [],
  )

  return (
    <div className="space-y-5">
      <section className="space-y-2">
        <h3 className="text-sm font-semibold text-ink">Pedidos</h3>
        <SysDataTable
          columns={pedidos}
          rows={ficha.pedidos}
          rowKey="id"
          toolbar={false}
          paginacion={false}
          empty="Sin pedidos."
        />
      </section>

      <section className="space-y-2">
        <h3 className="text-sm font-semibold text-ink">Devoluciones</h3>
        <SysDataTable
          columns={devoluciones}
          rows={ficha.devoluciones}
          rowKey="id"
          toolbar={false}
          paginacion={false}
          empty="Sin devoluciones."
        />
      </section>
    </div>
  )
}
