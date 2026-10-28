import { useCallback, useEffect, useMemo, useState } from 'react'
import { ArrowDown, ArrowUp, Award, Minus, Settings2 } from 'lucide-react'
import { Alert, Badge, Button, PageHeader, SysDataTable } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta } from '../../lib/fechas'
import { ACCION, usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { CategoriaBadge } from './CategoriaBadge'
import { categorizacionApi } from './categorizacionApi'
import type { Categorizacion, ClienteCategorizado } from './categorizacionApi'
import { soles } from './formato'
import { ModalCategorizacion } from './ModalCategorizacion'

const SUBMODULO = 'crm.categorizacion'

const MOVIMIENTOS = {
  SUBE: { icono: <ArrowUp size={13} />, label: 'Sube', tono: 'success' as const },
  BAJA: { icono: <ArrowDown size={13} />, label: 'Baja', tono: 'danger' as const },
  IGUAL: { icono: <Minus size={13} />, label: 'Igual', tono: 'neutral' as const },
  NUEVO: { icono: null, label: 'Nuevo', tono: 'sys' as const },
}

/**
 * Clientes por categoría: cómo quedó cada cliente en el último cálculo (Socio, Distribuidor, Mayorista...)
 * y si subió o bajó frente al ciclo anterior.
 *
 * Los tramos y el ciclo no se tocan aquí: se ajustan en la ventana «Categorización de clientes», que es la
 * misma que se abre desde Clientes. Esta pantalla es para mirar el resultado.
 */
export function CategorizacionPage() {
  const { puede } = usePermisos()
  const puedeEditar = puede(SUBMODULO, ACCION.editar)

  const [datos, setDatos] = useState<Categorizacion | null>(null)
  const [clientes, setClientes] = useState<ClienteCategorizado[]>([])
  const [error, setError] = useState('')
  const [cargando, setCargando] = useState(true)
  const [abierta, setAbierta] = useState(false)

  const cargar = useCallback(async () => {
    try {
      const [config, lista] = await Promise.all([categorizacionApi.obtener(), categorizacionApi.clientes()])
      setDatos(config)
      setClientes(lista)
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar la categorización.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['categorizacion', 'clientes'], cargar)

  const categoriaDe = useCallback((codigo: string) => datos?.categorias.find((c) => c.codigo === codigo), [datos])

  const columnas: DataTableColumn<ClienteCategorizado>[] = useMemo(
    () => [
      {
        key: 'cliente',
        label: 'Cliente',
        filterable: false,
        render: (r) => (
          <span className="flex flex-col">
            <span className="font-medium text-ink">{r.nombre}</span>
            <span className="text-xs text-ink-soft">
              {r.codigo} · {r.documento}
            </span>
          </span>
        ),
      },
      {
        key: 'mercado',
        label: 'Mercado',
        filterType: 'select',
        filterOptions: opciones(clientes.map((c) => c.mercado)),
        value: (r) => r.mercado ?? '',
        render: (r) => r.mercado ?? '—',
      },
      {
        key: 'ruta',
        label: 'Ruta',
        filterType: 'select',
        filterOptions: opciones(clientes.map((c) => c.ruta)),
        value: (r) => r.ruta ?? '',
        render: (r) => r.ruta ?? '—',
      },
      {
        key: 'monto',
        label: 'Compró en el ciclo',
        align: 'right',
        filterable: false,
        value: (r) => r.monto,
        render: (r) => soles(r.monto),
      },
      {
        key: 'categoria',
        label: 'Categoría',
        filterType: 'select',
        filterOptions: (datos?.categorias ?? []).map((c) => ({ value: c.codigo, label: `${c.codigo} · ${c.nombre}` })),
        value: (r) => r.categoria,
        render: (r) => {
          const c = categoriaDe(r.categoria)
          return <CategoriaBadge codigo={r.categoria} nombre={c?.nombre} color={c?.color} />
        },
      },
      {
        key: 'movimiento',
        label: 'Frente al ciclo anterior',
        filterType: 'select',
        filterOptions: Object.entries(MOVIMIENTOS).map(([value, { label }]) => ({ value, label })),
        value: (r) => r.movimiento,
        render: (r) => {
          if (!r.movimiento) return <span className="text-ink-soft">—</span>
          const m = MOVIMIENTOS[r.movimiento]
          return (
            <span className="flex items-center gap-2">
              <Badge tone={m.tono}>
                <span className="mr-1 inline-flex">{m.icono}</span>
                {m.label}
              </Badge>
              {r.categoriaAnterior && r.movimiento !== 'IGUAL' && (
                <span className="text-xs text-ink-soft">antes {r.categoriaAnterior}</span>
              )}
            </span>
          )
        },
      },
    ],
    [clientes, datos, categoriaDe],
  )

  const vigente = datos?.vigente

  return (
    <div className="space-y-5">
      <PageHeader
        icon={<Award size={20} />}
        title="Categorización de clientes"
        description="Cada cliente tiene la categoría que le toca por lo que compró en el ciclo anterior."
        actions={
          <Button size="sm" variant={puedeEditar ? 'primary' : 'secondary'} onClick={() => setAbierta(true)}>
            <Settings2 size={15} />
            {puedeEditar ? 'Configurar categorías' : 'Ver categorías'}
          </Button>
        }
      />

      {error && <Alert>{error}</Alert>}

      {datos && !vigente && (
        <Alert tone="warning">
          Todavía no se calculó ninguna categoría.
          {puedeEditar
            ? ' Abre «Configurar categorías», revisa los montos y pulsa «Calcular ahora»: desde ahí se actualizan solas cuando empieza un ciclo nuevo.'
            : ' Cuando se calculen, las verás aquí y en la lista de clientes.'}
        </Alert>
      )}
      {vigente?.vencido && (
        <Alert tone="warning">
          El último cálculo rigió hasta el {fechaCorta(vigente.ventana.vigenteHasta)} y todavía no se actualizó.
          {puedeEditar && ' Pulsa «Calcular ahora» en Configurar categorías si no se hizo solo.'}
        </Alert>
      )}
      {datos?.cicloDistinto && (
        <Alert tone="info">
          El ciclo guardado es distinto al del último cálculo: las categorías actuales siguen siendo las de ese cálculo
          hasta que se calcule de nuevo.
        </Alert>
      )}

      {datos && vigente && (
        <div className="flex flex-wrap gap-2">
          {datos.categorias.map((c) => (
            <span key={c.codigo} className="inline-flex items-center gap-2 rounded-field border border-line bg-white px-3 py-1.5 text-sm">
              <CategoriaBadge codigo={c.codigo} nombre={c.nombre} color={c.color} />
              <span className="font-semibold text-ink">{c.clientes}</span>
              <span className="text-xs text-ink-soft">{c.clientes === 1 ? 'cliente' : 'clientes'}</span>
            </span>
          ))}
        </div>
      )}

      <section className="space-y-2">
        <h2 className="text-sm font-semibold text-ink">
          Clientes por categoría
          {vigente && (
            <span className="ml-2 font-normal text-ink-soft">
              compras del {fechaCorta(vigente.ventana.evaluadoDesde)} al {fechaCorta(vigente.ventana.evaluadoHasta)} ·
              rige hasta el {fechaCorta(vigente.ventana.vigenteHasta)}
            </span>
          )}
        </h2>
        <SysDataTable
          columns={columnas}
          rows={clientes}
          rowKey="clienteId"
          searchPlaceholder="Buscar cliente, documento..."
          cardIcon={Award}
          empty={
            cargando
              ? 'Cargando clientes...'
              : vigente
                ? 'No hay clientes en este cálculo.'
                : 'Calcula las categorías para ver los clientes.'
          }
        />
      </section>

      <ModalCategorizacion open={abierta} onClose={() => setAbierta(false)} onCambio={() => void cargar()} />
    </div>
  )
}

/** Las opciones distintas de una lista de textos, sin vacíos y en orden alfabético. */
function opciones(valores: (string | null)[]) {
  return [...new Set(valores.filter((v): v is string => !!v))]
    .sort((a, b) => a.localeCompare(b, 'es'))
    .map((v) => ({ value: v, label: v }))
}
