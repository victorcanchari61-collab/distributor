import { useEffect, useState } from 'react'
import { Plus } from 'lucide-react'
import { BuscadorCampo } from './BuscadorCampo'
import type { OpcionBuscador } from './BuscadorCampo'
import { BuscadorProductoModal } from './BuscadorProductoModal'
import type { ProductoBuscable } from './BuscadorProductoModal'
import { Button } from './Button'
import { Desplegable } from './Desplegable'
import { Input } from './Input'

export type { ProductoBuscable }

/** Una línea lista para agregar a la tabla de productos. */
export interface LineaProductoNueva {
  /** Identifica la fila en la tabla de abajo — SysDataTable la necesita para no confundir filas. */
  id: string
  /** Solo al editar un documento existente: el id real de la línea en el servidor. */
  lineaId?: number
  productoId: number
  /** 0 = unidad base. */
  presentacionId: number
  cantidad: string
  costo: string
  lote: string
  fechaVencimiento: string
}

export interface AgregarProductoPanelProps {
  productos: ProductoBuscable[]
  /** Stock actual por producto, en unidad base — para mostrarlo mientras se arma la línea. */
  stock?: Record<number, number>
  /** Si el motivo/documento pide declarar costo (una entrada) o no (una salida/transferencia). */
  pideCosto?: boolean
  costoLabel?: string
  /** Solo para entradas con seguimiento de vencimiento (ajustes, recepciones). */
  pideLote?: boolean
  /**
   * De dónde sale el precio, cuando lo pone una lista y no el que carga.
   *
   * Recibe la presentación real (nunca 0: la unidad base tiene su propia
   * presentación) y la cantidad, porque el precio depende de cuánto se lleva
   * —el tramo "desde 5 sacos" es más barato—. Devuelve el precio de UNA
   * presentación, o null si esa forma de vender no tiene precio cargado.
   */
  resolverPrecio?: (presentacionId: number, cantidad: number) => Promise<number | null>
  onAgregar: (linea: LineaProductoNueva) => void
}

const VACIO = { productoId: 0, presentacionId: 0, cantidad: '', costo: '', lote: '', fechaVencimiento: '' }

/**
 * Buscar un producto, armar la línea (unidad, cantidad, costo) y agregarla a
 * la tabla de abajo — en vez de agregar una fila vacía y llenarla adentro de
 * la tabla.
 *
 * El mismo panel sirve para Ajustes, Transferencias, Préstamos y Compras:
 * `pideCosto` oculta el costo cuando el motivo no lo declara (una
 * transferencia hereda el costo, no lo inventa), y `pideLote` solo aparece
 * donde tiene sentido guardar vencimiento.
 *
 * El campo de búsqueda trae también su búsqueda avanzada: un
 * [BuscadorProductoModal] con tarjetas filtrables por categoría y marca,
 * para cuando escribir dos letras no alcanza.
 */
