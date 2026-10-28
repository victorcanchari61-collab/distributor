import { useEffect, useMemo, useState } from 'react'
import { ArrowDown, ArrowUp, Minus, Plus } from 'lucide-react'
import { Alert, Badge, SysDataTable } from '../../../components/ui'
import type { DataTableColumn } from '../../../components/ui'
import { ApiError } from '../../../lib/apiClient'
import { fechaCorta } from '../../../lib/fechas'
import { crmApi } from '../crmApi'
import type { ComprasCliente, SituacionProducto, SituacionProductoFila } from '../crmApi'
import { colorCambio, porcentaje, soles, solesConSigno } from '../formato'
import { TarjetaReporte } from '../piezas'

/** Qué le pasó a un producto del cliente entre los dos tramos. */
export const SITUACION: Record<SituacionProducto, { etiqueta: string; color: string; fondo: string }> = {
  DEJO: { etiqueta: 'Dejó de comprar', color: '#dc2626', fondo: '#fef2f2' },
  NUEVO: { etiqueta: 'Nueva compra', color: '#2563eb', fondo: '#eff6ff' },
  IGUAL: { etiqueta: 'Sin variación', color: '#64748b', fondo: '#f1f5f9' },
  MAS: { etiqueta: 'Incrementó compra', color: '#16a34a', fondo: '#f0fdf4' },
  MENOS: { etiqueta: 'Redujo compra', color: '#ea580c', fondo: '#fff7ed' },
}

const TONO_ESTADO: Record<string, 'success' | 'danger' | 'neutral'> = { CONFIRMADA: 'success', ANULADA: 'danger' }

/** La etiqueta de color de la situación de un producto. */
export function EtiquetaSituacion({ situacion }: { situacion: SituacionProducto }) {
  const ui = SITUACION[situacion]
  return (
    <span className="inline-flex rounded-md px-2 py-0.5 text-xs font-semibold whitespace-nowrap" style={{ color: ui.color, backgroundColor: ui.fondo }}>
      {ui.etiqueta}
    </span>
  )
}

/** La tabla de qué compraba y qué compra el cliente, producto por producto. Sirve en la ficha y en la ventana del reporte. */
export function TablaProductos({ productos, anterior, actual }: { productos: SituacionProductoFila[]; anterior: string; actual: string }) {
  const columnas: DataTableColumn<SituacionProductoFila>[] = useMemo(
    () => [
      {
        key: 'producto',
        label: 'Producto',
        filterable: false,
        render: (r) => (
          <span className="flex flex-col">
            <span className="font-medium text-ink">{r.producto}</span>
            <span className="text-xs text-ink-soft">{r.codigo}</span>
          </span>
        ),
      },
      { key: 'anterior', label: `Ventas ${anterior}`, align: 'right', filterable: false, value: (r) => r.ventaAnterior, render: (r) => soles(r.ventaAnterior) },
      { key: 'actual', label: `Ventas ${actual}`, align: 'right', filterable: false, value: (r) => r.ventaActual, render: (r) => soles(r.ventaActual) },
      {
        key: 'variacion',
        label: 'Variación',
        align: 'right',
        filterable: false,
        value: (r) => r.variacion,
        render: (r) => <span className={`font-semibold ${colorCambio(r.variacion)}`}>{solesConSigno(r.variacion)}</span>,
      },
      {
        key: 'situacion',
        label: 'Situación',
        filterType: 'select',
        filterOptions: Object.entries(SITUACION).map(([value, { etiqueta }]) => ({ value, label: etiqueta })),
        value: (r) => r.situacion,
        render: (r) => <EtiquetaSituacion situacion={r.situacion} />,
      },
    ],
    [anterior, actual],
  )

  return (
    <SysDataTable
      columns={columnas}
      rows={productos}
      rowKey="productoId"
      toolbar={false}
      pageSize={8}
      empty="El cliente no compró productos en estos tramos."
    />
  )
}

/**
 * La pestaña Compras: las ventas del año contra el año anterior, qué productos dejó de comprar o compra menos y las
 * últimas ventas con lo que debe de cada una.
 */
