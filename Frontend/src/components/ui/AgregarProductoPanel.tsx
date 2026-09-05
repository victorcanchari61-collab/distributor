import { useState } from 'react'
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
  onAgregar,
}: AgregarProductoPanelProps) {
  const [linea, setLinea] = useState(VACIO)
  const [buscadorAbierto, setBuscadorAbierto] = useState(false)

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
        <Input
          label="Stock"
          disabled
          value={producto && stockActual != null ? `${stockActual} ${producto.unidadBase}` : ''}
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
