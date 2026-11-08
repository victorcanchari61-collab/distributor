import { useCallback, useEffect, useMemo, useState } from 'react'
import { MapPin, MoveRight, PackageSearch, TriangleAlert, Warehouse, X } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Checkbox,
  Desplegable,
  ListPage,
  Modal,
  StatCard,
  Tabs,
  useToast,
} from '../../components/ui'
import type { DataTableColumn, TabItem } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { ACCION, usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { almacenApi, ubicacionApi, ubicacionProductoApi } from './inventarioApi'
import type { AlmacenResponse, ProductoUbicado, ProductosUbicados, UbicacionResponse } from './inventarioApi'

import { opcional } from '../../lib/apoyo'
const SUBMODULO = 'inv.ubicaciones'

type Mostrar = 'todos' | 'sin' | 'con'

/**
 * Ubicación de productos: dónde está puesto cada producto dentro de un almacén.
 *
 * La lista de trabajo para ordenar el almacén: «Sin lugar» son los productos que tienen stock y nadie sabe dónde
 * están. Se eligen varios y se ponen o se mueven a un lugar de una vez. El stock sigue siendo por almacén: esto
 * dice dónde buscar, no cuánto hay en cada cuarto.
 */
export function UbicacionProductosPage() {
  const toast = useToast()
  const { puede } = usePermisos()
  const puedeEditar = puede(SUBMODULO, ACCION.editar)

  const [almacenes, setAlmacenes] = useState<AlmacenResponse[]>([])
  const [almacenId, setAlmacenId] = useState(0)
  const [datos, setDatos] = useState<ProductosUbicados | null>(null)
  const [lugares, setLugares] = useState<UbicacionResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [mostrar, setMostrar] = useState<Mostrar>('todos')
  const [elegidos, setElegidos] = useState<Set<number>>(new Set())

  // El modal de poner o mover.
  const [poniendo, setPoniendo] = useState(false)
  const [lugarId, setLugarId] = useState(0)
  const [mover, setMover] = useState(true)
  const [guardando, setGuardando] = useState(false)

  // Los almacenes, una vez: el primero activo es el que se abre.
  useEffect(() => {
    almacenApi
      .getAll()
      .then((a) => {
        const activos = a.filter((x) => x.activo)
        setAlmacenes(activos)
        setAlmacenId((actual) => actual || (activos.find((x) => x.esPrincipal) ?? activos[0])?.id || 0)
      })
      .catch((e) => setError(e instanceof ApiError ? e.message : 'No pudimos cargar los almacenes.'))
  }, [])

  const cargar = useCallback(async () => {
    if (!almacenId) return
    setCargando(true)
    try {
      const [lista, arbol] = await Promise.all([ubicacionProductoApi.listar(almacenId), opcional(ubicacionApi.listar(almacenId), [])])
      setDatos(lista)
      setLugares(arbol)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los productos.')
    } finally {
      setCargando(false)
    }
  }, [almacenId])

  useEffect(() => {
    setElegidos(new Set())
    void cargar()
  }, [cargar])

  // Un lugar o un producto cambiaron en otra PC (o aquí mismo).
  useRealtime(['ubicaciones', 'stock'], cargar)

  const filas = useMemo(() => {
    const todos = datos?.items ?? []
    return mostrar === 'sin'
      ? todos.filter((p) => p.lugares.length === 0)
      : mostrar === 'con'
        ? todos.filter((p) => p.lugares.length > 0)
        : todos
  }, [datos, mostrar])

  const lugaresActivos = useMemo(() => lugares.filter((l) => l.activo), [lugares])

  const alternar = (id: number) =>
    setElegidos((previo) => {
      const siguiente = new Set(previo)
      if (siguiente.has(id)) siguiente.delete(id)
      else siguiente.add(id)
      return siguiente
    })

  const elegirSinLugar = () =>
    setElegidos(new Set((datos?.items ?? []).filter((p) => p.lugares.length === 0).map((p) => p.productoId)))

  const abrirPoner = () => {
    setLugarId(0)
    // Si algún elegido ya tiene lugar, lo normal es moverlo; si ninguno, no hay nada que quitar.
    setMover(true)
    setPoniendo(true)
  }

  const poner = async () => {
    if (!lugarId) return toast.error('Elige el lugar.')

    setGuardando(true)
    try {
      setDatos(await ubicacionProductoApi.asignar({ ubicacionId: lugarId, productoIds: [...elegidos], reemplazar: mover }))
      toast.exito(`${elegidos.size} ${elegidos.size === 1 ? 'producto puesto' : 'productos puestos'}`)
      setElegidos(new Set())
      setPoniendo(false)
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos poner los productos.')
    } finally {
      setGuardando(false)
    }
  }

  const quitar = async (producto: ProductoUbicado, ubicacionId: number) => {
    try {
      setDatos(await ubicacionProductoApi.quitar({ ubicacionId, productoIds: [producto.productoId] }))
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos quitar el producto del lugar.')
    }
  }

  const columnas: DataTableColumn<ProductoUbicado>[] = [
    ...(puedeEditar
      ? [
          {
            key: 'elegir',
            label: '',
            width: 48,
            filterable: false,
            sortable: false,
            searchable: false,
            render: (p: ProductoUbicado) => (
              <input
                type="checkbox"
                aria-label={`Elegir ${p.producto}`}
                checked={elegidos.has(p.productoId)}
                onChange={() => alternar(p.productoId)}
                className="size-4 cursor-pointer accent-[rgb(var(--sys-rgb))]"
              />
            ),
          } satisfies DataTableColumn<ProductoUbicado>,
        ]
      : []),
    { key: 'codigo', label: 'Código', filterable: false, render: (p) => <span className="text-ink-soft">{p.codigo}</span> },
    {
      key: 'producto',
      label: 'Producto',
      filterable: false,
      render: (p) => <span className="font-medium text-ink">{p.producto}</span>,
    },
    {
      key: 'categoria',
      label: 'Categoría',
      filterType: 'select',
      filterOptions: [...new Set((datos?.items ?? []).map((p) => p.categoria).filter((c): c is string => !!c))]
        .sort((a, b) => a.localeCompare(b, 'es'))
        .map((c) => ({ value: c, label: c })),
      value: (p) => p.categoria ?? '',
      render: (p) => p.categoria ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'stock',
      label: 'Stock',
      align: 'right',
      filterable: false,
      value: (p) => p.stock,
      render: (p) => (p.stock > 0 ? Number(p.stock.toFixed(4)) : <span className="text-ink-soft">—</span>),
    },
    {
      key: 'unidadBase',
      label: 'Unidad',
      filterable: false,
      value: (p) => (p.stock > 0 ? p.unidadBase : ''),
      render: (p) => (p.stock > 0 ? p.unidadBase : <span className="text-ink-soft">—</span>),
    },
    {
      key: 'lugar',
      label: 'Dónde está',
      // El filtro acierta si CUALQUIERA de sus lugares coincide: un producto puede estar en varios.
      filterType: 'select',
      filterOptions: lugaresActivos.map((l) => ({ value: l.ruta, label: l.nombre ? `${l.ruta} · ${l.nombre}` : l.ruta })),
      valores: (p) => p.lugares.map((l) => l.ruta),
      value: (p) => p.lugares.map((l) => l.ruta).join(' '),
      render: (p) =>
        p.lugares.length === 0 ? (
          <Badge tone="warning">Sin lugar</Badge>
        ) : (
          <span className="flex flex-wrap gap-1.5">
            {p.lugares.map((l) => (
              <span
                key={l.ubicacionId}
                className="inline-flex items-center gap-1 rounded-full bg-[rgb(var(--sys-rgb)/0.1)] py-0.5 pr-1 pl-2 text-xs font-semibold text-[rgb(var(--sys-ink-rgb))]"
                title={l.nombre ?? l.ruta}
              >
                <MapPin size={11} />
                {l.ruta}
                {puedeEditar && (
                  <button
                    type="button"
                    aria-label={`Quitar ${p.producto} de ${l.ruta}`}
                    onClick={() => void quitar(p, l.ubicacionId)}
                    className="cursor-pointer rounded-full p-0.5 hover:bg-black/10"
                  >
                    <X size={11} />
                  </button>
                )}
              </span>
            ))}
          </span>
        ),
    },
  ]

  const tabs: TabItem[] = almacenes.map((a) => ({ id: String(a.id), label: a.nombre, icon: <Warehouse size={15} /> }))
  const ninguno = datos !== null && datos.lugares === 0

  return (
    <ListPage
      icon={<MapPin size={20} />}
      title="Ubicación de productos"
      description="Dónde está puesto cada producto dentro del almacén: piso y cuarto."
      alert={
        error ? (
          <Alert>{error}</Alert>
        ) : ninguno ? (
          <Alert tone="info">
            Este almacén todavía no tiene lugares definidos. Créalos en Almacenes → Ubicaciones (pisos y cuartos) y vuelve aquí para poner los productos.
          </Alert>
        ) : undefined
      }
      banner={
        almacenes.length > 1 ? (
          <Tabs active={String(almacenId)} onChange={(id) => setAlmacenId(Number(id))} items={tabs} />
        ) : undefined
      }
      stats={
        <>
          <StatCard label="Productos" value={String(datos?.items.length ?? 0)} hint="con stock o ya ubicados" icon={<PackageSearch size={18} />} />
          <StatCard
            label="Sin lugar"
            value={String(datos?.sinLugar ?? 0)}
            hint="nadie sabe dónde están"
            icon={<TriangleAlert size={18} />}
            tono={datos && datos.sinLugar > 0 ? 'warning' : 'success'}
          />
          <StatCard
            label="Con lugar"
            value={String((datos?.items.length ?? 0) - (datos?.sinLugar ?? 0))}
            icon={<MapPin size={18} />}
            tono="success"
          />
          <StatCard label="Lugares definidos" value={String(datos?.lugares ?? 0)} hint="pisos y cuartos" icon={<Warehouse size={18} />} tono="neutral" />
        </>
      }
      actions={
        <div className="flex flex-wrap items-center gap-2">
          <Desplegable
            size="sm"
            value={mostrar}
            onChange={(v) => setMostrar(v as Mostrar)}
            options={[
              { value: 'todos', label: 'Todos los productos' },
              { value: 'sin', label: 'Solo sin lugar' },
              { value: 'con', label: 'Solo con lugar' },
            ]}
          />
          {puedeEditar && (datos?.sinLugar ?? 0) > 0 && (
            <Button size="sm" variant="secondary" onClick={elegirSinLugar}>
              Elegir los sin lugar
            </Button>
          )}
          {puedeEditar && elegidos.size > 0 && (
            <>
              <Button size="sm" variant="ghost" onClick={() => setElegidos(new Set())}>
                Limpiar ({elegidos.size})
              </Button>
              <Button size="sm" onClick={abrirPoner} iconRight={<MoveRight size={15} />} disabled={lugaresActivos.length === 0}>
                Poner en un lugar
              </Button>
            </>
          )}
        </div>
      }
      columns={columnas}
      rows={filas}
      rowKey="productoId"
      cardIcon={MapPin}
      searchPlaceholder="Buscar producto, código o lugar..."
      empty={cargando ? 'Cargando productos...' : 'No hay productos para mostrar.'}
      note="El stock se cuenta por almacén, no por cuarto: esto dice dónde buscar el producto."
    >
      <Modal
        open={poniendo}
        size="sm"
        title={`Poner ${elegidos.size} ${elegidos.size === 1 ? 'producto' : 'productos'} en un lugar`}
        description="Se guardan en el lugar que elijas."
        onClose={() => setPoniendo(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setPoniendo(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void poner()}>
              Poner
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          <Desplegable
            label="Lugar"
            value={lugarId}
            onChange={(v) => setLugarId(Number(v))}
            options={[
              { value: 0, label: 'Elegir' },
              ...lugaresActivos.map((l) => ({ value: l.id, label: l.ruta, detalle: l.nombre ?? l.tipoEtiqueta })),
            ]}
          />
          <div>
            <Checkbox label="Mover: quitarlos de donde estén ahora" checked={mover} onChange={(e) => setMover(e.target.checked)} />
            <p className="mt-1 text-xs text-ink-soft">
              Desmarcado, quedan puestos en el lugar nuevo y también donde ya estaban (un producto puede estar en varios
              lugares).
            </p>
          </div>
        </div>
      </Modal>
    </ListPage>
  )
}
