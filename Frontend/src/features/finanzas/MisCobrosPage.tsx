import { useCallback, useEffect, useState } from 'react'
import { Ban, Coins, HandCoins, Wallet } from 'lucide-react'
import { Alert, Badge, ListPage, StatCard } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { useRealtime } from '../../lib/realtime'
import { notaVentaApi } from '../facturacion/ventasApi'
import type { CobroResponse } from '../facturacion/ventasApi'

/**
 * Los cobros que YO registré: cada pago de una nota de venta, visto desde
 * quién lo cobró en vez de desde el documento.
 *
 * Incluye los que después se anularon (marcados aquí mismo con su estado):
 * no desaparecen, para que quede el registro de qué se cobró y qué se corrigió
 * después. Solo los válidos cuentan para "Total cobrado". Para acotar por
 * fecha se usa el filtro de la columna "Fecha", como en cualquier otra tabla
 * del sistema.
 */
export function MisCobrosPage() {
  const [cobros, setCobros] = useState<CobroResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const cargar = useCallback(async () => {
    setCargando(true)
    try {
      setCobros(await notaVentaApi.misCobros())
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar tus cobros.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['notasventa'], cargar)

  const columns: DataTableColumn<CobroResponse>[] = [
    {
      key: 'fecha',
      label: 'Fecha',
      value: (row) => new Date(row.fecha).getTime(),
      render: (row) => new Date(row.fecha).toLocaleString('es-PE'),
    },
    { key: 'notaVentaNumero', label: 'Nota de venta', render: (row) => <Badge>{row.notaVentaNumero}</Badge> },
    { key: 'cliente', label: 'Cliente' },
    { key: 'metodoPago', label: 'Método' },
    {
      key: 'monto',
      label: 'Monto',
      align: 'right',
      value: (row) => row.monto,
      render: (row) =>
        row.anulado ? (
          <span className="text-ink-soft line-through">S/ {row.monto.toFixed(2)}</span>
        ) : (
          `S/ ${row.monto.toFixed(2)}`
        ),
    },
    {
      key: 'anulado',
      label: 'Estado',
      render: (row) => (row.anulado ? <Badge tone="danger">Anulado</Badge> : <Badge tone="success">Válido</Badge>),
    },
  ]

  const validos = cobros.filter((c) => !c.anulado)
  const anulados = cobros.filter((c) => c.anulado)
  const totalCobrado = validos.reduce((n, c) => n + c.monto, 0)
  const promedio = validos.length ? totalCobrado / validos.length : 0

  return (
    <ListPage
      icon={<HandCoins size={20} />}
      title="Mis cobros"
      description="Los pagos que registraste de notas de venta vigentes. Los anulados se conservan marcados, no desaparecen."
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Cobros válidos" value={String(validos.length)} icon={<HandCoins size={18} />} />
          <StatCard
            label="Total cobrado"
            value={`S/ ${totalCobrado.toFixed(2)}`}
            icon={<Wallet size={18} />}
            tono="success"
          />
          <StatCard
            label="Promedio por cobro"
            value={`S/ ${promedio.toFixed(2)}`}
            icon={<Coins size={18} />}
          />
          <StatCard
            label="Cobros anulados"
            value={String(anulados.length)}
            icon={<Ban size={18} />}
            tono={anulados.length > 0 ? 'warning' : undefined}
          />
        </>
      }
      columns={columns}
      rows={cobros}
      cardIcon={HandCoins}
      searchPlaceholder="Buscar por número, cliente..."
      empty={cargando ? 'Cargando tus cobros...' : 'Todavía no registraste cobros.'}
    />
  )
}
