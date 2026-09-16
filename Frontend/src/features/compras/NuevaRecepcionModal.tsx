import { useEffect, useState } from 'react'
import { ClipboardList, PackageCheck } from 'lucide-react'
import {
  Badge,
  BuscadorCampo,
  BuscadorModal,
  Button,
  Desplegable,
  Input,
  Modal,
  SysDataTable,
  Tabs,
  useToast,
} from '../../components/ui'
import type { DataTableColumn, OpcionBuscador } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { productoApi } from '../maestros'
import type { ProductoResponse } from '../maestros'
import type { AlmacenOpcion, CrearRecepcionRequest } from '../inventario'
import { recepcionApi } from '../inventario'
import type { CompraDetalleResponse, CompraResponse } from './comprasApi'

export interface NuevaRecepcionModalProps {
  open: boolean
  onClose: () => void
  /** Si viene fijada (desde "Recibir" en una fila de Mis compras), se salta el buscador. */
  compraFija?: CompraResponse | null
  /** Compras Pendiente o Recibida parcial, para elegir cuando no viene fijada. */
  compras: CompraResponse[]
  almacenes: AlmacenOpcion[]
  onCreada: () => void
}

type Pestana = 'datos' | 'lineas'

/**
 * Registrar que llegó mercadería de una compra, total o parcialmente.
 *
 * Es más chico que el formulario de una orden/compra: no arma líneas nuevas,
 * solo dice cuánto de lo YA pactado llegó ahora. Por eso sí cabe en un modal.
 *
 * Va en dos pestañas por lo mismo que el formulario de producto: de un tirón
 * había que bajar por encima del almacén y la observación para llegar a las
 * líneas, que es lo único que se toca en cada recepción.
 */
