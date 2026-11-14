import { useCallback, useEffect, useMemo, useState } from 'react'
import { CheckCircle2, MapPin, Phone, Plus, Store } from 'lucide-react'
import { Alert, Badge, Desplegable, ListPage, StatCard } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta } from '../../lib/fechas'
import { useRealtime } from '../../lib/realtime'
import { ESTADOS_UI, ORDEN_ESTADOS, colorCambio, porcentaje } from '../crm/formato'
import { EtiquetaEstado } from '../crm/piezas'
import { visitaApi } from './visitaApi'
import type { ResumenVisitas, RutaVisita, VisitaResponse } from './visitaApi'

/** Los días de visita, en orden de semana, tal como los entiende el backend. */
const DIAS = [
  { valor: 'LUNES', etiqueta: 'Lunes' },
  { valor: 'MARTES', etiqueta: 'Martes' },
  { valor: 'MIERCOLES', etiqueta: 'Miércoles' },
  { valor: 'JUEVES', etiqueta: 'Jueves' },
  { valor: 'VIERNES', etiqueta: 'Viernes' },
  { valor: 'SABADO', etiqueta: 'Sábado' },
  { valor: 'DOMINGO', etiqueta: 'Domingo' },
  { valor: 'SEMANA', etiqueta: 'Toda la semana' },
] as const

/** El día de hoy como lo guarda el sistema: es el que se abre por defecto. */
const diaDeHoy = (): string => DIAS[(new Date().getDay() + 6) % 7].valor

/**
 * Visitas: a qué clientes toca ir y a cuáles ya se les tomó pedido.
 *
 * No es un documento nuevo ni guarda nada: es una lista de trabajo armada con
 * el día de visita del cliente y los pedidos de esa fecha. Sirve para que el
 * vendedor no dependa de acordarse, y para ver al cierre del día cuántos
 * puestos quedaron sin pasar.
 */
