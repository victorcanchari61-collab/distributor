import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { FileSpreadsheet, MessageCircle, PackageSearch, TrendingDown, UserSearch } from 'lucide-react'
import { DonutChart, HBarChart, Marco, moneda } from '../../components/charts'
import { Alert, Button, ListPage, Modal, RowAction } from '../../components/ui'
import type { ConsultaTabla, DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { exportarExcel } from '../../lib/excel'
import { hoyLocal } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { CategoriaBadge } from './CategoriaBadge'
import { crmApi } from './crmApi'
import type { CaidaClientes, EstadoClave, FilaCaida, QueDejoDeComprar } from './crmApi'
import { whatsapp } from './contacto'
import { inicioDeAnio, useCatalogosCrm } from './filtros'
import { ESTADOS_UI, ORDEN_ESTADOS, TRAMOS_INACTIVIDAD, colorCambio, colorDeDias, fechaDia, nombreCorto, porcentaje, soles, solesConSigno } from './formato'
import { ICONO_ESTADO } from './iconosEstado'
import { EtiquetaEstado, EtiquetaResultado, TarjetaReporte } from './piezas'
import { TablaProductos } from './seguimiento/TabCompras'

/** Lo que el panel de filtros decide que se pida al servidor. */
interface FiltrosCaida {
  desde: string
  hasta: string
  mercadoId?: number
  rutaId?: number
  vendedorId?: number
  /** Los que dejaron de comprar: id de un tramo de TRAMOS_INACTIVIDAD. Se aplica aquí: cada fila trae sus días. */
  sinComprar?: string
}

const mismos = (a: FiltrosCaida, b: FiltrosCaida) =>
  a.desde === b.desde &&
  a.hasta === b.hasta &&
  a.mercadoId === b.mercadoId &&
  a.rutaId === b.rutaId &&
  a.vendedorId === b.vendedorId &&
  a.sinComprar === b.sinComprar

/**
 * Clientes con caída: lo que compró cada cliente del 1 de enero a hoy (o el rango que se elija) contra el mismo tramo del
 * año anterior, y en qué estado está por cuánto cayó. Las tarjetas son filtros: tocar una deja solo esos clientes.
 * Desde cada fila se abre Gestión y seguimiento con el cliente ya elegido.
 */
export function CaidaPage() {
  const navegar = useNavigate()
  const { puede } = usePermisos()
  const { mercados, rutas, usuarios } = useCatalogosCrm()

  // Lo que decide qué se trae: lo dice el panel de filtros de la tabla, con los demás.
  const [desdeInicial] = useState(inicioDeAnio())
  const [hastaInicial] = useState(hoyLocal())
  const [filtros, setFiltros] = useState<FiltrosCaida>({ desde: desdeInicial, hasta: hastaInicial })
  const [estado, setEstado] = useState<EstadoClave>()
  const { desde, hasta, mercadoId, rutaId, vendedorId } = filtros

  const [datos, setDatos] = useState<CaidaClientes | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [productos, setProductos] = useState<QueDejoDeComprar | null>(null)
  const [cargandoProductos, setCargandoProductos] = useState(false)

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setDatos(await crmApi.caida({ desde, hasta, mercadoId, rutaId, vendedorId, estado }))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar el reporte.')
    } finally {
      setCargando(false)
    }
  }, [desde, hasta, mercadoId, rutaId, vendedorId, estado])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['notasventa', 'clientes', 'seguimientos', 'devoluciones'], cargar)

  /** Traduce el panel de filtros a lo que se pide al servidor. */
  const aplicar = useCallback(
    (q: ConsultaTabla) => {
      const valor = (columna: string) => q.filtros.find((f) => f.columna === columna)
      const fecha = valor('fecha')
      const siguiente: FiltrosCaida = {
        desde: fecha?.valor || desdeInicial,
        hasta: fecha?.valorHasta || fecha?.valor || hastaInicial,
        mercadoId: Number(valor('mercado')?.valor) || undefined,
        rutaId: Number(valor('ruta')?.valor) || undefined,
        vendedorId: Number(valor('vendedor')?.valor) || undefined,
        sinComprar: valor('sinComprar')?.valor || undefined,
      }
      // Cada tecla del buscador también llega aquí: sin esta comparación se volvería a pedir todo.
      setFiltros((previo) => (mismos(previo, siguiente) ? previo : siguiente))
    },
    [desdeInicial, hastaInicial],
  )

  const gestionar = useCallback(
    (id: number) => navegar(`/crm/seguimiento?cliente=${id}&pestana=seguimiento`),
    [navegar],
  )

  const verProductos = useCallback(
    async (fila: FilaCaida) => {
      setProductos({ clienteId: fila.id, cliente: fila.cliente, periodo: datos!.periodo, productos: [] })
      setCargandoProductos(true)
      try {
        setProductos(await crmApi.queDejoDeComprar(fila.id, { desde, hasta }))
      } catch (e) {
        setProductos(null)
        setError(e instanceof ApiError ? e.message : 'No pudimos cargar los productos.')
      } finally {
        setCargandoProductos(false)
      }
    },
    [datos, desde, hasta],
  )

  const columnas: DataTableColumn<FilaCaida>[] = useMemo(
    () => [
      // Estas cinco solo existen en el panel de Filtros: deciden qué se pide (ver SysDataTable).
      { key: 'fecha', label: 'Fechas', soloFiltro: true, filterType: 'date' },
      {
        key: 'mercado',
        label: 'Mercado',
        soloFiltro: true,
        filterType: 'select',
        filterOptions: mercados.map((m) => ({ value: String(m.id), label: m.nombre })),
      },
      {
        key: 'ruta',
        label: 'Ruta',
        soloFiltro: true,
        filterType: 'select',
        filterOptions: rutas.map((r) => ({ value: String(r.id), label: r.nombre })),
      },
      {
        key: 'vendedor',
        label: 'Vendedor',
        soloFiltro: true,
        filterType: 'select',
        filterOptions: usuarios.map((u) => ({ value: String(u.id), label: u.nombre })),
      },
      {
        key: 'sinComprar',
        label: 'Sin comprar hace',
        soloFiltro: true,
        filterType: 'select',
        filterOptions: TRAMOS_INACTIVIDAD.map((x) => ({ value: x.id, label: x.label })),
      },
      {
        key: 'estado', width: 120,
        label: 'Estado',
        filterable: false,
        value: (r) => ORDEN_ESTADOS.indexOf(r.estado),
        render: (r) => <EtiquetaEstado estado={r.estado} />,
      },
      {
        key: 'cliente', width: 270,
        label: 'Cliente',
        filterable: false,
        // Lo que busca el buscador de la tabla.
        value: (r) => `${r.cliente} ${r.documento} ${r.codigo} ${r.vendedor ?? ''} ${r.mercado ?? ''}`,
        render: (r) => (
          <span className="flex flex-col">
            <span className="font-medium text-ink">{r.cliente}</span>
            <span className="flex items-center gap-1.5 text-xs text-ink-soft">
              {r.codigo} · {r.documento}
              {r.categoriaCodigo && <CategoriaBadge codigo={r.categoriaCodigo} nombre={null} color={r.categoriaColor} />}
            </span>
          </span>
        ),
      },
      {
        key: 'vendedor', width: 170,
        label: 'Vendedor',
        filterable: false,
        render: (r) => (
          <span className="flex flex-col">
            <span>{r.vendedor ? nombreCorto(r.vendedor) : '—'}</span>
            <span className="text-xs text-ink-soft">{r.mercado ?? 'Sin mercado'}</span>
          </span>
        ),
      },
      {
        key: 'ultimaCompra', width: 130,
        label: 'Última compra',
        filterable: false,
        value: (r) => r.diasSinCompra ?? Number.MAX_SAFE_INTEGER,
        render: (r) =>
          r.ultimaCompra ? (
            <span className="flex flex-col">
              <span>{fechaDia(r.ultimaCompra)}</span>
              <span className="text-xs font-medium" style={{ color: colorDeDias(r.diasSinCompra) }}>
                hace {r.diasSinCompra} días
              </span>
            </span>
          ) : (
            <span className="text-ink-soft">Nunca</span>
          ),
      },
      {
        key: 'ventas', width: 130,
        label: 'Venta',
        align: 'right',
        filterable: false,
        value: (r) => r.ventaActual,
        render: (r) => (
          <span className="flex flex-col items-end">
            <span className="font-medium">{soles(r.ventaActual)}</span>
            <span className="text-xs text-ink-soft">antes {soles(r.ventaAnterior)}</span>
          </span>
        ),
      },
      {
        key: 'variacion', width: 130,
        label: 'Variación',
        align: 'right',
        filterable: false,
        value: (r) => r.caidaPct ?? -999,
        render: (r) => (
          <span className={`flex flex-col items-end ${colorCambio(r.variacion)}`}>
            <span className="font-semibold">{solesConSigno(r.variacion)}</span>
            <span className="text-xs">{r.caidaPct === null ? 'Sin comparación' : porcentaje(-r.caidaPct)}</span>
          </span>
        ),
      },
      {
        key: 'riesgo', width: 130,
        label: 'Monto en riesgo',
        align: 'right',
        filterable: false,
        value: (r) => r.montoRiesgo,
        render: (r) => (r.montoRiesgo > 0 ? <span className="font-semibold text-red-600">{soles(r.montoRiesgo)}</span> : '—'),
      },
      {
        key: 'gestion', width: 180,
        label: 'Última gestión',
        filterable: false,
        render: (r) =>
          r.gestionEtiqueta && r.gestionTono ? (
            <span className="flex flex-col items-start gap-0.5">
              <EtiquetaResultado tono={r.gestionTono} texto={r.gestionEtiqueta} />
              {r.proximoSeguimiento && (
                <span className={`text-[11px] ${r.seguimientoVencido ? 'font-semibold text-red-600' : 'text-ink-soft'}`}>
                  {r.seguimientoVencido ? 'Vencido' : 'Próximo'}: {fechaDia(r.proximoSeguimiento)}
                </span>
              )}
            </span>
          ) : (
            <span className="text-ink-soft">Sin gestiones</span>
          ),
      },
    ],
    [mercados, rutas, usuarios],
  )

  const resumen = datos?.estados ?? []
  const tramo = TRAMOS_INACTIVIDAD.find((x) => x.id === filtros.sinComprar)
  const items = useMemo(
    () =>
      (datos?.items ?? []).filter(
        (f) =>
          !tramo ||
          (f.diasSinCompra !== null && f.diasSinCompra >= tramo.desde && (tramo.hasta === null || f.diasSinCompra <= tramo.hasta)),
      ),
    [datos, tramo],
  )
  const mayores = useMemo(
    () => [...items].filter((f) => f.montoRiesgo > 0).sort((a, b) => b.montoRiesgo - a.montoRiesgo).slice(0, 8),
    [items],
  )

  /** Lo que se ve en la tabla (con sus filtros y la tarjeta elegida), en un Excel. */
  const exportar = () =>
    exportarExcel(
      `clientes-con-caida-${filtros.desde}_${filtros.hasta}`,
      items.map((f) => ({
        Estado: ESTADOS_UI[f.estado].etiqueta,
        Código: f.codigo,
        Cliente: f.cliente,
        Documento: f.documento,
        Teléfono: f.telefono,
        Vendedor: f.vendedor,
        Mercado: f.mercado,
        Ruta: f.ruta,
        Categoría: f.categoria,
        'Última compra': f.ultimaCompra ? f.ultimaCompra.slice(0, 10) : null,
        'Días sin comprar': f.diasSinCompra,
        'Venta anterior': f.ventaAnterior,
        'Venta actual': f.ventaActual,
        Variación: f.variacion,
        '% Caída': f.caidaPct === null ? null : Math.round(f.caidaPct * 10) / 10,
        'Monto en riesgo': f.montoRiesgo,
        'Saldo por cobrar': f.saldoPorCobrar,
        'Última gestión': f.gestionEtiqueta,
        'Próximo seguimiento': f.proximoSeguimiento ? f.proximoSeguimiento.slice(0, 10) : null,
      })),
    )

  return (
    <ListPage
      icon={<TrendingDown size={20} />}
      title="Clientes con caída"
      description="Cuánto compra cada cliente frente al mismo tramo del año anterior, y en qué estado está. También sirve para encontrar a los que dejaron de comprar."
      actions={
        puede('crm.caida', 'exportar') ? (
          <Button variant="secondary" size="sm" disabled={items.length === 0} onClick={exportar} iconRight={<FileSpreadsheet size={15} />}>
            Exportar Excel
          </Button>
        ) : undefined
      }
      alert={
        error ? (
          <Alert>{error}</Alert>
        ) : datos?.soloPropios ? (
          <Alert tone="info">Ves solo los clientes de tus rutas y los que tienes asignados.</Alert>
        ) : undefined
      }
      banner={
        <div className="space-y-4">
          {datos && (
            <p className="text-xs text-ink-soft">
              Del {datos.periodo.etiqueta} frente al {datos.periodo.etiquetaAnterior}. Ventas con IGV, sin anuladas ni recojos. Las fechas, el
              mercado, la ruta, el vendedor y los días sin comprar se eligen en el ícono de filtros de la tabla.
            </p>
          )}

          {/* Una tarjeta por estado: son filtros. */}
          <section className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
            {ORDEN_ESTADOS.map((e) => {
              const ui = ESTADOS_UI[e]
              const fila = resumen.find((r) => r.estado === e)
              return (
                <TarjetaReporte
                  key={e}
                  titulo={ui.etiqueta}
                  nota={ui.rango}
                  valor={fila?.clientes ?? 0}
                  detalle={
                    e === 'SIN_BASE' ? 'no compraron el año anterior' : e === 'NORMAL' ? `compran igual o casi` : `${soles(fila?.monto ?? 0)} en riesgo`
                  }
                  icono={ICONO_ESTADO[e]}
                  color={ui.color}
                  activa={estado === e}
                  onClick={() => setEstado(estado === e ? undefined : e)}
                />
              )
            })}
          </section>

          <section className="grid gap-4 lg:grid-cols-2">
            <Marco
              titulo="Clientes por estado"
              subtitulo={datos ? `${soles(datos.ventaActual)} vendidos frente a ${soles(datos.ventaAnterior)} el año anterior` : undefined}
              cargando={cargando && !datos}
              vacio={!!datos && resumen.every((r) => r.clientes === 0)}
              mensajeVacio="No hay clientes con ventas en este tramo"
              alto={168}
            >
              <DonutChart
                porciones={ORDEN_ESTADOS.filter((e) => (resumen.find((r) => r.estado === e)?.clientes ?? 0) > 0).map((e) => ({
                  nombre: ESTADOS_UI[e].etiqueta,
                  valor: resumen.find((r) => r.estado === e)?.clientes ?? 0,
                  color: ESTADOS_UI[e].color,
                }))}
                formato={(n) => `${n} ${n === 1 ? 'cliente' : 'clientes'}`}
                centro={{ titulo: 'Clientes', valor: String(resumen.reduce((s, r) => s + r.clientes, 0)) }}
              />
            </Marco>

            <Marco
              titulo="Dónde está el mayor monto en riesgo"
              subtitulo="Lo que dejaron de comprar los clientes que más bajaron"
              cargando={cargando && !datos}
              vacio={mayores.length === 0}
              mensajeVacio="Ningún cliente bajó en este tramo"
              alto={168}
            >
              <HBarChart
                items={mayores.map((f) => ({ nombre: f.cliente, valor: f.montoRiesgo, color: ESTADOS_UI[f.estado].color, detalle: ESTADOS_UI[f.estado].etiqueta }))}
                formato={(n) => moneda(n)}
              />
            </Marco>
          </section>
        </div>
      }
      columns={columnas}
      rows={items}
      rowKey="id"
      onConsulta={aplicar}
      filtrosIniciales={[{ column: 'fecha', operator: 'between', value: desdeInicial, valueTo: hastaInicial }]}
      pageSize={15}
      cardIcon={TrendingDown}
      searchPlaceholder="Buscar cliente, documento o vendedor..."
      empty={cargando ? 'Cargando clientes...' : 'No hay clientes con ventas en este tramo.'}
      actionsWidth={120}
      rowActions={(r) => (
        <>
          <RowAction label="Gestionar" tone="view" onClick={() => gestionar(r.id)}>
            <UserSearch size={16} />
          </RowAction>
          <RowAction label="Qué dejó de comprar" tone="warning" onClick={() => void verProductos(r)}>
            <PackageSearch size={16} />
          </RowAction>
          {r.telefono && (
            <a
              href={`https://wa.me/${whatsapp(r.telefono)}`}
              target="_blank"
              rel="noreferrer"
              title="WhatsApp"
              aria-label="WhatsApp"
              className="inline-flex rounded-md p-1.5 text-emerald-600 transition-colors hover:bg-emerald-50"
            >
              <MessageCircle size={16} />
            </a>
          )}
        </>
      )}
    >
      <Modal
        open={productos !== null}
        size="xl"
        title={productos ? `Qué dejó de comprar · ${productos.cliente}` : ''}
        description={productos ? `${productos.periodo.etiqueta} frente a ${productos.periodo.etiquetaAnterior}` : undefined}
        onClose={() => setProductos(null)}
      >
        {productos &&
          (cargandoProductos ? (
            <p className="py-10 text-center text-sm text-ink-soft">Cargando productos...</p>
          ) : (
            <TablaProductos
              productos={productos.productos}
              anterior={productos.periodo.anterior.hasta.slice(0, 4)}
              actual={productos.periodo.actual.hasta.slice(0, 4)}
            />
          ))}
      </Modal>
    </ListPage>
  )
}
