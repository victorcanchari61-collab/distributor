import { useCallback, useEffect, useState } from 'react'
import { Calendar, HandCoins } from 'lucide-react'
import { Alert, Badge, Button, Input, ListPage, StatCard } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { useRealtime } from '../../lib/realtime'
import { notaVentaApi } from '../facturacion/ventasApi'
import type { CobroResponse } from '../facturacion/ventasApi'

function hoyISO() {
  return new Date().toISOString().slice(0, 10)
}

/**
 * Los cobros que YO registré: cada pago de una nota de venta, visto desde
 * quién lo cobró en vez de desde el documento. Por defecto muestra solo los
 * de hoy — es lo que un cobrador revisa al cerrar el día —, pero se puede
 * ampliar el rango.
 *
 * Si la venta se anula, el cobro también desaparece de aquí: solo se listan
 * pagos de notas de venta vigentes (no anuladas).
 */
export function MisCobrosPage() {
  const [cobros, setCobros] = useState<CobroResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')

  const [desde, setDesde] = useState(hoyISO())
  const [hasta, setHasta] = useState(hoyISO())

  const cargar = useCallback(async (d: string, h: string) => {
    setCargando(true)
    try {
      setCobros(
        await notaVentaApi.misCobros(
          d ? `${d}T00:00:00` : undefined,
          h ? `${h}T23:59:59` : undefined,
        ),
      )
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar tus cobros.')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar(desde, hasta)
    // Solo al montar: cambiar las fechas se aplica con el botón "Filtrar".
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useRealtime(['notasventa'], () => void cargar(desde, hasta))

  const verHoy = () => {
    setDesde(hoyISO())
    setHasta(hoyISO())
    void cargar(hoyISO(), hoyISO())
  }

  const verTodo = () => {
    setDesde('')
    setHasta('')
    void cargar('', '')
  }

  const columns: DataTableColumn<CobroResponse>[] = [
    {
      key: 'fecha',
      label: 'Fecha',
      render: (row) => new Date(row.fecha).toLocaleString('es-PE'),
    },
    { key: 'notaVentaNumero', label: 'Nota de venta', render: (row) => <Badge>{row.notaVentaNumero}</Badge> },
    { key: 'cliente', label: 'Cliente' },
    { key: 'metodoPago', label: 'Método' },
    { key: 'monto', label: 'Monto', align: 'right', render: (row) => `S/ ${row.monto.toFixed(2)}` },
  ]

  const totalCobrado = cobros.reduce((n, c) => n + c.monto, 0)

  return (
    <ListPage
      icon={<HandCoins size={20} />}
      title="Mis cobros"
      description="Los pagos que registraste de notas de venta vigentes. Si una venta se anula, su cobro desaparece de aquí."
      alert={error ? <Alert>{error}</Alert> : undefined}
      banner={
        <div className="flex flex-wrap items-end gap-3 rounded-field border border-line bg-surface-soft px-4 py-3">
          <Input
            label="Desde"
            type="date"
            value={desde}
            onChange={(e) => setDesde(e.target.value)}
            className="w-40"
          />
          <Input
            label="Hasta"
            type="date"
            value={hasta}
            onChange={(e) => setHasta(e.target.value)}
            className="w-40"
          />
          <Button size="sm" onClick={() => void cargar(desde, hasta)}>
            Filtrar
          </Button>
          <Button size="sm" variant="secondary" onClick={verHoy}>
            <Calendar size={15} />
            Hoy
          </Button>
          <Button size="sm" variant="secondary" onClick={verTodo}>
            Ver todo
          </Button>
        </div>
      }
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
      empty={cargando ? 'Cargando tus cobros...' : 'No registraste cobros en este rango.'}
    />
  )
}
