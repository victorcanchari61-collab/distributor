import { useCallback, useEffect, useState } from 'react'
import { ArrowLeft, Eye, Package, Pencil, Plus, Truck, Undo2 } from 'lucide-react'
import {
  AccionPdf,
  Alert,
  Badge,
  Button,
  cn,
  Desplegable,
  Input,
  ListPage,
  Modal,
  PageHeader,
  PageSection,
  RowAction,
  StatCard,
  TablaProductosDetalle,
  useConfirmacion,
  useToast,
} from '../../components/ui'
import type { ColumnaDetalleProducto, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { usePermisos } from '../../lib/permisos'
import { diaLocal, hoyLocal, fechaCorta } from '../../lib/fechas'
import { useRealtime } from '../../lib/realtime'
import { conductorApi, vehiculoApi } from './flotaApi'
import { DIAS_SEMANA } from './RecorridoVehiculoModal'
import type { ConductorResponse, VehiculoResponse } from './flotaApi'
import { rutaApi } from './rutaApi'
import type { RutaResponse } from './rutaApi'
import { despachoApi } from './despachoApi'
import { AccionCargaDespacho } from './AccionCargaDespacho'
import type {
  DespachoPedidoResponse,
  DespachoResponse,
  ResumenDespachos,
} from './despachoApi'

const hoy = () => hoyLocal()

function estadoBadge(estado: DespachoResponse['estado']) {
  return estado === 'ANULADO' ? (
    <Badge tone="danger">Anulado</Badge>
  ) : (
    <Badge tone="success">Armado</Badge>
  )
}

/**
 * Despacho: la carga de un camión para un día y una ruta.
 *
 * Junta PEDIDOS, no ventas: el vendedor los toma en la calle, aquí se arma con
 * ellos el reparto, y es el repartidor quien convierte cada uno en venta al
 * entregarlo. Por eso esta pantalla no factura ni mueve stock.
 */
export function DespachosPage() {
  const { puede } = usePermisos()
  const toast = useToast()
  const [vista, setVista] = useState<'lista' | 'form'>('lista')
  const [despachos, setDespachos] = useState<DespachoResponse[]>([])
  const [resumen, setResumen] = useState<ResumenDespachos | null>(null)
  const [rutas, setRutas] = useState<RutaResponse[]>([])
  const [vehiculos, setVehiculos] = useState<VehiculoResponse[]>([])
  const [conductores, setConductores] = useState<ConductorResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [detalle, setDetalle] = useState<DespachoResponse | null>(null)
  const [editando, setEditando] = useState<DespachoResponse | null>(null)
  const [guardando, setGuardando] = useState(false)

  const [fecha, setFecha] = useState(hoy())

  /*
   * De qué días son los pedidos que suben al camión.
   *
   * No es la fecha del reparto: lo que sale el lunes se tomó el viernes y se
   * siguió aumentando el sábado mientras se pesaba. Sin esto la lista traía
   * mezclados todos los pendientes de la ruta —el que quedó colgado del
   * miércoles, el de hoy que es para el próximo camión— y había que adivinar
   * cuáles iban.
   */
  const [desde, setDesde] = useState(hoy())
  const [hasta, setHasta] = useState(hoy())
  // Las rutas que carga el camión ese día: el lunes del camión 1 son la 1 y la 7.
  const [rutaIds, setRutaIds] = useState<number[]>([])
  // Igual que el conductor: si se tocaron a mano, el recorrido del vehículo deja de imponerlas.
  const [rutasTocadas, setRutasTocadas] = useState(false)
  // De qué está hecho el recorrido del vehículo elegido: para proponer las rutas y decir de dónde salieron.
  const [recorrido, setRecorrido] = useState<Record<string, number[]> | null>(null)
  /*
   * El día de visita que atiende el despacho: UNO solo, como en el reporte del sistema anterior (día de
   * visita + camión → rutas). Es lo que decide qué clientes salen, y no tiene por qué ser el día de la
   * fecha del reparto. Al abrir un despacho nuevo arranca en el día de hoy y sigue a la fecha mientras nadie
   * lo elija a mano.
   */
  const [diaVisita, setDiaVisita] = useState<string>(DIAS_SEMANA[0].id)
  const [diaTocado, setDiaTocado] = useState(false)
  const [vehiculoId, setVehiculoId] = useState(0)
  const [conductorId, setConductorId] = useState(0)
  const [observacion, setObservacion] = useState('')
  const [disponibles, setDisponibles] = useState<DespachoPedidoResponse[]>([])
  const [cargandoPedidos, setCargandoPedidos] = useState(false)
  const [elegidos, setElegidos] = useState<number[]>([])

  /*
   * Si el conductor se cambió a mano, el camión deja de imponerlo.
   *
   * Sin esto, elegir otro vehículo pisaría la elección de quien ya dijo
   * expresamente "hoy maneja este otro", que es justo el caso que el
   * autocompletado tiene que ayudar, no estorbar.
   */
  const [conductorTocado, setConductorTocado] = useState(false)

  const { confirmar, dialogo } = useConfirmacion()

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      const [lista, res, rts, vhs, cds] = await Promise.all([
        despachoApi.getAll(),
        despachoApi.resumen(),
        rutaApi.getAll(),
        vehiculoApi.getAll(),
        conductorApi.getAll(),
      ])
      setDespachos(lista)
      setResumen(res)
      setRutas(rts.filter((r) => r.activo))
      setVehiculos(vhs.filter((v) => v.activo))
      setConductores(cds.filter((c) => c.activo))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los despachos.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['despachos', 'pedidos', 'notasventa'], cargar)

  // El camión propone su conductor habitual; queda como propuesta hasta que
  // alguien decida otra cosa.
  useEffect(() => {
    if (conductorTocado || !vehiculoId) return
    const vehiculo = vehiculos.find((v) => v.id === vehiculoId)
    if (vehiculo?.conductorId) setConductorId(vehiculo.conductorId)
  }, [vehiculoId, vehiculos, conductorTocado])

  // El recorrido del vehículo elegido, para proponer las rutas del día.
  useEffect(() => {
    if (vista !== 'form' || !vehiculoId) {
      setRecorrido(null)
      return
    }
    let vivo = true
    void vehiculoApi
      .recorrido(vehiculoId)
      .then((r) => {
        if (vivo) setRecorrido(r.dias)
      })
      // Sin recorrido se sigue: las rutas se eligen a mano, como siempre.
      .catch(() => {
        if (vivo) setRecorrido(null)
      })
    return () => {
      vivo = false
    }
  }, [vehiculoId, vista])

  const diaDeLaFecha = DIAS_SEMANA[(new Date(`${fecha}T00:00:00`).getDay() + 6) % 7]
  const diaElegido = DIAS_SEMANA.find((d) => d.id === diaVisita) ?? diaDeLaFecha
  const rutasDelDia = recorrido?.[diaElegido.id] ?? []

  // Mientras el dia no se haya elegido a mano, sigue a la fecha del reparto.
  useEffect(() => {
    if (vista === 'form' && !diaTocado) setDiaVisita(diaDeLaFecha.id)
  }, [vista, diaTocado, diaDeLaFecha.id])

  // Elegir vehículo o día de visita propone las rutas de ese día, salvo que ya se hayan tocado a mano.
  useEffect(() => {
    if (vista !== 'form' || rutasTocadas || !recorrido) return
    setRutaIds(rutasDelDia)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [recorrido, diaVisita, vista, rutasTocadas])

  // Al cambiar de rutas o de día se piden los pedidos pendientes.
  const rutasClave = rutaIds.join(',')
  useEffect(() => {
    if (vista !== 'form' || rutaIds.length === 0) {
      setDisponibles([])
      return
    }

    let vivo = true
    setCargandoPedidos(true)
    void despachoApi
      .disponibles(rutaIds, editando?.id, diaVisita)
      .then((lista) => {
        if (!vivo) return

        /*
         * Al editar, los pedidos propios que ya se entregaron también cuentan.
         *
         * "Disponibles" son los pendientes, y uno que el repartidor ya
         * convirtió en venta deja de serlo. Sin sumarlos aquí desaparecían de
         * la lista, se desmarcaban solos y al guardar se quitaban del
         * despacho: el camión perdía justo lo que ya había repartido, y con
         * eso su detalle por cliente y su cobranza.
         */
        const entregados = (editando?.detalle ?? []).filter(
          (p) => !lista.some((x) => x.pedidoId === p.pedidoId),
        )
        const completa = [...lista, ...entregados]

        setDisponibles(completa)
        // Lo que ya no está disponible deja de estar marcado: si no, se
        // enviaría un pedido que otro camión se llevó.
        setElegidos((prev) => prev.filter((id) => completa.some((p) => p.pedidoId === id)))
      })
      .catch((e) => {
        if (vivo) toast.error(e instanceof ApiError ? e.message : 'No pudimos cargar los pedidos.')
      })
      .finally(() => {
        if (vivo) setCargandoPedidos(false)
      })

    return () => {
      vivo = false
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [rutasClave, diaVisita, vista, editando])

  const abrirNuevo = () => {
    setEditando(null)
    setFecha(hoy())
    setDesde(hoy())
    setHasta(hoy())
    setRutaIds([])
    setRutasTocadas(false)
    // El recorrido del vehiculo anterior no debe proponer rutas en un despacho nuevo.
    setRecorrido(null)
    setDiaTocado(false)
    setVehiculoId(0)
    setConductorId(0)
    setConductorTocado(false)
    setObservacion('')
    setElegidos([])
    setVista('form')
  }

  const abrirEdicion = (d: DespachoResponse) => {
    setEditando(d)
    setFecha(d.fecha.slice(0, 10))
    // Los despachos armados antes de que existiera el rango no lo tienen: se
    // toma el de sus propios pedidos, para que ninguno quede fuera de la vista.
    const dias = d.detalle.filter((p) => p.fecha).map((p) => diaLocal(p.fecha)).sort()
    setDesde(d.pedidosDesde?.slice(0, 10) ?? dias[0] ?? hoy())
    setHasta(d.pedidosHasta?.slice(0, 10) ?? dias[dias.length - 1] ?? hoy())
    setRutaIds(d.rutaIds?.length ? d.rutaIds : [d.rutaId])
    // Al editar, las rutas guardadas mandan: fueron una decision que ya se tomo.
    setRutasTocadas(true)
    // El dia de visita guardado manda. Los despachos de antes no lo tienen: se toma el de sus pedidos y, si no
    // hay, el de la fecha.
    setDiaTocado(true)
    setDiaVisita(
      d.diaVisita ??
        d.detalle.find((p) => p.diaVisita)?.diaVisita ??
        DIAS_SEMANA[(new Date(`${d.fecha.slice(0, 10)}T00:00:00`).getDay() + 6) % 7].id,
    )
    setVehiculoId(d.vehiculoId)
    setConductorId(d.conductorId)
    // Al editar, el conductor guardado manda: fue una decisión que ya se tomó.
    setConductorTocado(true)
    setObservacion(d.observacion ?? '')
    setElegidos(d.detalle.map((p) => p.pedidoId))
    setVista('form')
  }

  const alternar = (pedidoId: number) =>
    setElegidos((prev) =>
      prev.includes(pedidoId) ? prev.filter((id) => id !== pedidoId) : [...prev, pedidoId],
    )

  const guardar = async () => {
    if (rutaIds.length === 0) return toast.error('Elige al menos una ruta.')
    if (!vehiculoId) return toast.error('Elige el vehículo.')
    if (!conductorId) return toast.error('Elige el conductor.')
    if (desde > hasta) return toast.error('El "desde" de los pedidos no puede ser después del "hasta".')
    if (elegidos.length === 0) return toast.error('Marca al menos un pedido para cargar.')

    const body = {
      fecha,
      pedidosDesde: desde,
      pedidosHasta: hasta,
      diaVisita,
      rutaIds,
      vehiculoId,
      conductorId,
      observacion: observacion.trim() || null,
      pedidoIds: elegidos,
    }

    setGuardando(true)
    try {
      if (editando) {
        await despachoApi.update(editando.id, body)
      } else {
        await despachoApi.create(body)
      }
      setVista('lista')
      await cargar()
      toast.exito(editando ? 'Despacho actualizado' : 'Despacho creado')
    } catch (e) {
      toast.error(
        e instanceof ApiError
          ? e.errors.length
            ? e.errors.join(' ')
            : e.message
          : 'No pudimos guardar el despacho.',
      )
    } finally {
      setGuardando(false)
    }
  }

  const anular = (d: DespachoResponse) =>
    confirmar({
      titulo: `Anular ${d.numero}`,
      mensaje: 'Sus pedidos vuelven a quedar libres para otro despacho.',
      confirmar: 'Anular',
      tono: 'danger',
      accion: async () => {
        setError('')
        try {
          await despachoApi.anular(d.id)
          await cargar()
          toast.exito(`${d.numero} anulado`)
        } catch (e) {
          setError(e instanceof ApiError ? e.message : 'No pudimos anular el despacho.')
        }
      },
    })

  /*
   * Los pedidos del rango, y los que ya están marcados aunque caigan fuera.
   *
   * Un pedido marcado nunca se esconde: al editar un despacho viejo, o al
   * achicar el rango, desaparecer de la vista algo que sigue yendo en el camión
   * es la forma de cargarlo sin saberlo.
   */
  const enRango = (p: DespachoPedidoResponse) => {
    // Un backend sin actualizar no manda la fecha: mejor mostrarlo que romper la pantalla.
    if (!p.fecha) return true
    const dia = diaLocal(p.fecha)
    return dia >= desde && dia <= hasta
  }
  const visibles = disponibles.filter((p) => enRango(p) || elegidos.includes(p.pedidoId))
  const fueraDeRango = disponibles.filter((p) => !enRango(p) && !elegidos.includes(p.pedidoId))
  const todosMarcados =
    visibles.length > 0 && visibles.every((p) => elegidos.includes(p.pedidoId))

  /** Lo normal es que suban todos los del rango: marcarlos de a uno es donde se escapa alguno. */
  const alternarTodos = () =>
    setElegidos((prev) =>
      todosMarcados
        ? prev.filter((id) =>
            // Los ya entregados se quedan: no se quita del camión lo repartido.
            visibles.some((p) => p.pedidoId === id && p.notaVentaId != null) ||
            !visibles.some((p) => p.pedidoId === id),
          )
        : [...new Set([...prev, ...visibles.map((p) => p.pedidoId)])],
    )

  const totalElegido = disponibles
    .filter((p) => elegidos.includes(p.pedidoId))
    .reduce((n, p) => n + p.total, 0)

  const columns: DataTableColumn<DespachoResponse>[] = [
    // El número se busca con el buscador de arriba, no en el panel.
    { key: 'numero', label: 'Número', filterable: false, render: (row) => <Badge>{row.numero}</Badge> },
    {
      key: 'fecha',
      label: 'Fecha',
      filterType: 'date',
      value: (row) => new Date(row.fecha).getTime(),
      render: (row) => fechaCorta(row.fecha),
    },
    {
      key: 'ruta',
      label: 'Ruta',
      filterType: 'select',
      filterOptions: [...new Set(despachos.map((d) => d.ruta))]
        .sort((a, b) => a.localeCompare(b, 'es', { numeric: true }))
        .map((n) => ({ value: n, label: n })),
    },
    {
      key: 'diaVisita',
      label: 'Día de visita',
      filterType: 'select',
      filterOptions: DIAS_SEMANA.filter((d) => d.id !== 'DOMINGO').map((d) => ({ value: d.label, label: d.label })),
      value: (row) => DIAS_SEMANA.find((d) => d.id === row.diaVisita)?.label ?? '',
      render: (row) =>
        DIAS_SEMANA.find((d) => d.id === row.diaVisita)?.label ?? <span className="text-ink-soft">—</span>,
    },
    {
      key: 'vehiculo',
      label: 'Vehículo',
      filterType: 'select',
      filterOptions: [...new Set(vehiculos.map((v) => v.placa))]
        .sort((a, b) => a.localeCompare(b, 'es'))
        .map((n) => ({ value: n, label: n })),
    },
    {
      key: 'conductor',
      label: 'Conductor',
      filterType: 'select',
      filterOptions: [...new Set(conductores.map((c) => c.nombre))]
        .sort((a, b) => a.localeCompare(b, 'es'))
        .map((n) => ({ value: n, label: n })),
    },
    {
      key: 'pedidos',
      label: 'Entregas',
      align: 'right',
      filterable: false,
      // Cuántos de los que lleva ya se entregaron: es lo que se mira para
      // saber si el camión terminó su vuelta.
      render: (row) => (
        <span className="inline-flex flex-wrap items-center justify-end gap-1">
          <Badge tone={row.entregados === row.pedidos ? 'success' : 'warning'}>
            {row.entregados} de {row.pedidos}
          </Badge>
          {row.noEntregados > 0 && (
            <Badge tone="danger">
              {row.noEntregados} no {row.noEntregados === 1 ? 'entregado' : 'entregados'}
            </Badge>
          )}
        </span>
      ),
    },
    {
      key: 'total',
      label: 'Total',
      align: 'right',
      filterable: false,
      render: (row) => `S/ ${row.total.toFixed(2)}`,
    },
    {
      key: 'estado',
      label: 'Estado',
      filterType: 'select',
      filterOptions: [
        { value: 'ARMADO', label: 'Armado' },
        { value: 'ANULADO', label: 'Anulado' },
      ],
      render: (row) => estadoBadge(row.estado),
    },
  ]

  if (vista === 'form') {
    return (
      <div className="flex flex-col gap-4">
        <PageHeader
          icon={<Truck size={20} />}
          title={editando ? `Editar ${editando.numero}` : 'Nuevo despacho'}
          description="Arma la carga del camión: elige el vehículo y el día, y marca los pedidos que salen."
          actions={
            <Button variant="secondary" size="sm" onClick={() => setVista('lista')} iconRight={<ArrowLeft size={15} />}>
              Volver
            </Button>
          }
        />


        <div className="grid gap-4 xl:grid-cols-[1fr_22rem]">
          <PageSection
            title="Pedidos"
            description="Los pendientes de los clientes de esas rutas, tomados entre esas fechas."
          >
            <div className="mb-3 grid gap-3 sm:grid-cols-2">
              <Input
                label="Pedidos desde"
                type="date"
                value={desde}
                max={hasta}
                onChange={(e) => setDesde(e.target.value)}
              />
              <Input
                label="Pedidos hasta"
                type="date"
                value={hasta}
                min={desde}
                onChange={(e) => setHasta(e.target.value)}
              />
            </div>
            <p className="mb-3 text-xs text-ink-soft">
              Incluye el día en que se pesa: los aumentos de ese día también suben al camión.
            </p>

            {rutaIds.length > 0 && fueraDeRango.length > 0 && (
              <div className="mb-3 rounded-field border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-800">
                {fueraDeRango.length === 1
                  ? 'Hay 1 pedido pendiente de esta ruta fuera de esas fechas'
                  : `Hay ${fueraDeRango.length} pedidos pendientes de esta ruta fuera de esas fechas`}
                {' '}(del {fechaCorta(fueraDeRango.map((p) => p.fecha).sort()[0])}
                {fueraDeRango.length > 1 &&
                  ` al ${fechaCorta(fueraDeRango.map((p) => p.fecha).sort()[fueraDeRango.length - 1])}`}
                ). No suben al camión; amplía las fechas si deben ir.
              </div>
            )}

            {rutaIds.length === 0 ? (
              <p className="py-8 text-center text-sm text-ink-soft">
                Elige primero las rutas para ver sus pedidos.
              </p>
            ) : cargandoPedidos ? (
              <p className="py-8 text-center text-sm text-ink-soft">Cargando pedidos...</p>
            ) : disponibles.length === 0 ? (
              <p className="py-8 text-center text-sm text-ink-soft">
                No hay pedidos pendientes para esas rutas con visita el {diaElegido.label.toLowerCase()}. Puede que ya estén en otro camión.
              </p>
            ) : visibles.length === 0 ? (
              <p className="py-8 text-center text-sm text-ink-soft">
                No hay pedidos de esas rutas entre esas fechas.
              </p>
            ) : (
              <div className="flex flex-col gap-2">
                <label className="flex cursor-pointer items-center gap-3 px-3 py-1 text-sm font-semibold text-ink">
                  <input type="checkbox" checked={todosMarcados} onChange={alternarTodos} />
                  {todosMarcados ? 'Quitar todos' : `Marcar todos (${visibles.length})`}
                </label>
                {/*
                  Con 45 pedidos la lista se iba hasta abajo y "Marcar todos" quedaba fuera de la vista: la lista
                  tiene su propio scroll y el marcar-todos se queda fijo arriba.
                */}
                <div className="flex max-h-[65vh] flex-col gap-2 overflow-y-auto pr-1">
                {visibles.map((p) => (
                  <label
                    key={p.pedidoId}
                    className="flex cursor-pointer items-start gap-3 rounded-field border border-line p-3 transition hover:border-ink-soft"
                  >
                    <input
                      type="checkbox"
                      className="mt-1"
                      checked={elegidos.includes(p.pedidoId)}
                      // Ya se entregó: no se puede bajar del camión lo que ya se repartió.
                      disabled={p.notaVentaId != null}
                      title={p.notaVentaId != null ? 'Ya se entregó: no se puede quitar del despacho' : undefined}
                      onChange={() => alternar(p.pedidoId)}
                    />
                    <span className="flex min-w-0 flex-1 flex-col">
                      <span className="flex items-center gap-2">
                        <Badge>{p.numero}</Badge>
                        <span className="truncate text-sm font-semibold text-ink">{p.cliente}</span>
                        {p.notaVentaNumero && <Badge tone="success">{p.notaVentaNumero}</Badge>}
                      </span>
                      {/* Dónde entregarlo: sin esto el reparto no se puede armar. */}
                      <span className="truncate text-xs text-ink-soft">
                        {[p.mercado, p.direccion].filter(Boolean).join(' — ') || 'Sin dirección'}
                        {p.telefono ? ` · ${p.telefono}` : ''}
                      </span>
                      {/* Con varias rutas en el camión, dice de cuál es cada cliente y qué día se lo visita. */}
                      {(p.rutaCliente || p.diaVisita) && (
                        <span className="text-xs text-ink-soft">
                          {p.rutaCliente ? `Ruta ${p.rutaCliente}` : ''}
                          {p.rutaCliente && p.diaVisita ? ' · ' : ''}
                          {p.diaVisita ? (DIAS_SEMANA.find((d) => d.id === p.diaVisita)?.label ?? p.diaVisita) : ''}
                        </span>
                      )}
                    </span>
                    <span className="text-sm font-semibold text-ink">S/ {p.total.toFixed(2)}</span>
                  </label>
                ))}
                </div>
              </div>
            )}
          </PageSection>

          <PageSection title="Despacho">
            <div className="flex flex-col gap-4">
              <Input
                label="Fecha del reparto"
                type="date"
                value={fecha}
                onChange={(e) => setFecha(e.target.value)}
              />

              {/*
                El día de visita que atiende este despacho: uno solo. Con el vehículo decide las rutas
                (camión 1 + lunes = rutas 1 y 7) y qué clientes salen.
              */}
              <Desplegable
                label="Día de visita"
                value={diaVisita}
                onChange={(v) => {
                  setDiaVisita(String(v))
                  setDiaTocado(true)
                }}
                options={DIAS_SEMANA.filter((d) => d.id !== 'DOMINGO').map((d) => ({ value: d.id, label: d.label }))}
              />

              <Desplegable
                label="Vehículo"
                value={vehiculoId}
                onChange={(v) => setVehiculoId(Number(v))}
                options={vehiculos.map((v) => ({
                  value: v.id,
                  label: v.placa,
                  detalle: v.conductor ?? undefined,
                }))}
              />

              {/*
                Las rutas que carga el camión ese día. El vehículo y la fecha las proponen desde su
                recorrido semanal; se pueden cambiar para este despacho.
              */}
              <div>
                <span className="ui-label mb-1.5 block">Rutas</span>
                <div className="flex flex-wrap gap-1.5">
                  {rutas.map((r) => {
                    const puesta = rutaIds.includes(r.id)
                    return (
                      <button
                        key={r.id}
                        type="button"
                        aria-pressed={puesta}
                        onClick={() => {
                          setRutasTocadas(true)
                          setRutaIds((prev) => (prev.includes(r.id) ? prev.filter((id) => id !== r.id) : [...prev, r.id]))
                        }}
                        className={cn(
                          'min-w-9 cursor-pointer rounded-full border px-3 py-1 text-sm font-semibold transition-colors',
                          puesta
                            ? 'border-[rgb(var(--sys-rgb))] bg-[rgb(var(--sys-rgb)/0.12)] text-[rgb(var(--sys-ink-rgb))]'
                            : 'border-line text-ink-muted hover:border-ink-soft',
                        )}
                      >
                        {r.nombre}
                      </button>
                    )
                  })}
                </div>
                <p className="mt-1.5 text-xs text-ink-soft">
                  {!vehiculoId
                    ? 'Elige el vehículo y el día de visita: sus rutas se proponen solas.'
                    : rutasDelDia.length === 0
                      ? `Este vehículo no tiene rutas los ${diaElegido.label.toLowerCase()}. Elígelas a mano o cárgalas en Flota → Recorrido.`
                      : rutasTocadas
                        ? 'Cambiadas a mano para este despacho.'
                        : `Del recorrido del vehículo para el ${diaElegido.label.toLowerCase()}.`}
                </p>
              </div>

              <Desplegable
                label="Conductor"
                value={conductorId}
                onChange={(v) => {
                  setConductorId(Number(v))
                  setConductorTocado(true)
                }}
                options={conductores.map((c) => ({ value: c.id, label: c.nombre }))}
              />

              <label className="block">
                <span className="ui-label mb-1.5">Observación (opcional)</span>
                <textarea
                  rows={2}
                  value={observacion}
                  onChange={(e) => setObservacion(e.target.value)}
                  className="w-full rounded-field border border-line bg-surface px-3 py-2 text-sm text-ink outline-none placeholder:text-ink-soft focus:border-ink-soft"
                />
              </label>

              <div className="rounded-field bg-surface-alt p-3">
                <p className="text-xs text-ink-soft">Carga del camión</p>
                <p className="text-lg font-semibold text-ink">
                  {elegidos.length} pedido{elegidos.length === 1 ? '' : 's'}
                </p>
                <p className="text-sm text-ink-muted">S/ {totalElegido.toFixed(2)}</p>
              </div>

              <Button loading={guardando} onClick={() => void guardar()}>
                {editando ? 'Guardar cambios' : 'Armar despacho'}
              </Button>
            </div>
          </PageSection>
        </div>
      </div>
    )
  }

  return (
    <ListPage
      icon={<Truck size={20} />}
      title="Despachos"
      description="La carga de cada camión. Los pedidos se convierten en venta cuando el repartidor los entrega."
      actions={
        puede('tms.despachos', 'crear') ? (
          <Button size="sm" onClick={abrirNuevo} iconRight={<Plus size={15} />}>
            Nuevo despacho
          </Button>
        ) : undefined
      }
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Despachos" value={String(resumen?.total ?? 0)} icon={<Truck size={18} />} />
          <StatCard
            label="Armados"
            value={String(resumen?.armados ?? 0)}
            icon={<Package size={18} />}
            tono="success"
          />
          <StatCard
            label="Pedidos en ruta"
            value={String(resumen?.pedidosEnRuta ?? 0)}
            hint="cargados y sin entregar"
            icon={<Package size={18} />}
            tono="warning"
          />
        </>
      }
      columns={columns}
      rows={despachos}
      cardIcon={Truck}
      searchPlaceholder="Buscar por número, ruta, placa..."
      empty={cargando ? 'Cargando despachos...' : 'Todavía no hay despachos armados.'}
      actionsWidth={220}
      rowActions={(row) => (
        <>
          <RowAction label={`Ver ${row.numero}`} tone="view" onClick={() => setDetalle(row)}>
            <Eye size={15} />
          </RowAction>
          {/* Los papeles de la carga: dos copias por hoja, para el repartidor. */}
          {puede('tms.despachos', 'exportar') && (
            <AccionPdf documento="despacho" id={row.id} numero={row.numero} />
          )}
          {/* Qué productos hay que subir al camión, sumados de todos sus pedidos. */}
          {puede('tms.despachos', 'exportar') && (
            <AccionCargaDespacho id={row.id} numero={row.numero} />
          )}
          {/* Con qué sale el repartidor y con qué se cuadra la cobranza al volver. */}
          {puede('tms.despachos', 'exportar') && (
            <AccionPdf documento="despacho" id={row.id} numero={row.numero} reporte="clientes" />
          )}
          {puede('tms.despachos', 'editar') && (
            <RowAction
              label={`Editar ${row.numero}`}
              disabled={row.estado === 'ANULADO'}
              disabledReason="Está anulado"
              onClick={() => abrirEdicion(row)}
            >
              <Pencil size={15} />
            </RowAction>
          )}
          {puede('tms.despachos', 'anular') && (
            <RowAction
              label={`Anular ${row.numero}`}
              tone="danger"
              disabled={row.estado === 'ANULADO' || row.entregados > 0}
              disabledReason={
                row.estado === 'ANULADO' ? 'Ya está anulado' : 'Ya tiene entregas facturadas'
              }
              onClick={() => anular(row)}
            >
              <Undo2 size={15} />
            </RowAction>
          )}
        </>
      )}
    >
      <Modal
        open={detalle !== null}
        size="lg"
        title={detalle ? `${detalle.numero} — ${detalle.ruta}` : ''}
        description={
          detalle
            ? `${detalle.vehiculo} · ${detalle.conductor} · ${fechaCorta(detalle.fecha)}`
            : ''
        }
        onClose={() => setDetalle(null)}
      >
        {detalle && (
          <div className="flex flex-col gap-3">
            <TablaProductosDetalle<DespachoPedidoResponse>
              filas={detalle.detalle}
              rowKey={(p) => p.pedidoId}
              titulo={(p) => p.cliente}
              subtitulo={(p) =>
                `${p.numero} · ${[p.mercado, p.direccion].filter(Boolean).join(' — ') || 'Sin dirección'}`
              }
              grupos={[
                [
                  { key: 'total', label: 'Total', render: (p) => `S/ ${p.total.toFixed(2)}` },
                  {
                    key: 'entrega',
                    label: 'Entrega',
                    render: (p) => {
                      if (p.noEntregadoMotivo) return `No entregado: ${p.noEntregadoMotivo}`
                      const base = p.notaVentaNumero ?? 'Sin entregar'
                      return p.lineasConNovedad > 0
                        ? `${base} · ${p.lineasConNovedad} con novedad`
                        : base
                    },
                  },
                ] satisfies ColumnaDetalleProducto<DespachoPedidoResponse>[],
              ]}
            />

            {detalle.observacion && (
              <p className="text-sm text-ink-soft">
                <span className="font-semibold text-ink-muted">Observación: </span>
                {detalle.observacion}
              </p>
            )}
          </div>
        )}
      </Modal>

      {dialogo}
    </ListPage>
  )
}
