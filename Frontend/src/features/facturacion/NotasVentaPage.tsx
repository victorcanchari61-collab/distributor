import { useCallback, useEffect, useState } from 'react'
import { idUnico } from '../../lib/ids'
import { fechaCorta } from '../../lib/fechas'
import { ArrowLeft, Check, Contact, Eye, History, Pencil, Plus, ShoppingBag, Trash2, Undo2, X } from 'lucide-react'
import { motivoNovedadApi } from '../tms/motivoNovedadApi'
import type { MotivoNovedadOpcion } from '../tms/motivoNovedadApi'
import {
  AccionPdf,
  AgregarProductoPanel,
  Alert,
  Badge,
  BuscadorCampo,
  BuscadorModal,
  Button,
  Desplegable,
  SelectorPresentacion,
  HistorialCambios,
  Input,
  ListPage,
  Modal,
  PageHeader,
  PageSection,
  ResumenDocumento,
  RowAction,
  StatCard,
  SysDataTable,
  TablaProductosDetalle,
  useConfirmacion,
  useToast,
  cn,
} from '../../components/ui'
import type {
  ColumnaDetalleProducto,
  ConsultaTabla,
  DataTableColumn,
  LineaProductoNueva,
  OpcionBuscador,
} from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { presentacionInicialDe } from '../../lib/presentaciones'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { clienteApi, productoApi } from '../maestros'
import type { ClienteResponse, ProductoResponse } from '../maestros'
import { almacenApi, stockApi } from '../inventario'
import type { AlmacenOpcion } from '../inventario'
import { metodoPagoApi } from '../finanzas'
import type { MetodoPagoResponse, TipoMetodoPago } from '../finanzas'
import { listaPrecioApi } from './listaPrecioApi'
import type { ListaPrecioResponse } from './listaPrecioApi'
import { devolucionVentaApi, notaVentaApi } from './ventasApi'
import type { AuditoriaResponse } from '../config'
import type {
  CrearNotaVentaRequest,
  DevolucionDeVenta,
  FormaPagoVenta,
  LineaDevuelta,
  LineaVentaResponse,
  NotaVentaResponse,
  RecojoRequest,
  ResumenNotasVenta,
} from './ventasApi'

const FORMAS_PAGO: { value: FormaPagoVenta; label: string }[] = [
  { value: 'CONTADO', label: 'Contado' },
  { value: 'CREDITO', label: 'Crédito' },
]

function estadoNotaVentaBadge(estado: NotaVentaResponse['estado']) {
  return <Badge tone={estado === 'ANULADA' ? 'danger' : 'success'}>{estado === 'ANULADA' ? 'Anulada' : 'Confirmada'}</Badge>
}

function estadoDevolucionBadge(estado: DevolucionDeVenta['estado']) {
  if (estado === 'APROBADA') return <Badge tone="success">Aprobada</Badge>
  if (estado === 'RECHAZADA') return <Badge tone="danger">Rechazada</Badge>
  return <Badge tone="warning">Por aprobar</Badge>
}

/** Como se nombra cada tipo de metodo en la tabla de pagos. */
const NOTA_TIPO: Record<TipoMetodoPago, string> = {
  EFECTIVO: 'Efectivo',
  BILLETERA_DIGITAL: 'Billetera digital',
  TRANSFERENCIA: 'Transferencia',
}

/** La fila del modal de pagos que todavía no existe. */
const NUEVA_FILA = -1

/** Una fila de la tabla de pagos del formulario. */
interface FilaPagoVenta {
  clave: number
  metodoPagoId: number
  monto: string
}

const TIPOS_METODO_PAGO: { value: TipoMetodoPago; label: string }[] = [
  { value: 'EFECTIVO', label: 'Efectivo' },
  { value: 'BILLETERA_DIGITAL', label: 'Billetera digital' },
  { value: 'TRANSFERENCIA', label: 'Transferencia' },
]

type FilaVenta = LineaProductoNueva

/** Una línea de recojo: lo que arma el buscador, más el motivo y la observación. */
interface RecojoLinea extends LineaProductoNueva {
  motivoId: number
  observacion: string
}

/**
 * Notas de venta: la venta lista tal cual, nacida de confirmar un pedido o
 * registrada directa. El stock sale al momento de crearla — no existe una
 * "nota de venta a medio despachar" como sí existe una compra a medio
 * recibir, así que no hay una pantalla de despachos aparte.
 */
