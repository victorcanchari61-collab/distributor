import { useEffect, useState } from 'react'
import { Alert, Badge, SysDataTable } from '../../../components/ui'
import { ApiError } from '../../../lib/apiClient'
import { fechaCorta } from '../../../lib/fechas'
import { crmApi } from '../crmApi'
import type { DocumentosCliente } from '../crmApi'

const capitalizar = (t: string) => t.charAt(0) + t.slice(1).toLowerCase()

/** La pestaña Documentos: los pedidos y las devoluciones del cliente. */
export function TabDocumentos({ clienteId }: { clienteId: number }) {
  const [datos, setDatos] = useState<DocumentosCliente | null>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    let vigente = true
    setDatos(null)
    crmApi
      .documentos(clienteId)
      .then((d) => vigente && setDatos(d))
      .catch((e) => vigente && setError(e instanceof ApiError ? e.message : 'No pudimos cargar los documentos.'))
    return () => {
      vigente = false
    }
  }, [clienteId])

  if (error) return <Alert>{error}</Alert>
  if (!datos) return <p className="py-10 text-center text-sm text-ink-soft">Cargando documentos...</p>

  return (
    <div className="space-y-5">
      <section className="space-y-2">
        <h3 className="text-sm font-semibold text-ink">Pedidos</h3>
        <SysDataTable
          columns={[
            { key: 'fecha', label: 'Fecha', filterable: false, value: (r) => new Date(r.fecha).getTime(), render: (r) => fechaCorta(r.fecha) },
            { key: 'numero', label: 'Pedido', filterable: false, render: (r) => <span className="font-medium">{r.numero}</span> },
            { key: 'condicionPago', label: 'Pago', filterable: false, render: (r) => (r.condicionPago === 'CREDITO' ? 'Crédito' : 'Contado') },
            {
              key: 'estado',
              label: 'Estado',
              filterable: false,
              render: (r) => (
                <Badge tone={r.estado === 'CONFIRMADO' ? 'success' : r.estado === 'ANULADO' ? 'danger' : 'warning'}>{capitalizar(r.estado)}</Badge>
              ),
            },
          ]}
          rows={datos.pedidos}
          rowKey="id"
          toolbar={false}
          pageSize={8}
          empty="Sin pedidos."
        />
      </section>

      <section className="space-y-2">
        <h3 className="text-sm font-semibold text-ink">Devoluciones</h3>
        <SysDataTable
          columns={[
            { key: 'fecha', label: 'Fecha', filterable: false, value: (r) => new Date(r.fecha).getTime(), render: (r) => fechaCorta(r.fecha) },
            { key: 'numero', label: 'Devolución', filterable: false, render: (r) => <span className="font-medium">{r.numero}</span> },
            { key: 'notaVenta', label: 'De la nota', filterable: false },
            { key: 'motivo', label: 'Motivo', filterable: false, render: (r) => r.motivo ?? '—' },
            {
              key: 'estado',
              label: 'Estado',
              filterable: false,
              render: (r) => (
                <Badge tone={r.estado === 'APROBADA' ? 'success' : r.estado === 'RECHAZADA' ? 'danger' : 'warning'}>{capitalizar(r.estado)}</Badge>
              ),
            },
          ]}
          rows={datos.devoluciones}
          rowKey="id"
          toolbar={false}
          pageSize={8}
          empty="Sin devoluciones."
        />
      </section>
    </div>
  )
}
