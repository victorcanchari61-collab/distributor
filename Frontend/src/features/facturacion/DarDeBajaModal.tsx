import { useEffect, useState } from 'react'
import { Alert, Button, Input, Modal, useToast } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { comprobanteApi } from './comprobanteApi'
import type { ComprobanteResponse } from './comprobanteApi'

/**
 * Comunicación de baja de una factura: se anula ante SUNAT sin emitir una nota de crédito. Solo dentro de los 7 días de emitida.
 * Si SUNAT la acepta, la venta de la factura también se anula y el stock vuelve al almacén. Puede quedar pendiente: SUNAT
 * procesa las bajas aparte y se consulta después.
 */
export function DarDeBajaModal({
  comprobante,
  onClose,
  onResuelta,
}: {
  /** La factura a dar de baja; nulo con el modal cerrado. */
  comprobante: ComprobanteResponse | null
  onClose: () => void
  onResuelta: (c: ComprobanteResponse) => void
}) {
  const toast = useToast()
  const [motivo, setMotivo] = useState('')
  const [enviando, setEnviando] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!comprobante) return
    setMotivo('')
    setError('')
  }, [comprobante])

  const enviar = async () => {
    if (!comprobante) return
    setEnviando(true)
    setError('')
    try {
      const c = await comprobanteApi.darDeBaja(comprobante.id, motivo.trim())
      if (c.bajaEstado === 'ACEPTADA') toast.exito(`${c.numeroCompleto} dada de baja`)
      else if (c.bajaEstado === 'PENDIENTE') toast.exito('SUNAT todavía procesa la baja: consúltala en unos minutos')
      else toast.error(c.bajaMensaje ?? 'SUNAT no aceptó la baja')
      onResuelta(c)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos enviar la baja')
    } finally {
      setEnviando(false)
    }
  }

  return (
    <Modal
      open={comprobante !== null}
      title={`Dar de baja ${comprobante?.numeroCompleto ?? ''}`}
      description={comprobante ? comprobante.clienteNombre : undefined}
      size="md"
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cancelar
          </Button>
          <Button size="sm" loading={enviando} disabled={motivo.trim().length < 3} onClick={() => void enviar()}>
            Dar de baja
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-4">
        {error && <Alert>{error}</Alert>}
        <Alert tone="info">
          {comprobante?.ventaDirecta
            ? 'Si SUNAT la acepta, la factura deja de valer: el stock vuelve al almacén y deja de contar en los reportes.'
            : comprobante?.notaVentaNumero
              ? `Si SUNAT la acepta, la venta ${comprobante.notaVentaNumero} se anula: el stock vuelve al almacén y deja de contar en los reportes.`
              : 'Si SUNAT la acepta, la factura deja de valer.'}
        </Alert>
        <Input
          label="Motivo de la baja"
          placeholder="Ej.: Error en los productos facturados"
          maxLength={100}
          value={motivo}
          onChange={(e) => setMotivo(e.target.value)}
        />
      </div>
    </Modal>
  )
}
