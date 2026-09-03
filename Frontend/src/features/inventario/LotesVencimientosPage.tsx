import { useCallback, useEffect, useState } from 'react'
import { AlertTriangle, CalendarClock, PackageX } from 'lucide-react'
import { Alert, Badge, ListPage, StatCard } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { useRealtime } from '../../lib/realtime'
import { loteApi } from './inventarioApi'
import type { LoteResponse } from './inventarioApi'

/** Por debajo de esto se avisa "por vencer"; por encima, no se destaca. */
const DIAS_ALERTA = 30

/**
 * Lotes y vencimientos: todo lo que tiene fecha de vencimiento y todavía
 * tiene stock, lo más próximo primero.
 *
 * Es solo informativo — avisa, no bloquea. La decisión de vender o dar de
 * baja un lote vencido la toma la persona, normalmente con un ajuste de
 * motivo "Vencimiento".
 */
export function LotesVencimientosPage() {
  const [lotes, setLotes] = useState<LoteResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setLotes(await loteApi.getAll())
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los lotes.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime('stock', cargar)

  const vencidos = lotes.filter((l) => (l.diasParaVencer ?? 1) < 0)
  const porVencer = lotes.filter((l) => (l.diasParaVencer ?? Infinity) >= 0 && l.diasParaVencer! <= DIAS_ALERTA)

  const columns: DataTableColumn<LoteResponse>[] = [
    {
      key: 'producto',
      label: 'Producto',
      render: (row) => (
        <span>
          <span className="font-medium text-ink">{row.producto}</span>
          <span className="ml-2 text-xs text-ink-soft">{row.codigo}</span>
        </span>
      ),
    },
    { key: 'almacen', label: 'Almacén' },
    { key: 'lote', label: 'Lote', render: (row) => row.lote ?? '—' },
    {
      key: 'fechaVencimiento',
      label: 'Vence',
      render: (row) =>
        row.fechaVencimiento ? new Date(row.fechaVencimiento).toLocaleDateString('es-PE') : '—',
    },
    {
      key: 'diasParaVencer',
      label: 'Estado',
      value: (row) => row.diasParaVencer ?? 0,
      render: (row) => {
        const dias = row.diasParaVencer
        if (dias == null) return <Badge>Sin fecha</Badge>
        if (dias < 0) return <Badge tone="danger">Vencido hace {Math.abs(dias)} días</Badge>
        if (dias <= DIAS_ALERTA) return <Badge tone="warning">Vence en {dias} días</Badge>
        return <Badge tone="success">Vigente</Badge>
      },
    },
    {
      key: 'cantidadDisponible',
      label: 'Stock',
      align: 'right',
      render: (row) => `${row.cantidadDisponible} ${row.unidadBase}`,
    },
    {
      key: 'valor',
      label: 'Valorizado',
      align: 'right',
      render: (row) => `S/ ${row.valor.toFixed(2)}`,
    },
  ]

  return (
    <ListPage
      icon={<CalendarClock size={20} />}
      title="Lotes y vencimientos"
      description="Lo que tiene fecha de vencimiento y todavía tiene stock. Avisa, no bloquea: la baja se registra con un ajuste."
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Con vencimiento" value={String(lotes.length)} icon={<CalendarClock size={18} />} />
          <StatCard
            label="Por vencer"
            value={String(porVencer.length)}
            icon={<AlertTriangle size={18} />}
            tono="warning"
          />
          <StatCard
            label="Vencidos"
            value={String(vencidos.length)}
            icon={<PackageX size={18} />}
            tono="danger"
          />
        </>
      }
      columns={columns}
      rows={lotes}
      rowKey="capaId"
      cardIcon={CalendarClock}
      searchPlaceholder="Buscar por producto, lote, almacén..."
      empty={cargando ? 'Cargando lotes...' : 'No hay lotes con fecha de vencimiento registrados.'}
    />
  )
}
