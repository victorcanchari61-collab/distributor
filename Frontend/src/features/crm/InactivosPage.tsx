import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { MessageCircle, UserSearch, UserX } from 'lucide-react'
import { HBarChart, Marco, moneda } from '../../components/charts'
import { Alert, Input, PageHeader, RowAction, SysDataTable } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { useRealtime } from '../../lib/realtime'
import { CategoriaBadge } from './CategoriaBadge'
import { crmApi } from './crmApi'
import type { EstadoClave, FilaInactivo, Inactivos } from './crmApi'
import { whatsapp } from './contacto'
import { SelectorCatalogo, useCatalogosCrm } from './filtros'
import { ESCALA_DIAS, ESTADOS_UI, RANGO_DIAS, colorDeDias, fechaDia, nombreCorto, soles } from './formato'
import { ICONO_ESTADO } from './iconosEstado'
import { EtiquetaEstado, TarjetaReporte } from './piezas'

/** Los estados que tiene sentido ver aquí: quien compró hace menos de 16 días no está inactivo. */
const ESTADOS_INACTIVOS: EstadoClave[] = ['CRITICO', 'RIESGO', 'SEGUIMIENTO']

/**
 * Clientes inactivos: quienes compraron alguna vez pero llevan días sin hacerlo, por cuántos días. No compara años: mide
 * el silencio. Cada fila abre Gestión y seguimiento para llamar, escribir o programar la visita.
 */