export function TabCompras({ clienteId }: { clienteId: number }) {
  const [datos, setDatos] = useState<ComprasCliente | null>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    let vigente = true
    setDatos(null)
    crmApi
      .compras(clienteId)
      .then((d) => vigente && setDatos(d))
      .catch((e) => vigente && setError(e instanceof ApiError ? e.message : 'No pudimos cargar las compras.'))
    return () => {
      vigente = false
    }
  }, [clienteId])

  if (error) return <Alert>{error}</Alert>
  if (!datos) return <p className="py-10 text-center text-sm text-ink-soft">Cargando compras...</p>

  const { periodo } = datos
  const cambio = periodo.caidaPct === null ? null : -periodo.caidaPct
  const anioActual = periodo.desde.slice(0, 4)
  const anioAnterior = String(Number(anioActual) - 1)

  const resumen = {
    dejo: datos.productos.filter((p) => p.situacion === 'DEJO').length,
    menos: datos.productos.filter((p) => p.situacion === 'MENOS').length,
    mas: datos.productos.filter((p) => p.situacion === 'MAS').length,
    nuevo: datos.productos.filter((p) => p.situacion === 'NUEVO').length,
  }

  return (
    <div className="space-y-4">
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <TarjetaReporte titulo={`Ventas ${anioAnterior}`} nota={periodo.etiquetaAnterior} valor={soles(periodo.ventasAnterior)} detalle="mismo tramo del año anterior" icono={Minus} color="#64748b" />
        <TarjetaReporte titulo={`Ventas ${anioActual}`} nota={periodo.etiqueta} valor={soles(periodo.ventas)} detalle="del 1 de enero a hoy" icono={Plus} color="#2563eb" />
        <TarjetaReporte
          titulo="Contra el año anterior"
          valor={cambio === null ? '—' : porcentaje(cambio)}
          detalle={cambio === null ? 'no compró entonces' : `antes: ${soles(periodo.ventasAnterior)}`}
          icono={cambio !== null && cambio < 0 ? ArrowDown : ArrowUp}
          color={cambio === null ? '#64748b' : cambio < 0 ? '#dc2626' : '#16a34a'}
        />
        <TarjetaReporte
          titulo="Productos"
          valor={`${resumen.dejo} dejó · ${resumen.menos} menos`}
          detalle={`${resumen.mas} compra más · ${resumen.nuevo} nuevos`}
          icono={ArrowDown}
          color="#ea580c"
        />
      </div>

      <section className="space-y-2">
        <h3 className="text-sm font-semibold text-ink">Qué compra y qué dejó de comprar</h3>
        <TablaProductos productos={datos.productos} anterior={anioAnterior} actual={anioActual} />
      </section>

      <section className="space-y-2">
        <h3 className="text-sm font-semibold text-ink">Últimas ventas</h3>
        <SysDataTable
          columns={[
            { key: 'fecha', label: 'Fecha', filterable: false, value: (r) => new Date(r.fecha).getTime(), render: (r) => fechaCorta(r.fecha) },
            { key: 'numero', label: 'Nota', filterable: false, render: (r) => <span className="font-medium">{r.numero}</span> },
            { key: 'formaPago', label: 'Pago', filterable: false, render: (r) => (r.formaPago === 'CREDITO' ? 'Crédito' : 'Contado') },
            {
              key: 'estado',
              label: 'Estado',
              filterable: false,
              render: (r) => <Badge tone={TONO_ESTADO[r.estado] ?? 'neutral'}>{r.estado.charAt(0) + r.estado.slice(1).toLowerCase()}</Badge>,
            },
            { key: 'vendedor', label: 'Vendedor', filterable: false, render: (r) => r.vendedor ?? '—' },
            { key: 'total', label: 'Total', align: 'right', filterable: false, value: (r) => r.total, render: (r) => soles(r.total, 2) },
            {
              key: 'saldo',
              label: 'Debe',
              align: 'right',
              filterable: false,
              value: (r) => r.saldo,
              render: (r) => (r.saldo > 0 ? <span className="text-red-600">{soles(r.saldo, 2)}</span> : '—'),
            },
          ]}
          rows={datos.ventas}
          rowKey="notaVentaId"
          toolbar={false}
          pageSize={8}
          empty="Este cliente no tiene ventas."
        />
      </section>
    </div>
  )
}
