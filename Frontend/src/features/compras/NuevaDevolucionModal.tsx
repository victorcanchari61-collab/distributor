import { useEffect, useState } from 'react'
import { Undo2 } from 'lucide-react'
import {
  Badge,
  BuscadorCampo,
  BuscadorModal,
  Button,
  CifrasPago,
  Desplegable,
  Input,
  Modal,
  SysDataTable,
  useToast,
} from '../../components/ui'
import type { DataTableColumn, OpcionBuscador } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import type { AlmacenOpcion } from '../inventario'
import { devolucionProveedorApi } from './comprasApi'
import type { CompraDetalleResponse, CompraResponse, CrearDevolucionProveedorRequest, ResolucionDevolucion } from './comprasApi'

export interface NuevaDevolucionModalProps {
  open: boolean
  onClose: () => void
  /** Si viene fijada (desde "Devolver" en una fila de Mis compras), se salta el buscador. */
  compraFija?: CompraResponse | null
  /** Las compras de las que se puede devolver algo, para elegir cuando no viene fijada. */
  compras: CompraResponse[]
  almacenes: AlmacenOpcion[]
  onCreada: () => void
}

/** Motivos de siempre, para no escribirlos cada vez (se puede escribir otro). */
const MOTIVOS = ['Llegó en mal estado', 'Vencido o por vencer', 'No es lo que se pidió', 'Llegó de más', 'No lo trajo']

const RESOLUCIONES: { value: ResolucionDevolucion; label: string; detalle: string }[] = [
  { value: 'DESCUENTO', label: 'Descuento', detalle: 'No lo repone: baja la compra' },
  { value: 'REPOSICION', label: 'Reposición', detalle: 'Lo traerá otro día' },
]

/** Cuántas unidades base es la presentación en que se compró esa línea. */
const factorDe = (d: CompraDetalleResponse) => (d.cantidadPresentacion > 0 ? d.cantidad / d.cantidadPresentacion : 1)

/** Un número en unidad base, dicho en la presentación de la compra (sin decimales de más). */
const enCompra = (d: CompraDetalleResponse, base: number) => Number((base / factorDe(d)).toFixed(4))

const soles = (n: number) => `S/ ${n.toFixed(2)}`

/**
 * Devolverle al proveedor parte de una compra: lo que llegó mal o lo que no llegó.
 *
 * Por cada producto se dice cuánto de lo que llegó se devuelve (sale del stock) y cuánto de lo que no llegó se da por
 * no recibido, y qué da el proveedor a cambio: reposición (lo trae otro día; esa cantidad vuelve a quedar por recibir)
 * o descuento (la compra baja; si ya estaba pagada, queda saldo a favor). Las cifras de arriba dicen, antes de guardar,
 * cuánto baja la compra y cuánto quedaría a favor.
 */