export function VisitasPage() {
  const [visitas, setVisitas] = useState<VisitaResponse[]>([])
  const [resumen, setResumen] = useState<ResumenVisitas | null>(null)
  const [rutas, setRutas] = useState<RutaVisita[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  /*
   * Se mira por DÍA DE VISITA y por RUTA, no por rango de fechas.
   *
   * El día de visita es una propiedad del cliente (los del lunes), así que se elige el día de la semana y la
   * ruta; las fechas salen solas — la del día elegido en la semana de hoy — y sirven para saber a cuáles ya se
   * les tomó pedido. Las rutas que se ofrecen son las del usuario: el administrador ve todas.
   */
  const [dia, setDia] = useState<string>(diaDeHoy)
  const [rutaId, setRutaId] = useState(0)

  // Las tarjetas llevan a lo que cuentan: "Ver las 14" pone ese filtro en "Estado".
  const [filtroPedido, setFiltroPedido] = useState<{ column: string; value: string; vez: number }>()
  const verEstado = (value: string) => setFiltroPedido((f) => ({ column: 'atendido', value, vez: (f?.vez ?? 0) + 1 }))

  const consulta = useMemo(() => ({ dia, rutaId: rutaId || undefined }), [dia, rutaId])

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      // El resumen sale de la misma lista: pedírselo al servidor era hacer
      // dos veces el mismo trabajo (programadas, atendidas y total).
      const lista = await visitaApi.listar(consulta)
      const atendidas = lista.filter((v) => v.atendido).length
      setVisitas(lista)
      setResumen({
        programadas: lista.length,
        atendidas,
        pendientes: lista.length - atendidas,
        total: Math.round(lista.reduce((s, v) => s + v.total, 0) * 100) / 100,
      })
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las visitas.')
    } finally {
      setCargando(false)
    }
  }, [consulta])

  useEffect(() => {
    void cargar()
  }, [cargar])

  // Las rutas que puede mirar quien entra: todas si es administrador, las suyas si no.
  useEffect(() => {
    void visitaApi
      .rutas()
      .then((rts) => {
        setRutas(rts)
        // Con una sola ruta no hay nada que elegir: queda fija.
        if (rts.length === 1) setRutaId(rts[0].id)
      })
      .catch(() => {
        /* Sin rutas la lista sigue sirviendo: solo se pierde filtrar. */
      })
  }, [])

  // Al tomar un pedido, la lista tiene que reflejarlo sin recargar a mano.
  useRealtime(['pedidos', 'clientes'], cargar)

  const columns: DataTableColumn<VisitaResponse>[] = useMemo(
    () => [
      {
        key: 'fecha',
        label: 'Fecha',
        // Se elige arriba, con los días de visita.
        filterable: false,
        render: (row) => fechaCorta(row.fecha),
      },
      {
        key: 'dia',
        label: 'Día',
        filterable: false,
        value: (row) => row.dia,
        render: (row) => <span className="capitalize">{row.dia.toLowerCase()}</span>,
      },
      {
        // Se busca con el buscador de arriba, no en el panel.
        key: 'cliente',
        label: 'Cliente',
        filterable: false,
        render: (row) => <span className="font-medium text-ink">{row.cliente}</span>,
      },
      {
        key: 'documento',
        label: 'Documento',
        filterable: false,
        value: (row) => row.documento,
        render: (row) => row.documento,
      },
      {
        key: 'mercado',
        label: 'Mercado',
        // El filtro compara solo por mercado; la dirección va en su propia columna.
        filterType: 'select',
        filterOptions: [...new Set(visitas.map((v) => v.mercado).filter((v): v is string => !!v))]
          .sort((a, b) => a.localeCompare(b, 'es'))
          .map((v) => ({ value: v, label: v })),
        render: (row) => row.mercado ?? <span className="text-ink-soft">—</span>,
      },
      {
        key: 'direccion',
        label: 'Dirección',
        filterable: false,
        value: (row) => row.direccion ?? '',
        render: (row) => row.direccion ?? <span className="text-ink-soft">—</span>,
      },
      {
        key: 'telefono',
        label: 'Teléfono',
        filterable: false,
        render: (row) =>
          row.telefono ? (
            <span className="flex items-center gap-1.5">
              <Phone size={13} className="text-ink-soft" />
              {row.telefono}
            </span>
          ) : (
            <span className="text-ink-soft">—</span>
          ),
      },
      {
        key: 'ruta',
        label: 'Ruta',
        // Se elige arriba, junto al día.
        filterable: false,
        render: (row) => row.ruta ?? '—',
      },
      {
        key: 'vendedor',
        label: 'Vendedor',
        filterable: false,
        render: (row) => row.vendedor ?? '—',
      },
      {
        // Solo llega para quien puede abrir Clientes con caída del CRM: sin ese permiso la columna sale vacía.
        key: 'riesgo',
        label: 'Compra',
        filterType: 'select',
        filterOptions: ORDEN_ESTADOS.map((value) => ({ value, label: ESTADOS_UI[value].etiqueta })),
        value: (row) => row.riesgo ?? '',
        render: (row) => (row.riesgo ? <EtiquetaEstado estado={row.riesgo} /> : <span className="text-ink-soft">—</span>),
      },
      {
        key: 'caidaPct',
        label: '% caída',
        align: 'right',
        filterable: false,
        value: (row) => row.caidaPct ?? -999,
        render: (row) =>
          row.riesgo && row.caidaPct !== null ? (
            <span className={colorCambio(-row.caidaPct)}>{porcentaje(-row.caidaPct)}</span>
          ) : (
            <span className="text-ink-soft">—</span>
          ),
      },
      {
        key: 'accionPendiente',
        label: 'Acción pendiente',
        filterable: false,
        value: (row) => row.accionPendiente ?? '',
        render: (row) =>
          row.riesgo && row.accionPendiente ? (
            <span className={row.accionVencida ? 'text-red-600' : undefined}>
              {row.accionPendiente}
              {row.accionVencida && ' (vencida)'}
            </span>
          ) : (
            <span className="text-ink-soft">—</span>
          ),
      },
      {
        key: 'atendido',
        label: 'Estado',
        filterType: 'select',
        filterOptions: [
          { value: 'Pendiente', label: 'Pendiente' },
          { value: 'Con pedido', label: 'Con pedido' },
        ],
        value: (row) => (row.atendido ? 'Con pedido' : 'Pendiente'),
        render: (row) =>
          row.atendido ? (
            <Badge tone="success">{row.pedidoNumero}</Badge>
          ) : (
            <Badge tone="warning">Pendiente</Badge>
          ),
      },
      {
        key: 'total',
        label: 'Pedido',
        align: 'right',
        filterable: false,
        render: (row) =>
          row.atendido ? `S/ ${row.total.toFixed(2)}` : <span className="text-ink-soft">—</span>,
      },
    ],
    [visitas],
  )

  return (
    <ListPage
      icon={<Store size={20} />}
      title="Visitas"
      description="Clientes que toca visitar según su día de visita y su ruta, y a cuáles ya se les tomó pedido."
      alert={error ? <Alert>{error}</Alert> : undefined}
      filtroPedido={filtroPedido}
      stats={
        <>
          <StatCard
            label="Programadas"
            value={String(resumen?.programadas ?? 0)}
            icon={<Store size={18} />}
            progreso={(resumen?.programadas ?? 0) > 0 ? 1 : 0}
            accion={{ label: 'Ver todas', onClick: () => verEstado('') }}
          />
          <StatCard
            label="Con pedido"
            value={String(resumen?.atendidas ?? 0)}
            // El % de cobertura ya lo dice la barra con su porcentaje.
            hint="ya se les tomó pedido"
            icon={<CheckCircle2 size={18} />}
            tono="success"
            progreso={resumen?.programadas ? resumen.atendidas / resumen.programadas : 0}
            accion={{
              label: resumen?.atendidas ? `Ver las ${resumen.atendidas}` : 'Ver',
              onClick: () => verEstado('Con pedido'),
            }}
          />
          <StatCard
            label="Pendientes"
            value={String(resumen?.pendientes ?? 0)}
            hint="todavía sin pasar"
            icon={<MapPin size={18} />}
            tono="warning"
            progreso={resumen?.programadas ? resumen.pendientes / resumen.programadas : 0}
            accion={{
              label: resumen?.pendientes ? `Ver las ${resumen.pendientes}` : 'Ver',
              onClick: () => verEstado('Pendiente'),
            }}
          />
          <StatCard
            label="Pedido de la selección"
            value={`S/ ${(resumen?.total ?? 0).toFixed(2)}`}
            icon={<Plus size={18} />}
            tono="neutral"
          />
        </>
      }
      banner={
        <div className="flex flex-col gap-3 rounded-panel border border-line bg-white p-3 sm:flex-row sm:items-end">
          <div className="min-w-0 flex-1">
            <span className="ui-label">Día de visita</span>
            <div className="mt-1.5 flex flex-wrap gap-1.5" role="group" aria-label="Día de visita">
              {DIAS.map((d) => (
                <button
                  key={d.valor}
                  type="button"
                  onClick={() => setDia(d.valor)}
                  aria-pressed={dia === d.valor}
                  className={`rounded-full border px-3 py-1.5 text-sm transition-colors ${
                    dia === d.valor
                      ? 'border-blue-500 bg-blue-50 font-semibold text-blue-700'
                      : 'border-line bg-white text-ink-muted hover:bg-surface-alt'
                  }`}
                >
                  {d.etiqueta}
                </button>
              ))}
            </div>
          </div>
          <div className="sm:w-60">
            <Desplegable
              label="Ruta"
              value={rutaId}
              onChange={(v) => setRutaId(Number(v))}
              options={[
                { value: 0, label: rutas.length > 1 ? 'Todas mis rutas' : 'Sin rutas' },
                ...rutas.map((r) => ({ value: r.id, label: r.nombre })),
              ]}
            />
          </div>
        </div>
      }
      columns={columns}
      rows={visitas}
      cardIcon={Store}
      searchPlaceholder="Buscar cliente, mercado..."
      empty={cargando ? 'Cargando visitas...' : 'No hay clientes con visita en esos días.'}
      note="Los pendientes salen primero. El pedido se toma desde Facturación → Pedidos."
    />
  )
}
