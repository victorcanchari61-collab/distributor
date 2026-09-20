import { useCallback, useEffect, useState } from 'react'
import { idUnico } from '../../lib/ids'
import { Banknote, Check, Pencil, Plus, Star, Tag, Trash2 } from 'lucide-react'
import {
  Alert,
  Badge,
  BuscadorCampo,
  Button,
  Input,
  ListPage,
  Modal,
  RowAction,
  StatCard,
  SysDataTable,
  Tabs,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { DataTableColumn, OpcionBuscador } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { productoApi } from '../maestros'
import type { ProductoResponse } from '../maestros'
import { listaPrecioApi } from './listaPrecioApi'
import type { ListaPrecioResponse, PrecioResponse } from './listaPrecioApi'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'

/**
 * Una linea de la tabla de precios del modal.
 *
 * `desde` es la cantidad minima a partir de la cual rige ese precio: es la
 * regla que hace que una lista Mayorista tenga sentido —el saco de camanejo a
 * un precio, y desde 5 sacos a otro mas bajo—. Los numeros viajan como texto
 * porque son inputs a medio escribir.
 */
interface FilaPrecio {
  clave: string
  /** Id del precio guardado del que salio la fila; ausente si es nueva. */
  id?: number
  presentacionId: number
  desde: string
  precio: string
  margen: string
}

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
  /** Producto abierto en el modal de precios. */
  const [precioForm, setPrecioForm] = useState({ productoId: 0 })

  /*
   * Precios de TODAS las presentaciones del producto, de una sentada.
   *
   * Un producto de abarrotes se vende en siete formas —el kilo, cinco bolsas
   * y el saco— y cargarlas de a una era abrir el modal siete veces. El
   * backend ya aceptaba una lista en un solo PUT; lo que faltaba era la
   * pantalla.
   *
   * Es una lista y no un diccionario por presentacion porque una misma
   * presentacion puede tener varios tramos: el saco suelto a un precio y
   * desde 5 sacos a otro.
   */
  const [filasPrecio, setFilasPrecio] = useState<FilaPrecio[]>([])
  /** Para llenar toda la columna de golpe a partir del costo. */
  const [margenObjetivo, setMargenObjetivo] = useState('')

  const [guardando, setGuardando] = useState(false)
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

  const opcionesProducto: OpcionBuscador<number>[] = productos.map((p) => ({
    item: p.id,
    label: p.nombre,
    detalle: p.codigo,
  }))

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
    if (!form.nombre.trim()) return toast.error('Ingresa el nombre de la lista.')

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
      toast.error(e instanceof ApiError ? e.message : 'No pudimos guardar la lista.')
    } finally {
      setGuardando(false)
    }
  }

  /** Las presentaciones que se pueden vender, que son a las que se les pone precio. */
  const vendibles = (producto?.presentaciones ?? []).filter((p) => p.esVenta && p.activo)

  const presentacionDe = (id: number) => vendibles.find((p) => p.id === id)

  /** Abre el modal con lo que ya tiene cargado ese producto, tramos incluidos. */
  const cambiarProductoMasivo = (productoId: number) => {
    const elegido = productos.find((p) => p.id === productoId)
    const filas: FilaPrecio[] = []

    for (const pres of elegido?.presentaciones ?? []) {
      if (!pres.esVenta || !pres.activo) continue

      // Los ya cargados salen tal cual, y el de "desde 1" siempre esta
      // aunque todavia no tenga precio: es el renglon normal de esa forma
      // de vender.
      const suyos = precios
        .filter((x) => x.presentacionId === pres.id)
        .sort((a, b) => a.cantidadMinima - b.cantidadMinima)

      if (!suyos.some((x) => x.cantidadMinima === 1)) {
        filas.push({
          clave: idUnico(),
          presentacionId: pres.id,
          desde: '1',
          precio: '',
          margen: '',
        })
      }

      for (const x of suyos) {
        // El margen de lo ya guardado no viene del backend: se saca del
        // costo, igual que cuando se teclea el precio a mano. Sin esto la
        // columna salia vacia al editar y parecia rota.
        const costo = elegido?.costoReferencia != null ? elegido.costoReferencia * pres.factor : null

        filas.push({
          clave: idUnico(),
          id: x.id,
          presentacionId: pres.id,
          desde: String(x.cantidadMinima),
          precio: String(x.precio),
          margen:
            costo != null && x.precio > 0
              ? (((x.precio - costo) / x.precio) * 100).toFixed(1)
              : '',
        })
      }
    }

    setPrecioForm({ productoId })
    setFilasPrecio(filas)
    setMargenObjetivo('')
  }

  /**
   * Precio que deja el margen pedido, redondeado al centimo de ARRIBA.
   *
   * El kilo de camanejo cuesta 3.40 y al 25% daria 4.5333, que no se puede
   * cobrar. Al redondear al mas cercano quedaba 4.53, o sea 24.9%: un pelo
   * MENOS de lo pedido, y encima distinto del margen que salia en el saco.
   * Subiendo el centimo el margen nunca queda por debajo del que se escribio.
   */
  const precioPorMargen = (costo: number, margen: number) =>
    (Math.ceil((costo / (1 - margen / 100)) * 100) / 100).toFixed(2)

  /** Costo de una presentacion: el de la unidad base por su factor. */
  const costoDe = (factor: number) =>
    producto?.costoReferencia != null ? producto.costoReferencia * factor : null

  const actualizarFila = (clave: string, cambio: Partial<FilaPrecio>) =>
    setFilasPrecio((prev) => prev.map((f) => (f.clave === clave ? { ...f, ...cambio } : f)))

  /** Escriben el precio: el margen de esa fila se recalcula solo. */
  const escribirPrecio = (fila: FilaPrecio, valor: string) => {
    const costo = costoDe(presentacionDe(fila.presentacionId)?.factor ?? 0)
    const precio = Number(valor)
    actualizarFila(fila.clave, {
      precio: valor,
      margen: costo != null && precio > 0 ? (((precio - costo) / precio) * 100).toFixed(1) : '',
    })
  }

  /** Escriben el margen: el precio de esa fila se recalcula solo. */
  const escribirMargen = (fila: FilaPrecio, valor: string) => {
    const costo = costoDe(presentacionDe(fila.presentacionId)?.factor ?? 0)
    const margen = Number(valor)

    // Borrar el margen es dejarlo en cero: el precio baja al costo. Antes se
    // quedaba el precio del margen anterior y las dos columnas se
    // contradecian. Para dejar la fila sin precio se vacia la de precio.
    if (valor === '') {
      return actualizarFila(fila.clave, {
        margen: '',
        ...(costo != null ? { precio: costo.toFixed(2) } : {}),
      })
    }

    actualizarFila(fila.clave, {
      margen: valor,
      ...(costo != null && margen < 100 ? { precio: precioPorMargen(costo, margen) } : {}),
    })
  }

  /**
   * Otro tramo de la misma presentacion.
   *
   * Es la escalera por volumen: el saco suelto va a un precio y desde 5 sacos
   * a otro mas bajo. El backend ya la resolvia (ResolverPrecioAsync toma el
   * tramo mas alto que la cantidad alcance); lo que faltaba era poder
   * cargarla.
   */
  const agregarTramo = (fila: FilaPrecio) =>
    setFilasPrecio((prev) => {
      const hermanas = prev.filter((f) => f.presentacionId === fila.presentacionId)
      const ultimo = Math.max(...hermanas.map((f) => Number(f.desde) || 1))
      const nueva: FilaPrecio = {
        clave: idUnico(),
        presentacionId: fila.presentacionId,
        desde: String(ultimo + 1),
        precio: '',
        margen: '',
      }

      // Va pegada a las de su presentacion, no al final de la tabla.
      const ultimaHermana = prev.map((f) => f.presentacionId).lastIndexOf(fila.presentacionId)
      return [...prev.slice(0, ultimaHermana + 1), nueva, ...prev.slice(ultimaHermana + 1)]
    })

  const quitarTramo = (clave: string) =>
    setFilasPrecio((prev) => prev.filter((f) => f.clave !== clave))

  /** Llena toda la columna a partir del costo: precio = costo / (1 - margen). */
  const llenarPorMargen = () => {
    const margen = Number(margenObjetivo)
    if (!producto?.costoReferencia) {
      return toast.error('Este producto no tiene costo de referencia: no hay de dónde calcular.')
    }
    if (!margen || margen <= 0 || margen >= 100) {
      return toast.error('El margen va entre 1 y 99.')
    }

    setFilasPrecio((prev) =>
      prev.map((f) => {
        const costo = costoDe(presentacionDe(f.presentacionId)?.factor ?? 0)
        // Los tramos por volumen quedan como estan: son un descuento puesto a
        // mano y llenarlos con el mismo margen los dejaria al precio normal,
        // que es justo lo contrario de para lo que existen.
        if (costo == null || Number(f.desde) > 1) return f
        return { ...f, precio: precioPorMargen(costo, margen), margen: margen.toFixed(1) }
      }),
    )
  }

  /*
   * Columnas de la tabla de precios del producto.
   *
   * Misma tabla que el editor de presentaciones del formulario de producto
   * (SysDataTable), para que se lea igual en los dos sitios.
   */
  const columnasPrecios: DataTableColumn<FilaPrecio>[] = [
    {
      key: 'nombre',
      label: 'Presentación',
      width: 200,
      render: (fila) => (
        <span className="text-sm font-medium text-ink">
          {presentacionDe(fila.presentacionId)?.nombre}
        </span>
      ),
    },
    {
      /*
       * La regla del precio: desde cuantas se cobra asi.
       *
       * Es lo que separa una lista Mayorista de la general — el saco de
       * camanejo a un precio, pero desde 5 sacos a otro.
       */
      key: 'desde',
      label: 'Desde',
      width: 90,
      render: (fila) => (
        <Input
          size="sm"
          type="number"
          min={1}
          step="1"
          value={fila.desde}
          onChange={(e) => actualizarFila(fila.clave, { desde: e.target.value })}
        />
      ),
    },
    {
      key: 'equivale',
      label: 'Equivale',
      width: 110,
      render: (fila) => (
        <Badge tone="sys">
          {presentacionDe(fila.presentacionId)?.factor} {producto?.unidadBase}
        </Badge>
      ),
    },
    {
      key: 'costo',
      label: 'Costo',
      align: 'right',
      width: 100,
      render: (fila) => {
        const costo = costoDe(presentacionDe(fila.presentacionId)?.factor ?? 0)
        return (
          <span className="text-sm font-medium text-ink">
            {costo != null ? `S/ ${costo.toFixed(2)}` : '—'}
          </span>
        )
      },
    },
    {
      key: 'precio',
      label: 'Precio',
      render: (fila) => (
        <Input
          size="sm"
          type="number"
          step="0.01"
          min={0}
          placeholder="0.00"
          value={fila.precio}
          onChange={(e) => escribirPrecio(fila, e.target.value)}
        />
      ),
    },
    {
      key: 'margen',
      label: 'Margen %',
      render: (fila) => (
        <Input
          size="sm"
          type="number"
          step="0.1"
          max={99}
          placeholder="—"
          disabled={producto?.costoReferencia == null}
          value={fila.margen}
          onChange={(e) => escribirMargen(fila, e.target.value)}
        />
      ),
    },
    {
      /*
       * El costo por unidad base, siempre a la vista.
       *
       * "Costo" de arriba es el de la presentación —S/ 280.00 el saco— y no dice cuánto cuesta
       * el kilo, que es contra lo que se compara el precio por kilo de al lado. Es el mismo en
       * todas las filas del producto, pero repetirlo aquí evita tener que dividir a mano.
       */
      key: 'costoBase',
      label: `Costo por ${producto?.unidadBase ?? 'unidad'}`,
      align: 'right',
      width: 110,
      render: () => (
        <span
          className="text-sm font-medium text-ink"
          title={producto?.costoReferencia == null ? 'Este producto no tiene costo de referencia' : undefined}
        >
          {producto?.costoReferencia != null ? `S/ ${producto.costoReferencia.toFixed(2)}` : '—'}
        </span>
      ),
    },
    {
      key: 'porBase',
      label: `Precio por ${producto?.unidadBase ?? 'unidad'}`,
      align: 'right',
      width: 110,
      render: (fila) => {
        const precio = Number(fila.precio) || 0
        const factor = presentacionDe(fila.presentacionId)?.factor ?? 0
        return (
          <span className="text-sm font-medium text-ink">
            {precio > 0 && factor > 0 ? `S/ ${(precio / factor).toFixed(2)}` : '—'}
          </span>
        )
      },
    },
  ]

  const guardarPrecio = async () => {
    if (!listaActiva) return
    if (!precioForm.productoId) return toast.error('Elige el producto.')

    const conPrecio = filasPrecio.filter((f) => Number(f.precio) > 0)

    if (conPrecio.some((f) => !Number(f.desde) || Number(f.desde) < 1)) {
      return toast.error('El "desde" de cada precio empieza en 1.')
    }

    // Dos tramos con el mismo "desde" dejarian a la venta sin saber cual
    // cobrar, y el backend se quedaria con el ultimo sin avisar.
    const claves = conPrecio.map((f) => `${f.presentacionId}-${Number(f.desde)}`)
    if (new Set(claves).size !== claves.length) {
      return toast.error('Hay dos precios de la misma presentación con el mismo "desde".')
    }

    const aGuardar = conPrecio.map((f) => ({
      presentacionId: f.presentacionId,
      precio: Number(f.precio),
      cantidadMinima: Number(f.desde),
    }))

    if (aGuardar.length === 0) return toast.error('Pon al menos un precio.')

    /*
     * Los tramos que se quitaron de la tabla.
     *
     * El PUT solo crea y actualiza, asi que borrar la fila en pantalla no
     * bastaba: el precio viejo seguia en la lista y se seguia cobrando. Vale
     * igual para la fila que se deja sin precio: si tenia uno guardado, se
     * borra.
     */
    const vivos = new Set(conPrecio.map((f) => f.id).filter((id) => id != null))
    const aBorrar = precios.filter(
      (x) => x.productoId === precioForm.productoId && !vivos.has(x.id),
    )

    setGuardando(true)
    try {
      // Una sola llamada para todas: el backend actualiza la que ya existía
      // y crea la que no, sin duplicar.
      await listaPrecioApi.guardarPrecios(listaActiva, aGuardar)
      for (const x of aBorrar) await listaPrecioApi.eliminarPrecio(x.id)
      setPrecioAbierto(false)
      await cargarPrecios(listaActiva)
      await cargar()
      toast.exito(
        aGuardar.length === 1 ? 'Precio guardado' : `${aGuardar.length} precios guardados`,
      )
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos guardar los precios.')
    } finally {
      setGuardando(false)
    }
  }

  const columns: DataTableColumn<PrecioResponse>[] = [
    // El producto se busca con el buscador de arriba, no en el panel.
    { key: 'producto', label: 'Producto', filterable: false },
    {
      key: 'presentacion',
      label: 'Presentación',
      filterType: 'select',
      filterOptions: [...new Set(precios.map((p) => p.presentacion))]
        .sort((a, b) => a.localeCompare(b, 'es'))
        .map((v) => ({ value: v, label: v })),
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
                  setPrecioForm({ productoId: 0 })
                  setFilasPrecio([])
                  setMargenObjetivo('')
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
              label={`Editar precios de ${row.producto}`}
              onClick={() => {
                const p = productos.find((x) => x.id === row.productoId)
                cambiarProductoMasivo(row.productoId)
                // Solo se avisa si hay algo que avisar: el aviso salia igual
                // con el producto activo, en rojo y sin texto.
                if (!p) toast.error('El producto de este precio está desactivado.')
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

        {/* Precios del producto: todas sus presentaciones de una sentada */}
        <Modal
          open={precioAbierto}
          size="2xl"
          title="Precios del producto"
          description="Elige el producto y pon el precio de cada forma en que lo vendes."
          onClose={() => setPrecioAbierto(false)}
          footer={
            <>
              <Button variant="secondary" size="sm" onClick={() => setPrecioAbierto(false)}>
                Cancelar
              </Button>
              <Button size="sm" loading={guardando} onClick={() => void guardarPrecio()}>
                Guardar precios
              </Button>
            </>
          }
        >
          <div className="flex flex-col gap-4">

            <div className="grid gap-4 sm:grid-cols-[1fr_auto]">
              {/* Se escribe para buscar: el catálogo tiene cientos de productos y una lista plana obligaba a recorrerla. */}
              <BuscadorCampo
                label="Producto"
                value={precioForm.productoId || null}
                onChange={(id) => cambiarProductoMasivo(id ?? 0)}
                opciones={opcionesProducto}
                placeholder="Nombre o código..."
                vacio="Ningún producto coincide"
              />

              {producto?.costoReferencia != null && (
                <div className="flex items-end gap-2">
                  <Input
                    label="Margen"
                    type="number"
                    min="1"
                    max="99"
                    placeholder="25"
                    className="w-24"
                    value={margenObjetivo}
                    onChange={(e) => setMargenObjetivo(e.target.value)}
                  />
                  <Button
                    variant="secondary"
                    onClick={llenarPorMargen}
                    disabled={!margenObjetivo}
                  >
                    Llenar %
                  </Button>
                </div>
              )}
            </div>

            {!producto ? (
              <p className="py-10 text-center text-sm text-ink-soft">
                Elige un producto para ver sus presentaciones.
              </p>
            ) : (
              <SysDataTable<FilaPrecio>
                columns={columnasPrecios}
                rows={filasPrecio}
                rowKey="clave"
                toolbar={false}
                empty="Este producto no tiene ninguna presentación marcada como se vende."
                actionsWidth={96}
                actions={(fila) => (
                  <>
                    <RowAction
                      label={`Agregar un tramo de ${presentacionDe(fila.presentacionId)?.nombre}`}
                      onClick={() => agregarTramo(fila)}
                    >
                      <Plus size={15} />
                    </RowAction>
                    {/* El renglon de "desde 1" es el precio normal: no se quita. */}
                    {filasPrecio.filter((f) => f.presentacionId === fila.presentacionId).length >
                      1 && (
                      <RowAction
                        label="Quitar este tramo"
                        tone="danger"
                        onClick={() => quitarTramo(fila.clave)}
                      >
                        <Trash2 size={15} />
                      </RowAction>
                    )}
                  </>
                )}
              />
            )}
          </div>
        </Modal>

        {dialogo}
      </ListPage>
    </>
  )
}
