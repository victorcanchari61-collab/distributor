import { useCallback, useEffect, useState } from 'react'
import { Layers, PackagePlus } from 'lucide-react'
import { Alert, Badge, Button, Desplegable, Input } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { inventarioApi } from './inventarioApi'
import type { StockProductoResponse } from './inventarioApi'
import type { ProductoResponse } from './productoApi'

const ORIGENES = {
  SALDO_INICIAL: 'Saldo inicial',
  COMPRA: 'Compra',
  AJUSTE: 'Ajuste',
} as const

export interface StockYCostoProps {
  producto: ProductoResponse
  /** Se avisa al padre para que refresque el listado. */
  onCambio: () => Promise<void>
}

/**
 * Stock y costos de un producto.
 *
 * Aquí se ve la idea central del inventario: el costo no es UNO. Cada entrada
 * guarda el suyo y las dos conviven mientras quede mercadería de ambas. Una
 * venta consume primero la capa más antigua, así que la ganancia sale exacta
 * aunque el proveedor haya subido el precio en el medio.
 */
export function StockYCosto({ producto, onCambio }: StockYCostoProps) {
  const [stock, setStock] = useState<StockProductoResponse | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const compras = producto.presentaciones.filter((p) => p.esCompra && p.activo)

  const [form, setForm] = useState({
    presentacionId: 0,
    cantidad: '',
    costoTotal: '',
    flete: '',
    referencia: '',
    origen: 'COMPRA' as 'SALDO_INICIAL' | 'COMPRA' | 'AJUSTE',
  })
  const [guardando, setGuardando] = useState(false)

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setStock(await inventarioApi.stock(producto.id))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar el stock.')
    } finally {
      setCargando(false)
    }
  }, [producto.id])

  useEffect(() => {
    void cargar()
    // La presentación de compra predeterminada sale elegida: es la que se usa
    // casi siempre al recibir mercadería.
    const preferida = compras.find((p) => p.predeterminadaCompra) ?? compras[0]
    setForm((f) => ({ ...f, presentacionId: preferida?.id ?? 0 }))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [cargar])

  const presentacion = producto.presentaciones.find((p) => p.id === form.presentacionId)
  const factor = presentacion?.factor ?? 1
  const enBase = Number(form.cantidad || 0) * factor
  const costoTotal = Number(form.costoTotal || 0) * Number(form.cantidad || 0) + Number(form.flete || 0)
  const costoUnitario = enBase > 0 ? costoTotal / enBase : 0

  const registrar = async () => {
    if (!form.cantidad || Number(form.cantidad) <= 0) {
      return setError('Ingresa la cantidad que entró.')
    }

    setGuardando(true)
    setError('')
    try {
      await inventarioApi.entrada({
        productoId: producto.id,
        presentacionId: form.presentacionId || null,
        cantidad: Number(form.cantidad),
        costoTotal: Number(form.costoTotal || 0),
        flete: Number(form.flete || 0),
        referencia: form.referencia.trim() || null,
        origen: form.origen,
      })

      setForm((f) => ({ ...f, cantidad: '', costoTotal: '', flete: '', referencia: '' }))
      await cargar()
      await onCambio()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos registrar la entrada.')
    } finally {
      setGuardando(false)
    }
  }

  return (
    <div className="flex flex-col gap-4">
      {error && <Alert>{error}</Alert>}

      {/* Resumen: lo que hay y cuánto vale */}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
        <Resumen
          titulo="Stock"
          valor={`${stock?.stock ?? 0} ${producto.unidadBase}`}
          nota={cargando ? 'cargando...' : undefined}
        />
        <Resumen
          titulo="Costo actual"
          valor={stock?.costoAntiguo != null ? `S/ ${stock.costoAntiguo}` : '—'}
          nota={`por ${producto.unidadBase}`}
        />
        <Resumen
          titulo="Valorizado"
          valor={`S/ ${(stock?.valorizado ?? 0).toFixed(2)}`}
          nota="lo que vale el stock"
        />
      </div>

      {/* Capas: el corazón del asunto */}
      <div>
        <p className="mb-2 flex items-center gap-2 text-sm font-semibold text-ink">
          <Layers size={15} />
          Capas de costo
        </p>

        {!stock || stock.capas.length === 0 ? (
          <p className="rounded-field bg-slate-50 px-3 py-4 text-center text-xs text-ink-soft">
            Todavía no hay stock. Registra abajo lo que ya tienes con su costo, y de ahí en
            adelante lo irán llenando las compras.
          </p>
        ) : (
          <ul className="flex flex-col gap-2">
            {stock.capas.map((capa, i) => (
              <li
                key={capa.id}
                className="flex flex-wrap items-center justify-between gap-2 rounded-field border border-line bg-white px-3 py-2"
              >
                <span className="flex items-center gap-2">
                  {/* La primera es la que se consume en la próxima venta. */}
                  <Badge tone={i === 0 ? 'sys' : 'neutral'}>
                    {i === 0 ? 'Sale primero' : `#${i + 1}`}
                  </Badge>
                  <span className="text-sm text-ink">
                    {capa.cantidadDisponible} {producto.unidadBase}
                  </span>
                  <span className="text-xs text-ink-soft">
                    de {capa.cantidadInicial} · {ORIGENES[capa.origen as keyof typeof ORIGENES] ?? capa.origen}
                    {capa.referencia ? ` · ${capa.referencia}` : ''}
                  </span>
                </span>

                <span className="flex items-center gap-3">
                  <span className="text-sm font-semibold text-ink">
                    S/ {capa.costoUnitario}
                    <span className="ml-1 text-xs font-normal text-ink-soft">
                      × {producto.unidadBase}
                    </span>
                  </span>
                  <span className="text-xs text-ink-muted">S/ {capa.valor.toFixed(2)}</span>
                </span>
              </li>
            ))}
          </ul>
        )}
      </div>

      <hr className="border-line" />

      {/* Entrada de mercadería */}
      <div className="flex flex-col gap-3">
        <p className="flex items-center gap-2 text-sm font-semibold text-ink">
          <PackagePlus size={15} />
          Registrar entrada
        </p>

        <div className="grid gap-3 sm:grid-cols-2">
          <Desplegable
            label="Motivo"
            value={form.origen}
            onChange={(v) => setForm({ ...form, origen: v as typeof form.origen })}
            options={[
              { value: 'SALDO_INICIAL', label: 'Saldo inicial', nota: 'lo que ya tenías' },
              { value: 'COMPRA', label: 'Compra', nota: 'mercadería recibida' },
              { value: 'AJUSTE', label: 'Ajuste', nota: 'corrección de inventario' },
            ]}
          />

          <Desplegable
            label="Entró por"
            value={form.presentacionId}
            onChange={(v) => setForm({ ...form, presentacionId: Number(v) })}
            options={compras.map((p) => ({
              value: p.id,
              label: p.nombre,
              detalle: `${p.factor} ${producto.unidadBase}`,
            }))}
          />
        </div>

        <div className="grid gap-3 sm:grid-cols-3">
          <Input
            label="Cantidad"
            type="number"
            step="0.0001"
            placeholder="1"
            value={form.cantidad}
            onChange={(e) => setForm({ ...form, cantidad: e.target.value })}
          />
          <Input
            label={`Costo por ${presentacion?.nombre ?? 'unidad'}`}
            type="number"
            step="0.01"
            placeholder="170.00"
            value={form.costoTotal}
            onChange={(e) => setForm({ ...form, costoTotal: e.target.value })}
          />
          <Input
            label="Flete"
            optional
            type="number"
            step="0.01"
            hint={<span className="text-xs text-ink-soft">de toda la entrada</span>}
            value={form.flete}
            onChange={(e) => setForm({ ...form, flete: e.target.value })}
          />
        </div>

        <Input
          label="Referencia"
          optional
          placeholder="F001-2280"
          value={form.referencia}
          onChange={(e) => setForm({ ...form, referencia: e.target.value })}
        />

        {/* El cálculo a la vista: es donde se nota si el costo se puso por kilo
            en vez de por saco. */}
        {enBase > 0 && (
          <p className="rounded-field bg-slate-50 px-3 py-2 text-xs text-ink-muted">
            Entran <span className="font-semibold text-ink">{enBase} {producto.unidadBase}</span>
            {costoTotal > 0 && (
              <>
                {' '}
                a{' '}
                <span className="font-semibold text-ink">
                  S/ {costoUnitario.toFixed(4)} por {producto.unidadBase}
                </span>{' '}
                (S/ {costoTotal.toFixed(2)} en total{form.flete ? ', flete incluido' : ''})
              </>
            )}
          </p>
        )}

        <Button size="sm" loading={guardando} onClick={() => void registrar()}>
          Registrar entrada
        </Button>
      </div>
    </div>
  )
}

function Resumen({ titulo, valor, nota }: { titulo: string; valor: string; nota?: string }) {
  return (
    <div className="rounded-field border border-line bg-white px-3 py-2">
      <p className="text-[11px] text-ink-soft">{titulo}</p>
      <p className="truncate text-lg font-bold text-ink">{valor}</p>
      {nota && <p className="truncate text-[11px] text-ink-soft">{nota}</p>}
    </div>
  )
}
