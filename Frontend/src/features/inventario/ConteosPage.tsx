import { useCallback, useEffect, useMemo, useState } from 'react'
import { ClipboardCheck, Save, Search } from 'lucide-react'
import { Alert, Badge, Button, Desplegable, Input, PageHeader, PageSection } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { usePermisos } from '../../lib/permisos'
import { productoApi } from '../maestros'
import type { ProductoResponse } from '../maestros'
import { almacenApi, ajusteApi, motivoApi, stockApi } from './inventarioApi'
import type { AlmacenResponse, MotivoResponse, StockResponse } from './inventarioApi'

/**
 * Conteo cíclico: cuánto hay en el sistema (teórico) contra cuánto hay en el
 * anaquel (contado). La diferencia se registra sola como un ajuste de
 * "Sobrante de conteo" o "Faltante de conteo" — los mismos motivos que ya
 * existen para un ajuste manual, así que no hace falta un documento nuevo:
 * un conteo simplemente genera el ajuste por ti.
 */
export function ConteosPage() {
  const { puede } = usePermisos()
  const [almacenes, setAlmacenes] = useState<AlmacenResponse[]>([])
  const [productos, setProductos] = useState<ProductoResponse[]>([])
  const [motivos, setMotivos] = useState<MotivoResponse[]>([])
  const [stock, setStock] = useState<StockResponse[]>([])
  const [almacenId, setAlmacenId] = useState(0)
  const [busqueda, setBusqueda] = useState('')
  const [contados, setContados] = useState<Record<number, string>>({})

  const [cargando, setCargando] = useState(true)
  const [cargandoStock, setCargandoStock] = useState(false)
  const [guardando, setGuardando] = useState(false)
  const [error, setError] = useState('')
  const [resultado, setResultado] = useState('')

  useEffect(() => {
    const cargarBase = async () => {
      setCargando(true)
      try {
        const [alms, prods, mots] = await Promise.all([
          almacenApi.getAll(),
          productoApi.getAll(),
          motivoApi.getAll(),
        ])
        setAlmacenes(alms)
        setProductos(prods)
        setMotivos(mots)
        setAlmacenId(alms.find((a) => a.esPrincipal)?.id ?? alms[0]?.id ?? 0)
      } catch (e) {
        setError(e instanceof ApiError ? e.message : 'No pudimos cargar los datos.')
      } finally {
        setCargando(false)
      }
    }
    void cargarBase()
  }, [])

  const cargarStock = useCallback(async (idAlmacen: number) => {
    if (!idAlmacen) return
    setCargandoStock(true)
    try {
      setStock(await stockApi.getAll(idAlmacen))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar el stock.')
    } finally {
      setCargandoStock(false)
    }
  }, [])

  useEffect(() => {
    if (almacenId) void cargarStock(almacenId)
  }, [almacenId, cargarStock])

  const motivoSobrante = motivos.find((m) => m.codigo === 'SOBRANTE')
  const motivoFaltante = motivos.find((m) => m.codigo === 'FALTANTE')

  const visibles = useMemo(() => {
    const term = busqueda.trim().toLowerCase()
    if (!term) return stock
    return stock.filter(
      (s) => s.producto.toLowerCase().includes(term) || s.codigo.toLowerCase().includes(term),
    )
  }, [stock, busqueda])

  const contadosActivos = stock.filter((s) => (contados[s.productoId] ?? '').trim() !== '')

  const registrarConteo = async () => {
    if (!almacenId) return setError('Elige el almacén.')

    const lineas = contadosActivos
      .map((s) => ({
        productoId: s.productoId,
        diferencia: Number(contados[s.productoId]) - s.stock,
      }))
      .filter((l) => l.diferencia !== 0)

    const sobrantes = lineas.filter((l) => l.diferencia > 0)
    const faltantes = lineas.filter((l) => l.diferencia < 0)

    if (sobrantes.length === 0 && faltantes.length === 0) {
      return setError('No hay diferencias que registrar: lo contado coincide con lo teórico.')
    }
    if (sobrantes.length > 0 && !motivoSobrante) {
      return setError('No se encontró el motivo "Sobrante de conteo". Revisa Ajustes → Motivos.')
    }
    if (faltantes.length > 0 && !motivoFaltante) {
      return setError('No se encontró el motivo "Faltante de conteo". Revisa Ajustes → Motivos.')
    }

    setGuardando(true)
    setError('')
    setResultado('')
    try {
      if (sobrantes.length > 0 && motivoSobrante) {
        await ajusteApi.create({
          almacenId,
          motivoId: motivoSobrante.id,
          observacion: 'Conteo cíclico',
          flete: 0,
          detalle: sobrantes.map((l) => {
            const producto = productos.find((p) => p.id === l.productoId)
            return {
              productoId: l.productoId,
              cantidad: l.diferencia,
              costoPresentacion: producto?.costoReferencia ?? 0,
            }
          }),
        })
      }
      if (faltantes.length > 0 && motivoFaltante) {
        await ajusteApi.create({
          almacenId,
          motivoId: motivoFaltante.id,
          observacion: 'Conteo cíclico',
          flete: 0,
          detalle: faltantes.map((l) => ({ productoId: l.productoId, cantidad: Math.abs(l.diferencia) })),
        })
      }
      setResultado(
        `Registrado: ${sobrantes.length} sobrante(s) y ${faltantes.length} faltante(s). El stock ya quedó ajustado.`,
      )
      setContados({})
      await cargarStock(almacenId)
    } catch (e) {
      setError(
        e instanceof ApiError ? (e.errors.length ? e.errors.join(' ') : e.message) : 'No pudimos registrar el conteo.',
      )
    } finally {
      setGuardando(false)
    }
  }

  return (
    <div className="space-y-5">
      <PageHeader
        icon={<ClipboardCheck size={20} />}
        title="Conteos cíclicos"
        description="Cuánto hay en el sistema contra cuánto hay en el anaquel. La diferencia se registra sola como ajuste."
      />

      {error && <Alert>{error}</Alert>}
      {resultado && (
        <div className="rounded-field border border-emerald-600 bg-emerald-50 p-3 text-sm text-emerald-700">
          {resultado}
        </div>
      )}

      <PageSection title="Qué contar">
        <div className="grid gap-4 sm:grid-cols-2">
          <Desplegable
            label="Almacén"
            value={almacenId}
            onChange={(v) => setAlmacenId(Number(v))}
            options={almacenes
              .filter((a) => a.activo)
              .map((a) => ({ value: a.id, label: a.nombre, detalle: a.codigo }))}
          />
          <Input
            label="Buscar producto"
            optional
            placeholder="Nombre o código..."
            value={busqueda}
            onChange={(e) => setBusqueda(e.target.value)}
            icon={<Search size={15} />}
          />
        </div>
      </PageSection>

      <PageSection
        title="Contar"
        description={`${contadosActivos.length} producto(s) con conteo escrito, de ${visibles.length} mostrados.`}
        actions={
          puede('inv.conteos', 'crear') ? (
            <Button size="sm" onClick={() => void registrarConteo()} loading={guardando}>
              <Save size={15} />
              Registrar conteo
            </Button>
          ) : undefined
        }
      >
        <div className="max-h-[28rem] overflow-y-auto rounded-field border border-line">
          <table className="w-full min-w-[32rem] border-collapse text-sm">
            <thead>
              <tr className="sticky top-0 border-b border-line bg-surface-soft text-left text-[11px] font-semibold tracking-wider text-ink-soft uppercase">
                <th className="px-3 py-2 font-semibold">Producto</th>
                <th className="w-28 px-3 py-2 text-right font-semibold">Teórico</th>
                <th className="w-28 px-3 py-2 text-right font-semibold">Contado</th>
                <th className="w-32 px-3 py-2 text-right font-semibold">Diferencia</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-line">
              {visibles.map((s) => {
                const texto = contados[s.productoId] ?? ''
                const diferencia = texto.trim() !== '' ? Number(texto) - s.stock : null

                return (
                  <tr key={s.productoId} className="align-middle">
                    <td className="px-3 py-2">
                      <span className="font-medium text-ink">{s.producto}</span>
                      <span className="ml-2 text-xs text-ink-soft">{s.codigo}</span>
                    </td>
                    <td className="px-3 py-2 text-right text-ink-soft">
                      {s.stock} {s.unidadBase}
                    </td>
                    <td className="p-2">
                      <Input
                        type="number"
                        step="0.0001"
                        value={texto}
                        onChange={(e) => setContados({ ...contados, [s.productoId]: e.target.value })}
                      />
                    </td>
                    <td className="px-3 py-2 text-right">
                      {diferencia == null ? (
                        <span className="text-ink-soft">—</span>
                      ) : diferencia === 0 ? (
                        <Badge tone="neutral">Sin diferencia</Badge>
                      ) : diferencia > 0 ? (
                        <Badge tone="success">+{diferencia}</Badge>
                      ) : (
                        <Badge tone="danger">{diferencia}</Badge>
                      )}
                    </td>
                  </tr>
                )
              })}
              {!cargandoStock && visibles.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-3 py-6 text-center text-sm text-ink-soft">
                    {cargando ? 'Cargando...' : 'No hay productos que controlen stock en este almacén.'}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </PageSection>
    </div>
  )
}
