import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { MessageCircle, PackageSearch, TrendingDown, UserSearch } from 'lucide-react'
import { DonutChart, HBarChart, Marco, moneda } from '../../components/charts'
import { Alert, Input, Modal, PageHeader, RowAction, Select, SysDataTable } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { hoyLocal } from '../../lib/fechas'
import { useRealtime } from '../../lib/realtime'
import { CategoriaBadge } from './CategoriaBadge'
import { crmApi } from './crmApi'
import type { CaidaClientes, EstadoClave, FilaCaida, QueDejoDeComprar } from './crmApi'
import { whatsapp } from './contacto'
import { FiltroFechas, SelectorCatalogo, inicioDeAnio, useCatalogosCrm } from './filtros'
import { ESTADOS_UI, ORDEN_ESTADOS, TRAMOS_INACTIVIDAD, colorCambio, colorDeDias, fechaDia, nombreCorto, porcentaje, soles, solesConSigno } from './formato'
import { ICONO_ESTADO } from './iconosEstado'
import { EtiquetaEstado, EtiquetaResultado, TarjetaReporte } from './piezas'
import { TablaProductos } from './seguimiento/TabCompras'

/**
 * Clientes con caída: lo que compró cada cliente del 1 de enero a hoy (o el rango que se elija) contra el mismo tramo del
 * año anterior, y en qué estado está por cuánto cayó. Las tarjetas son filtros: tocar una deja solo esos clientes.
 * Desde cada fila se abre Gestión y seguimiento con el cliente ya elegido.
 */
export function CaidaPage() {
  const navegar = useNavigate()
  const { mercados, rutas, usuarios } = useCatalogosCrm()

  const [desde, setDesde] = useState(inicioDeAnio())
  const [hasta, setHasta] = useState(hoyLocal())
  const [mercadoId, setMercadoId] = useState<number>()
  const [rutaId, setRutaId] = useState<number>()
  const [vendedorId, setVendedorId] = useState<number>()
  const [estado, setEstado] = useState<EstadoClave>()
  const [texto, setTexto] = useState('')
  const [buscar, setBuscar] = useState('')
  // Los que dejaron de comprar: por cuántos días llevan sin hacerlo. Se acota aquí porque cada fila ya trae sus días.
  const [inactividad, setInactividad] = useState('')

  const [datos, setDatos] = useState<CaidaClientes | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [productos, setProductos] = useState<QueDejoDeComprar | null>(null)
  const [cargandoProductos, setCargandoProductos] = useState(false)

  // La búsqueda espera a que se deje de escribir.
  useEffect(() => {
    const espera = setTimeout(() => setBuscar(texto.trim()), 400)
    return () => clearTimeout(espera)
  }, [texto])

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setDatos(await crmApi.caida({ desde, hasta, mercadoId, rutaId, vendedorId, estado, buscar }))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar el reporte.')
    } finally {
      setCargando(false)
    }
  }, [desde, hasta, mercadoId, rutaId, vendedorId, estado, buscar])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['notasventa', 'clientes', 'seguimientos', 'devoluciones'], cargar)

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
    [],
  )

  const resumen = datos?.estados ?? []
  const tramo = TRAMOS_INACTIVIDAD.find((x) => x.id === inactividad)
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

  return (
    <div className="space-y-5">
      <PageHeader
        icon={<TrendingDown size={20} />}
        title="Clientes con caída"
        description="Cuánto compra cada cliente frente al mismo tramo del año anterior, y en qué estado está. También sirve para encontrar a los que dejaron de comprar."
      />

      {error && <Alert>{error}</Alert>}
      {datos?.soloPropios && <Alert tone="info">Ves solo los clientes de tus rutas y los que tienes asignados.</Alert>}

      {/* Qué se mide y con qué se acota. */}
      <section className="rounded-panel border border-line bg-white p-4">
        <div className="flex flex-wrap items-end gap-x-5 gap-y-3">
          <FiltroFechas desde={desde} hasta={hasta} onChange={(d, h) => { setDesde(d); setHasta(h) }} />
          <SelectorCatalogo etiqueta="Mercado" todos="Todos" valor={mercadoId} opciones={mercados} onChange={setMercadoId} />
          <SelectorCatalogo etiqueta="Ruta" todos="Todas" valor={rutaId} opciones={rutas} onChange={setRutaId} />
          <SelectorCatalogo etiqueta="Vendedor" todos="Todos" valor={vendedorId} opciones={usuarios} onChange={setVendedorId} />
          <div className="w-44">
            <Select label="Sin comprar hace" size="sm" value={inactividad} onChange={(e) => setInactividad(e.target.value)}>
              <option value="">Cualquiera</option>
              {TRAMOS_INACTIVIDAD.map((x) => (
                <option key={x.id} value={x.id}>
                  {x.label}
                </option>
              ))}
            </Select>
          </div>
          <div className="min-w-56 flex-1">
            <Input label="Buscar" size="sm" placeholder="Cliente o documento..." value={texto} onChange={(e) => setTexto(e.target.value)} />
          </div>
        </div>
        {datos && (
          <p className="mt-3 text-xs text-ink-soft">
            Del {datos.periodo.etiqueta} frente al {datos.periodo.etiquetaAnterior}. Ventas con IGV, sin anuladas ni recojos.
          </p>
        )}
      </section>

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

      <SysDataTable
        columns={columnas}
        rows={items}
        rowKey="id"
        toolbar={false}
        pageSize={15}
        cardIcon={TrendingDown}
        empty={cargando ? 'Cargando clientes...' : 'No hay clientes con ventas en este tramo.'}
        actionsWidth={120}
        actions={(r) => (
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
      />

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
    </div>
  )
}