export function InactivosPage() {
  const navegar = useNavigate()
  const { mercados, rutas, usuarios } = useCatalogosCrm()

  const [mercadoId, setMercadoId] = useState<number>()
  const [rutaId, setRutaId] = useState<number>()
  const [vendedorId, setVendedorId] = useState<number>()
  const [estado, setEstado] = useState<EstadoClave>()
  const [texto, setTexto] = useState('')
  const [buscar, setBuscar] = useState('')

  const [datos, setDatos] = useState<Inactivos | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    const espera = setTimeout(() => setBuscar(texto.trim()), 400)
    return () => clearTimeout(espera)
  }, [texto])

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setDatos(await crmApi.inactivos({ mercadoId, rutaId, vendedorId, estado, buscar }))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar el reporte.')
    } finally {
      setCargando(false)
    }
  }, [mercadoId, rutaId, vendedorId, estado, buscar])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['notasventa', 'clientes'], cargar)

  const gestionar = useCallback(
    (id: number) => navegar(`/crm/seguimiento?cliente=${id}&pestana=seguimiento`),
    [navegar],
  )

  const columnas: DataTableColumn<FilaInactivo>[] = useMemo(
    () => [
      {
        key: 'estado', width: 120,
        label: 'Estado',
        filterable: false,
        value: (r) => r.diasSinCompra,
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
            <span className="text-xs text-ink-soft">{[r.mercado, r.ruta].filter(Boolean).join(' · ') || 'Sin zona'}</span>
          </span>
        ),
      },
      { key: 'ultimaCompra', width: 130, label: 'Última compra', filterable: false, value: (r) => r.ultimaCompra, render: (r) => fechaDia(r.ultimaCompra) },
      {
        key: 'dias', width: 130,
        label: 'Días sin comprar',
        align: 'right',
        filterable: false,
        value: (r) => r.diasSinCompra,
        render: (r) => (
          <span className="font-bold tabular-nums" style={{ color: colorDeDias(r.diasSinCompra) }}>
            {r.diasSinCompra}
          </span>
        ),
      },
      { key: 'ventas', width: 150, label: 'Compró en 12 meses', align: 'right', filterable: false, value: (r) => r.ventas12m, render: (r) => soles(r.ventas12m) },
      { key: 'compras', width: 90, label: 'Compras', align: 'right', filterable: false, value: (r) => r.compras12m, render: (r) => r.compras12m },
      { key: 'ticket', width: 130, label: 'Ticket promedio', align: 'right', filterable: false, value: (r) => r.ticketPromedio, render: (r) => soles(r.ticketPromedio) },
    ],
    [],
  )

  const resumen = datos?.estados ?? []
  const items = datos?.items ?? []
  const mayores = useMemo(
    () => [...items].sort((a, b) => b.ventas12m - a.ventas12m).slice(0, 8),
    [items],
  )

  return (
    <div className="space-y-5">
      <PageHeader
        icon={<UserX size={20} />}
        title="Clientes inactivos"
        description="Clientes que compraron alguna vez y llevan días sin volver, para recuperarlos antes de perderlos."
      />

      {error && <Alert>{error}</Alert>}
      {datos?.soloPropios && <Alert tone="info">Ves solo los clientes de tus rutas y los que tienes asignados.</Alert>}

      <section className="rounded-panel border border-line bg-white p-4">
        <div className="flex flex-wrap items-end gap-x-5 gap-y-3">
          <SelectorCatalogo etiqueta="Mercado" todos="Todos" valor={mercadoId} opciones={mercados} onChange={setMercadoId} />
          <SelectorCatalogo etiqueta="Ruta" todos="Todas" valor={rutaId} opciones={rutas} onChange={setRutaId} />
          <SelectorCatalogo etiqueta="Vendedor" todos="Todos" valor={vendedorId} opciones={usuarios} onChange={setVendedorId} />
          <div className="min-w-56 flex-1">
            <Input label="Buscar" size="sm" placeholder="Cliente o documento..." value={texto} onChange={(e) => setTexto(e.target.value)} />
          </div>
        </div>
        <p className="mt-3 text-xs text-ink-soft">Días sin comprar: {ESCALA_DIAS}.</p>
      </section>

      <section className="grid gap-3 md:grid-cols-3">
        {ESTADOS_INACTIVOS.map((e) => {
          const ui = ESTADOS_UI[e]
          const fila = resumen.find((r) => r.estado === e)
          return (
            <TarjetaReporte
              key={e}
              titulo={ui.etiqueta}
              nota={RANGO_DIAS[e]}
              valor={fila?.clientes ?? 0}
              detalle={`${soles(fila?.monto ?? 0)} comprados en 12 meses`}
              icono={ICONO_ESTADO[e]}
              color={ui.color}
              activa={estado === e}
              onClick={() => setEstado(estado === e ? undefined : e)}
            />
          )
        })}
      </section>

      {datos && datos.nuncaCompraron > 0 && (
        <Alert tone="info">
          Hay {datos.nuncaCompraron} {datos.nuncaCompraron === 1 ? 'cliente activo que nunca compró' : 'clientes activos que nunca compraron'}: no
          aparecen aquí porque no hay una compra de la que contar los días.
        </Alert>
      )}

      <Marco
        titulo="Los inactivos que más compraban"
        subtitulo="Lo comprado en los últimos 12 meses: lo que se pierde si no vuelven"
        cargando={cargando && !datos}
        vacio={mayores.length === 0}
        mensajeVacio="No hay clientes inactivos con estos filtros"
        alto={168}
      >
        <HBarChart
          items={mayores.map((f) => ({
            nombre: f.cliente,
            valor: f.ventas12m,
            color: ESTADOS_UI[f.estado].color,
            detalle: `${f.diasSinCompra} días`,
          }))}
          formato={(n) => moneda(n)}
        />
      </Marco>

      <SysDataTable
        columns={columnas}
        rows={items}
        rowKey="id"
        toolbar={false}
        pageSize={15}
        cardIcon={UserX}
        empty={cargando ? 'Cargando clientes...' : 'No hay clientes inactivos con estos filtros.'}
        actionsWidth={96}
        actions={(r) => (
          <>
            <RowAction label="Gestionar" tone="view" onClick={() => gestionar(r.id)}>
              <UserSearch size={16} />
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
    </div>
  )
}
