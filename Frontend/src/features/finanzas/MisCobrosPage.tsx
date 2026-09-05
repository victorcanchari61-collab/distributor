import { useCallback, useEffect, useState } from 'react'
import { HandCoins } from 'lucide-react'
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
 * Si la venta se anula, el cobro también desaparece de aquí: solo se listan
 * pagos de notas de venta vigentes (no anuladas). Para acotar por fecha se usa
 * el filtro de la columna "Fecha", como en cualquier otra tabla del sistema.
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
      render: (row) => `S/ ${row.monto.toFixed(2)}`,
    },
  ]

  const totalCobrado = cobros.reduce((n, c) => n + c.monto, 0)

  return (
    <ListPage
      icon={<HandCoins size={20} />}
      title="Mis cobros"
      description="Los pagos que registraste de notas de venta vigentes. Si una venta se anula, su cobro desaparece de aquí."
      alert={error ? <Alert>{error}</Alert> : undefined}
      stats={
        <>
          <StatCard label="Cobros" value={String(cobros.length)} icon={<HandCoins size={18} />} />
          <StatCard
            label="Total cobrado"
            value={`S/ ${totalCobrado.toFixed(2)}`}
            icon={<HandCoins size={18} />}
            tono="success"
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
