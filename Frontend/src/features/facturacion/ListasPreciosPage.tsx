import { useCallback, useEffect, useState } from 'react'
import { Banknote, Check, Pencil, Plus, Star, Tag, Trash2 } from 'lucide-react'
import {
  Alert,
  Badge,
  Button,
  Input,
  ListPage,
  Modal,
  RowAction,
  Select,
  StatCard,
  Tabs,
  useConfirmacion,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { productoApi } from '../maestros'
import type { ProductoResponse } from '../maestros'
import { listaPrecioApi } from './listaPrecioApi'
import type { ListaPrecioResponse, PrecioResponse } from './listaPrecioApi'

export function ListasPreciosPage() {
  const [listas, setListas] = useState<ListaPrecioResponse[]>([])
  const [productos, setProductos] = useState<ProductoResponse[]>([])
  const [listaActiva, setListaActiva] = useState<number | null>(null)
  const [precios, setPrecios] = useState<PrecioResponse[]>([])

  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [abierto, setAbierto] = useState(false)
  const [editando, setEditando] = useState<ListaPrecioResponse | null>(null)
  const [form, setForm] = useState({ nombre: '', descripcion: '' })

  const [precioAbierto, setPrecioAbierto] = useState(false)
  const [precioForm, setPrecioForm] = useState({
    productoId: 0,
    presentacionId: 0,
    precio: '',
    cantidadMinima: '1',
  })

  const [guardando, setGuardando] = useState(false)
  const [errorForm, setErrorForm] = useState('')
  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [l, p] = await Promise.all([listaPrecioApi.getAll(), productoApi.getAll()])
      setListas(l)
      setProductos(p.filter((x) => x.activo))
      setListaActiva((actual) => actual ?? l.find((x) => x.esPredeterminada)?.id ?? l[0]?.id ?? null)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las listas.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  const cargarPrecios = useCallback(async (listaId: number) => {
    try {
      setPrecios(await listaPrecioApi.getPrecios(listaId))
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los precios.')
    }
  }, [])

  useEffect(() => {
    if (listaActiva) void cargarPrecios(listaActiva)
  }, [listaActiva, cargarPrecios])

  const lista = listas.find((l) => l.id === listaActiva) ?? null
  const producto = productos.find((p) => p.id === precioForm.productoId)

  const guardarLista = async () => {
    if (!form.nombre.trim()) return setErrorForm('Ingresa el nombre de la lista.')

    setGuardando(true)
    try {
      if (editando) {
        await listaPrecioApi.update(editando.id, {
          nombre: form.nombre.trim(),
          descripcion: form.descripcion.trim() || null,
          activo: editando.activo,
        })
      } else {
        const creada = await listaPrecioApi.create({
          nombre: form.nombre.trim(),
          descripcion: form.descripcion.trim() || null,
          esPredeterminada: false,
        })
        setListaActiva(creada.id)
      }
      setAbierto(false)
      await cargar()
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos guardar la lista.')
    } finally {
      setGuardando(false)
    }
  }

  const guardarPrecio = async () => {
    if (!listaActiva) return
    if (!precioForm.presentacionId) return setErrorForm('Elige la presentación.')
    if (!precioForm.precio) return setErrorForm('Ingresa el precio.')

    setGuardando(true)
    try {
      await listaPrecioApi.guardarPrecios(listaActiva, [
        {
          presentacionId: precioForm.presentacionId,
          precio: Number(precioForm.precio),
          cantidadMinima: Number(precioForm.cantidadMinima || 1),
        },
      ])
      setPrecioAbierto(false)
      await cargarPrecios(listaActiva)
      await cargar()
    } catch (e) {
      setErrorForm(e instanceof ApiError ? e.message : 'No pudimos guardar el precio.')
    } finally {
      setGuardando(false)
    }
  }

  const columns: DataTableColumn<PrecioResponse>[] = [
    { key: 'producto', label: 'Producto' },
    {
      key: 'presentacion',
      label: 'Presentación',
      render: (row) => <Badge tone="sys">{row.presentacion}</Badge>,
    },
    {
      key: 'cantidadMinima',
      label: 'Desde',
      align: 'right',
      render: (row) =>
        row.cantidadMinima > 1 ? (
          <Badge tone="warning">{row.cantidadMinima}+</Badge>
        ) : (
          <span className="text-ink-soft">1</span>
        ),
    },
    {
      key: 'precio',
      label: 'Precio',
      align: 'right',
      render: (row) => <span className="font-semibold text-ink">S/ {row.precio.toFixed(2)}</span>,
    },
    {
      key: 'precioUnidadBase',
      label: 'Equivale a',
      align: 'right',
      // La columna que hace visible el negocio: el saco sale mas barato por
      // kilo que el kilo suelto.
      render: (row) => (
        <span className="text-ink-muted">
          S/ {row.precioUnidadBase.toFixed(2)} × {row.unidadBase}
        </span>
      ),
    },
  ]

  return (
    <>
      {listas.length > 0 && (
        <Tabs
          className="mb-5"
          active={String(listaActiva ?? '')}
          onChange={(id) => setListaActiva(Number(id))}
          items={listas.map((l) => ({
            id: String(l.id),
            label: l.nombre,
            icon: l.esPredeterminada ? <Star size={14} /> : <Tag size={14} />,
            badge: l.precios,
          }))}
        />
      )}

      <ListPage
        icon={<Banknote size={20} />}
        title={lista ? lista.nombre : 'Listas de precios'}
        description={
          lista?.descripcion ??
          'El precio se pone por presentación: así el saco sale más barato por kilo que el kilo suelto.'
        }
        actions={
          <>
            <Button
              variant="secondary"
              size="sm"
              onClick={() => {
                setEditando(null)
                setForm({ nombre: '', descripcion: '' })
                setErrorForm('')
                setAbierto(true)
              }}
            >
              <Plus size={15} />
              Nueva lista
            </Button>
            <Button
              size="sm"
              disabled={!listaActiva}
              onClick={() => {
                setPrecioForm({ productoId: 0, presentacionId: 0, precio: '', cantidadMinima: '1' })
                setErrorForm('')
                setPrecioAbierto(true)
              }}
              iconRight={<Plus size={15} />}
            >
              Agregar precio
            </Button>
          </>
        }
        alert={error ? <Alert>{error}</Alert> : undefined}
        stats={
          lista ? (
            <>
              <StatCard
                label="Precios en la lista"
                value={String(precios.length)}
                icon={<Banknote size={18} />}
              />
              <StatCard
                label="Productos con precio"
                value={String(new Set(precios.map((p) => p.productoId)).size)}
                icon={<Tag size={18} />}
                tono="success"
                hint={`de ${productos.length} activos`}
              />
              <StatCard
                label="Escalones por volumen"
                value={String(precios.filter((p) => p.cantidadMinima > 1).length)}
                icon={<Check size={18} />}
                tono="warning"
                hint="precios por cantidad"
              />
              <StatCard
                label="Listas"
                value={String(listas.length)}
                icon={<Star size={18} />}
                tono="neutral"
                hint={lista.esPredeterminada ? 'esta es la predeterminada' : 'no predeterminada'}
              />
            </>
          ) : undefined
        }
        banner={
          lista && !lista.esPredeterminada ? (
            <div className="flex flex-wrap items-center justify-between gap-3 rounded-panel border border-line bg-white p-4">
              <p className="text-sm text-ink-muted">
                Los clientes sin lista propia compran con la predeterminada.
              </p>
              <Button
                variant="secondary"
                size="sm"
                onClick={() =>
                  confirmar({
                    titulo: `Usar ${lista.nombre} como predeterminada`,
                    mensaje:
                      'Pasa a aplicarse a todo cliente que no tenga una lista propia. La anterior deja de serlo.',
                    confirmar: 'Marcar',
                    accion: async () => {
                      await listaPrecioApi.predeterminada(lista.id)
                      await cargar()
                    },
                  })
                }
              >
                <Star size={15} />
                Marcar predeterminada
              </Button>
            </div>
          ) : undefined
        }
        columns={columns}
        rows={precios}
        cardIcon={Banknote}
        searchPlaceholder="Buscar por producto o presentación..."
        empty={
          cargando
            ? 'Cargando precios...'
            : listas.length === 0
              ? 'Crea una lista de precios para empezar.'
              : 'Esta lista todavía no tiene precios.'
        }
        note={
          <>
            <span className="font-semibold">Equivale a</span> muestra el precio llevado a la unidad
            base. Sirve para ver cuánto ganas vendiendo suelto frente a vender por bulto.
          </>
        }
        rowActions={(row) => (
          <>
            <RowAction
              label={`Editar precio de ${row.producto}`}
              onClick={() => {
                const p = productos.find((x) => x.id === row.productoId)
                setPrecioForm({
                  productoId: row.productoId,
                  presentacionId: row.presentacionId,
                  precio: String(row.precio),
                  cantidadMinima: String(row.cantidadMinima),
                })
                setErrorForm(p ? '' : 'El producto de este precio está desactivado.')
                setPrecioAbierto(true)
              }}
            >
              <Pencil size={15} />
            </RowAction>
            <RowAction
              label={`Eliminar precio de ${row.producto}`}
              tone="danger"
              onClick={() =>
                confirmar({
                  titulo: `Quitar precio de ${row.presentacion}`,
                  mensaje: 'Deja de tener precio en esta lista.',
                  confirmar: 'Quitar',
                  tono: 'danger',
                  accion: async () => {
                    await listaPrecioApi.eliminarPrecio(row.id)
                    if (listaActiva) await cargarPrecios(listaActiva)
                    await cargar()
                  },
                })
              }
            >
              <Trash2 size={15} />
            </RowAction>
          </>
        )}
      >
        {/* Alta y edicion de la lista */}
        <Modal
          open={abierto}
          size="sm"
          title={editando ? `Editar ${editando.nombre}` : 'Nueva lista de precios'}
          description="Mayorista, Minorista, Bodega: cada cliente compra con la suya."
          onClose={() => setAbierto(false)}
          footer={
            <>
              <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
                Cancelar
              </Button>
              <Button size="sm" loading={guardando} onClick={() => void guardarLista()}>
                {editando ? 'Guardar cambios' : 'Crear lista'}
              </Button>
            </>
          }
        >
          <div className="flex flex-col gap-4">
            {errorForm && <Alert>{errorForm}</Alert>}
            <Input
              label="Nombre"
              placeholder="Mayorista"
              value={form.nombre}
              onChange={(e) => setForm({ ...form, nombre: e.target.value })}
            />
            <Input
              label="Descripción"
              optional
              value={form.descripcion}
              onChange={(e) => setForm({ ...form, descripcion: e.target.value })}
            />
          </div>
        </Modal>

        {/* Alta y edicion de un precio */}
        <Modal
          open={precioAbierto}
          size="sm"
          title="Precio de una presentación"
          description="Elige el producto y en qué presentación se vende a ese precio."
          onClose={() => setPrecioAbierto(false)}
          footer={
            <>
              <Button variant="secondary" size="sm" onClick={() => setPrecioAbierto(false)}>
                Cancelar
              </Button>
              <Button size="sm" loading={guardando} onClick={() => void guardarPrecio()}>
                Guardar precio
              </Button>
            </>
          }
        >
          <div className="flex flex-col gap-4">
            {errorForm && <Alert>{errorForm}</Alert>}

            <Select
              label="Producto"
              value={precioForm.productoId}
              onChange={(e) =>
                setPrecioForm({
                  ...precioForm,
                  productoId: Number(e.target.value),
                  presentacionId: 0,
                })
              }
            >
              <option value={0}>Elige un producto</option>
              {productos.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.codigo} — {p.nombre}
                </option>
              ))}
            </Select>

            <Select
              label="Presentación"
              value={precioForm.presentacionId}
              disabled={!producto}
              onChange={(e) =>
                setPrecioForm({ ...precioForm, presentacionId: Number(e.target.value) })
              }
            >
              <option value={0}>Elige la presentación</option>
              {producto?.presentaciones
                .filter((p) => p.esVenta && p.activo)
                .map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.nombre} — {p.factor} {producto.unidadBase}
                  </option>
                ))}
            </Select>

            <div className="grid gap-4 sm:grid-cols-2">
              <Input
                label="Precio"
                type="number"
                step="0.01"
                placeholder="195.00"
                value={precioForm.precio}
                onChange={(e) => setPrecioForm({ ...precioForm, precio: e.target.value })}
              />
              <Input
                label="Desde"
                type="number"
                step="1"
                min={1}
                hint={<span className="text-xs text-ink-soft">cantidad mínima</span>}
                value={precioForm.cantidadMinima}
                onChange={(e) => setPrecioForm({ ...precioForm, cantidadMinima: e.target.value })}
              />
            </div>

            {/* Adelanto del calculo, para detectar el precio puesto al reves. */}
            {producto && precioForm.presentacionId > 0 && precioForm.precio && (
              <p className="rounded-field bg-slate-50 px-3 py-2 text-xs text-ink-muted">
                Equivale a{' '}
                <span className="font-semibold text-ink">
                  S/{' '}
                  {(
                    Number(precioForm.precio) /
                    (producto.presentaciones.find((p) => p.id === precioForm.presentacionId)
                      ?.factor ?? 1)
                  ).toFixed(4)}
                </span>{' '}
                por {producto.unidadBase}.
              </p>
            )}
          </div>
        </Modal>

        {dialogo}
      </ListPage>
    </>
  )
}