export function NotasVentaPage() {
  const { puede } = usePermisos()
  const [vista, setVista] = useState<'lista' | 'form'>('lista')
  const [notas, setNotas] = useState<NotaVentaResponse[]>([])
  const [clientes, setClientes] = useState<ClienteResponse[]>([])
  const [productos, setProductos] = useState<ProductoResponse[]>([])
  const [almacenes, setAlmacenes] = useState<AlmacenOpcion[]>([])
  const [listas, setListas] = useState<ListaPrecioResponse[]>([])
  const [metodosPago, setMetodosPago] = useState<MetodoPagoResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [editando, setEditando] = useState<NotaVentaResponse | null>(null)
  const [detalleAbierto, setDetalleAbierto] = useState<NotaVentaResponse | null>(null)
  const [rechazando, setRechazando] = useState<DevolucionDeVenta | null>(null)
  const [motivoRechazo, setMotivoRechazo] = useState('')
  const [historialAbierto, setHistorialAbierto] = useState<NotaVentaResponse | null>(null)
  const [historial, setHistorial] = useState<AuditoriaResponse[]>([])
  const [historialCargando, setHistorialCargando] = useState(false)
  const [buscadorAbierto, setBuscadorAbierto] = useState(false)
  const [pagosAbierto, setPagosAbierto] = useState(false)
  const [guardando, setGuardando] = useState(false)
  // Que campo quedo mal: el aviso dice QUE pasa y esto marca DONDE.
  const [errorPagos, setErrorPagos] = useState('')
  const toast = useToast()

  const [clienteId, setClienteId] = useState(0)
  const [almacenId, setAlmacenId] = useState(0)
  const [listaPrecioId, setListaPrecioId] = useState(0)
  const [formaPago, setFormaPago] = useState<FormaPagoVenta>('CONTADO')
  const [pagos, setPagos] = useState<{ metodoPagoId: number; monto: string }[]>([])
  const [pagoTipo, setPagoTipo] = useState<TipoMetodoPago | ''>('')
  const [pagoMetodoId, setPagoMetodoId] = useState(0)
  const [pagoMonto, setPagoMonto] = useState('')
  const [observacion, setObservacion] = useState('')
  const [filas, setFilas] = useState<FilaVenta[]>([])
  // Mercadería de OTRA venta que se recoge al registrar esta: solo al crear, no al editar.
  const [recojos, setRecojos] = useState<RecojoLinea[]>([])
  const [motivos, setMotivos] = useState<MotivoNovedadOpcion[]>([])
  const [stockMap, setStockMap] = useState<Record<number, number>>({})
  /** Lo que apartan otros pedidos pendientes, por producto: el panel lo muestra como aviso. */
  const [reservadoMap, setReservadoMap] = useState<Record<number, number>>({})

  const { confirmar, dialogo } = useConfirmacion()

  /*
   * Las ventas se acumulan con la operacion: la tabla pide solo la pagina que
   * muestra. Los contadores vienen del resumen — sumarlos sobre las filas
   * cargadas daria el total de 20 ventas, no el del negocio.
   */
  const [consulta, setConsulta] = useState<ConsultaTabla | null>(null)
  const [totalRegistros, setTotalRegistros] = useState(0)
  const [resumen, setResumen] = useState<ResumenNotasVenta | null>(null)

  const cargarPagina = useCallback(async (q: ConsultaTabla) => {
    setCargando(true)
    try {
      const pagina = await notaVentaApi.listar(q)
      setNotas(pagina.items)
      setTotalRegistros(pagina.total)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las notas de venta.')
    } finally {
      setCargando(false)
    }
  }, [])

  /** Catalogos del formulario y contadores: no cambian al paginar. */
  const cargarApoyo = useCallback(async () => {
    try {
      const [res, clis, prods, alms, lis, metodos, motivosNovedad] = await Promise.all([
        notaVentaApi.resumen(),
        clienteApi.getAll('notaventa'),
        productoApi.getAll(),
        almacenApi.opciones(),
        listaPrecioApi.getAll(),
        metodoPagoApi.getAll(),
        motivoNovedadApi.opciones(),
      ])
      setResumen(res)
      setClientes(clis.filter((c) => c.activo))
      setProductos(prods.filter((p) => p.activo && p.controlaStock))
      setAlmacenes(alms.filter((a) => a.activo))
      setListas(lis.filter((l) => l.activo))
      setMetodosPago(metodos.filter((m) => m.activo))
      setMotivos(motivosNovedad)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los datos de apoyo.')
    }
  }, [])

  const cargar = useCallback(async () => {
    await Promise.all([consulta ? cargarPagina(consulta) : Promise.resolve(), cargarApoyo()])
  }, [consulta, cargarPagina, cargarApoyo])

  useEffect(() => {
    void cargarApoyo()
  }, [cargarApoyo])

  useRealtime(['notasventa', 'pedidos', 'stock'], cargar)

  // Stock disponible del almacén elegido: es lo que se puede vender desde ahí.
  useEffect(() => {
    if (!almacenId) return
    let cancelado = false
    void stockApi.disponible(almacenId).then((stock) => {
      if (!cancelado) {
        setStockMap(Object.fromEntries(stock.map((s) => [s.productoId, s.disponible])))
        setReservadoMap(Object.fromEntries(stock.map((s) => [s.productoId, s.reservado])))
      }
    })
    return () => {
      cancelado = true
    }
  }, [almacenId, notas])

  const abrirNueva = () => {
    setEditando(null)
    setClienteId(0)
    // El principal por defecto: quien tiene un solo depósito nunca lo elige.
    setAlmacenId(almacenes.find((a) => a.esPrincipal)?.id ?? almacenes[0]?.id ?? 0)
    setListaPrecioId(0)
    setFormaPago('CONTADO')
    setPagos([])
    setPagoTipo('')
    setPagoMetodoId(0)
    setPagoMonto('')
    setObservacion('')
    setFilas([])
    setRecojos([])
    setVista('form')
  }

  const abrirEdicion = (nota: NotaVentaResponse) => {
    setEditando(nota)
    setClienteId(nota.clienteId)
    setAlmacenId(nota.almacenId)
    setListaPrecioId(0)
    setFormaPago(nota.formaPago)
    setPagos([])
    setPagoTipo('')
    setPagoMetodoId(0)
    setPagoMonto('')
    setObservacion(nota.observacion ?? '')
    setRecojos([])
    setFilas(
      nota.detalle
        .filter((l) => !l.anulado)
        .map((l) => ({
          id: idUnico(),
          lineaId: l.id,
          productoId: l.productoId,
          presentacionId: l.presentacionId ?? 0,
          cantidad: String(l.cantidadPresentacion),
          // El precio pactado, tal cual se guardo: multiplicar el de unidad
          // base por el factor devolvia 13.5999 donde se habia puesto 13.60.
          costo: String(l.precioPresentacion),
          lote: '',
          fechaVencimiento: '',
        })),
    )
    setVista('form')
  }

  const abrirHistorial = (nota: NotaVentaResponse) => {
    setHistorialAbierto(nota)
    setHistorial([])
    setHistorialCargando(true)
    void notaVentaApi
      .historial(nota.id)
      .then(setHistorial)
      .catch(() => setHistorial([]))
      .finally(() => setHistorialCargando(false))
  }

  const actualizarFila = (id: string, cambio: Partial<FilaVenta>) =>
    setFilas((prev) => prev.map((f) => (f.id === id ? { ...f, ...cambio } : f)))

  const total = filas.reduce((n, f) => n + (Number(f.cantidad) || 0) * (Number(f.costo) || 0), 0)
  // Solo al crear: mercadería de otra venta que se recoge al registrar esta y se descuenta del total.
  const totalRecojo = editando ? 0 : recojos.reduce((s, r) => s + (Number(r.cantidad) || 0) * (Number(r.costo) || 0), 0)
  const totalNeto = total - totalRecojo
  const totalPagado = pagos.reduce((n, p) => n + (Number(p.monto) || 0), 0)

  /**
   * Que fila del modal de pagos se esta editando: el indice del pago, o NUEVA
   * para la que todavia no existe. Null es que no se edita ninguna.
   *
   * Es el mismo trato que en Cuentas por cobrar: la tabla ES el formulario, en
   * vez de un bloque de campos aparte encima de la lista.
   */
  const [filaPago, setFilaPago] = useState<number | null>(null)

  const abrirFilaPago = () => {
    setFilaPago(NUEVA_FILA)
    setPagoTipo('')
    setPagoMetodoId(0)
    setPagoMonto('')
  }

  const editarFilaPago = (i: number) => {
    const pago = pagos[i]
    setFilaPago(i)
    setPagoTipo(metodosPago.find((m) => m.id === pago.metodoPagoId)?.tipo ?? '')
    setPagoMetodoId(pago.metodoPagoId)
    setPagoMonto(String(pago.monto))
  }

  const cerrarFilaPago = () => {
    setFilaPago(null)
    setPagoTipo('')
    setPagoMetodoId(0)
    setPagoMonto('')
  }

  /** Guarda la fila en edicion: la nueva se agrega, una existente se reemplaza. */
  const guardarFilaPago = () => {
    if (!pagoMetodoId) return toast.error('Elige el método de pago.')

    const monto = Number(pagoMonto)
    if (!monto || monto <= 0) return toast.error('Pon cuánto se pagó.')

    // Lo ya cargado sin contar la fila que se esta editando.
    const otros = pagos.reduce(
      (suma, p, i) => (i === filaPago ? suma : suma + (Number(p.monto) || 0)),
      0,
    )

    if (otros + monto > totalNeto + 0.001) {
      return toast.error(
        `Ese pago deja lo pagado en S/ ${(otros + monto).toFixed(2)}, más que el total a cobrar (S/ ${totalNeto.toFixed(2)}).`,
      )
    }

    setPagos((prev) =>
      filaPago === NUEVA_FILA
        ? [...prev, { metodoPagoId: pagoMetodoId, monto: pagoMonto }]
        : prev.map((p, i) => (i === filaPago ? { metodoPagoId: pagoMetodoId, monto: pagoMonto } : p)),
    )
    cerrarFilaPago()
  }

  const quitarPago = (i: number) => setPagos((prev) => prev.filter((_, idx) => idx !== i))

  /** Recarga la venta abierta: tras resolver una devolución cambian sus totales. */
  const refrescarDetalle = async (id: number) => {
    const fresca = await notaVentaApi.getById(id)
    setDetalleAbierto(fresca)
    await cargar()
  }

  const aprobarDevolucion = (d: DevolucionDeVenta) =>
    confirmar({
      titulo: `Aprobar ${d.numero}`,
      mensaje:
        'La mercadería entra al stock y la venta baja de importe, así que el cliente deja de deberla. No se puede deshacer.',
      confirmar: 'Aprobar',
      tono: 'pregunta',
      accion: async () => {
        if (!detalleAbierto) return
        await devolucionVentaApi.aprobar(d.id)
        await refrescarDetalle(detalleAbierto.id)
        toast.exito(`${d.numero} aprobada`)
      },
    })

  const rechazarDevolucion = async () => {
    if (!rechazando || !detalleAbierto) return
    if (!motivoRechazo.trim()) return fallar('Di por qué se rechaza.')

    try {
      await devolucionVentaApi.rechazar(rechazando.id, motivoRechazo.trim())
      const numero = rechazando.numero
      setRechazando(null)
      setMotivoRechazo('')
      await refrescarDetalle(detalleAbierto.id)
      toast.exito(`${numero} rechazada`)
    } catch (e) {
      fallar(e instanceof ApiError ? e.message : 'No pudimos rechazar la devolución.')
    }
  }

  /** Un fallo de validacion: aviso arriba y, si toca, el campo en rojo. */
  const fallar = (mensaje: string, campo?: 'pagos') => {
    toast.error(mensaje)
    setErrorPagos(campo === 'pagos' ? mensaje : '')
    toast.error(mensaje)
  }

  /** Filas del modal de pagos: las cargadas, más la nueva mientras se escribe. */
  const filasPago: FilaPagoVenta[] = [
    ...pagos.map((p, i) => ({ clave: i, metodoPagoId: p.metodoPagoId, monto: String(p.monto) })),
    ...(filaPago === NUEVA_FILA ? [{ clave: NUEVA_FILA, metodoPagoId: 0, monto: '' }] : []),
  ]

  const columnasPagos: DataTableColumn<FilaPagoVenta>[] = [
    {
      key: 'tipo',
      label: 'Tipo de pago',
      render: (fila) => {
        if (fila.clave === filaPago) {
          return (
            <Desplegable
              value={pagoTipo}
              onChange={(v) => {
                setPagoTipo(v as TipoMetodoPago)
                setPagoMetodoId(0)
              }}
              placeholder="Elige el tipo"
              options={TIPOS_METODO_PAGO}
            />
          )
        }
        const tipo = metodosPago.find((m) => m.id === fila.metodoPagoId)?.tipo
        return tipo ? <Badge tone="sys">{NOTA_TIPO[tipo]}</Badge> : <span className="text-ink-soft">—</span>
      },
    },
    {
      key: 'metodo',
      label: 'Método',
      render: (fila) =>
        fila.clave === filaPago ? (
          <Desplegable
            value={pagoMetodoId}
            onChange={(v) => setPagoMetodoId(Number(v))}
            placeholder={pagoTipo ? 'Elige el método' : 'Elige el tipo primero'}
            disabled={!pagoTipo}
            options={metodosPago
              .filter((m) => m.tipo === pagoTipo)
              .map((m) => ({ value: m.id, label: m.nombre }))}
          />
        ) : (
          (metodosPago.find((m) => m.id === fila.metodoPagoId)?.nombre ?? '—')
        ),
    },
    {
      key: 'monto',
      label: 'Monto',
      align: 'right',
      render: (fila) =>
        fila.clave === filaPago ? (
          <Input
            type="number"
            step="0.01"
            placeholder="0.00"
            value={pagoMonto}
            onChange={(e) => setPagoMonto(e.target.value)}
          />
        ) : (
          `S/ ${(Number(fila.monto) || 0).toFixed(2)}`
        ),
    },
  ]


  /*
   * La lista con la que se cobra.
   *
   * Vacio en el formulario significa "la predeterminada", que es la que el
   * backend aplica a un cliente sin lista propia: para resolver precios hay
   * que resolver ese vacio a un id de verdad.
   */
  const listaEfectiva = listaPrecioId || listas.find((l) => l.esPredeterminada)?.id || 0

  /**
   * El precio de una presentación por esa cantidad.
   *
   * Sale de la lista elegida; si la lista no tiene cargada esa presentación —o no hay lista— cae al
   * precio de referencia del producto, para que nada salga en cero por una lista a medio armar. El
   * panel avisa de cuál de los dos vino.
   */
  const precioDeLista = async (presentacionId: number, cantidad: number) =>
    await listaPrecioApi.precioVenta(presentacionId, cantidad, listaEfectiva || undefined)


  /*
   * Elegir al cliente trae su lista.
   *
   * El mayorista tiene la suya guardada en su ficha: sin esto habia que
   * acordarse de cambiarla a mano en cada pedido, y basta olvidarlo una vez
   * para cobrarle precio de menudeo. Si el cliente no tiene lista propia se
   * vuelve a "la predeterminada", no se queda la del cliente anterior.
   */
  const elegirCliente = (id: number) => {
    setClienteId(id)
    setListaPrecioId(clientes.find((c) => c.id === id)?.listaPrecioId ?? 0)
  }

  const guardar = async () => {
    setErrorPagos('')
    if (!clienteId) return fallar('Elige el cliente.')
    if (!almacenId) return fallar('Elige el almacén.')

    const validas = filas.filter((f) => f.productoId && f.cantidad && f.costo)
    if (validas.length === 0) return fallar('Agrega al menos un producto con su precio.')

    // Una linea sin precio se caia de la venta sin decir nada: el documento se
    // guardaba con un producto menos y nadie se enteraba.
    const sinPrecio = filas.find((f) => f.productoId && !Number(f.costo))
    if (sinPrecio) {
      const nombre = productos.find((p) => p.id === sinPrecio.productoId)?.nombre ?? 'Un producto'
      return fallar(`${nombre} no tiene precio. Ponlo o quita la línea.`)
    }

    if (!editando) {
      for (const r of recojos) {
        const producto = productos.find((p) => p.id === r.productoId)
        if (!r.motivoId) return fallar(`Elige el motivo del recojo de ${producto?.nombre ?? 'un producto'}.`)
        if (!(Number(r.costo) > 0)) return fallar(`Indica el valor de lo recogido de ${producto?.nombre ?? 'un producto'}.`)
      }
      if (totalRecojo > total) {
        return fallar(`Lo recogido (S/ ${totalRecojo.toFixed(2)}) supera el total de la venta (S/ ${total.toFixed(2)}).`)
      }
    }

    // Al editar no se tocan los pagos: eso ya tiene su propio flujo
    // ("Gestionar pagos" desde Ver detalle), así que ni se valida ni se envía.
    if (!editando && totalPagado > totalNeto + 0.001) {
      return fallar(
        `Los pagos suman S/ ${totalPagado.toFixed(2)}, más que el total a cobrar (S/ ${totalNeto.toFixed(2)}).`,
        'pagos',
      )
    }

    // Al contado el dinero entra ahora. Sin esto quedaba una venta cobrada que
    // nadie pagó y que, por no ser a crédito, tampoco salía en cuentas por cobrar.
    if (!editando && formaPago === 'CONTADO' && totalPagado < totalNeto - 0.001) {
      return fallar(
        `Una venta al contado se cobra completa: faltan S/ ${(totalNeto - totalPagado).toFixed(2)} por registrar.`,
        'pagos',
      )
    }

    const recojosEnvio: RecojoRequest[] = editando
      ? []
      : recojos.map((r) => ({
          productoId: r.productoId,
          presentacionId: r.presentacionId || null,
          cantidad: Number(r.cantidad) || 0,
          precioUnitario: Number(r.costo) || 0,
          motivoId: r.motivoId,
          observacion: r.observacion.trim() || null,
        }))

    const body: CrearNotaVentaRequest = {
      clienteId,
      almacenId,
      listaPrecioId: listaPrecioId || null,
      formaPago,
      pagos: editando ? [] : pagos.map((p) => ({ metodoPagoId: p.metodoPagoId, monto: Number(p.monto) })),
      observacion: observacion.trim() || null,
      detalle: validas.map((f) => ({
        id: f.lineaId ?? null,
        productoId: f.productoId,
        presentacionId: f.presentacionId || null,
        cantidad: Number(f.cantidad),
        precioUnitario: Number(f.costo),
      })),
      recojos: recojosEnvio,
    }

    setGuardando(true)
    try {
      if (editando) {
        await notaVentaApi.update(editando.id, body)
      } else {
        await notaVentaApi.create(body)
      }
      setVista('lista')
      await cargar()
      toast.exito(editando ? 'Venta actualizada' : 'Venta registrada')
    } catch (e) {
      // El de arriba tambien: el formulario es largo y el pie no se ve.
      fallar(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos registrar la venta.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const anularNota = (nota: NotaVentaResponse) =>
    confirmar({
      titulo: `Anular ${nota.numero}`,
      mensaje: 'Se anula la venta y el stock que salió vuelve al almacén. No se puede deshacer.',
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await notaVentaApi.anular(nota.id)
          await cargar()
          toast.exito(`${nota.numero} anulada`)
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos anular la venta.')
        }
      },
    })


  /** A cuántas unidades base equivale la presentación de esa línea. */
  const factorDeFila = (fila: { productoId: number; presentacionId: number }) =>
    productos
      .find((p) => p.id === fila.productoId)
      ?.presentaciones.find((x) => x.id === fila.presentacionId)?.factor ?? 1


  /**
   * El selector de presentacion de una linea: se usa en dos sitios.
   *
   * Al cambiar de unidad se vuelve a pedir el precio: si no, la linea se
   * quedaba con el precio de la presentacion anterior (el del saco) puesto
   * ahora sobre la nueva (la bolsa), y nadie se daba cuenta hasta cobrar mal.
   */
  const presentacionDeFila = (fila: {
    id: string
    productoId: number
    presentacionId: number
    cantidad: string
  }) => {
    const producto = productos.find((p) => p.id === fila.productoId)
    return (
      <SelectorPresentacion
        value={fila.presentacionId}
        onChange={(v) => {
          actualizarFila(fila.id, { presentacionId: v })
          const real = v || producto?.presentaciones.find((x) => x.esBase)?.id || 0
          if (!real) return
          void precioDeLista(real, Number(fila.cantidad) || 1).then((precio) => {
            if (precio != null) actualizarFila(fila.id, { costo: String(precio.precio) })
          })
        }}
        placeholder={producto?.unidadBase ?? 'Elegir'}
        disabled={!producto}
        producto={producto}
        uso="venta"
        actual={fila.presentacionId}
        resolverPrecio={precioDeLista}
        claveLista={listaEfectiva}
      />
    )
  }

  const columnasFilas: DataTableColumn<FilaVenta>[] = [
    {
      key: 'producto',
      label: 'Producto',
      // La cabecera de la tarjeta es un desplegable, no el nombre de la fila:
      // sin su etiqueta es el unico dato sin rotular de la tarjeta.
      etiquetaEnTarjeta: true,
      value: (fila) => productos.find((p) => p.id === fila.productoId)?.nombre ?? '',
      render: (fila) => (
        <Desplegable
          value={fila.productoId}
          onChange={(v) => actualizarFila(fila.id, { productoId: Number(v), presentacionId: presentacionInicialDe(productos, Number(v), 'venta') })}
          options={productos.map((p) => ({ value: p.id, label: p.nombre, detalle: p.codigo }))}
        />
      ),
    },
    {
      key: 'presentacion',
      label: 'Presentación',
      width: 190,
      render: presentacionDeFila,
    },
    {
      key: 'cantidad',
      label: 'Cantidad',
      align: 'right',
      width: 100,
      value: (fila) => Number(fila.cantidad) || 0,
      render: (fila) => (
        <Input
          type="number"
          step="0.0001"
          value={fila.cantidad}
          onChange={(e) => actualizarFila(fila.id, { cantidad: e.target.value })}
        />
      ),
    },
    {
      key: 'costo',
      label: 'Precio de venta',
      align: 'right',
      width: 130,
      value: (fila) => Number(fila.costo) || 0,
      render: (fila) => (
        <Input
          type="number"
          step="0.01"
          value={fila.costo}
          onChange={(e) => actualizarFila(fila.id, { costo: e.target.value })}
        />
      ),
    },
    {
      /*
       * Lo que sale la unidad base.
       *
       * El precio de la fila es el de la presentacion —S/ 226.67 el saco—, y
       * asi no se puede comparar una linea en sacos contra otra en kilos ni
       * ver si el descuento por volumen quedo al derecho.
       */
      key: 'precioUnitario',
      label: 'P. unit.',
      align: 'right',
      width: 140,
      value: (fila) => {
        const factor = factorDeFila(fila)
        return factor > 0 ? (Number(fila.costo) || 0) / factor : 0
      },
      render: (fila) => {
        const producto = productos.find((p) => p.id === fila.productoId)
        const factor = factorDeFila(fila)
        const precio = Number(fila.costo) || 0
        return precio > 0 && factor > 0 ? (
          <span className="font-medium text-ink">
            S/ {(precio / factor).toFixed(2)} × {producto?.unidadBase}
          </span>
        ) : (
          <span className="text-ink-soft">—</span>
        )
      },
    },
    {
      key: 'subtotal',
      label: 'Subtotal',
      align: 'right',
      width: 120,
      value: (fila) => (Number(fila.cantidad) || 0) * (Number(fila.costo) || 0),
      render: (fila) => `S/ ${((Number(fila.cantidad) || 0) * (Number(fila.costo) || 0)).toFixed(2)}`,
    },
  ]

  const opcionesCliente: OpcionBuscador<number>[] = clientes.map((c) => ({
    item: c.id,
    label: c.nombre,
    detalle: c.documento,
    nota: c.distrito ?? undefined,
  }))

  const columnasCliente: DataTableColumn<ClienteResponse>[] = [
    {
      key: 'documento',
      label: 'Documento',
      render: (row) => (
        <span className="flex items-center gap-2">
          <span className="font-medium text-ink">{row.documento}</span>
          <Badge>{row.tipoDoc}</Badge>
        </span>
      ),
    },
    { key: 'nombre', label: 'Nombre' },
    { key: 'distrito', label: 'Distrito' },
    { key: 'ruta', label: 'Ruta' },
  ]

  const columns: DataTableColumn<NotaVentaResponse>[] = [
    // El número se busca con el buscador de arriba, no en el panel.
    { key: 'numero', label: 'Número', filterable: false, render: (row) => <Badge>{row.numero}</Badge> },
    {
      key: 'cliente',
      label: 'Cliente',
      filterType: 'select',
      filterOptions: [...new Set(clientes.map((c) => c.nombre))]
        .sort((a, b) => a.localeCompare(b, 'es'))
        .map((n) => ({ value: n, label: n })),
    },
    {
      key: 'pedidoNumero',
      label: 'Pedido de origen',
      sortable: false,
      // El numero del pedido no se busca: solo si vino de uno o fue directa.
      filterType: 'select',
      filterOptions: [
        { value: 'De un pedido', label: 'De un pedido' },
        { value: 'Directa', label: 'Directa' },
      ],
      render: (row) =>
        row.pedidoNumero ? <Badge>{row.pedidoNumero}</Badge> : <span className="text-ink-soft">Directa</span>,
    },
    {
      key: 'fecha',
      label: 'Fecha',
      filterType: 'date',
      render: (row) => fechaCorta(row.fecha),
    },
    {
      key: 'total',
      label: 'Total',
      align: 'right',
      // Sin control numerico en el panel, buscar "9" contra "S/ 9.00" no
      // encuentra lo que la persona espera.
      filterable: false,
      render: (row) => `S/ ${row.total.toFixed(2)}`,
    },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'CONFIRMADA', label: 'Confirmada' },
        { value: 'ANULADA', label: 'Anulada' },
      ],
      render: (row) => estadoNotaVentaBadge(row.estado),
    },
  ]

  if (vista === 'form') {
    return (
      <div className="space-y-5">
        <PageHeader
          icon={<ShoppingBag size={20} />}
          title={editando ? `Editar ${editando.numero}` : 'Nueva venta directa'}
          description={
            editando
              ? 'Lo que le quites queda como devolución y no baja nada hasta que la aprueben. Los pagos se gestionan desde Finanzas → Cuentas por cobrar.'
              : 'Sin pasar por un pedido primero. El stock sale del almacén elegido al momento de registrarla.'
          }
          actions={
            <Button variant="secondary" size="sm" onClick={() => setVista('lista')}>
              <ArrowLeft size={15} />
              Volver
            </Button>
          }
        />

        <div className="grid grid-cols-1 gap-5 xl:grid-cols-[1fr_360px] xl:items-start">
          <PageSection
            title="Productos"
            description={`${filas.length} producto${filas.length === 1 ? '' : 's'} agregado${filas.length === 1 ? '' : 's'}`}
          >
            <AgregarProductoPanel
              productos={productos}
              stock={stockMap}
              reservado={reservadoMap}
              uso="venta"
              costoLabel="Precio de venta"
              resolverPrecio={precioDeLista}
              claveLista={listaEfectiva}
              onAgregar={(linea: LineaProductoNueva) => setFilas((f) => [...f, linea])}
            />

            <div className="mt-4">
              <SysDataTable
                columns={columnasFilas}
                rows={filas}
                rowKey="id"
                toolbar={false}
                empty="Agrega productos con el buscador de arriba."
                // Una papelera no necesita 140px, que es lo que ocupa la
                // columna de acciones de un listado con tres botones.
                actionsWidth={64}
                actions={(fila) => (
                  <RowAction
                    label={`Quitar ${productos.find((p) => p.id === fila.productoId)?.nombre ?? 'línea'}`}
                    tone="danger"
                    onClick={() => setFilas((f) => f.filter((x) => x.id !== fila.id))}
                  >
                    <Trash2 size={15} />
                  </RowAction>
                )}
              />
            </div>
          </PageSection>

          <div className="flex flex-col gap-5">
            <PageSection title="Venta">
              <BuscadorCampo
                label="Cliente"
                value={clienteId || null}
                onChange={(id) => elegirCliente(id ?? 0)}
                opciones={opcionesCliente}
                placeholder="Buscar cliente..."
                vacio="Ningún cliente coincide"
                onAvanzado={() => setBuscadorAbierto(true)}
                avanzadoLabel="Búsqueda avanzada de clientes"
              />

              <Desplegable
                className="mt-4"
                label="Almacén"
                value={almacenId}
                onChange={(v) => setAlmacenId(Number(v))}
                placeholder="Elige el almacén"
                options={almacenes.map((a) => ({ value: a.id, label: a.nombre }))}
              />

              <Desplegable
                className="mt-4"
                label="Lista de precios"
                optional
                value={listaPrecioId}
                onChange={(v) => setListaPrecioId(Number(v))}
                placeholder="Predeterminada"
                options={listas.map((l) => ({ value: l.id, label: l.nombre }))}
              />

              {editando ? (
                <p className="mt-4 rounded-field bg-surface-alt px-3 py-2 text-xs text-ink-soft">
                  Forma de pago: <span className="font-medium text-ink">
                    {FORMAS_PAGO.find((f) => f.value === formaPago)?.label ?? formaPago}
                  </span>
                  . Los pagos se gestionan desde Finanzas → Cuentas por cobrar.
                </p>
              ) : (
                <>
                  <Desplegable
                    className="mt-4"
                    label="Forma de pago"
                    value={formaPago}
                    onChange={(v) => {
                      const nueva = v as FormaPagoVenta
                      setFormaPago(nueva)
                      if (nueva === 'CREDITO') setPagos([])
                    }}
                    options={FORMAS_PAGO}
                  />

                  {formaPago === 'CONTADO' ? (
                    <>
                      <div
                        className={cn(
                          'mt-4 flex items-center justify-between gap-3 rounded-field border px-3 py-2.5',
                          errorPagos ? 'border-red-600 bg-red-50' : 'border-line',
                        )}
                      >
                        <div>
                          <span className="ui-label block">
                            Pagos
                            <span className="ml-1 text-red-600">*</span>
                          </span>
                          <span className={cn('text-xs', errorPagos ? 'text-red-700' : 'text-ink-soft')}>
                            {pagos.length === 0
                              ? 'Sin registrar'
                              : `S/ ${totalPagado.toFixed(2)} de S/ ${totalNeto.toFixed(2)} · ${pagos.length} ${pagos.length === 1 ? 'línea' : 'líneas'}`}
                          </span>
                        </div>
                        {puede('fact.notaventa', 'cobrar') && (
                          <Button type="button" size="sm" variant="secondary" onClick={() => setPagosAbierto(true)}>
                            {pagos.length === 0 ? 'Agregar pago' : 'Gestionar pagos'}
                          </Button>
                        )}
                      </div>

                      {errorPagos && <p className="mt-1.5 text-xs text-red-600">{errorPagos}</p>}
                    </>
                  ) : (
                    <p className="mt-4 text-xs text-ink-soft">
                      Al crédito no se registra pago ahora — queda pendiente de cobro.
                    </p>
                  )}
                </>
              )}

              <Input
                className="mt-4"
                label="Observación"
                optional
                placeholder="Referencia..."
                value={observacion}
                onChange={(e) => setObservacion(e.target.value)}
              />
            </PageSection>

            {!editando && (
              <PageSection
                title="Recojo"
                description="Mercadería de otra venta que se recoge al registrar esta: se descuenta del total. A qué almacén entra lo decide quien lo revise en Novedades de entrega."
              >
                <div>
                  <AgregarProductoPanel
                    productos={productos}
                    uso="venta"
                    pideCosto
                    costoLabel="Valor recogido"
                    onAgregar={(linea) => setRecojos((r) => [...r, { ...linea, motivoId: 0, observacion: '' }])}
                  />
                </div>

                {recojos.length > 0 && (
                  <div className="mt-3 divide-y divide-line rounded-field border border-line">
                    {recojos.map((r) => {
                      const producto = productos.find((p) => p.id === r.productoId)
                      const subtotal = (Number(r.cantidad) || 0) * (Number(r.costo) || 0)
                      return (
                        <div key={r.id} className="flex flex-col gap-2 px-3 py-2.5">
                          <div className="flex items-start justify-between gap-3">
                            <div className="min-w-0">
                              <p className="truncate text-sm font-semibold text-ink">{producto?.nombre ?? 'Producto'}</p>
                              <p className="text-xs text-ink-soft">
                                {Number(r.cantidad) || 0} × S/ {(Number(r.costo) || 0).toFixed(2)} = S/ {subtotal.toFixed(2)}
                              </p>
                            </div>
                            <button
                              type="button"
                              onClick={() => setRecojos((rs) => rs.filter((x) => x.id !== r.id))}
                              className="shrink-0 cursor-pointer rounded-md p-1.5 text-ink-soft transition-colors hover:bg-surface-alt hover:text-red-600"
                              title="Quitar"
                            >
                              <Trash2 size={15} />
                            </button>
                          </div>
                          <div className="grid gap-2 sm:grid-cols-2">
                            <Desplegable
                              label="Motivo"
                              size="sm"
                              value={r.motivoId}
                              onChange={(v) =>
                                setRecojos((rs) => rs.map((x) => (x.id === r.id ? { ...x, motivoId: Number(v) } : x)))
                              }
                              placeholder="¿Por qué se recoge?"
                              options={motivos.map((m) => ({
                                value: m.id,
                                label: m.nombre,
                                nota: m.descripcion ?? undefined,
                              }))}
                            />
                            <Input
                              label="Observación"
                              optional
                              size="sm"
                              maxLength={250}
                              value={r.observacion}
                              onChange={(e) =>
                                setRecojos((rs) =>
                                  rs.map((x) => (x.id === r.id ? { ...x, observacion: e.target.value } : x)),
                                )
                              }
                            />
                          </div>
                        </div>
                      )
                    })}
                  </div>
                )}
              </PageSection>
            )}

            <PageSection title="Resumen">
              {totalRecojo > 0 && (
                <div className="mb-2 flex items-center justify-between text-sm text-ink-soft">
                  <span>Recojo</span>
                  <span>− S/ {totalRecojo.toFixed(2)}</span>
                </div>
              )}
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold text-ink-soft uppercase tracking-wide">
                  {totalRecojo > 0 ? 'Total a cobrar' : 'Total de la venta'}
                </span>
                <span className="text-xl font-bold text-[rgb(var(--sys-rgb))]">S/ {totalNeto.toFixed(2)}</span>
              </div>
            </PageSection>
          </div>
        </div>

        <div className="flex justify-end gap-2">
          <Button variant="secondary" size="sm" onClick={() => setVista('lista')}>
            Cancelar
          </Button>
          <Button size="sm" loading={guardando} onClick={() => void guardar()}>
            {editando ? 'Guardar cambios' : 'Registrar venta'}
          </Button>
        </div>

        <BuscadorModal
          open={buscadorAbierto}
          onClose={() => setBuscadorAbierto(false)}
          title="Elegir cliente"
          description="Busca por documento, nombre o distrito."
          columns={columnasCliente}
          rows={clientes}
          cardIcon={Contact}
          searchPlaceholder="Buscar cliente..."
          onSeleccionar={(c) => elegirCliente(c.id)}
        />

        <Modal
          open={pagosAbierto}
          onClose={() => {
            cerrarFilaPago()
            setPagosAbierto(false)
          }}
          size="lg"
          title="Pagos"
          description={`Reparte S/ ${totalNeto.toFixed(2)} entre uno o varios métodos.`}
          footer={
            <>
              <Button
                size="sm"
                variant="secondary"
                onClick={() => {
                  cerrarFilaPago()
                  setPagosAbierto(false)
                }}
              >
                Listo
              </Button>
              <Button size="sm" disabled={filaPago !== null} onClick={abrirFilaPago}>
                <Plus size={15} />
                Agregar pago
              </Button>
            </>
          }
        >
          <div className="flex flex-col gap-3">

            <SysDataTable<FilaPagoVenta>
              columns={columnasPagos}
              rows={filasPago}
              rowKey="clave"
              toolbar={false}
              empty="Todavía no hay pagos registrados."
              actions={(fila) =>
                fila.clave === filaPago ? (
                  <>
                    <RowAction label="Guardar pago" tone="success" onClick={guardarFilaPago}>
                      <Check size={15} />
                    </RowAction>
                    <RowAction label="Cancelar" tone="danger" onClick={cerrarFilaPago}>
                      <X size={15} />
                    </RowAction>
                  </>
                ) : (
                  <>
                    <RowAction
                      label="Editar pago"
                      tone="edit"
                      disabled={filaPago !== null}
                      onClick={() => editarFilaPago(fila.clave)}
                    >
                      <Pencil size={15} />
                    </RowAction>
                    <RowAction
                      label="Quitar pago"
                      tone="danger"
                      disabled={filaPago !== null}
                      onClick={() => quitarPago(fila.clave)}
                    >
                      <Trash2 size={15} />
                    </RowAction>
                  </>
                )
              }
            />

            <div className="flex items-center justify-between border-t border-line pt-3 text-sm font-semibold">
              <span>Pagado</span>
              <span className={totalPagado > totalNeto + 0.001 ? 'text-red-600' : 'text-ink'}>
                S/ {totalPagado.toFixed(2)} de S/ {totalNeto.toFixed(2)}
              </span>
            </div>
          </div>
        </Modal>
      </div>
    )
  }

  return (
    <ListPage
      icon={<ShoppingBag size={20} />}
      title="Notas de venta"
      description="La venta lista tal cual: nació de confirmar un pedido o se registró directa."
      actions={
        puede('fact.notaventa', 'crear') ? (
          <Button size="sm" onClick={abrirNueva} iconRight={<Plus size={15} />}>
            Nueva venta
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Notas de venta" value={String(resumen?.total ?? 0)} icon={<ShoppingBag size={18} />} />
          <StatCard
            label="Confirmadas"
            value={String(resumen?.confirmadas ?? 0)}
            icon={<ShoppingBag size={18} />}
            tono="success"
          />
          <StatCard
            label="Total vendido"
            value={`S/ ${(resumen?.totalVendido ?? 0).toFixed(2)}`}
            icon={<ShoppingBag size={18} />}
          />
        </>
      }
      columns={columns}
      // 4 íconos por fila (Ver, Historial, Editar, Anular) más 6 columnas de
      // datos: el ancho por defecto de Acciones queda muy justo.
      actionsWidth={180}
      rows={notas}
      servidor={{
        total: totalRegistros,
        cargando,
        onConsulta: (q) => {
          setConsulta(q)
          void cargarPagina(q)
        },
      }}
      cardIcon={ShoppingBag}
      searchPlaceholder="Buscar por número, cliente..."
      empty={cargando ? 'Cargando notas de venta...' : 'Todavía no hay notas de venta registradas.'}
      rowActions={(row) => (
        <>
          <RowAction label={`Ver ${row.numero}`} tone="view" onClick={() => setDetalleAbierto(row)}>
            <Eye size={15} />
          </RowAction>
          <RowAction tone="view" label={`Ver historial de ${row.numero}`} onClick={() => abrirHistorial(row)}>
            <History size={15} />
          </RowAction>
          {puede('fact.notaventa', 'exportar') && (
            <AccionPdf documento="notaventa" id={row.id} numero={row.numero} />
          )}
          {puede('fact.notaventa', 'editar') && (
            <RowAction
              label={`Editar ${row.numero}`}
              disabled={row.estado !== 'CONFIRMADA'}
              disabledReason="Ya está anulada"
              onClick={() => abrirEdicion(row)}
            >
              <Pencil size={15} />
            </RowAction>
          )}
          {puede('fact.notaventa', 'anular') && (
            <RowAction
              label={`Anular ${row.numero}`}
              tone="danger"
              disabled={row.estado !== 'CONFIRMADA'}
              disabledReason="Ya está anulada"
              onClick={() => anularNota(row)}
            >
              <Undo2 size={15} />
            </RowAction>
          )}
        </>
      )}
    >
      <Modal
        open={detalleAbierto !== null}
        title={detalleAbierto ? `${detalleAbierto.numero} · ${detalleAbierto.cliente}` : ''}
        description={
          detalleAbierto
            ? `Emisión ${fechaCorta(detalleAbierto.fecha)} · ${detalleAbierto.almacen} · ` +
              (FORMAS_PAGO.find((f) => f.value === detalleAbierto.formaPago)?.label ?? detalleAbierto.formaPago)
            : undefined
        }
        onClose={() => setDetalleAbierto(null)}
        size="lg"
      >
        {detalleAbierto && (
          <div className="flex flex-col gap-3">
            {detalleAbierto.estado === 'ANULADA' && <div>{estadoNotaVentaBadge(detalleAbierto.estado)}</div>}

            {detalleAbierto.detalle.some((l) => l.anulado) && (
              <p className="text-xs text-ink-soft">
                Se quitaron productos al editar esta venta — quedan solo en "Ver historial".
              </p>
            )}

            <TablaProductosDetalle<LineaVentaResponse>
              filas={detalleAbierto.detalle.filter((l) => !l.anulado)}
              rowKey={(l) => l.id}
              titulo={(l) => l.producto}
              subtitulo={(l) => `${l.codigo} · ${l.presentacion ?? l.unidadBase}`}
              grupos={[
                [
                  { key: 'cant', label: 'Cant.', render: (l) => `${l.cantidadPresentacion}` },
                  // El pactado por presentacion, que es el que se cobro y el
                  // que sale en el papel; el de unidad base es derivado.
                  {
                    key: 'precio',
                    label: 'Precio',
                    render: (l) => `S/ ${l.precioPresentacion.toFixed(2)}`,
                  },
                  { key: 'subtotal', label: 'Subtotal', render: (l) => `S/ ${l.subtotal.toFixed(2)}` },
                ] satisfies ColumnaDetalleProducto<LineaVentaResponse>[],
              ]}
            />

            <ResumenDocumento
              pagos={detalleAbierto.pagos.map((p) => ({ id: p.id, label: p.metodoPago, monto: p.monto }))}
              total={detalleAbierto.total}
            />

            {detalleAbierto.devoluciones.length > 0 && (
              <div className="flex flex-col gap-2 rounded-field border border-line p-3">
                <span className="ui-label">Devuelto por el cliente</span>

                {detalleAbierto.devoluciones.map((d) => (
                  <div key={d.id} className="flex flex-col gap-1.5 border-t border-line pt-2 first:border-0 first:pt-0">
                    <div className="flex items-center justify-between gap-2">
                      <span className="text-sm font-semibold text-ink">{d.numero}</span>
                      {estadoDevolucionBadge(d.estado)}
                    </div>

                    <TablaProductosDetalle<LineaDevuelta>
                      filas={d.detalle}
                      rowKey={(l) => l.notaVentaDetalleId}
                      titulo={(l) => l.producto}
                      subtitulo={(l) => l.unidad}
                      grupos={[
                        [
                          { key: 'cant', label: 'Cant.', render: (l) => `${l.cantidad}` },
                          {
                            key: 'importe',
                            label: 'Importe',
                            render: (l) => `S/ ${l.importe.toFixed(2)}`,
                          },
                        ] satisfies ColumnaDetalleProducto<LineaDevuelta>[],
                      ]}
                    />

                    <div className="flex justify-between text-xs">
                      <span className="text-ink-muted">
                        {d.estado === 'RECHAZADA' && d.motivoRechazo
                          ? `Rechazada: ${d.motivoRechazo}`
                          : d.estado === 'APROBADA'
                            ? `Aprobada por ${d.aprobadoPor ?? '—'}`
                            : 'Espera aprobación: todavía no baja el stock ni la deuda.'}
                      </span>
                      <span className="font-semibold text-ink">S/ {d.total.toFixed(2)}</span>
                    </div>

                    {d.estado === 'SOLICITADA' && puede('dms.devoluciones', 'confirmar') && (
                      <div className="flex gap-2 pt-1">
                        <Button size="sm" onClick={() => aprobarDevolucion(d)}>
                          Aprobar
                        </Button>
                        <Button size="sm" variant="secondary" onClick={() => setRechazando(d)}>
                          Rechazar
                        </Button>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}

            {detalleAbierto.recojos.length > 0 && (
              <div className="flex flex-col gap-2 rounded-field border border-line p-3">
                <span className="ui-label">Recogido de otra venta</span>

                {detalleAbierto.recojos.map((r) => (
                  <div
                    key={r.id}
                    className={cn(
                      'flex items-center justify-between gap-2 border-t border-line pt-2 text-sm first:border-0 first:pt-0',
                      r.estado === 'ANULADO' && 'opacity-60',
                    )}
                  >
                    <div className="min-w-0">
                      <p className="truncate font-medium text-ink">
                        {r.producto} <span className="text-ink-soft">· {r.cantidadPresentacion} {r.presentacion ?? r.unidadBase}</span>
                      </p>
                      <p className="text-xs text-ink-soft">
                        {r.motivo}
                        {' · '}
                        {r.estado === 'ANULADO'
                          ? 'anulado'
                          : r.estado === 'VERIFICADO'
                            ? `entró a ${r.almacen}`
                            : 'pendiente de revisar'}
                      </p>
                    </div>
                    <span className="shrink-0 font-semibold text-ink">S/ {r.importe.toFixed(2)}</span>
                  </div>
                ))}
              </div>
            )}

            {detalleAbierto.pedidoNumero && (
              <p className="text-sm text-ink-soft">
                <span className="font-semibold text-ink-muted">Pedido: </span>
                {detalleAbierto.pedidoNumero}
              </p>
            )}
            {detalleAbierto.observacion && (
              <p className="text-sm text-ink-soft">
                <span className="font-semibold text-ink-muted">Observación: </span>
                {detalleAbierto.observacion}
              </p>
            )}
          </div>
        )}
      </Modal>

      <Modal
        open={rechazando !== null}
        size="sm"
        title={rechazando ? `Rechazar ${rechazando.numero}` : ''}
        description="No entra nada al stock y la venta queda como está. Di por qué."
        onClose={() => {
          setRechazando(null)
          setMotivoRechazo('')
        }}
        footer={
          <>
            <Button
              size="sm"
              variant="secondary"
              onClick={() => {
                setRechazando(null)
                setMotivoRechazo('')
              }}
            >
              Cancelar
            </Button>
            <Button size="sm" onClick={rechazarDevolucion}>
              Rechazar
            </Button>
          </>
        }
      >
        <Input
          label="Motivo"
          placeholder="La mercadería no llegó, el cliente se retractó..."
          value={motivoRechazo}
          onChange={(e) => setMotivoRechazo(e.target.value)}
        />
      </Modal>

      <Modal
        open={historialAbierto !== null}
        title={historialAbierto ? `Historial de ${historialAbierto.numero}` : ''}
        description={historialAbierto ? historialAbierto.cliente : undefined}
        onClose={() => setHistorialAbierto(null)}
        size="xl"
      >
        <HistorialCambios registros={historial} cargando={historialCargando} />
      </Modal>

      {dialogo}
    </ListPage>
  )
}
