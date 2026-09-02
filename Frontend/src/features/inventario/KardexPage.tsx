import { useCallback, useEffect, useState } from 'react'
import { ArrowDownCircle, ArrowUpCircle, BookOpen } from 'lucide-react'
import { Alert, Badge, ListPage, Select } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { productoApi } from '../maestros'
import type { ProductoResponse } from '../maestros'
import { almacenApi, kardexApi } from './inventarioApi'
import type { AlmacenResponse, KardexResponse } from './inventarioApi'

/**
 * El kardex: todo lo que entró y salió, con el saldo que dejó cada línea.
 *
 * Es solo lectura. Lo alimentan los ajustes hoy, y mañana las compras y
 * ventas: todos escriben aquí por el mismo camino.
 */
export function KardexPage() {
  const [productos, setProductos] = useState<ProductoResponse[]>([])
  const [almacenes, setAlmacenes] = useState<AlmacenResponse[]>([])
  const [productoId, setProductoId] = useState(0)
  const [almacenId, setAlmacenId] = useState(0)

  const [kardex, setKardex] = useState<KardexResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    void productoApi.getAll().then(setProductos)
    void almacenApi.getAll().then(setAlmacenes)
  }, [])

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setKardex(
        await kardexApi.getAll({
          productoId: productoId || undefined,
          almacenId: almacenId || undefined,
        }),
      )
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar el kardex.')
    } finally {
      setCargando(false)
    }
  }, [productoId, almacenId])

  useEffect(() => {
    void cargar()
  }, [cargar])

  const entradas = kardex.filter((k) => k.tipo === 'ENTRADA')
  const salidas = kardex.filter((k) => k.tipo === 'SALIDA')

  const columns: DataTableColumn<KardexResponse>[] = [
    {
      key: 'fecha',
      label: 'Fecha',
      render: (row) => new Date(row.fecha).toLocaleString('es-PE'),
    },
    { key: 'documento', label: 'Documento', render: (row) => <Badge>{row.documento}</Badge> },
    {
      key: 'motivo',
      label: 'Motivo',
      render: (row) => (
        <span className="flex items-center gap-1.5">
          {row.tipo === 'ENTRADA' ? (
            <ArrowDownCircle size={14} className="text-emerald-600" />
          ) : (
            <ArrowUpCircle size={14} className="text-amber-600" />
          )}
          {row.motivo}
          {row.anulado && <Badge tone="danger">Anulado</Badge>}
        </span>
      ),
    },
    { key: 'producto', label: 'Producto' },
    { key: 'almacen', label: 'Almacén' },
    {
      key: 'cantidadPresentacion',
      label: 'Cantidad',
      align: 'right',
      render: (row) =>
        row.presentacion ? `${row.cantidadPresentacion} ${row.presentacion}` : `${row.cantidad}`,
    },
    {
      key: 'cantidad',
      label: 'En unidad base',
      align: 'right',
      render: (row) => (
        <span className={row.tipo === 'ENTRADA' ? 'text-emerald-600' : 'text-amber-600'}>
          {row.tipo === 'ENTRADA' ? '+' : '−'}
          {row.cantidad} {row.unidadBase}
        </span>
      ),
    },
    {
      key: 'costoTotal',
      label: 'Costo',
      align: 'right',
      render: (row) => `S/ ${row.costoTotal.toFixed(2)}`,
    },
    {
      key: 'saldo',
      label: 'Saldo',
      align: 'right',
      render: (row) => (
        <span className="font-semibold text-ink">
          {row.saldo} {row.unidadBase}
        </span>
      ),
    },
  ]

  return (
    <ListPage
      icon={<BookOpen size={20} />}
      title="Kardex"
      description="Todo lo que entró y salió, con el saldo que dejó cada movimiento."
      alert={error ? <Alert>{error}</Alert> : undefined}
      banner={
        <div className="grid gap-3 sm:grid-cols-2 sm:max-w-lg">
          <Select
            label="Producto"
            value={productoId}
            onChange={(e) => setProductoId(Number(e.target.value))}
          >
            <option value={0}>Todos los productos</option>
            {productos.map((p) => (
              <option key={p.id} value={p.id}>
                {p.codigo} — {p.nombre}
              </option>
            ))}
          </Select>
          <Select
            label="Almacén"
            value={almacenId}
            onChange={(e) => setAlmacenId(Number(e.target.value))}
          >
            <option value={0}>Todos los almacenes</option>
            {almacenes.map((a) => (
              <option key={a.id} value={a.id}>
                {a.nombre}
              </option>
            ))}
          </Select>
        </div>
      }
      columns={columns}
      rows={kardex}
      cardIcon={BookOpen}
      searchPlaceholder="Buscar por documento, motivo, producto..."
      empty={
        cargando
          ? 'Cargando kardex...'
          : 'Todavía no hay movimientos. Se generan al registrar un ajuste.'
      }
      note={
        <>
          {entradas.length} entrada(s) · {salidas.length} salida(s)
        </>
      }
    />
  )
}