export function AgregarProductoPanel({
  productos,
  stock,
  pideCosto = true,
  costoLabel = 'Precio',
  pideLote = false,
  resolverPrecio,
  onAgregar,
}: AgregarProductoPanelProps) {
  const [linea, setLinea] = useState(VACIO)
  const [buscadorAbierto, setBuscadorAbierto] = useState(false)
  /** Qué dijo la lista: para avisar cuando no hay precio o cuando se cambió. */
  const [precioLista, setPrecioLista] = useState<number | null>(null)
  const [buscandoPrecio, setBuscandoPrecio] = useState(false)

  const producto = productos.find((p) => p.id === linea.productoId)
  const presentaciones = producto?.presentaciones.filter((p) => p.activo) ?? []
  const presentacionElegida = presentaciones.find((p) => p.id === linea.presentacionId)
  const factor = presentacionElegida?.factor ?? 1
  const stockActual = producto ? (stock?.[producto.id] ?? 0) : null

  const opcionesProducto: OpcionBuscador<number>[] = productos.map((p) => ({
    item: p.id,
    label: p.nombre,
    detalle: p.codigo,
  }))

  const elegir = (id: number) => setLinea({ ...VACIO, productoId: id })

  /*
   * El precio se pide a la lista, no se teclea.
   *
   * Se vuelve a pedir cuando cambia la cantidad y no solo al elegir el
   * producto: el tramo por volumen depende de cuanto se lleva, asi que
   * resolver una sola vez dejaria el descuento de 5 sacos sin aplicarse
   * nunca. Queda editable: un precio especial a un cliente sigue siendo
   * cosa de todos los dias.
   */
  const presentacionReal =
    linea.presentacionId || presentaciones.find((x) => x.esBase)?.id || 0

  useEffect(() => {
    if (!resolverPrecio || !producto || !presentacionReal) return

    const cantidad = Number(linea.cantidad) || 1
    let vigente = true
    setBuscandoPrecio(true)

    void resolverPrecio(presentacionReal, cantidad)
      .then((precio) => {
        if (!vigente) return
        setPrecioLista(precio)
        // Solo escribe el precio: si el que carga ya lo piso a mano, se
        // respeta lo que puso.
        setLinea((l) => (precio == null ? l : { ...l, costo: String(precio) }))
      })
      .finally(() => vigente && setBuscandoPrecio(false))

    return () => {
      vigente = false
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [producto?.id, presentacionReal, linea.cantidad])

  const agregar = () => {
    if (!producto || !linea.cantidad) return

    onAgregar({
      id: crypto.randomUUID(),
      productoId: producto.id,
      presentacionId: linea.presentacionId,
      cantidad: linea.cantidad,
      costo: linea.costo,
      lote: linea.lote,
      fechaVencimiento: linea.fechaVencimiento,
    })

    // Vuelve a cero: el siguiente producto se busca de nuevo, no se
    // arrastra nada de la línea anterior.
    setLinea(VACIO)
    setPrecioLista(null)
  }

  return (
    <div className="flex flex-col gap-4">
      <BuscadorCampo
        label="Buscar producto"
        value={linea.productoId || null}
        onChange={(id) => elegir(id ?? 0)}
        opciones={opcionesProducto}
        placeholder="Nombre o código..."
        vacio="Ningún producto coincide"
        onAvanzado={() => setBuscadorAbierto(true)}
        avanzadoLabel="Búsqueda avanzada de productos"
      />

      {/* Siempre visible, aunque no haya producto elegido todavía: así el
          panel no "salta" de tamaño al buscar, y se ve de entrada qué datos
          va a pedir (costo incluido) en vez de sorprender después. */}
      <Input label="Descripción" disabled value={producto ? producto.descripcion || producto.nombre : ''} />

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        {/*
          El stock, en la unidad que se eligio abajo.
          Decia "1250 KG" con la linea armada en sacos: para saber si alcanzan
          los 3 sacos que se estan vendiendo habia que dividir a mano.
        */}
        <Input
          label="Stock"
          disabled
          value={
            producto && stockActual != null
              ? `${Number((stockActual / factor).toFixed(4))} ${
                  presentacionElegida?.nombre ?? producto.unidadBase
                }`
              : ''
          }
        />

        <Desplegable
          label="Unidad"
          value={linea.presentacionId}
          onChange={(v) => setLinea({ ...linea, presentacionId: Number(v) })}
          disabled={!producto}
          options={
            producto
              ? [
                  { value: 0, label: producto.unidadBase, nota: 'unidad base' },
                  ...presentaciones
                    .filter((p) => !p.esBase)
                    .map((p) => ({
                      value: p.id,
                      label: p.nombre,
                      detalle: `${p.factor} ${producto.unidadBase}`,
                    })),
                ]
              : []
          }
        />

        <Input
          label="Cantidad"
          type="number"
          step="0.0001"
          disabled={!producto}
          value={linea.cantidad}
          onChange={(e) => setLinea({ ...linea, cantidad: e.target.value })}
        />

        {pideCosto && (
          <Input
            label={costoLabel}
            type="number"
            step="0.01"
            disabled={!producto}
            placeholder={producto?.costoReferencia ? String(producto.costoReferencia * factor) : '0.00'}
            value={linea.costo}
            onChange={(e) => setLinea({ ...linea, costo: e.target.value })}
            hint={
              resolverPrecio && producto ? (
                buscandoPrecio ? (
                  <span className="text-xs text-ink-soft">Buscando en la lista...</span>
                ) : precioLista == null ? (
                  // Sin precio cargado la venta saldria en cero sin que nadie
                  // chille: mejor decirlo aqui, antes de agregar la linea.
                  <span className="text-xs font-medium text-amber-600">Sin precio en la lista</span>
                ) : Number(linea.costo) !== precioLista ? (
                  <span className="text-xs font-medium text-amber-600">
                    Lista: S/ {precioLista.toFixed(2)}
                  </span>
                ) : (
                  <span className="text-xs text-ink-soft">De la lista</span>
                )
              ) : undefined
            }
          />
        )}
      </div>

      {pideLote && (
        <div className="grid grid-cols-2 gap-3">
          <Input
            label="Lote"
            optional
            disabled={!producto}
            placeholder="Opcional"
            value={linea.lote}
            onChange={(e) => setLinea({ ...linea, lote: e.target.value })}
          />
          <Input
            label="Vencimiento"
            optional
            type="date"
            disabled={!producto}
            value={linea.fechaVencimiento}
            onChange={(e) => setLinea({ ...linea, fechaVencimiento: e.target.value })}
          />
        </div>
      )}

      <Button size="sm" onClick={agregar} disabled={!producto || !linea.cantidad} className="self-start">
        <Plus size={15} />
        Agregar producto
      </Button>

      <BuscadorProductoModal
        open={buscadorAbierto}
        onClose={() => setBuscadorAbierto(false)}
        productos={productos}
        stock={stock}
        onAgregar={(selecciones) => {
          selecciones.forEach(({ producto, presentacionId, cantidad }) =>
            onAgregar({
              id: crypto.randomUUID(),
              productoId: producto.id,
              presentacionId,
              cantidad: String(cantidad),
              costo: '',
              lote: '',
              fechaVencimiento: '',
            }),
          )
        }}
      />
    </div>
  )
}
