import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import type { DragEvent } from 'react'
import { DoorOpen, Footprints, LayoutGrid, Plus, Search, Trash2, X } from 'lucide-react'
import { FaXmark } from 'react-icons/fa6'
import { Alert, Badge, BuscadorModal, Button, Input, PageHeader, RowAction, Tabs, useToast } from '../../../components/ui'
import type { DataTableColumn } from '../../../components/ui'
import { ApiError } from '../../../lib/apiClient'
import { ACCION, usePermisos } from '../../../lib/permisos'
import { useRealtime } from '../../../lib/realtime'
import { almacenApi, planoApi, ubicacionApi, ubicacionProductoApi } from '../inventarioApi'
import type {
  AlmacenResponse,
  ElementoPlano,
  ProductoUbicado,
  ProductosUbicados,
  RectPlano,
  TipoElementoPlano,
} from '../inventarioApi'
import { PlanoLienzo } from './PlanoLienzo'
import { MIME_PRODUCTO, huecoLibre } from './geometria'
import { figurasDe, idDeClave, normalizar, pisosDe, usePlanoAlmacen } from './datosPlano'

const SUBMODULO = 'inv.plano'

/** Lo que lleva un producto arrastrado: cuál es y de qué lugar sale (null si no estaba en ninguno). */
interface ProductoArrastrado {
  productoId: number
  desde: number | null
}

const mensaje = (e: unknown, otro: string) => (e instanceof ApiError ? e.message : otro)
const cantidad = (n: number) => Number(n.toFixed(2)).toString()

/**
 * El plano del almacén: cada piso dibujado con sus lugares, pasillos y escaleras, y la mercadería puesta en cada
 * lugar.
 *
 * Sirve para dos cosas. Para ordenar: se dibuja el piso como es (arrastrar mueve, la esquina agranda) y se arrastra
 * cada producto al lugar donde está. Y para encontrar: se escribe "arroz" y se ilumina el lugar donde buscarlo.
 * El stock sigue siendo por almacén; el plano dice dónde está, no cuánto hay en cada lugar.
 */
