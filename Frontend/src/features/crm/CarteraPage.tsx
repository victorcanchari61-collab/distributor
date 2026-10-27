import { useCallback, useEffect, useMemo, useState } from 'react'
import { CalendarClock, Clock, TrendingDown, TriangleAlert, Wallet } from 'lucide-react'
import { Alert, ListPage, StatCard, Tabs } from '../../components/ui'
import type { ConsultaTabla, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta } from '../../lib/fechas'
import { useRealtime } from '../../lib/realtime'
import { usuarioApi } from '../config/usuarioApi'
import type { UsuarioResponse } from '../config/usuarioApi'
import { mercadoApi, rutaApi } from '../tms'
import type { MercadoResponse, RutaResponse } from '../tms'
import { crmApi } from './crmApi'
import type { CarteraCrm, ClienteCrm, ConsultaCartera, PeriodoCrm } from './crmApi'
import { CategoriaBadge } from './CategoriaBadge'
import { FichaClienteModal } from './FichaClienteModal'
import { NIVELES, PERIODOS, colorCambio, porcentaje, rango, soles, solesConSigno } from './formato'
import { NivelBadge } from './NivelBadge'

/**
 * Cartera en riesgo: qué clientes están comprando menos que antes.
 *
 * No guarda nada: compara lo vendido en el periodo en curso contra el anterior del mismo largo y
 * ordena por la plata que se dejó de vender. Mercado, ruta y vendedor acotan lo que se pide al
 * servidor (así el resumen de arriba es el de lo filtrado); el nivel se filtra en la tabla.
 */
