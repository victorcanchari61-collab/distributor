import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  Boxes,
  Download,
  Package,
  PackageCheck,
  Pencil,
  Plus,
  Ruler,
  ShieldCheck,
  ShieldOff,
  Tags,
  Trash2,
  Upload,
} from 'lucide-react'
import {
  Alert,
  Badge,
  BotonMas,
  Button,
  Desplegable,
  ImportarModal,
  Input,
  ListaDesplegable,
  ListPage,
  Modal,
  RowAction,
  StatCard,
  Tabs,
  useConfirmacion,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { exportarExcel, valorDe } from '../../lib/excel'
import { CatalogoSimple } from './CatalogoSimple'
import { CostoReferenciaInput } from './CostoReferenciaInput'
import { PresentacionesEditor } from './PresentacionesEditor'
import type { FilaPresentacion } from './PresentacionesEditor'
import { categoriaApi, marcaApi, productoApi, unidadApi } from './productoApi'
import type {
  CategoriaResponse,
  MarcaResponse,
  ProductoImportRequest,
  ProductoResponse,
  UnidadResponse,
} from './productoApi'
import { useRealtime } from '../../lib/realtime'

/** "Kilos" -> KG, "Sacos" -> SAC... lo que ya trae el catálogo de unidades. */
function unidadDesdeMedida(medida: string): string {
  const m = medida.trim().toLowerCase()
  if (m === 'kilos' || m === 'kilo' || m === 'kg') return 'KG'
  if (m === 'sacos' || m === 'saco') return 'SAC'
  if (m === 'caja' || m === 'cajas') return 'CJA'
  if (m === 'litros' || m === 'litro') return 'LT'
  return 'UND'
}

/** Solo el número si es mayor que cero: precios en 0 o negativos no son reales. */
function numeroPositivo(texto: string): number | null {
  const n = Number(String(texto).replace(',', '.'))
  return Number.isFinite(n) && n > 0 ? n : null
}

const VACIO = {
  codigo: '',
  nombre: '',
  descripcion: '',
  categoriaId: 0,
  marcaId: 0,
  unidadBaseId: 0,
  contenido: '',
  contenidoUnidadId: 0,
  costoReferencia: '',
  stockMinimo: '',
}

type Pestana = 'productos' | 'categorias' | 'marcas' | 'unidades'
type PestanaForm = 'datos' | 'presentaciones'

/** Que catalogo se esta creando sin salir del formulario. */
type CatalogoRapido = 'categoria' | 'marca' | 'unidad' | 'unidadContenido' | null

/** Las dos altas de unidad piden los mismos campos; cambia dónde queda elegida. */
const esUnidad = (c: CatalogoRapido) => c === 'unidad' || c === 'unidadContenido'

export function ProductosPage() {
  const [pestana, setPestana] = useState<Pestana>('productos')

  const [productos, setProductos] = useState<ProductoResponse[]>([])
  const [categorias, setCategorias] = useState<CategoriaResponse[]>([])
  const [marcas, setMarcas] = useState<MarcaResponse[]>([])
  const [unidades, setUnidades] = useState<UnidadResponse[]>([])

  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [importando, setImportando] = useState(false)
  const [editando, setEditando] = useState<ProductoResponse | null>(null)
  const [form, setForm] = useState(VACIO)
  const [presentaciones, setPresentaciones] = useState<FilaPresentacion[]>([])
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')
  const [pestanaForm, setPestanaForm] = useState<PestanaForm>('datos')

  // En que presentacion se escribe el costo de referencia: el saco, la caja.
  const [presentacionCosto, setPresentacionCosto] = useState(0)

  // Alta rapida desde el formulario: que catalogo se esta creando.
  const [crearRapido, setCrearRapido] = useState<CatalogoRapido>(null)
  const [formRapido, setFormRapido] = useState({ nombre: '', codigo: '', tipo: 'CONTEO' })
  const [creando, setCreando] = useState(false)
  const [errorRapido, setErrorRapido] = useState('')

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [p, c, m, u] = await Promise.all([
        productoApi.getAll(),
        categoriaApi.getAll(),
        marcaApi.getAll(),
        unidadApi.getAll(),
      ])
      setProductos(p)
      setCategorias(c)
      setMarcas(m)
      setUnidades(u)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar el catálogo.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['productos', 'categorias', 'marcas', 'unidades'], cargar)

  const unidadesActivas = useMemo(() => unidades.filter((u) => u.activo), [unidades])
  const activos = productos.filter((p) => p.activo)

  const unidadBase = unidades.find((u) => u.id === form.unidadBaseId)?.codigo ?? ''

  const abrirNuevo = () => {
    setEditando(null)
    setForm({ ...VACIO, unidadBaseId: unidadesActivas[0]?.id ?? 0 })
    setPresentaciones([])
    setPresentacionCosto(0)
    setErrorForm('')
    setPestanaForm('datos')
    setAbierto(true)
  }

  const abrirEdicion = (producto: ProductoResponse) => {
    setEditando(producto)
    setForm({
      codigo: producto.codigo,
      nombre: producto.nombre,
      descripcion: producto.descripcion ?? '',
      categoriaId: producto.categoriaId ?? 0,
      marcaId: producto.marcaId ?? 0,
      unidadBaseId: producto.unidadBaseId,
      contenido: producto.contenido ? String(producto.contenido) : '',
      contenidoUnidadId: producto.contenidoUnidadId ?? 0,
      costoReferencia: producto.costoReferencia ? String(producto.costoReferencia) : '',
      stockMinimo: producto.stockMinimo ? String(producto.stockMinimo) : '',
    })

    // Se escribe en la presentación con la que se compra habitualmente.
    const compra =
      producto.presentaciones.find((p) => p.predeterminadaCompra) ??
      producto.presentaciones.find((p) => p.esCompra) ??
      producto.presentaciones[0]
    setPresentacionCosto(compra?.id ?? 0)
    // La base no se edita aquí: la maneja el backend.
    setPresentaciones(
      producto.presentaciones
        .filter((p) => !p.esBase)
        .map((p) => ({
          id: p.id,
          unidadId: p.unidadId,
          nombre: p.nombre,
          factor: p.factor,
          esCompra: p.esCompra,
          esVenta: p.esVenta,
          activo: p.activo,
        })),
    )
    setErrorForm('')
    setPestanaForm('datos')
    setAbierto(true)
  }

  const guardar = async () => {
    setErrorForm('')

    if (!form.codigo.trim()) return setErrorForm('Ingresa el código del producto.')
    if (!form.nombre.trim()) return setErrorForm('Ingresa el nombre.')
    if (!form.unidadBaseId) return setErrorForm('Elige la unidad base.')

    const sinFactor = presentaciones.find((p) => !p.factor || p.factor <= 0)
    if (sinFactor) {
      return setErrorForm(
        `La presentación "${sinFactor.nombre || 'sin nombre'}" necesita un factor mayor que cero.`,
      )
    }

    const sinNombre = presentaciones.find((p) => !p.nombre.trim())
    if (sinNombre) return setErrorForm('Cada presentación necesita un nombre.')

    const base = {
      codigo: form.codigo.trim(),
      nombre: form.nombre.trim(),
      descripcion: form.descripcion.trim() || null,
      categoriaId: form.categoriaId || null,
      marcaId: form.marcaId || null,
      unidadBaseId: form.unidadBaseId,
      contenido: form.contenido ? Number(form.contenido) : null,
      contenidoUnidadId: form.contenido ? form.contenidoUnidadId || null : null,
      costoReferencia: form.costoReferencia ? Number(form.costoReferencia) : null,
      controlaStock: true,
      stockMinimo: Number(form.stockMinimo || 0),
    }

    setGuardando(true)
    try {
      if (editando) {
        await productoApi.update(editando.id, { ...base, activo: editando.activo })

        // Las presentaciones se guardan una a una: las nuevas se agregan y las
        // que ya existían se actualizan.
        for (const fila of presentaciones) {
          const cuerpo = {
            unidadId: fila.unidadId,
            nombre: fila.nombre.trim(),
            factor: fila.factor,
            esCompra: fila.esCompra,
            esVenta: fila.esVenta,
            activo: fila.activo ?? true,
          }
          if (fila.id) {
            await productoApi.actualizarPresentacion(fila.id, cuerpo)
          } else {
            await productoApi.agregarPresentacion(editando.id, cuerpo)
          }
        }

        // Las que se quitaron en pantalla se borran en el servidor.
        const quedaron = new Set(presentaciones.map((p) => p.id).filter(Boolean))
        for (const previa of editando.presentaciones) {
          if (!previa.esBase && !quedaron.has(previa.id)) {
            await productoApi.eliminarPresentacion(previa.id)
          }
        }
      } else {
        await productoApi.create({
          ...base,
          presentaciones: presentaciones.map((p) => ({
            unidadId: p.unidadId,
            nombre: p.nombre.trim(),
            factor: p.factor,
            esCompra: p.esCompra,
            esVenta: p.esVenta,
            activo: true,
          })),
        })
      }

      setAbierto(false)
      await cargar()
    } catch (e) {
      setErrorForm(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos guardar el producto.',
      )
    } finally {
      setGuardando(false)
    }
  }

  /**
   * Crea la categoria, marca o unidad y la deja elegida en el producto: es el
   * motivo de tener el + aqui, no obligar a salir y volver a empezar.
   */
  const crearRapidoGuardar = async () => {
    if (!formRapido.nombre.trim()) return setErrorRapido('Ingresa el nombre.')
    if (esUnidad(crearRapido) && !formRapido.codigo.trim()) {
      return setErrorRapido('Ingresa el código de la unidad.')
    }

    setCreando(true)
    setErrorRapido('')
    try {
      if (crearRapido === 'categoria') {
        const creada = await categoriaApi.create({ nombre: formRapido.nombre.trim() })
        setForm((f) => ({ ...f, categoriaId: creada.id }))
      } else if (crearRapido === 'marca') {
        const creada = await marcaApi.create({ nombre: formRapido.nombre.trim() })
        setForm((f) => ({ ...f, marcaId: creada.id }))
      } else {
        const creada = await unidadApi.create({
          codigo: formRapido.codigo.trim(),
          nombre: formRapido.nombre.trim(),
          tipo: formRapido.tipo as UnidadResponse['tipo'],
          fraccionable: formRapido.tipo !== 'CONTEO',
        })

        // Queda elegida en el campo desde el que se abrió el +.
        setForm((f) =>
          crearRapido === 'unidadContenido'
            ? { ...f, contenidoUnidadId: creada.id }
            : { ...f, unidadBaseId: creada.id },
        )
      }

      await cargar()
      setFormRapido({ nombre: '', codigo: '', tipo: 'CONTEO' })
      setCrearRapido(null)
    } catch (e) {
      setErrorRapido(e instanceof ApiError ? e.message : 'No pudimos crearlo.')
    } finally {
      setCreando(false)
    }
  }

  const cambiarEstado = (producto: ProductoResponse) =>
    confirmar({
      titulo: `${producto.activo ? 'Desactivar' : 'Activar'} ${producto.nombre}`,
      mensaje: producto.activo
        ? 'Deja de aparecer en pedidos y compras nuevos, pero conserva su historial.'
        : 'Vuelve a estar disponible para comprarse y venderse.',
      confirmar: producto.activo ? 'Desactivar' : 'Activar',
      tono: producto.activo ? 'warning' : 'pregunta',
      accion: async () => {
        setError('')
        try {
          await (producto.activo
            ? productoApi.desactivar(producto.id)
            : productoApi.activar(producto.id))
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos cambiar el estado.')
        }
      },
    })

  const exportarProductos = () => {
    exportarExcel(
      'catalogo_productos',
      productos.map((p) => ({
        Código: p.codigo,
        Nombre: p.nombre,
        Categoría: p.categoria ?? '',
        Marca: p.marca ?? '',
        'Unidad base': p.unidadBase,
        'Costo referencia': p.costoReferencia ?? '',
        Presentaciones: p.presentaciones.map((pr) => `${pr.nombre} (${pr.factor})`).join(', '),
        Estado: p.activo ? 'Activo' : 'Inactivo',
      })),
    )
  }

  const eliminar = (producto: ProductoResponse) =>
    confirmar({
      titulo: `Eliminar ${producto.nombre}`,
      mensaje:
        'Se borra junto con sus presentaciones y no se puede deshacer. Si solo quieres dejar de usarlo, desactívalo.',
      confirmar: 'Eliminar',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await productoApi.remove(producto.id)
          await cargar()
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos eliminar el producto.')
        }
      },
    })

  const columns: DataTableColumn<ProductoResponse>[] = [
    { key: 'codigo', label: 'Código' },
    { key: 'nombre', label: 'Nombre' },
    {
      key: 'categoria',
      label: 'Categoría',
      render: (row) => row.categoria ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'marca',
      label: 'Marca',
      render: (row) => row.marca ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'unidadBase',
      label: 'Unidad base',
      render: (row) => <Badge>{row.unidadBase}</Badge>,
    },
    {
      key: 'contenido',
      label: 'Contenido',
      render: (row) =>
        row.contenido ? (
          `${row.contenido} ${row.contenidoUnidad ?? ''}`
        ) : (
          <span className="text-ink-soft">—</span>
        ),
    },
    {
      key: 'costoReferencia',
      label: 'Costo ref.',
      align: 'right',
      render: (row) =>
        row.costoReferencia == null ? (
          <span className="text-ink-soft">—</span>
        ) : (
          <span>
            S/ {row.costoReferencia}
            <span className="ml-1 text-xs text-ink-soft">× {row.unidadBase}</span>
          </span>
        ),
    },
    {
      key: 'presentaciones',
      label: 'Presentaciones',
      value: (row) => row.presentaciones.map((p) => p.nombre).join(' '),
      // Una lista desplegable en vez de una pila de pastillas: con cuatro o
      // cinco presentaciones la fila crecia y la tabla se volvia ilegible.
      render: (row) => (
        <ListaDesplegable
          icono={<Boxes size={13} />}
          titulo="Cómo se compra y se vende"
          resumen={`${row.presentaciones.length} ${
            row.presentaciones.length === 1 ? 'presentación' : 'presentaciones'
          }`}
          items={row.presentaciones.map((p) => ({
            id: p.id,
            label: p.nombre,
            nota: p.esBase ? 'unidad base del stock' : undefined,
            detalle: `${p.factor} ${row.unidadBase}`,
          }))}
        />
      ),
    },
    {
      key: 'activo',
      label: 'Estado',
      value: (row) => (row.activo ? 'Activo' : 'Inactivo'),
      render: (row) => (
        <Badge tone={row.activo ? 'success' : 'neutral'}>
          {row.activo ? 'Activo' : 'Inactivo'}
        </Badge>
      ),
    },
  ]

  const cabecera = (
    <Tabs
      className="mb-5"
      active={pestana}
      onChange={(id) => setPestana(id as Pestana)}
      items={[
        { id: 'productos', label: 'Productos', icon: <Package size={15} />, badge: productos.length },
        { id: 'categorias', label: 'Categorías', icon: <Boxes size={15} />, badge: categorias.length },
        { id: 'marcas', label: 'Marcas', icon: <Tags size={15} />, badge: marcas.length },
        { id: 'unidades', label: 'Unidades', icon: <Ruler size={15} />, badge: unidades.length },
      ]}
    />
  )

  if (pestana !== 'productos') {
    return (
      <>
        {cabecera}
        {pestana === 'categorias' && (
          <CatalogoSimple
            titulo="Categorías"
            descripcion="Familias comerciales del catálogo: abarrotes, aceites, fideos."
            icono={<Boxes size={20} />}
            filas={categorias}
            conDescripcion
            onCrear={(datos) => categoriaApi.create(datos)}
            onActualizar={(id, datos) => categoriaApi.update(id, datos)}
            onEliminar={(id) => categoriaApi.remove(id)}
            onRecargar={cargar}
          />
        )}
        {pestana === 'marcas' && (
          <CatalogoSimple
            titulo="Marcas"
            descripcion="Marcas con las que trabajas."
            icono={<Tags size={20} />}
            filas={marcas}
            onCrear={(datos) => marcaApi.create({ nombre: datos.nombre })}
            onActualizar={(id, datos) =>
              marcaApi.update(id, { nombre: datos.nombre, activo: datos.activo })
            }
            onEliminar={(id) => marcaApi.remove(id)}
            onRecargar={cargar}
          />
        )}
        {pestana === 'unidades' && <UnidadesTabla unidades={unidades} onRecargar={cargar} />}
      </>
    )
  }

  return (
    <>
      {cabecera}
      <ListPage
        icon={<Package size={20} />}
        title="Productos"
        description="Qué se compra y se vende, y en qué presentaciones."
        actions={
          <>
            <Button variant="secondary" size="sm" onClick={exportarProductos} iconRight={<Download size={15} />}>
              Exportar
            </Button>
            <Button variant="secondary" size="sm" onClick={() => setImportando(true)} iconRight={<Upload size={15} />}>
              Importar
            </Button>
            <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
              Nuevo producto
            </Button>
          </>
        }
        alert={error ? <Alert>{error}</Alert> : undefined}
        stats={
          <>
            <StatCard
              label="Productos activos"
              value={String(activos.length)}
              icon={<Package size={18} />}
            />
            <StatCard
              label="Desactivados"
              value={String(productos.length - activos.length)}
              icon={<ShieldOff size={18} />}
              tono={productos.length > activos.length ? 'warning' : 'neutral'}
            />
            <StatCard
              label="Presentaciones"
              value={String(productos.reduce((n, p) => n + p.presentaciones.length, 0))}
              icon={<PackageCheck size={18} />}
              tono="success"
              hint="formas de comprar y vender"
            />
            <StatCard
              label="Categorías"
              value={String(categorias.length)}
              icon={<Boxes size={18} />}
              tono="neutral"
              hint={`${marcas.length} marcas`}
            />
          </>
        }
        columns={columns}
        rows={productos}
        cardIcon={Package}
        searchPlaceholder="Buscar por código, nombre, marca..."
        empty={cargando ? 'Cargando productos...' : 'Todavía no hay productos registrados.'}
        rowActions={(row) => (
          <>
            <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)}>
              <Pencil size={15} />
            </RowAction>
            <RowAction
              label={`${row.activo ? 'Desactivar' : 'Activar'} ${row.nombre}`}
              tone={row.activo ? 'warning' : 'success'}
              onClick={() => cambiarEstado(row)}
            >
              {row.activo ? <ShieldOff size={15} /> : <ShieldCheck size={15} />}
            </RowAction>
            <RowAction label={`Eliminar ${row.nombre}`} tone="danger" onClick={() => eliminar(row)}>
              <Trash2 size={15} />
            </RowAction>
          </>
        )}
      >
        <Modal
          open={abierto}
          title={editando ? `Editar ${editando.nombre}` : 'Nuevo producto'}
          onClose={() => setAbierto(false)}
          footer={
            <>
              <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
                Cancelar
              </Button>
              <Button size="sm" loading={guardando} onClick={() => void guardar()}>
                {editando ? 'Guardar cambios' : 'Crear producto'}
              </Button>
            </>
          }
        >
          <div className="flex flex-col gap-4">
            {errorForm && <Alert>{errorForm}</Alert>}

            {/* Dos pestañas: los datos de la ficha y como se compra y se vende.
                En un solo bloque el formulario obligaba a hacer scroll para
                llegar a las presentaciones, que es lo que mas se toca. */}
            <Tabs
              active={pestanaForm}
              onChange={(id) => setPestanaForm(id as PestanaForm)}
              items={[
                { id: 'datos', label: 'Datos', icon: <Package size={14} /> },
                {
                  id: 'presentaciones',
                  label: 'Presentaciones',
                  icon: <Boxes size={14} />,
                  badge: presentaciones.length + 1,
                },
              ]}
            />

            {pestanaForm === 'datos' ? (
              <div className="flex flex-col gap-4">
                <div className="grid gap-4 sm:grid-cols-[10rem_1fr]">
                  <Input
                    label="Código"
                    placeholder="AZ-RUB"
                    value={form.codigo}
                    onChange={(e) => setForm({ ...form, codigo: e.target.value })}
                  />
                  <Input
                    label="Nombre"
                    placeholder="Azúcar rubia"
                    value={form.nombre}
                    onChange={(e) => setForm({ ...form, nombre: e.target.value })}
                  />
                </div>

                <div className="grid gap-4 sm:grid-cols-2">
                  {/* El + crea la categoria sin salir del formulario: si no
                      existe, no hay que perder lo escrito para ir a crearla. */}
                  <Desplegable
                    label="Categoría"
                    optional
                    hint={
                      <BotonMas label="Nueva categoría" onClick={() => setCrearRapido('categoria')} />
                    }
                    value={form.categoriaId}
                    onChange={(v) => setForm({ ...form, categoriaId: Number(v) })}
                    options={[
                      { value: 0, label: 'Sin categoría' },
                      ...categorias
                        .filter((c) => c.activo)
                        .map((c) => ({ value: c.id, label: c.nombre })),
                    ]}
                  />

                  <Desplegable
                    label="Marca"
                    optional
                    hint={<BotonMas label="Nueva marca" onClick={() => setCrearRapido('marca')} />}
                    value={form.marcaId}
                    onChange={(v) => setForm({ ...form, marcaId: Number(v) })}
                    options={[
                      { value: 0, label: 'Sin marca' },
                      ...marcas
                        .filter((m) => m.activo)
                        .map((m) => ({ value: m.id, label: m.nombre })),
                    ]}
                  />
                </div>

                <Desplegable
                  label="Unidad base"
                  value={form.unidadBaseId}
                  disabled={Boolean(editando)}
                  hint={
                    editando ? (
                      <span className="text-xs text-ink-soft">No se puede cambiar</span>
                    ) : (
                      <BotonMas label="Nueva unidad" onClick={() => setCrearRapido('unidad')} />
                    )
                  }
                  onChange={(v) => setForm({ ...form, unidadBaseId: Number(v) })}
                  options={unidadesActivas.map((u) => ({
                    value: u.id,
                    label: u.nombre,
                    detalle: u.codigo,
                  }))}
                />

                {/* Contenido del envase: informativo, para comparar precio por litro. */}
                <div className="grid gap-4 sm:grid-cols-2">
                  <Input
                    label="Contenido"
                    optional
                    type="number"
                    step="0.0001"
                    placeholder="900"
                    value={form.contenido}
                    onChange={(e) => setForm({ ...form, contenido: e.target.value })}
                  />
                  <Desplegable
                    label="Unidad"
                    optional
                    hint={
                      <BotonMas
                        label="Nueva unidad"
                        onClick={() => setCrearRapido('unidadContenido')}
                      />
                    }
                    value={form.contenidoUnidadId}
                    disabled={!form.contenido}
                    placeholder="—"
                    onChange={(v) => setForm({ ...form, contenidoUnidadId: Number(v) })}
                    options={[
                      { value: 0, label: '—' },
                      ...unidadesActivas.map((u) => ({
                        value: u.id,
                        label: u.nombre,
                        detalle: u.codigo,
                      })),
                    ]}
                  />
                </div>

                <Input
                  label="Stock mínimo"
                  optional
                  type="number"
                  step="0.0001"
                  hint={
                    <span className="text-xs text-ink-soft">en {unidadBase || 'unidad base'}</span>
                  }
                  value={form.stockMinimo}
                  onChange={(e) => setForm({ ...form, stockMinimo: e.target.value })}
                />

                <hr className="border-line" />

                {/* Se escribe como lo cobra el proveedor y se guarda por unidad
                    base, igual que los precios de venta. */}
                <CostoReferenciaInput
                  valor={form.costoReferencia}
                  onChange={(v) => setForm({ ...form, costoReferencia: v })}
                  presentacionId={presentacionCosto}
                  onPresentacion={setPresentacionCosto}
                  presentaciones={editando?.presentaciones ?? []}
                  unidadBase={unidadBase || 'unidad base'}
                  disabled={guardando}
                />
              </div>
            ) : (
              <div className="flex flex-col gap-4">
                {/* La base se muestra pero no se edita: la crea el backend. */}
                <div className="flex items-center justify-between gap-3 rounded-field bg-slate-50 px-3 py-2.5">
                  <span className="text-sm text-ink">
                    {unidades.find((u) => u.id === form.unidadBaseId)?.nombre ?? 'Unidad base'}
                  </span>
                  <Badge>1 {unidadBase} · base</Badge>
                </div>

                <PresentacionesEditor
                  filas={presentaciones}
                  unidades={unidades}
                  unidadBase={unidadBase}
                  onChange={setPresentaciones}
                  disabled={guardando}
                />
              </div>
            )}
          </div>
        </Modal>

        {/* Alta rapida de categoria, marca o unidad desde el propio formulario. */}
        <Modal
          open={crearRapido !== null}
          size="sm"
          title={
            crearRapido === 'categoria'
              ? 'Nueva categoría'
              : crearRapido === 'marca'
                ? 'Nueva marca'
                : 'Nueva unidad'
          }
          description="Se crea y queda elegida en el producto que estás dando de alta."
          onClose={() => setCrearRapido(null)}
          footer={
            <>
              <Button variant="secondary" size="sm" onClick={() => setCrearRapido(null)}>
                Cancelar
              </Button>
              <Button size="sm" loading={creando} onClick={() => void crearRapidoGuardar()}>
                Crear
              </Button>
            </>
          }
        >
          <div className="flex flex-col gap-4">
            {errorRapido && <Alert>{errorRapido}</Alert>}

            {esUnidad(crearRapido) && (
              <Input
                label="Código"
                placeholder="SAC"
                value={formRapido.codigo}
                onChange={(e) =>
                  setFormRapido({ ...formRapido, codigo: e.target.value.toUpperCase() })
                }
              />
            )}

            <Input
              label="Nombre"
              placeholder={
                crearRapido === 'categoria'
                  ? 'Aceites y grasas'
                  : crearRapido === 'marca'
                    ? 'Primor'
                    : 'Saco'
              }
              value={formRapido.nombre}
              onChange={(e) => setFormRapido({ ...formRapido, nombre: e.target.value })}
            />

            {esUnidad(crearRapido) && (
              <Desplegable
                label="Tipo"
                value={formRapido.tipo}
                onChange={(v) => setFormRapido({ ...formRapido, tipo: String(v) })}
                options={[
                  { value: 'CONTEO', label: 'Conteo', nota: 'se cuenta: saco, caja' },
                  { value: 'PESO', label: 'Peso', nota: 'se pesa: kilo, gramo' },
                  { value: 'VOLUMEN', label: 'Volumen', nota: 'se mide: litro' },
                ]}
              />
            )}
          </div>
        </Modal>

        <ImportarModal<ProductoImportRequest>
          open={importando}
          onClose={() => setImportando(false)}
          titulo="productos"
          columnasEsperadas={[
            'Codigo',
            'Descripcion',
            'Medida',
            'Presentacion',
            'Costo',
            'Precio',
            'P. Saco',
            'P. Mayor',
          ]}
          mapear={(() => {
            // Mismo código con nombre distinto = producto distinto en el
            // archivo viejo: se le agrega un sufijo para no perderlo. Mismo
            // código con el mismo nombre es una fila repetida de verdad, y esa
            // la detecta sola el backend (queda como omitida, con su motivo).
            const vistos = new Map<string, string>()
            const sufijos = new Map<string, number>()

            return (fila): ProductoImportRequest => {
              const codigoOriginal = valorDe(fila, 'codigo').trim().toUpperCase()
              const nombre = valorDe(fila, 'descripcion').trim()

              let codigo = codigoOriginal
              const previo = vistos.get(codigoOriginal)
              if (codigoOriginal && previo !== undefined && previo !== nombre) {
                const n = (sufijos.get(codigoOriginal) ?? 0) + 1
                sufijos.set(codigoOriginal, n)
                codigo = `${codigoOriginal}-${String.fromCharCode(65 + n)}`
              } else if (codigoOriginal && previo === undefined) {
                vistos.set(codigoOriginal, nombre)
              }

              const presentaciones = valorDe(fila, 'presentacion')
                .split(',')
                .map((n) => numeroPositivo(n))
                .filter((n): n is number => n !== null && n !== 1)

              const mayor = numeroPositivo(valorDe(fila, 'p. mayor', 'p mayor'))

              return {
                codigo,
                nombre,
                unidadBaseCodigo: unidadDesdeMedida(valorDe(fila, 'medida')),
                costoReferencia: numeroPositivo(valorDe(fila, 'costo')),
                presentaciones,
                precioContado: numeroPositivo(valorDe(fila, 'precio')),
                precioPorSaco: numeroPositivo(valorDe(fila, 'p. saco', 'p saco')),
                // "1" es el relleno del sistema viejo para "no aplica".
                precioMayorista: mayor !== null && mayor > 1 ? mayor : null,
              }
            }
          })()}
          onImportar={productoApi.importar}
          onListo={() => void cargar()}
        />

        {dialogo}
      </ListPage>
    </>
  )
}