export function PlanoPage() {
  const toast = useToast()
  const { puede } = usePermisos()
  const puedeEditar = puede(SUBMODULO, ACCION.editar)

  const [almacenes, setAlmacenes] = useState<AlmacenResponse[]>([])
  const [almacenId, setAlmacenId] = useState(0)
  const [errorAlmacenes, setErrorAlmacenes] = useState('')
  const { lugares, setLugares, plano, setPlano, cargando, error, recargar } = usePlanoAlmacen(almacenId)
  const [productos, setProductos] = useState<ProductosUbicados | null>(null)

  const [pisoElegido, setPisoElegido] = useState<number | null>(null)
  const [seleccion, setSeleccion] = useState<string | null>(null)
  const [busqueda, setBusqueda] = useState('')
  const [ocupado, setOcupado] = useState(false)
  const [poniendo, setPoniendo] = useState(false)
  const [nombre, setNombre] = useState('')

  useEffect(() => {
    almacenApi
      .getAll()
      .then((a) => {
        const activos = a.filter((x) => x.activo)
        setAlmacenes(activos)
        setAlmacenId((actual) => actual || (activos.find((x) => x.esPrincipal) ?? activos[0])?.id || 0)
      })
      .catch((e) => setErrorAlmacenes(mensaje(e, 'No pudimos cargar los almacenes.')))
  }, [])

  // El almacén que se mira ahora: una respuesta que llega tarde, de otro almacén, se descarta.
  const almacenVigente = useRef(almacenId)
  almacenVigente.current = almacenId

  const cargarProductos = useCallback(async () => {
    if (!almacenId) return
    try {
      const lista = await ubicacionProductoApi.listar(almacenId)
      if (almacenVigente.current === almacenId) setProductos(lista)
    } catch {
      if (almacenVigente.current === almacenId) setProductos(null)
    }
  }, [almacenId])

  useEffect(() => {
    setSeleccion(null)
    setPisoElegido(null)
    setProductos(null)
    void cargarProductos()
  }, [cargarProductos])

  useRealtime(['ubicaciones', 'stock'], cargarProductos)

  // ------------------------------------------------------------- El piso que se mira

  const pisos = useMemo(() => pisosDe(lugares), [lugares])
  const usaPisos = pisos.length > 0
  const tieneSueltos = lugares.some((l) => l.tipo === 'CUARTO' && l.padreId === null)
  const pisoId = usaPisos ? (pisos.some((p) => p.id === pisoElegido) ? pisoElegido : pisos[0].id) : null
  const piso = pisos.find((p) => p.id === pisoId) ?? null

  const figuras = useMemo(() => figurasDe(lugares, plano, pisoId), [lugares, plano, pisoId])
  const sinDibujar = lugares.filter((l) => l.tipo === 'CUARTO' && l.padreId === pisoId && l.planoX === null && l.activo)
  const columnas = plano?.columnas ?? 24
  const filas = plano?.filas ?? 14

  const lugarElegido = seleccion?.startsWith('L') ? (lugares.find((l) => l.id === idDeClave(seleccion)) ?? null) : null
  const elementoElegido: ElementoPlano | null = seleccion?.startsWith('E')
    ? (plano?.elementos.find((e) => e.id === idDeClave(seleccion)) ?? null)
    : null

  // El nombre que se edita en el panel sigue a lo elegido.
  useEffect(() => {
    setNombre(lugarElegido ? (lugarElegido.nombre ?? '') : elementoElegido ? elementoElegido.nombre : (piso?.nombre ?? ''))
  }, [lugarElegido?.id, lugarElegido?.nombre, elementoElegido?.id, elementoElegido?.nombre, piso?.id, piso?.nombre])

  // ------------------------------------------------------------- Buscar un producto

  const q = normalizar(busqueda)
  const hallados = useMemo(
    () =>
      q
        ? (productos?.items ?? []).filter((p) => normalizar(p.producto).includes(q) || normalizar(p.codigo).includes(q))
        : [],
    [productos, q],
  )
  const lugaresHallados = useMemo(() => new Set(hallados.flatMap((p) => p.lugares.map((l) => l.ubicacionId))), [hallados])
  const resaltadas = useMemo(() => new Set([...lugaresHallados].map((id) => `L${id}`)), [lugaresHallados])

  /** Cuántos lugares con lo buscado hay en cada piso: el número de su pestaña. */
  const halladosPorPiso = (id: number) => lugares.filter((l) => l.padreId === id && lugaresHallados.has(l.id)).length

  /** Lleva al piso del lugar y lo elige. */
  const irALugar = (ubicacionId: number) => {
    const l = lugares.find((x) => x.id === ubicacionId)
    if (!l) return
    if (l.padreId !== null) setPisoElegido(l.padreId)
    setSeleccion(`L${l.id}`)
  }

  // ------------------------------------------------------------- Dibujar

  /** Mover o agrandar: se ve al instante y se guarda; si el servidor no lo acepta, vuelve a donde estaba. */
  const cambiar = async (clave: string, rect: RectPlano) => {
    const id = idDeClave(clave)
    if (clave.startsWith('L')) {
      const antes = lugares
      setLugares((ls) =>
        ls.map((l) => (l.id === id ? { ...l, planoX: rect.x, planoY: rect.y, planoAncho: rect.ancho, planoAlto: rect.alto } : l)),
      )
      try {
        await planoApi.posicionar(id, rect)
      } catch (e) {
        setLugares(antes)
        toast.error(mensaje(e, 'No pudimos mover el lugar.'))
      }
    } else if (plano) {
      const el = plano.elementos.find((x) => x.id === id)
      if (!el) return
      const antes = plano
      setPlano({ ...plano, elementos: plano.elementos.map((x) => (x.id === id ? { ...x, ...rect } : x)) })
      try {
        await planoApi.actualizarElemento(id, { ...el, ...rect })
      } catch (e) {
        setPlano(antes)
        toast.error(mensaje(e, 'No pudimos moverlo.'))
      }
    }
  }

  const hueco = (ancho: number, alto: number, minAncho: number, minAlto: number) =>
    huecoLibre(figuras, columnas, filas, ancho, alto) ?? huecoLibre(figuras, columnas, filas, minAncho, minAlto)

  const conOcupado = async (accion: () => Promise<void>, error: string) => {
    setOcupado(true)
    try {
      await accion()
    } catch (e) {
      toast.error(mensaje(e, error))
    } finally {
      setOcupado(false)
    }
  }

  const agregarLugar = () => {
    const r = hueco(5, 4, 2, 2)
    if (!r) return toast.error('No hay espacio libre en este plano.')
    void conOcupado(async () => {
      const nuevo = await ubicacionApi.crear(almacenId, { padreId: pisoId, tipo: 'CUARTO', nombre: 'Nuevo lugar' })
      await planoApi.posicionar(nuevo.id, r)
      await recargar()
      setSeleccion(`L${nuevo.id}`)
    }, 'No pudimos crear el lugar.')
  }

  /** Dibuja en el plano un lugar que ya existía (creado desde la lista de Almacenes). */
  const dibujar = (ubicacionId: number) => {
    const r = hueco(4, 3, 2, 2)
    if (!r) return toast.error('No hay espacio libre en este plano.')
    void conOcupado(async () => {
      await planoApi.posicionar(ubicacionId, r)
      await recargar()
      setSeleccion(`L${ubicacionId}`)
    }, 'No pudimos dibujar el lugar.')
  }

  const agregarElemento = (tipo: TipoElementoPlano) => {
    const r = tipo === 'PASILLO' ? hueco(8, 2, 2, 1) : hueco(3, 3, 2, 2)
    if (!r) return toast.error('No hay espacio libre en este plano.')
    void conOcupado(async () => {
      const nuevo = await planoApi.crearElemento(almacenId, {
        pisoId,
        tipo,
        nombre: tipo === 'PASILLO' ? 'Pasillo' : 'Escalera',
        ...r,
      })
      await recargar()
      setSeleccion(`E${nuevo.id}`)
    }, 'No pudimos agregarlo.')
  }

  const agregarPiso = () =>
    void conOcupado(async () => {
      const nuevo = await ubicacionApi.crear(almacenId, { padreId: null, tipo: 'PISO', nombre: `Piso ${pisos.length + 1}` })
      await recargar()
      setPisoElegido(nuevo.id)
      setSeleccion(null)
    }, 'No pudimos crear el piso.')

  /** Guarda el nombre del panel en lo elegido (o en el piso, si no hay nada elegido). */
  const guardarNombre = () => {
    const limpio = nombre.trim()
    if (lugarElegido || (!seleccion && piso)) {
      const l = lugarElegido ?? piso
      if (!l || limpio === (l.nombre ?? '') || (!limpio && lugarElegido)) return
      void conOcupado(async () => {
        await ubicacionApi.actualizar(l.id, { codigo: l.codigo, nombre: limpio || null, activo: l.activo })
        await recargar()
      }, 'No pudimos cambiar el nombre.')
    } else if (elementoElegido && limpio && limpio !== elementoElegido.nombre) {
      const el = elementoElegido
      void conOcupado(async () => {
        await planoApi.actualizarElemento(el.id, { ...el, nombre: limpio })
        await recargar()
      }, 'No pudimos cambiar el nombre.')
    }
  }

  const quitarDelPlano = (ubicacionId: number) =>
    void conOcupado(async () => {
      await planoApi.posicionar(ubicacionId, null)
      setSeleccion(null)
      await recargar()
    }, 'No pudimos sacarlo del plano.')

  const eliminarElemento = (id: number) =>
    void conOcupado(async () => {
      await planoApi.eliminarElemento(id)
      setSeleccion(null)
      await recargar()
    }, 'No pudimos eliminarlo.')

  // ------------------------------------------------------------- La mercadería

  const productosDe = (ubicacionId: number) =>
    (productos?.items ?? []).filter((p) => p.lugares.some((l) => l.ubicacionId === ubicacionId))
  const sinLugar = (productos?.items ?? []).filter((p) => p.lugares.length === 0)

  const arrastrar = (e: DragEvent, p: ProductoUbicado, desde: number | null) => {
    const datos: ProductoArrastrado = { productoId: p.productoId, desde }
    e.dataTransfer.setData(MIME_PRODUCTO, JSON.stringify(datos))
    e.dataTransfer.effectAllowed = 'move'
  }

  /** Poner un producto en un lugar; si venía de otro lugar, sale de ese (se mueve, no se copia). */
  const llevar = async (productoId: number, desde: number | null, hacia: number) => {
    if (desde === hacia) return
    const p = productos?.items.find((x) => x.productoId === productoId)
    const destino = lugares.find((l) => l.id === hacia)
    try {
      let r = await ubicacionProductoApi.asignar({ ubicacionId: hacia, productoIds: [productoId], reemplazar: false })
      if (desde !== null) r = await ubicacionProductoApi.quitar({ ubicacionId: desde, productoIds: [productoId] })
      setProductos(r)
      await recargar()
      toast.exito(`${p?.producto ?? 'Producto'} ${desde === null ? 'puesto' : 'movido'} en ${destino?.codigo ?? ''}${destino?.nombre ? ` · ${destino.nombre}` : ''}`)
    } catch (e) {
      toast.error(mensaje(e, 'No pudimos mover el producto.'))
    }
  }

  const soltarProducto = (clave: string, e: DragEvent) => {
    if (!puedeEditar || !clave.startsWith('L')) return
    try {
      const datos = JSON.parse(e.dataTransfer.getData(MIME_PRODUCTO)) as ProductoArrastrado
      void llevar(datos.productoId, datos.desde, idDeClave(clave))
    } catch {
      // No era un producto: se ignora.
    }
  }

  const quitarProducto = (p: ProductoUbicado, ubicacionId: number) =>
    void conOcupado(async () => {
      setProductos(await ubicacionProductoApi.quitar({ ubicacionId, productoIds: [p.productoId] }))
      await recargar()
    }, 'No pudimos quitar el producto.')

  const columnasProducto: DataTableColumn<ProductoUbicado>[] = [
    { key: 'codigo', label: 'Código', width: 100 },
    { key: 'producto', label: 'Producto' },
    { key: 'stock', label: 'Stock', align: 'right', width: 110, render: (p) => `${cantidad(p.stock)} ${p.unidadBase}` },
    {
      key: 'lugares',
      label: 'Está en',
      value: (p) => p.lugares.map((l) => l.ruta).join(', '),
      render: (p) => (p.lugares.length ? p.lugares.map((l) => l.ruta).join(', ') : <span className="text-ink-soft">Sin lugar</span>),
    },
  ]

  // ------------------------------------------------------------- Pantalla

  const filaProducto = (p: ProductoUbicado, desde: number | null) => (
    <li
      key={p.productoId}
      draggable={puedeEditar}
      onDragStart={(e) => arrastrar(e, p, desde)}
      className={`flex items-center justify-between gap-2 py-2 ${puedeEditar ? 'cursor-grab' : ''}`}
    >
      <span className="min-w-0">
        <span className="block truncate text-sm font-medium text-ink">
          {puedeEditar && <span className="mr-1 text-ink-soft">⠿</span>}
          {p.producto}
        </span>
        <span className="text-xs text-ink-soft">
          {p.codigo} · {cantidad(p.stock)} {p.unidadBase}
        </span>
      </span>
      {puedeEditar && desde !== null && (
        <RowAction label={`Quitar ${p.producto}`} tone="danger" onClick={() => quitarProducto(p, desde)}>
          <FaXmark size={14} />
        </RowAction>
      )}
    </li>
  )

  const panel = () => {
    if (lugarElegido) {
      const aqui = productosDe(lugarElegido.id)
      return (
        <>
          <div>
            <p className="text-xs text-ink-soft">Lugar</p>
            <h3 className="text-xl font-bold text-ink">{lugarElegido.ruta}</h3>
          </div>
          <Input
            label="Nombre"
            value={nombre}
            disabled={!puedeEditar}
            maxLength={80}
            onChange={(e) => setNombre(e.target.value)}
            onBlur={guardarNombre}
            onKeyDown={(e) => e.key === 'Enter' && (e.target as HTMLInputElement).blur()}
          />
          <div className="flex items-center justify-between gap-2">
            <p className="text-sm font-semibold text-ink">Productos aquí ({aqui.length})</p>
            {puedeEditar && lugarElegido.activo && (
              <Button size="sm" variant="secondary" onClick={() => setPoniendo(true)} iconRight={<Plus size={14} />}>
                Poner
              </Button>
            )}
          </div>
          {aqui.length === 0 ? (
            <p className="rounded-field border border-dashed border-line px-3 py-5 text-center text-sm text-ink-soft">
              {puedeEditar ? 'Vacío. Arrastra aquí un producto o usa «Poner».' : 'Todavía no hay productos puestos aquí.'}
            </p>
          ) : (
            <ul className="max-h-80 divide-y divide-line overflow-y-auto">{aqui.map((p) => filaProducto(p, lugarElegido.id))}</ul>
          )}
          {puedeEditar && (
            <Button size="sm" variant="secondary" onClick={() => quitarDelPlano(lugarElegido.id)} disabled={ocupado}>
              Sacar del plano
            </Button>
          )}
        </>
      )
    }

    if (elementoElegido) {
      return (
        <>
          <div>
            <p className="text-xs text-ink-soft">{elementoElegido.tipo === 'PASILLO' ? 'Pasillo' : 'Escalera'}</p>
            <h3 className="text-xl font-bold text-ink">{elementoElegido.nombre}</h3>
          </div>
          <Input
            label="Nombre"
            value={nombre}
            disabled={!puedeEditar}
            maxLength={80}
            onChange={(e) => setNombre(e.target.value)}
            onBlur={guardarNombre}
            onKeyDown={(e) => e.key === 'Enter' && (e.target as HTMLInputElement).blur()}
          />
          <p className="text-xs text-ink-soft">No guarda mercadería: ayuda a ubicarse en el plano.</p>
          {puedeEditar && (
            <Button size="sm" variant="secondary" onClick={() => eliminarElemento(elementoElegido.id)} disabled={ocupado} iconRight={<Trash2 size={14} />}>
              Eliminar {elementoElegido.tipo === 'PASILLO' ? 'pasillo' : 'escalera'}
            </Button>
          )}
        </>
      )
    }

    // Nada elegido: el piso, lo que falta dibujar y la mercadería sin lugar.
    return (
      <>
        <div>
          <p className="text-xs text-ink-soft">{piso ? 'Piso' : 'Plano'}</p>
          <h3 className="text-xl font-bold text-ink">{piso ? piso.codigo : (almacenes.find((a) => a.id === almacenId)?.nombre ?? '')}</h3>
        </div>
        {piso && (
          <Input
            label="Nombre del piso"
            optional
            value={nombre}
            disabled={!puedeEditar}
            maxLength={80}
            onChange={(e) => setNombre(e.target.value)}
            onBlur={guardarNombre}
            onKeyDown={(e) => e.key === 'Enter' && (e.target as HTMLInputElement).blur()}
          />
        )}
        <p className="text-sm text-ink-muted">
          Toca un lugar del plano para ver qué hay. {puedeEditar && 'Arrastra para moverlo; la esquina de color lo agranda.'}
        </p>

        {sinDibujar.length > 0 && (
          <div>
            <p className="mb-1 text-sm font-semibold text-ink">Sin dibujar en el plano ({sinDibujar.length})</p>
            <ul className="divide-y divide-line">
              {sinDibujar.map((l) => (
                <li key={l.id} className="flex items-center justify-between gap-2 py-1.5">
                  <span className="truncate text-sm text-ink">
                    <b>{l.codigo}</b> {l.nombre}
                  </span>
                  {puedeEditar && (
                    <Button size="sm" variant="secondary" disabled={ocupado} onClick={() => dibujar(l.id)}>
                      Dibujar
                    </Button>
                  )}
                </li>
              ))}
            </ul>
          </div>
        )}

        {sinLugar.length > 0 && (
          <div>
            <p className="text-sm font-semibold text-ink">
              Mercadería sin lugar <Badge tone="warning">{sinLugar.length}</Badge>
            </p>
            {puedeEditar && <p className="text-xs text-ink-soft">Arrástrala al lugar donde está.</p>}
            <ul className="mt-1 max-h-72 divide-y divide-line overflow-y-auto">{sinLugar.map((p) => filaProducto(p, null))}</ul>
          </div>
        )}
      </>
    )
  }

  const vacio = !cargando && lugares.length === 0 && (plano?.elementos.length ?? 0) === 0

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        icon={<LayoutGrid size={20} />}
        title="Plano del almacén"
        description="Cada piso dibujado con sus lugares. Busca un producto y te dice dónde está."
      />

      {(errorAlmacenes || error) && <Alert>{errorAlmacenes || error}</Alert>}

      {almacenes.length > 1 && (
        <Tabs
          active={String(almacenId)}
          onChange={(id) => setAlmacenId(Number(id))}
          items={almacenes.map((a) => ({ id: String(a.id), label: a.nombre }))}
        />
      )}

      <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_340px]">
        <section className="flex min-w-0 flex-col gap-3 rounded-panel border border-line bg-white p-3">
          <div className="flex flex-wrap items-center justify-between gap-2">
            {usaPisos ? (
              <Tabs
                active={String(pisoId)}
                onChange={(id) => {
                  setPisoElegido(Number(id))
                  setSeleccion(null)
                }}
                items={pisos.map((p) => ({
                  id: String(p.id),
                  label: p.nombre ? `${p.codigo} · ${p.nombre}` : p.codigo,
                  badge: q ? halladosPorPiso(p.id) || undefined : undefined,
                }))}
              />
            ) : (
              <span className="text-sm font-semibold text-ink">{tieneSueltos ? 'Un solo ambiente' : ''}</span>
            )}
            {puedeEditar && !vacio && (
              <div className="flex flex-wrap gap-2">
                <Button size="sm" variant="secondary" disabled={ocupado} onClick={agregarLugar} iconRight={<DoorOpen size={14} />}>
                  Lugar
                </Button>
                <Button size="sm" variant="secondary" disabled={ocupado} onClick={() => agregarElemento('PASILLO')} iconRight={<Footprints size={14} />}>
                  Pasillo
                </Button>
                <Button size="sm" variant="secondary" disabled={ocupado} onClick={() => agregarElemento('ESCALERA')}>
                  Escalera
                </Button>
                {!tieneSueltos && (
                  <Button size="sm" disabled={ocupado} onClick={agregarPiso} iconRight={<Plus size={14} />}>
                    Nuevo piso
                  </Button>
                )}
              </div>
            )}
          </div>

          <div className="relative">
            <Input
              icon={<Search size={16} />}
              placeholder="Buscar producto: arroz, 7526..."
              value={busqueda}
              onChange={(e) => setBusqueda(e.target.value)}
            />
            {busqueda && (
              <button
                type="button"
                aria-label="Borrar búsqueda"
                className="absolute top-1/2 right-2 -translate-y-1/2 cursor-pointer text-ink-soft hover:text-ink"
                onClick={() => setBusqueda('')}
              >
                <X size={16} />
              </button>
            )}
          </div>

          {q && (
            <div className="rounded-field bg-surface-alt px-3 py-2 text-sm">
              {hallados.length === 0 ? (
                <span className="text-ink-soft">Ningún producto de este almacén coincide.</span>
              ) : (
                <ul className="max-h-28 space-y-1 overflow-y-auto">
                  {hallados.slice(0, 20).map((p) => (
                    <li key={p.productoId} className="flex flex-wrap items-center gap-x-2 gap-y-1">
                      <span className="font-medium text-ink">{p.producto}</span>
                      {p.lugares.length === 0 ? (
                        <span className="text-xs text-ink-soft">sin lugar</span>
                      ) : (
                        p.lugares.map((l) => (
                          <button
                            key={l.ubicacionId}
                            type="button"
                            className="cursor-pointer rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-800 hover:bg-amber-200"
                            onClick={() => irALugar(l.ubicacionId)}
                          >
                            {l.ruta}
                            {l.nombre ? ` · ${l.nombre}` : ''}
                          </button>
                        ))
                      )}
                    </li>
                  ))}
                </ul>
              )}
            </div>
          )}

          {vacio ? (
            <div className="py-12 text-center">
              <p className="font-medium text-ink">Este almacén todavía no tiene plano</p>
              <p className="mx-auto mt-1 max-w-md text-sm text-ink-soft">
                {puedeEditar
                  ? '¿Tiene pisos? Crea el primero y dibuja sus lugares. ¿Es un solo ambiente? Dibuja sus lugares directo.'
                  : 'Pide a quien administra el almacén que lo dibuje.'}
              </p>
              {puedeEditar && (
                <div className="mt-4 flex justify-center gap-2">
                  <Button size="sm" disabled={ocupado} onClick={agregarPiso} iconRight={<Plus size={14} />}>
                    Crear el primer piso
                  </Button>
                  <Button size="sm" variant="secondary" disabled={ocupado} onClick={agregarLugar}>
                    Un solo ambiente
                  </Button>
                </div>
              )}
            </div>
          ) : (
            <PlanoLienzo
              columnas={columnas}
              filas={filas}
              figuras={figuras}
              seleccionada={seleccion}
              resaltadas={resaltadas}
              editable={puedeEditar}
              onSeleccionar={setSeleccion}
              onCambiar={(clave, rect) => void cambiar(clave, rect)}
              onSoltarProducto={soltarProducto}
            />
          )}
        </section>

        <aside className="flex flex-col gap-3 self-start rounded-panel border border-line bg-white p-4 lg:sticky lg:top-4">
          {panel()}
        </aside>
      </div>

      <BuscadorModal
        open={poniendo && lugarElegido !== null}
        onClose={() => setPoniendo(false)}
        title="Poner un producto aquí"
        description={lugarElegido ? `Se pondrá en ${lugarElegido.ruta}${lugarElegido.nombre ? ` · ${lugarElegido.nombre}` : ''}` : undefined}
        columns={columnasProducto}
        rows={(productos?.items ?? []).filter((p) => !lugarElegido || !p.lugares.some((l) => l.ubicacionId === lugarElegido.id))}
        rowKey="productoId"
        searchPlaceholder="Buscar producto..."
        empty="No hay más productos con stock en este almacén."
        onSeleccionar={(p) => lugarElegido && void llevar(p.productoId, null, lugarElegido.id)}
      />
    </div>
  )
}