export function NuevaDevolucionModal({ open, onClose, compraFija, compras, almacenes, onCreada }: NuevaDevolucionModalProps) {
  const toast = useToast()
  const [compra, setCompra] = useState<CompraResponse | null>(compraFija ?? null)
  const [buscadorAbierto, setBuscadorAbierto] = useState(false)
  const [motivo, setMotivo] = useState('')
  const [almacenId, setAlmacenId] = useState(0)
  const [fechaReposicion, setFechaReposicion] = useState('')
  const [serieNc, setSerieNc] = useState('')
  const [numeroNc, setNumeroNc] = useState('')
  const [observacion, setObservacion] = useState('')
  /** Por línea de la compra, en la presentación de la compra: cuánto de lo que llegó se devuelve. */
  const [devolver, setDevolver] = useState<Record<number, string>>({})
  /** Por línea: cuánto de lo que no llegó se da por no recibido. */
  const [rechazar, setRechazar] = useState<Record<number, string>>({})
  const [resoluciones, setResoluciones] = useState<Record<number, ResolucionDevolucion>>({})
  const [guardando, setGuardando] = useState(false)

  /** De dónde sale lo que llegó: donde se recibió esa compra; si no se sabe, el almacén principal. */
  const almacenDe = (c: CompraResponse | null) =>
    (c?.almacenRecepcionId && almacenes.some((a) => a.id === c.almacenRecepcionId && a.activo) ? c.almacenRecepcionId : 0) ||
    almacenes.find((a) => a.esPrincipal && a.activo)?.id ||
    almacenes.find((a) => a.activo)?.id ||
    0

  useEffect(() => {
    if (!open) return
    setCompra(compraFija ?? null)
    setMotivo('')
    setAlmacenId(almacenDe(compraFija ?? null))
    setFechaReposicion('')
    setSerieNc('')
    setNumeroNc('')
    setObservacion('')
    setDevolver({})
    setRechazar({})
    setResoluciones({})
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, compraFija])

  const elegirCompra = (c: CompraResponse) => {
    setCompra(c)
    setAlmacenId(almacenDe(c))
    setDevolver({})
    setRechazar({})
    setResoluciones({})
  }

  /** Solo las líneas de las que queda algo: recibido para devolver o pendiente para dar por no llegado. */
  const lineas = compra?.detalle.filter((d) => d.cantidadRecibida > 0 || d.cantidadPendiente > 0) ?? []

  const resolucionDe = (d: CompraDetalleResponse) => resoluciones[d.id] ?? 'DESCUENTO'
  const baseDevolver = (d: CompraDetalleResponse) => (Number(devolver[d.id]) || 0) * factorDe(d)
  const baseRechazar = (d: CompraDetalleResponse) => (Number(rechazar[d.id]) || 0) * factorDe(d)
  const importeDe = (d: CompraDetalleResponse) => (baseDevolver(d) + baseRechazar(d)) * d.costoUnitario

  const conAlgo = lineas.filter((d) => baseDevolver(d) > 0 || baseRechazar(d) > 0)
  const devuelto = conAlgo.reduce((s, d) => s + importeDe(d), 0)
  const descuento = conAlgo.filter((d) => resolucionDe(d) === 'DESCUENTO').reduce((s, d) => s + importeDe(d), 0)
  const reposicion = devuelto - descuento
  // Lo descontado baja primero lo que se debe; lo que pasa de eso ya estaba pagado y queda a favor.
  const deuda = compra ? Math.max(0, compra.total - compra.totalPagado) : 0
  const saldoFavor = Math.max(0, Math.round((descuento - deuda) * 100) / 100)
  const saleDelStock = conAlgo.some((d) => baseDevolver(d) > 0)
  const hayReposicion = conAlgo.some((d) => resolucionDe(d) === 'REPOSICION')
  const hayDescuento = descuento > 0

  const guardar = async () => {
    if (!compra) return toast.error('Elige la compra.')
    if (!motivo.trim()) return toast.error('Indica por qué se devuelve.')
    if (conAlgo.length === 0) return toast.error('Indica cuánto se devuelve de algún producto.')
    if (saleDelStock && !almacenId) return toast.error('Elige de qué almacén sale lo que ya había llegado.')

    for (const d of conAlgo) {
      if (baseDevolver(d) > d.cantidadRecibida + 0.0001) {
        return toast.error(`${d.producto}: llegaron ${enCompra(d, d.cantidadRecibida)}, no se puede devolver más.`)
      }
      if (baseRechazar(d) > d.cantidadPendiente + 0.0001) {
        return toast.error(`${d.producto}: faltan llegar ${enCompra(d, d.cantidadPendiente)}, no se puede rechazar más.`)
      }
    }

    const body: CrearDevolucionProveedorRequest = {
      compraId: compra.id,
      motivo: motivo.trim(),
      observacion: observacion.trim() || null,
      almacenId: saleDelStock ? almacenId : null,
      fechaReposicion: hayReposicion && fechaReposicion ? fechaReposicion : null,
      serieNotaCredito: hayDescuento ? serieNc.trim() || null : null,
      numeroNotaCredito: hayDescuento ? numeroNc.trim() || null : null,
      // En unidad base, que es como la compra y el almacén llevan las cantidades.
      detalle: conAlgo.flatMap((d) => [
        ...(baseDevolver(d) > 0
          ? [{ compraDetalleId: d.id, cantidad: baseDevolver(d), origen: 'RECIBIDO' as const, resolucion: resolucionDe(d) }]
          : []),
        ...(baseRechazar(d) > 0
          ? [{ compraDetalleId: d.id, cantidad: baseRechazar(d), origen: 'PENDIENTE' as const, resolucion: resolucionDe(d) }]
          : []),
      ]),
    }

    setGuardando(true)
    try {
      const creada = await devolucionProveedorApi.create(body)
      onClose()
      onCreada()
      toast.exito(
        creada.saldoFavorGenerado > 0
          ? `Devolución ${creada.numero} registrada: el proveedor te debe ${soles(creada.saldoFavorGenerado)}`
          : `Devolución ${creada.numero} registrada`,
      )
    } catch (e) {
      toast.error(
        e instanceof ApiError ? (e.errors.length ? e.errors.join(' ') : e.message) : 'No pudimos registrar la devolución.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const opcionesCompra: OpcionBuscador<CompraResponse>[] = compras.map((c) => ({
    item: c,
    label: `${c.numero} · ${c.proveedor}`,
    detalle: c.estado === 'RECIBIDA_TOTAL' ? 'Recibida' : c.estado === 'RECIBIDA_PARCIAL' ? 'Parcial' : 'Pendiente',
    nota: soles(c.total),
  }))

  const columnasCompra: DataTableColumn<CompraResponse>[] = [
    { key: 'numero', label: 'Número', render: (row) => <Badge>{row.numero}</Badge> },
    { key: 'proveedor', label: 'Proveedor' },
    { key: 'fecha', label: 'Fecha', render: (row) => row.fecha.slice(0, 10) },
    { key: 'total', label: 'Total', align: 'right', render: (row) => soles(row.total) },
  ]

  const unidad = (d: CompraDetalleResponse) => d.presentacion ?? d.unidadBase

  const columnasLineas: DataTableColumn<CompraDetalleResponse>[] = [
    {
      key: 'producto',
      label: 'Producto',
      width: 220,
      render: (d) => (
        <div className="flex flex-col">
          <span className="text-sm font-medium text-ink">{d.producto}</span>
          <span className="text-xs text-ink-soft">
            {d.codigo} · {soles(d.costoUnitario * factorDe(d))} por {unidad(d)}
          </span>
        </div>
      ),
    },
    /*
     * Cada columna tiene un solo tipo de contenido: las cantidades que hay en sus propias columnas (solo números), y
     * en las de devolver siempre un campo —deshabilitado si no hay nada de ese lado—, en vez de cambiarlo por un
     * texto en unas filas y no en otras.
     */
    {
      key: 'llego',
      label: 'Llegó',
      align: 'right',
      width: 100,
      render: (d) => `${enCompra(d, d.cantidadRecibida)} ${unidad(d)}`,
    },
    {
      key: 'falta',
      label: 'Por llegar',
      align: 'right',
      width: 110,
      render: (d) => `${enCompra(d, d.cantidadPendiente)} ${unidad(d)}`,
    },
    {
      key: 'devolver',
      label: 'Devolver',
      width: 120,
      render: (d) => (
        <Input
          size="sm"
          type="number"
          step="0.0001"
          min={0}
          max={enCompra(d, d.cantidadRecibida)}
          placeholder="0"
          disabled={d.cantidadRecibida <= 0}
          title={d.cantidadRecibida <= 0 ? 'No llegó nada que devolver' : undefined}
          aria-label={`Devolver de ${d.producto}`}
          value={devolver[d.id] ?? ''}
          onChange={(e) => setDevolver({ ...devolver, [d.id]: e.target.value })}
        />
      ),
    },
    {
      key: 'rechazar',
      label: 'No llegó',
      width: 120,
      render: (d) => (
        <Input
          size="sm"
          type="number"
          step="0.0001"
          min={0}
          max={enCompra(d, d.cantidadPendiente)}
          placeholder="0"
          disabled={d.cantidadPendiente <= 0}
          title={d.cantidadPendiente <= 0 ? 'Ya llegó todo' : undefined}
          aria-label={`No llegó de ${d.producto}`}
          value={rechazar[d.id] ?? ''}
          onChange={(e) => setRechazar({ ...rechazar, [d.id]: e.target.value })}
        />
      ),
    },
    {
      key: 'resolucion',
      label: 'A cambio',
      width: 190,
      render: (d) => (
        <Desplegable
          size="sm"
          value={resolucionDe(d)}
          onChange={(v) => setResoluciones({ ...resoluciones, [d.id]: v as ResolucionDevolucion })}
          options={RESOLUCIONES}
        />
      ),
    },
    {
      key: 'importe',
      label: 'Importe',
      align: 'right',
      width: 110,
      render: (d) => (importeDe(d) > 0 ? soles(importeDe(d)) : <span className="text-ink-soft">—</span>),
    },
  ]

  return (
    <>
      <Modal
        open={open}
        size="2xl"
        title="Nueva devolución a proveedor"
        description="Lo que llegó mal o no llegó, y qué da el proveedor a cambio."
        onClose={onClose}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={onClose}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()} disabled={!compra} iconRight={<Undo2 size={14} />}>
              Registrar devolución
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          <div className="grid gap-4 sm:grid-cols-2">
            {compraFija ? (
              <div>
                <span className="ui-label mb-1.5 block">Compra</span>
                <div className="flex items-center gap-2 rounded-field border border-line px-3 py-2 text-sm">
                  <Badge>{compraFija.numero}</Badge>
                  <span className="truncate text-ink">{compraFija.proveedor}</span>
                </div>
              </div>
            ) : (
              <BuscadorCampo
                label="Compra"
                value={compra}
                onChange={(c) => c && elegirCompra(c)}
                opciones={opcionesCompra}
                placeholder="Buscar compra..."
                vacio="Ninguna compra coincide"
                onAvanzado={() => setBuscadorAbierto(true)}
                avanzadoLabel="Búsqueda avanzada de compras"
              />
            )}

            <div>
              <Input
                label="Motivo"
                placeholder="Por qué se devuelve"
                list="motivos-devolucion-proveedor"
                value={motivo}
                onChange={(e) => setMotivo(e.target.value)}
              />
              <datalist id="motivos-devolucion-proveedor">
                {MOTIVOS.map((m) => (
                  <option key={m} value={m} />
                ))}
              </datalist>
            </div>

            {saleDelStock && (
              <Desplegable
                label="Sale del almacén"
                value={almacenId}
                onChange={(v) => setAlmacenId(Number(v))}
                options={almacenes.filter((a) => a.activo).map((a) => ({ value: a.id, label: a.nombre, detalle: a.codigo }))}
              />
            )}

            {hayReposicion && (
              <Input
                label="Lo repone el"
                optional
                type="date"
                value={fechaReposicion}
                onChange={(e) => setFechaReposicion(e.target.value)}
              />
            )}

            {hayDescuento && (
              <div>
                {/* Un solo rótulo para los dos campos: con uno cada uno, el de la serie no entraba. */}
                <span className="ui-label mb-1.5 block">
                  Nota de crédito del proveedor <span className="font-normal text-ink-soft">(opcional)</span>
                </span>
                <div className="grid grid-cols-[6rem_1fr] gap-2">
                  <Input placeholder="Serie" aria-label="Serie de la nota de crédito" value={serieNc} onChange={(e) => setSerieNc(e.target.value)} />
                  <Input placeholder="Número" aria-label="Número de la nota de crédito" value={numeroNc} onChange={(e) => setNumeroNc(e.target.value)} />
                </div>
              </div>
            )}

            <Input
              label="Observación"
              optional
              placeholder="Guía, quién lo recogió..."
              value={observacion}
              onChange={(e) => setObservacion(e.target.value)}
            />
          </div>

          {compra ? (
            <>
              <CifrasPago
                cifras={[
                  { label: 'Devuelto', monto: devuelto },
                  {
                    label: 'Baja la compra',
                    monto: descuento,
                    tono: descuento > 0 ? 'pendiente' : 'normal',
                    nota: descuento > 0 ? `Queda en ${soles(compra.total - descuento)}` : 'Nada se descuenta',
                  },
                  {
                    label: 'A reponer',
                    monto: reposicion,
                    nota: reposicion > 0 ? 'Vuelve a quedar por recibir' : undefined,
                  },
                  {
                    label: 'Saldo a favor',
                    monto: saldoFavor,
                    tono: saldoFavor > 0 ? 'exito' : 'normal',
                    nota: saldoFavor > 0 ? 'Ya estaba pagado: te lo debe' : `Debías ${soles(deuda)}`,
                  },
                ]}
              />
              <SysDataTable<CompraDetalleResponse>
                columns={columnasLineas}
                rows={lineas}
                rowKey="id"
                toolbar={false}
                paginacion={false}
                empty="De esta compra no queda nada por devolver."
              />
            </>
          ) : (
            <p className="py-8 text-center text-sm text-ink-soft">Elige la compra de la que se devuelve.</p>
          )}
        </div>
      </Modal>

      {!compraFija && (
        <BuscadorModal
          open={buscadorAbierto}
          onClose={() => setBuscadorAbierto(false)}
          title="Elegir compra"
          description="Las compras de las que se puede devolver algo."
          columns={columnasCompra}
          rows={compras}
          cardIcon={Undo2}
          searchPlaceholder="Buscar por número, proveedor..."
          onSeleccionar={elegirCompra}
        />
      )}
    </>
  )
}
