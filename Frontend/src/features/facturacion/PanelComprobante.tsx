import { useState } from 'react'
import { Download, FileArchive, FileCode2, RefreshCw } from 'lucide-react'
import { Alert, Badge, Button, useToast } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta, fechaHora } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { ESTADOS_CPE, TIPOS_CPE, comprobanteApi } from './comprobanteApi'
import type { ComprobanteResponse } from './comprobanteApi'

/** Soles con dos decimales: un comprobante se lee al centavo. */
export const monto = (n: number) => `S/ ${n.toLocaleString('es-PE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`

export function EstadoCpeBadge({ estado }: { estado: ComprobanteResponse['estado'] }) {
  const e = ESTADOS_CPE[estado]
  return <Badge tone={e.tone}>{e.label}</Badge>
}

/**
 * Un comprobante emitido: su número, en qué quedó frente a SUNAT y los botones para bajar el XML firmado y el CDR
 * (la constancia de recepción). Si no hubo respuesta de SUNAT, ofrece reenviarlo.
 */
export function PanelComprobante({
  comprobante,
  onCambio,
}: {
  comprobante: ComprobanteResponse
  /** Se reenvió y cambió: quien lo muestra se actualiza. */
  onCambio: (c: ComprobanteResponse) => void
}) {
  const toast = useToast()
  const { puede } = usePermisos()
  const [trabajando, setTrabajando] = useState<'xml' | 'cdr' | 'reenviar' | null>(null)
  const c = comprobante
  const estado = ESTADOS_CPE[c.estado]

  const ejecutar = async (que: 'xml' | 'cdr' | 'reenviar') => {
    setTrabajando(que)
    try {
      if (que === 'xml') await comprobanteApi.descargarXml(c)
      else if (que === 'cdr') await comprobanteApi.descargarCdr(c)
      else {
        const nuevo = await comprobanteApi.reenviar(c.id)
        onCambio(nuevo)
        if (nuevo.estado === 'ACEPTADO') toast.exito(`${nuevo.numeroCompleto} aceptado por SUNAT`)
        else toast.error(nuevo.mensajeSunat ?? `${nuevo.numeroCompleto}: ${ESTADOS_CPE[nuevo.estado].ayuda}`)
      }
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos completar la acción')
    } finally {
      setTrabajando(null)
    }
  }

  const puedeDescargar = puede('fact.comprobantes', 'exportar')
  const puedeReenviar = puede('fact.comprobantes', 'crear') && (c.estado === 'GENERADO' || c.estado === 'ERROR')

  return (
    <div className="flex flex-col gap-3">
      <div className="rounded-panel border border-line p-3">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div>
            <p className="text-xs text-ink-soft">{TIPOS_CPE[c.tipo].nombre}</p>
            <p className="text-lg font-bold text-ink">{c.numeroCompleto}</p>
          </div>
          <div className="flex items-center gap-2">
            {c.entorno !== 'produccion' && <Badge tone="neutral">Pruebas</Badge>}
            <EstadoCpeBadge estado={c.estado} />
          </div>
        </div>

        <dl className="mt-3 grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm">
          <dt className="text-ink-soft">Cliente</dt>
          <dd>
            {c.clienteNombre}
            <span className="text-ink-soft"> · {c.clienteDocumento === '-' ? 'sin documento' : c.clienteDocumento}</span>
          </dd>
          <dt className="text-ink-soft">Emisión</dt>
          <dd>{fechaCorta(c.fechaEmision)}</dd>
          <dt className="text-ink-soft">Total</dt>
          <dd className="font-semibold">{monto(c.total)}</dd>
          {c.afectadoNumero && (
            <>
              <dt className="text-ink-soft">Corrige a</dt>
              <dd>{c.afectadoNumero}</dd>
            </>
          )}
          {c.desMotivo && (
            <>
              <dt className="text-ink-soft">Motivo</dt>
              <dd>{c.desMotivo}</dd>
            </>
          )}
          {c.enviadoEn && (
            <>
              <dt className="text-ink-soft">Enviado</dt>
              <dd>{fechaHora(c.enviadoEn)}</dd>
            </>
          )}
        </dl>
      </div>

      {c.estado === 'ACEPTADO' ? (
        <Alert tone="info">{c.mensajeSunat || estado.ayuda}</Alert>
      ) : (
        <Alert tone={c.estado === 'RECHAZADO' ? 'error' : 'warning'}>
          {c.mensajeSunat ? `${c.codigoSunat ? `[${c.codigoSunat}] ` : ''}${c.mensajeSunat}` : estado.ayuda}
        </Alert>
      )}
      {c.notasSunat && <p className="text-xs whitespace-pre-line text-ink-soft">{c.notasSunat}</p>}

      <div className="flex flex-wrap gap-2">
        {puedeDescargar && (
          <Button variant="secondary" size="sm" loading={trabajando === 'xml'} onClick={() => void ejecutar('xml')}>
            <FileCode2 size={15} /> Descargar XML
          </Button>
        )}
        {puedeDescargar && c.tieneCdr && (
          <Button variant="secondary" size="sm" loading={trabajando === 'cdr'} onClick={() => void ejecutar('cdr')}>
            <FileArchive size={15} /> Descargar CDR
          </Button>
        )}
        {puedeReenviar && (
          <Button size="sm" loading={trabajando === 'reenviar'} onClick={() => void ejecutar('reenviar')}>
            <RefreshCw size={15} /> Reenviar a SUNAT
          </Button>
        )}
        {puedeDescargar && !c.tieneCdr && (
          <span className="flex items-center gap-1 self-center text-xs text-ink-soft">
            <Download size={13} /> El CDR aparece cuando SUNAT responde.
          </span>
        )}
      </div>
    </div>
  )
}