export function NuevaRecepcionModal({
  open,
  onClose,
  compraFija,
  compras,
  almacenes,
  onCreada,
}: NuevaRecepcionModalProps) {
  const toast = useToast()
  const [compra, setCompra] = useState<CompraResponse | null>(compraFija ?? null)
  const [pestana, setPestana] = useState<Pestana>('datos')
  const [buscadorAbierto, setBuscadorAbierto] = useState(false)
  const [almacenId, setAlmacenId] = useState(0)
  const [observacion, setObservacion] = useState('')
  const [cantidades, setCantidades] = useState<Record<number, string>>({})
  /*
   * En que se recibe cada linea: { [compraDetalleId]: presentacionId }.
   *
   * Se compro por saco pero no siempre llega por saco: a veces el proveedor
   * manda dos sacos y el resto suelto. Por eso cada linea elige su unidad y
   * arranca en la de la compra, que es lo normal.
   */
  const [unidades, setUnidades] = useState<Record<number, number>>({})
  const [productos, setProductos] = useState<ProductoResponse[]>([])
  const [lotes, setLotes] = useState<Record<number, string>>({})
  const [vencimientos, setVencimientos] = useState<Record<number, string>>({})
  const [guardando, setGuardando] = useState(false)

  /** Lo que todavía no llega: es lo único que se puede recibir. */
  const pendientes: CompraDetalleResponse[] =
    compra?.detalle.filter((d) => d.cantidadPendiente > 0) ?? []

  /*
   * Se compró por saco: se recibe por saco.
   *
   * La compra guarda todo en unidad base —50 sacos son 2500 KG— y esta
   * pantalla mostraba ese número, que no es el que cuenta el que descarga el
   * camión. El factor sale de la propia línea: cuántas unidades base es cada
   * presentación. Se muestra en presentación y se manda en unidad base, que es
   * lo que el backend espera.
   */
  /** Las formas de recibir ese producto: su unidad base y sus presentaciones. */
  const presentacionesDe = (d: CompraDetalleResponse) =>
    productos.find((p) => p.id === d.productoId)?.presentaciones.filter((x) => x.activo) ?? []

  /** Cuántas unidades base es una presentación. Sin elegir, la de la compra. */
  const factorDe = (d: CompraDetalleResponse, presentacionId?: number) => {
    const elegida = presentacionId ?? unidades[d.id] ?? d.presentacionId ?? 0
    const encontrada = presentacionesDe(d).find((x) => x.id === elegida)
    if (encontrada) return encontrada.factor

    // Sin catalogo cargado todavia: el factor de la compra sale de la linea.
    return d.cantidadPresentacion > 0 ? d.cantidad / d.cantidadPresentacion : 1
  }

  const unidadDe = (d: CompraDetalleResponse, presentacionId?: number) => {
    const elegida = presentacionId ?? unidades[d.id] ?? d.presentacionId ?? 0
    return presentacionesDe(d).find((x) => x.id === elegida)?.nombre
      ?? d.presentacion
      ?? d.unidadBase
  }

  /** Un número en unidad base, dicho en la presentación de la compra. */
  const enPresentacionCompra = (d: CompraDetalleResponse, base: number) => {
    const factor = d.cantidadPresentacion > 0 ? d.cantidad / d.cantidadPresentacion : 1
    // Sin decimales de mas: 3 sacos son 3, no 3.0000.
    return Number((base / factor).toFixed(4))
  }

  /** Un número en unidad base, dicho en la unidad elegida para recibir. */
  const enUnidadElegida = (d: CompraDetalleResponse, base: number) =>
    Number((base / factorDe(d)).toFixed(4))

  const llenarPendiente = (detalle: CompraDetalleResponse[]) =>
    Object.fromEntries(
      detalle
        .filter((d) => d.cantidadPendiente > 0)
        .map((d) => [d.id, String(enPresentacionCompra(d, d.cantidadPendiente))]),
    )

  const unidadesDeCompra = (detalle: CompraDetalleResponse[]) =>
    Object.fromEntries(
      detalle.filter((d) => d.cantidadPendiente > 0).map((d) => [d.id, d.presentacionId ?? 0]),
    )

  /*
   * El catalogo se pide una vez por apertura: hace falta para ofrecer las
   * otras presentaciones del producto, que la linea de la compra no trae.
   */
  useEffect(() => {
    if (!open || productos.length > 0) return
    void productoApi.getAll().then(setProductos).catch(() => setProductos([]))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open])

  useEffect(() => {
    if (!open) return
    const inicial = compraFija ?? null
    setCompra(inicial)
    // Con la compra ya elegida lo que importa son las líneas; sin elegir, lo
    // primero es elegirla.
    setPestana(inicial ? 'lineas' : 'datos')
    setAlmacenId(almacenes.find((a) => a.esPrincipal)?.id ?? almacenes[0]?.id ?? 0)
    setObservacion('')
    setCantidades(inicial ? llenarPendiente(inicial.detalle) : {})
    setUnidades(inicial ? unidadesDeCompra(inicial.detalle) : {})
    setLotes({})
    setVencimientos({})
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, compraFija])

  const elegirCompra = (c: CompraResponse) => {
    setCompra(c)
    setCantidades(llenarPendiente(c.detalle))
    setUnidades(unidadesDeCompra(c.detalle))
    setLotes({})
    setVencimientos({})
    setPestana('lineas')
  }

  const guardar = async () => {
    if (!compra) return toast.error('Elige la compra.')
    if (!almacenId) return toast.error('Elige el almacén.')

    const detalle = compra.detalle
      .map((d) => ({
        compraDetalleId: d.id,
        // De vuelta a unidad base: es como la compra tiene pactadas sus
        // cantidades y como el almacen lleva el stock.
        cantidad: Number(cantidades[d.id] || 0) * factorDe(d),
        lote: lotes[d.id]?.trim() || null,
        fechaVencimiento: vencimientos[d.id] || null,
      }))
      .filter((l) => l.cantidad > 0)

    if (detalle.length === 0) {
      setPestana('lineas')
      return toast.error('Indica cuánto llegó.')
    }

    const body: CrearRecepcionRequest = {
      compraId: compra.id,
      almacenId,
      observacion: observacion.trim() || null,
      detalle,
    }

    setGuardando(true)
    try {
      await recepcionApi.create(body)
      onClose()
      onCreada()
      toast.exito('Recepción registrada')
    } catch (e) {
      toast.error(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos registrar la recepción.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const opcionesCompra: OpcionBuscador<CompraResponse>[] = compras.map((c) => ({
    item: c,
    label: `${c.numero} · ${c.proveedor}`,
    detalle: c.estado === 'RECIBIDA_PARCIAL' ? 'Parcial' : 'Pendiente',
    nota: `S/ ${c.total.toFixed(2)}`,
  }))

  const columnasCompra: DataTableColumn<CompraResponse>[] = [
    { key: 'numero', label: 'Número', render: (row) => <Badge>{row.numero}</Badge> },
    { key: 'proveedor', label: 'Proveedor' },
    {
      key: 'estado',
      label: 'Estado',
      render: (row) => (
        <Badge tone={row.estado === 'RECIBIDA_PARCIAL' ? 'warning' : 'neutral'}>
          {row.estado === 'RECIBIDA_PARCIAL' ? 'Parcial' : 'Pendiente'}
        </Badge>
      ),
    },
    { key: 'total', label: 'Total', align: 'right', render: (row) => `S/ ${row.total.toFixed(2)}` },
  ]

  /*
   * Las líneas que llegan, en la misma tabla que el resto del sistema.
   *
   * Antes era una lista de tarjetas con los inputs adentro: cada producto
   * ocupaba tres renglones y no se podían comparar lo pactado, lo ya recibido
   * y lo que llega ahora sin ir tarjeta por tarjeta.
   */
  const columnasLineas: DataTableColumn<CompraDetalleResponse>[] = [
    {
      key: 'producto',
      label: 'Producto',
      width: 220,
      render: (d) => (
        <span className="flex flex-col">
          <span className="text-sm font-medium text-ink">{d.producto}</span>
          <span className="text-xs text-ink-soft">{d.codigo}</span>
        </span>
      ),
    },
    {
      key: 'cantidadRecibida',
      label: 'Ya recibido',
      align: 'right',
      width: 120,
      render: (d) =>
        d.cantidadRecibida > 0 ? (
          <span className="text-sm text-ink-soft">
            {enPresentacionCompra(d, d.cantidadRecibida)} {d.presentacion ?? d.unidadBase}
          </span>
        ) : (
          <span className="text-ink-soft">—</span>
        ),
    },
    {
      key: 'cantidadPendiente',
      label: 'Pendiente',
      align: 'right',
      width: 120,
      render: (d) => (
        <span className="text-sm font-medium text-ink">
          {enPresentacionCompra(d, d.cantidadPendiente)} {d.presentacion ?? d.unidadBase}
        </span>
      ),
    },
    {
      /*
       * Se escribe en lo que llego, que no siempre es lo que se compro: dos
       * sacos enteros y el resto suelto se registra eligiendo la unidad de
       * cada linea.
       */
      key: 'llego',
      label: 'Llegó ahora',
      width: 260,
      render: (d) => {
        const opciones = presentacionesDe(d)
        const enBase = (Number(cantidades[d.id]) || 0) * factorDe(d)
        const distintaALaCompra = (unidades[d.id] ?? d.presentacionId ?? 0) !== (d.presentacionId ?? 0)

        return (
          <div className="flex flex-col gap-0.5">
            <div className="flex items-center gap-2">
              <Input
                size="sm"
                type="number"
                step="0.0001"
                min={0}
                max={enUnidadElegida(d, d.cantidadPendiente)}
                value={cantidades[d.id] ?? ''}
                onChange={(e) => setCantidades({ ...cantidades, [d.id]: e.target.value })}
              />
              {opciones.length > 1 ? (
                <Desplegable
                  size="sm"
                  value={unidades[d.id] ?? d.presentacionId ?? 0}
                  onChange={(v) => setUnidades({ ...unidades, [d.id]: Number(v) })}
                  options={opciones.map((x) => ({
                    value: x.id,
                    label: x.nombre,
                    detalle: `${x.factor} ${d.unidadBase}`,
                  }))}
                />
              ) : (
                <span className="text-xs whitespace-nowrap text-ink-soft">{unidadDe(d)}</span>
              )}
            </div>
            {/* La equivalencia solo cuando hace falta comprobarla: al recibir
                en otra unidad que la de la compra. */}
            {distintaALaCompra && enBase > 0 && (
              <span className="text-xs text-ink-soft">
                = {Number(enBase.toFixed(4))} {d.unidadBase}
              </span>
            )}
          </div>
        )
      },
    },
    {
      key: 'lote',
      label: 'Lote',
      width: 140,
      render: (d) => (
        <Input
          size="sm"
          placeholder="Opcional"
          value={lotes[d.id] ?? ''}
          onChange={(e) => setLotes({ ...lotes, [d.id]: e.target.value })}
        />
      ),
    },
    {
      key: 'vencimiento',
      label: 'Vencimiento',
      width: 160,
      render: (d) => (
        <Input
          size="sm"
          type="date"
          value={vencimientos[d.id] ?? ''}
          onChange={(e) => setVencimientos({ ...vencimientos, [d.id]: e.target.value })}
        />
      ),
    },
  ]

  return (
    <>
      <Modal
        open={open}
        size="2xl"
        title="Nueva recepción"
        description="Cuánto de lo pactado llegó ahora. Puede ser parcial."
        onClose={onClose}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={onClose}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()} disabled={!compra}>
              Registrar recepción
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          <Tabs
            active={pestana}
            onChange={(id) => setPestana(id as Pestana)}
            items={[
              { id: 'datos', label: 'Datos', icon: <ClipboardList size={14} /> },
              {
                id: 'lineas',
                label: 'Qué llegó',
                icon: <PackageCheck size={14} />,
                badge: pendientes.length,
              },
            ]}
          />

          {pestana === 'datos' ? (
            <div className="flex flex-col gap-4">
              {compraFija ? (
                <div>
                  <span className="ui-label mb-1.5 block">Compra</span>
                  <div className="flex items-center gap-2 rounded-field border border-line px-3 py-2 text-sm">
                    <Badge>{compraFija.numero}</Badge>
                    <span className="text-ink">{compraFija.proveedor}</span>
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

              <div className="grid gap-4 sm:grid-cols-2">
                <Desplegable
                  label="Almacén de destino"
                  value={almacenId}
                  onChange={(v) => setAlmacenId(Number(v))}
                  options={almacenes
                    .filter((a) => a.activo)
                    .map((a) => ({ value: a.id, label: a.nombre, detalle: a.codigo }))}
                />

                <Input
                  label="Observación"
                  optional
                  placeholder="Guía de remisión, referencia..."
                  value={observacion}
                  onChange={(e) => setObservacion(e.target.value)}
                />
              </div>
            </div>
          ) : !compra ? (
            <p className="py-10 text-center text-sm text-ink-soft">
              Elige primero la compra en la pestaña Datos.
            </p>
          ) : (
            <>
              <SysDataTable<CompraDetalleResponse>
                columns={columnasLineas}
                rows={pendientes}
                rowKey="id"
                toolbar={false}
                empty="Esta compra ya llegó completa: no queda nada por recibir."
              />
              <p className="text-xs text-ink-soft">
                Viene lleno con lo que falta. Si llegó menos, corrige la cantidad y la compra
                queda como recibida parcial. Lo que dejes en cero no se recibe.
              </p>
            </>
          )}
        </div>
      </Modal>

      {!compraFija && (
        <BuscadorModal
          open={buscadorAbierto}
          onClose={() => setBuscadorAbierto(false)}
          title="Elegir compra"
          description="Solo las que aún tienen algo pendiente de recibir."
          columns={columnasCompra}
          rows={compras}
          cardIcon={PackageCheck}
          searchPlaceholder="Buscar por número, proveedor..."
          onSeleccionar={elegirCompra}
        />
      )}
    </>
  )
}