/** Unidades de medida: tabla propia porque tiene tipo y fraccionable. */
function UnidadesTabla({
  unidades,
  onRecargar,
}: {
  unidades: UnidadResponse[]
  onRecargar: () => Promise<void>
}) {
  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<UnidadResponse | null>(null)
  const [form, setForm] = useState({
    codigo: '',
    nombre: '',
    tipo: 'CONTEO' as UnidadResponse['tipo'],
    fraccionable: false,
  })
  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')
  const [error, setError] = useState('')
  const { confirmar, dialogo } = useConfirmacion()

  const abrirNuevo = () => {
    setEditando(null)
    setForm({ codigo: '', nombre: '', tipo: 'CONTEO', fraccionable: false })
    setErrorForm('')
    setAbierto(true)
  }

  const abrirEdicion = (unidad: UnidadResponse) => {
    setEditando(unidad)
    setForm({
      codigo: unidad.codigo,
      nombre: unidad.nombre,
      tipo: unidad.tipo,
      fraccionable: unidad.fraccionable,
    })
    setErrorForm('')
    setAbierto(true)
  }

  const guardar = async () => {
    if (!form.codigo.trim()) return setErrorForm('Ingresa el código.')
    if (!form.nombre.trim()) return setErrorForm('Ingresa el nombre.')

    setGuardando(true)
    try {
      if (editando) {
        await unidadApi.update(editando.id, { ...form, activo: editando.activo })
      } else {
        await unidadApi.create(form)
      }
      setAbierto(false)
      await onRecargar()
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos guardar la unidad.')
    } finally {
      setGuardando(false)
    }
  }

  const columns: DataTableColumn<UnidadResponse>[] = [
    { key: 'codigo', label: 'Código', render: (row) => <Badge>{row.codigo}</Badge> },
    { key: 'nombre', label: 'Nombre' },
    { key: 'tipo', label: 'Tipo', render: (row) => <Badge tone="sys">{row.tipo}</Badge> },
    {
      key: 'fraccionable',
      label: 'Admite decimales',
      value: (row) => (row.fraccionable ? 'Sí' : 'No'),
      render: (row) => (row.fraccionable ? 'Sí' : <span className="text-ink-soft">No</span>),
    },
    { key: 'usos', label: 'En uso', align: 'right' },
    {
      key: 'activo',
      label: 'Estado',
      value: (row) => (row.activo ? 'Activo' : 'Inactivo'),
      render: (row) => (
        <Badge tone={row.activo ? 'success' : 'neutral'}>
          {row.activo ? 'Activo' : 'Inactivo'}
        </Badge>
      ),
    },
  ]

  return (
    <ListPage
      icon={<Ruler size={20} />}
      title="Unidades de medida"
      description="Kilo, unidad, saco, caja. Cuántos kilos trae un saco se define en cada producto."
      actions={
        <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
          Nueva unidad
        </Button>
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      columns={columns}
      rows={unidades}
      cardIcon={Ruler}
      searchPlaceholder="Buscar unidad..."
      empty="No hay unidades."
      rowActions={(row) => (
        <>
          <RowAction label={`Editar ${row.nombre}`} onClick={() => abrirEdicion(row)}>
            <Pencil size={15} />
          </RowAction>
          <RowAction
            label={`Eliminar ${row.nombre}`}
            tone="danger"
            onClick={() =>
              confirmar({
                titulo: `Eliminar ${row.nombre}`,
                mensaje: 'Solo se puede eliminar si ningún producto la usa.',
                confirmar: 'Eliminar',
                tono: 'danger',
                accion: async () => {
                  setError('')
                  try {
                    await unidadApi.remove(row.id)
                    await onRecargar()
                  } catch (e) {
                    setError(e instanceof ApiError ? e.message : 'No pudimos eliminarla.')
                  }
                },
              })
            }
          >
            <Trash2 size={15} />
          </RowAction>
        </>
      )}
    >
      <Modal
        open={abierto}
        size="sm"
        title={editando ? `Editar ${editando.nombre}` : 'Nueva unidad'}
        description="El código es el que sale impreso en los documentos."
        onClose={() => setAbierto(false)}
        footer={
          <>
            <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
              Cancelar
            </Button>
            <Button size="sm" loading={guardando} onClick={() => void guardar()}>
              {editando ? 'Guardar cambios' : 'Crear unidad'}
            </Button>
          </>
        }
      >
        <div className="flex flex-col gap-4">
          {errorForm && <Alert>{errorForm}</Alert>}

          <div className="grid gap-4 sm:grid-cols-[8rem_1fr]">
            <Input
              label="Código"
              placeholder="SAC"
              value={form.codigo}
              onChange={(e) => setForm({ ...form, codigo: e.target.value.toUpperCase() })}
            />
            <Input
              label="Nombre"
              placeholder="Saco"
              value={form.nombre}
              onChange={(e) => setForm({ ...form, nombre: e.target.value })}
            />
          </div>

          <Desplegable
            label="Tipo"
            value={form.tipo}
            onChange={(v) => setForm({ ...form, tipo: v as UnidadResponse['tipo'] })}
            options={[
              { value: 'CONTEO', label: 'Conteo', nota: 'se cuenta: unidad, saco, caja' },
              { value: 'PESO', label: 'Peso', nota: 'se pesa: kilo, gramo' },
              { value: 'VOLUMEN', label: 'Volumen', nota: 'se mide: litro, mililitro' },
            ]}
          />

          <label className="flex items-center gap-2 text-sm text-ink-muted">
            <input
              type="checkbox"
              checked={form.fraccionable}
              onChange={(e) => setForm({ ...form, fraccionable: e.target.checked })}
            />
            Admite decimales (2.5 kilos sí, 2.5 sacos no)
          </label>
        </div>
      </Modal>

      {dialogo}
    </ListPage>
  )
}
