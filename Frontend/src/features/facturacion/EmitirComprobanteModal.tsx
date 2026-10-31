import { useEffect, useState } from 'react'
import { Receipt } from 'lucide-react'
import { Alert, Button, Modal, Select, useToast } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { usePermisos } from '../../lib/permisos'
import { comprobanteApi, SUBMODULO_CPE, TIPOS_CPE } from './comprobanteApi'
import type { ComprobanteResponse } from './comprobanteApi'
import { PanelComprobante, monto } from './PanelComprobante'

/**
 * Factura o boleta de una nota de venta. Si la venta ya tiene su comprobante lo muestra (con su XML y su CDR para
 * bajar); si no, deja elegir el tipo y emitirlo: se firma, se manda a SUNAT y se ve lo que respondió.
 */
export function EmitirComprobanteModal({
  nota,
  onClose,
}: {
  /** La venta a facturar; nula con el modal cerrado. */
  nota: { id: number; numero: string; cliente: string; total: number } | null
  onClose: () => void
}) {
  const toast = useToast()
  const { puede } = usePermisos()
  const puedeBoleta = puede(SUBMODULO_CPE['03'], 'crear')
  const puedeFactura = puede(SUBMODULO_CPE['01'], 'crear')
  const [cargando, setCargando] = useState(false)
  const [emitiendo, setEmitiendo] = useState(false)
  const [error, setError] = useState('')
  const [tipo, setTipo] = useState<'01' | '03'>('03')
  const [emitido, setEmitido] = useState<ComprobanteResponse | null>(null)

  useEffect(() => {
    if (!nota) return
    let vigente = true
    setCargando(true)
    setError('')
    setEmitido(null)
    setTipo(puedeBoleta ? '03' : '01')
    comprobanteApi
      .listar({ notaVentaId: nota.id })
      .then((lista) => {
        // El rechazado no cuenta: la venta se puede volver a emitir.
        const vivo = lista.find((c) => (c.tipo === '01' || c.tipo === '03') && c.estado !== 'RECHAZADO')
        if (vigente) setEmitido(vivo ?? null)
      })
      .catch((e) => vigente && setError(e instanceof ApiError ? e.message : 'No pudimos consultar los comprobantes'))
      .finally(() => vigente && setCargando(false))
    return () => {
      vigente = false
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- solo al abrir con otra venta
  }, [nota])

  const emitir = async () => {
    if (!nota) return
    setEmitiendo(true)
    setError('')
    try {
      const c = await comprobanteApi.emitir(nota.id, tipo)
      setEmitido(c)
      if (c.estado === 'ACEPTADO') toast.exito(`${c.numeroCompleto} aceptado por SUNAT`)
      else toast.error(c.mensajeSunat ?? `${c.numeroCompleto}: no se pudo confirmar con SUNAT`)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos emitir el comprobante')
    } finally {
      setEmitiendo(false)
    }
  }

  return (
    <Modal
      open={nota !== null}
      title={emitido ? `Comprobante de ${nota?.numero}` : `Facturar ${nota?.numero ?? ''}`}
      description={nota ? `${nota.cliente} · ${monto(nota.total)}` : undefined}
      size="md"
      onClose={onClose}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onClose}>
            Cerrar
          </Button>
          {!emitido && !cargando && (
            <Button size="sm" loading={emitiendo} onClick={() => void emitir()}>
              <Receipt size={15} /> Emitir {TIPOS_CPE[tipo].corto.toLowerCase()}
            </Button>
          )}
        </>
      }
    >
      <div className="flex flex-col gap-4">
        {error && <Alert>{error}</Alert>}

        {cargando && <p className="py-6 text-center text-sm text-ink-soft">Revisando si ya tiene comprobante...</p>}

        {!cargando && emitido && <PanelComprobante comprobante={emitido} onCambio={setEmitido} />}

        {!cargando && !emitido && (
          <>
            <Select label="Tipo de comprobante" value={tipo} onChange={(e) => setTipo(e.target.value as '01' | '03')}>
              {puedeBoleta && <option value="03">Boleta de venta electrónica</option>}
              {puedeFactura && <option value="01">Factura electrónica</option>}
            </Select>
            <p className="text-xs text-ink-soft">
              La factura pide que el cliente tenga RUC. La boleta acepta DNI o RUC; desde S/ 700 exige el documento del cliente. Se firma
              y se envía a SUNAT en el momento.
            </p>
          </>
        )}
      </div>
    </Modal>
  )
}