export function CarteraPage() {
  const [periodo, setPeriodo] = useState<PeriodoCrm>('mes')
  const [filtros, setFiltros] = useState<Omit<ConsultaCartera, 'periodo'>>({})
  const [cartera, setCartera] = useState<CarteraCrm | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [abierto, setAbierto] = useState<number | null>(null)

  const [mercados, setMercados] = useState<MercadoResponse[]>([])
  const [rutas, setRutas] = useState<RutaResponse[]>([])
  const [usuarios, setUsuarios] = useState<UsuarioResponse[]>([])

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setCartera(await crmApi.cartera({ periodo, ...filtros }))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar la cartera.')
    } finally {
      setCargando(false)
    }
  }, [periodo, filtros])

  useEffect(() => {
    void cargar()
  }, [cargar])

  // Los catálogos de los filtros no dependen del periodo.
  useEffect(() => {
    void Promise.all([mercadoApi.getAll(), rutaApi.getAll(), usuarioApi.getAll()])
      .then(([mer, rut, usr]) => {
        setMercados(mer.filter((m) => m.activo))
        setRutas(rut.filter((r) => r.activo))
        setUsuarios(usr.filter((u) => u.activo))
      })
      .catch(() => {
        /* Sin catálogos la lista sigue sirviendo: solo se pierde filtrar. */
      })
  }, [])

  // Una venta nueva, un cobro o un cambio en el cliente mueven los números.
  useRealtime(['notasventa', 'pedidos', 'clientes', 'devoluciones', 'seguimientos'], cargar)

  /** Traduce los filtros del panel a lo que el servidor necesita para acotar. */
  const aplicar = useCallback((q: ConsultaTabla) => {
    const valor = (columna: string) => Number(q.filtros.find((f) => f.columna === columna)?.valor) || undefined
    const siguiente = { mercadoId: valor('mercado'), rutaId: valor('ruta'), vendedorId: valor('vendedor') }

    // Cada tecla del buscador también llega aquí: sin esta comparación se volvería a pedir todo.
    setFiltros((previo) =>
      previo.mercadoId === siguiente.mercadoId &&
      previo.rutaId === siguiente.rutaId &&
      previo.vendedorId === siguiente.vendedorId
        ? previo
        : siguiente,
    )
  }, [])

  // Las categorías que de verdad hay en la lista, con su letra y su nombre.
  const categorias = useMemo(
    () =>
      [...new Map((cartera?.items ?? []).filter((i) => i.categoriaCodigo).map((i) => [i.categoriaCodigo!, i.categoria])).entries()]
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([value, nombre]) => ({ value, label: `${value} · ${nombre}` })),
    [cartera],
  )

  const columns: DataTableColumn<ClienteCrm>[] = useMemo(
    () => [
      {
        key: 'cliente',
        label: 'Cliente',
        filterable: false,
        render: (row) => (
          <span className="flex flex-col">
            <span className="font-medium text-ink">{row.nombre}</span>
            <span className="text-xs text-ink-soft">
              {row.codigo} · {row.documento}
            </span>
          </span>
        ),
      },
      {
        key: 'mercado',
        label: 'Mercado',
        filterType: 'select',
        filterOptions: mercados.map((m) => ({ value: String(m.id), label: m.nombre })),
        value: (row) => String(row.mercadoId ?? ''),
        render: (row) => row.mercado ?? '—',
      },
      {
        key: 'ruta',
        label: 'Ruta',
        filterType: 'select',
        filterOptions: rutas.map((r) => ({ value: String(r.id), label: r.nombre })),
        value: (row) => String(row.rutaId ?? ''),
        render: (row) => row.ruta ?? '—',
      },
      {
        key: 'vendedor',
        label: 'Vendedor',
        filterType: 'select',
        filterOptions: usuarios.map((u) => ({ value: String(u.id), label: u.nombre })),
        value: (row) => String(row.vendedorId ?? ''),
        render: (row) => row.vendedor ?? '—',
      },
      {
        key: 'actual',
        label: 'Ahora',
        align: 'right',
        filterable: false,
        value: (row) => row.actual,
        render: (row) => soles(row.actual),
      },
      {
        key: 'anterior',
        label: 'Antes',
        align: 'right',
        filterable: false,
        value: (row) => row.anterior,
        render: (row) => <span className="text-ink-soft">{soles(row.anterior)}</span>,
      },
      {
        key: 'diferencia',
        label: 'Cambio',
        align: 'right',
        filterable: false,
        value: (row) => row.diferencia,
        render: (row) => (
          <span className={`flex flex-col items-end ${colorCambio(row.diferencia)}`}>
            <span className="font-semibold">{solesConSigno(row.diferencia)}</span>
            <span className="text-xs">{porcentaje(row.variacion)}</span>
          </span>
        ),
      },
      {
        key: 'nivel',
        label: 'Nivel',
        filterType: 'select',
        filterOptions: Object.entries(NIVELES).map(([value, { label }]) => ({ value, label })),
        value: (row) => row.nivel,
        render: (row) => <NivelBadge nivel={row.nivel} />,
      },
      {
        key: 'categoria',
        label: 'Categoría',
        filterType: 'select',
        filterOptions: categorias,
        value: (row) => row.categoriaCodigo ?? '',
        render: (row) => (
          <CategoriaBadge codigo={row.categoriaCodigo} nombre={row.categoria} color={row.categoriaColor} />
        ),
      },
      {
        key: 'ultimaCompra',
        label: 'Última compra',
        filterable: false,
        // Ordenar por días: el más dormido arriba o abajo, que es lo que se busca.
        value: (row) => row.diasSinComprar ?? Number.MAX_SAFE_INTEGER,
        render: (row) =>
          row.ultimaCompra ? (
            <span className="flex flex-col">
              <span>{fechaCorta(row.ultimaCompra)}</span>
              <span className={`text-xs ${row.inactivo ? 'text-red-600' : 'text-ink-soft'}`}>
                hace {row.diasSinComprar} {row.diasSinComprar === 1 ? 'día' : 'días'}
              </span>
            </span>
          ) : (
            <span className="text-ink-soft">Nunca</span>
          ),
      },
      {
        key: 'proximaAccion',
        label: 'Próxima acción',
        filterType: 'select',
        filterOptions: [
          { value: 'vencida', label: 'Vencida' },
          { value: 'pendiente', label: 'Pendiente' },
          { value: 'ninguna', label: 'Sin acción' },
        ],
        value: (row) => (row.accionVencida ? 'vencida' : row.proximaAccion ? 'pendiente' : 'ninguna'),
        render: (row) =>
          row.proximaAccion && row.proximaFecha ? (
            <span className="flex flex-col">
              <span>{row.proximaAccion}</span>
              <span className={`text-xs ${row.accionVencida ? 'text-red-600' : 'text-ink-soft'}`}>
                {row.accionVencida ? 'Vencida el ' : 'Para el '}
                {fechaCorta(row.proximaFecha)}
              </span>
            </span>
          ) : (
            <span className="text-ink-soft">—</span>
          ),
      },
      {
        key: 'saldo',
        label: 'Debe',
        align: 'right',
        filterable: false,
        value: (row) => row.saldoPorCobrar,
        render: (row) =>
          row.saldoPorCobrar > 0 ? soles(row.saldoPorCobrar) : <span className="text-ink-soft">—</span>,
      },
    ],
    [mercados, rutas, usuarios, categorias],
  )

  const resumen = cartera?.resumen
  const contra = PERIODOS.find((p) => p.id === periodo)?.contra

  return (
    <ListPage
      icon={<TrendingDown size={20} />}
      title="Cartera en riesgo"
      description="Clientes que compran menos que antes, de mayor a menor pérdida."
      alert={
        error ? (
          <Alert>{error}</Alert>
        ) : cartera?.soloPropios ? (
          <Alert tone="info">Ves solo los clientes de tus rutas y los que tienes asignados.</Alert>
        ) : undefined
      }
      banner={
        <div className="space-y-2">
          <Tabs
            items={PERIODOS.map((p) => ({ id: p.id, label: p.label }))}
            active={periodo}
            onChange={(id) => setPeriodo(id as PeriodoCrm)}
          />
          {cartera && (
            <p className="text-xs text-ink-soft">
              Del {rango(cartera.ventanas.actual)} frente a {contra} ({rango(cartera.ventanas.anterior)}).
              Ventas con IGV, sin anuladas ni recojos.
            </p>
          )}
        </div>
      }
      stats={
        <>
          <StatCard
            label="En riesgo"
            value={String((resumen?.criticos ?? 0) + (resumen?.altos ?? 0))}
            hint={`${resumen?.criticos ?? 0} críticos · ${resumen?.altos ?? 0} altos`}
            icon={<TriangleAlert size={18} />}
            tono="danger"
          />
          <StatCard
            label="Venta perdida"
            value={soles(resumen?.ventaPerdida ?? 0)}
            hint="solo de los que bajaron"
            icon={<TrendingDown size={18} />}
            tono="warning"
          />
          <StatCard
            label="Vendido en el periodo"
            value={soles(resumen?.actual ?? 0)}
            hint={resumen ? `antes ${soles(resumen.anterior)}` : undefined}
            trend={resumen?.variacion ?? undefined}
            icon={<Wallet size={18} />}
          />
          <StatCard
            label="Acciones vencidas"
            value={String(resumen?.accionesVencidas ?? 0)}
            hint="seguimientos que ya debieron hacerse"
            icon={<CalendarClock size={18} />}
            tono={resumen && resumen.accionesVencidas > 0 ? 'danger' : 'neutral'}
          />
          <StatCard
            label="Inactivos"
            value={String(resumen?.inactivos ?? 0)}
            hint={`más de ${cartera?.diasInactivo ?? 60} días sin comprar`}
            icon={<Clock size={18} />}
            tono="neutral"
          />
        </>
      }
      columns={columns}
      rows={cartera?.items ?? []}
      rowKey="clienteId"
      onConsulta={aplicar}
      onRowClick={(row) => setAbierto(row.clienteId)}
      cardIcon={TrendingDown}
      searchPlaceholder="Buscar cliente, documento..."
      empty={cargando ? 'Cargando cartera...' : 'No hay clientes con ventas en estos periodos.'}
      note="Nuevo: no compraba en el periodo anterior. Inactivo: sin ventas en ninguno de los dos periodos y con días sin comprar."
    >
      {abierto !== null && (
        <FichaClienteModal
          clienteId={abierto}
          periodo={periodo}
          onClose={() => setAbierto(null)}
          onCambio={cargar}
        />
      )}
    </ListPage>
  )
}
