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
  useToast,
} from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { productoApi } from '../maestros'
import type { ProductoResponse } from '../maestros'
import { listaPrecioApi } from './listaPrecioApi'
import type { ListaPrecioResponse, PrecioResponse } from './listaPrecioApi'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'

export function ListasPreciosPage() {
  const { puede } = usePermisos()
  const toast = useToast()
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

  useRealtime('listasprecio', cargar)

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

  useRealtime('listasprecio', () => {
    if (listaActiva) void cargarPrecios(listaActiva)
  })

  const lista = listas.find((l) => l.id === listaActiva) ?? null
  const producto = productos.find((p) => p.id === precioForm.productoId)

  /**
   * Borra la lista abierta.
   *
   * El aviso dice de antemano lo que el backend va a rechazar — la
   * predeterminada, o una con precios cargados — para no hacer pulsar un botón
   * que va a fallar. La regla vive en el servidor de todas formas; esto solo
   * evita el viaje.
   */
  const eliminarLista = (l: ListaPrecioResponse) =>
    confirmar({
      titulo: `Eliminar ${l.nombre}`,
      mensaje:
        l.precios > 0
          ? `Tiene ${l.precios} precio(s) cargado(s), así que no se podrá eliminar: desactívala o vacíala primero.`
          : 'Se borra la lista. No afecta a los documentos ya emitidos con ella.',
      confirmar: 'Eliminar',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await listaPrecioApi.remove(l.id)
          // Al desaparecer la pestaña abierta hay que mover el foco, o la
          // pantalla queda mirando a una lista que ya no existe.
          setListaActiva(null)
          await cargar()
          toast.exito(`${l.nombre} eliminada`)
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos eliminar la lista.')
        }
      },
    })

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
      toast.exito('Lista creada')
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
      toast.exito('Precios guardados')
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
      // Cantidades e importes no entran al panel: el unico control es un
      // buscador de texto, y "9" contra "S/ 9.00" no encuentra lo esperado.
      filterable: false,
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
      filterable: false,
      render: (row) => <span className="font-semibold text-ink">S/ {row.precio.toFixed(2)}</span>,
    },
    {
      key: 'precioUnidadBase',
      label: 'Equivale a',
      align: 'right',
      filterable: false,
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
            {/*
              Las acciones de la LISTA van aqui y no en la tabla: la tabla son
              los precios de dentro, y las listas son las pestañas de arriba.
              Actuan sobre la que este abierta, que es la que se esta viendo.
            */}
            {lista && puede('fact.precios', 'editar') && (
              <Button
                variant="secondary"
                size="sm"
                onClick={() => {
                  setEditando(lista)
                  setForm({ nombre: lista.nombre, descripcion: lista.descripcion ?? '' })
                  setErrorForm('')
                  setAbierto(true)
                }}
                iconRight={<Pencil size={15} />}
              >
                Editar lista
              </Button>
            )}

            {lista && puede('fact.precios', 'eliminar') && (
              <Button
                variant="secondary"
                size="sm"
                // La predeterminada no se borra: dejaria sin precio a todo
                // cliente que no tenga lista propia.
                disabled={lista.esPredeterminada}
                title={
                  lista.esPredeterminada
                    ? 'Es la predeterminada: marca otra antes de eliminarla'
                    : undefined
                }
                onClick={() => eliminarLista(lista)}
                iconRight={<Trash2 size={15} />}
              >
                Eliminar lista
              </Button>
            )}

            {puede('fact.precios', 'crear') && (
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
            )}
            {puede('fact.precios', 'crear') && (
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
            )}
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
          lista && !lista.esPredeterminada && puede('fact.precios', 'editar') ? (
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
                      toast.exito(`${lista.nombre} es la predeterminada`)
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
            {puede('fact.precios', 'editar') && (
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
            )}
            {puede('fact.precios', 'eliminar') && (
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
                    toast.exito('Precio quitado')
                  },
                })
              }
            >
              <Trash2 size={15} />
            </RowAction>
            )}
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

            {/* Costo y margen en vivo: para no poner un precio que no deja ganancia. */}
            {producto && precioForm.presentacionId > 0 && precioForm.precio && (() => {
              const presentacion = producto.presentaciones.find(
                (p) => p.id === precioForm.presentacionId,
              )
              const factor = presentacion?.factor ?? 1
              const precio = Number(precioForm.precio)
              const precioPorUnidad = precio / factor
              const costoRef = producto.costoReferencia
              const costoPresentacion = costoRef != null ? costoRef * factor : null
              const margen =
                costoPresentacion != null && precio > 0
                  ? ((precio - costoPresentacion) / precio) * 100
                  : null

              return (
                <div className="flex flex-col gap-1.5 rounded-field bg-slate-50 px-3 py-2 text-xs text-ink-muted">
                  <p>
                    Equivale a{' '}
                    <span className="font-semibold text-ink">S/ {precioPorUnidad.toFixed(4)}</span>{' '}
                    por {producto.unidadBase}.
                  </p>
                  {costoPresentacion != null ? (
                    <p>
                      Costo de referencia:{' '}
                      <span className="font-semibold text-ink">S/ {costoPresentacion.toFixed(2)}</span>
                      {margen != null && (
                        <>
                          {' '}· Margen:{' '}
                          <span
                            className={
                              margen < 0
                                ? 'font-semibold text-red-600'
                                : margen < 15
                                  ? 'font-semibold text-amber-600'
                                  : 'font-semibold text-emerald-600'
                            }
                          >
                            {margen.toFixed(1)}%
                          </span>
                        </>
                      )}
                    </p>
                  ) : (
                    <p className="text-amber-600">
                      Este producto no tiene costo de referencia: no se puede calcular el margen.
                    </p>
                  )}
                </div>
              )
            })()}
          </div>
        </Modal>

        {dialogo}
      </ListPage>
    </>
  )
}
