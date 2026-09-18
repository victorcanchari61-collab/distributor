import { useCallback, useEffect, useState } from 'react'
import { ClipboardCheck, Save } from 'lucide-react'
import { Alert, Badge, Button, Input, ListPage, StatCard } from '../../components/ui'
import type { ConsultaTabla, DataTableColumn } from '../../components/ui'
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

  /*
   * Qué almacén contar vive como un filtro más, no como un control aparte:
   * al elegirlo acá se vuelve a pedir el stock de ESE almacén al servidor
   * (es un catálogo por almacén, no una columna más de la fila).
   */
  const alElegirAlmacen = (consulta: ConsultaTabla) => {
    const nombre = consulta.filtros.find((f) => f.columna === 'almacen')?.valor
    const elegido = nombre ? almacenes.find((a) => a.nombre === nombre) : undefined
    const principal = almacenes.find((a) => a.esPrincipal)?.id ?? almacenes[0]?.id ?? 0
    const nuevoId = elegido?.id ?? principal
    if (nuevoId && nuevoId !== almacenId) setAlmacenId(nuevoId)
  }

  const columns: DataTableColumn<StockResponse>[] = [
    // El producto se busca con el buscador de arriba, no en el panel.
    {
      key: 'producto',
      label: 'Producto',
      filterable: false,
      render: (row) => (
        <span>
          <span className="font-medium text-ink">{row.producto}</span>
          <span className="ml-2 text-xs text-ink-soft">{row.codigo}</span>
        </span>
      ),
    },
    {
      key: 'almacen',
      label: 'Almacén',
      filterType: 'select',
      filterOptions: almacenes.filter((a) => a.activo).map((a) => ({ value: a.nombre, label: a.nombre })),
    },
    {
      key: 'categoria',
      label: 'Categoría',
      filterType: 'select',
      filterOptions: [...new Set(stock.map((s) => s.categoria).filter((v): v is string => !!v))]
        .sort((a, b) => a.localeCompare(b, 'es'))
        .map((v) => ({ value: v, label: v })),
      render: (row) => row.categoria ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'marca',
      label: 'Marca',
      filterType: 'select',
      filterOptions: [...new Set(stock.map((s) => s.marca).filter((v): v is string => !!v))]
        .sort((a, b) => a.localeCompare(b, 'es'))
        .map((v) => ({ value: v, label: v })),
      render: (row) => row.marca ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'stock',
      label: 'Teórico',
      align: 'right',
      filterable: false,
      render: (row) => (
        <span className="text-ink-soft">
          {row.stock} {row.unidadBase}
        </span>
      ),
    },
    {
      // Lo tecleado no es un dato guardado: es transitorio, así que no
      // ordena ni filtra, solo se busca cuando se escribe (para eso entra
      // igual al buscador general, vía `value`).
      key: 'contado',
      label: 'Contado',
      align: 'right',
      sortable: false,
      filterable: false,
      value: (row) => contados[row.productoId] ?? '',
      render: (row) => (
        <Input
          type="number"
          step="0.0001"
          value={contados[row.productoId] ?? ''}
          onChange={(e) => setContados({ ...contados, [row.productoId]: e.target.value })}
        />
      ),
    },
    {
      key: 'diferencia',
      label: 'Diferencia',
      align: 'right',
      sortable: false,
      filterable: false,
      render: (row) => {
        const texto = contados[row.productoId] ?? ''
        const diferencia = texto.trim() !== '' ? Number(texto) - row.stock : null
        if (diferencia == null) return <span className="text-ink-soft">—</span>
        if (diferencia === 0) return <Badge tone="neutral">Sin diferencia</Badge>
        return diferencia > 0 ? (
          <Badge tone="success">+{diferencia}</Badge>
        ) : (
          <Badge tone="danger">{diferencia}</Badge>
        )
      },
    },
  ]

  return (
    <ListPage
      icon={<ClipboardCheck size={20} />}
      title="Conteos cíclicos"
      description="Cuánto hay en el sistema contra cuánto hay en el anaquel. La diferencia se registra sola como ajuste."
      actions={
        puede('inv.conteos', 'crear') ? (
          <Button size="sm" onClick={() => void registrarConteo()} loading={guardando}>
            <Save size={15} />
            Registrar conteo
          </Button>
        ) : undefined
      }
      alert={
        error ? (
          <Alert>{error}</Alert>
        ) : resultado ? (
          <div className="rounded-field border border-emerald-600 bg-emerald-50 p-3 text-sm text-emerald-700">
            {resultado}
          </div>
        ) : undefined
      }
      stats={
        <>
          <StatCard label="Productos en el almacén" value={String(stock.length)} icon={<ClipboardCheck size={18} />} />
          <StatCard
            label="Con conteo escrito"
            value={String(contadosActivos.length)}
            icon={<Save size={18} />}
            tono="success"
          />
        </>
      }
      columns={columns}
      rows={stock}
      rowKey="productoId"
      onConsulta={alElegirAlmacen}
      cardIcon={ClipboardCheck}
      searchPlaceholder="Buscar por producto o código..."
      empty={cargando || cargandoStock ? 'Cargando...' : 'No hay productos que controlen stock en este almacén.'}
    />
  )
}
