import { useCallback, useEffect, useMemo, useState } from 'react'
import { CircleCheck, CircleX, Clock, FileArchive, FileCode2, Eye, FilePen, Receipt, RefreshCw } from 'lucide-react'
import { Alert, ListPage, Modal, RowAction, StatCard, useToast } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { ESTADOS_CPE, TIPOS_CPE, comprobanteApi } from './comprobanteApi'
import type { ComprobanteResponse, EstadoCpe, TipoCpe } from './comprobanteApi'
import { EmitirNotaModal } from './EmitirNotaModal'
import { EstadoCpeBadge, PanelComprobante, monto } from './PanelComprobante'

/**
 * Comprobantes electrónicos emitidos: factura, boleta, y notas de crédito y débito. Cada uno muestra en qué quedó
 * frente a SUNAT y deja bajar su XML firmado y su CDR. Las facturas y boletas se emiten desde Notas de venta; las
 * notas, desde aquí, sobre un comprobante aceptado.
 */
export function ComprobantesPage() {
  const { puede } = usePermisos()
  const toast = useToast()

  const [filas, setFilas] = useState<ComprobanteResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [detalle, setDetalle] = useState<ComprobanteResponse | null>(null)
  const [corrigiendo, setCorrigiendo] = useState<ComprobanteResponse | null>(null)

  const cargar = useCallback(async () => {
    try {
      setFilas(await comprobanteApi.listar())
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los comprobantes')
    } finally {
      setCargando(false)
    }
  }, [])

  useEffect(() => {
    void cargar()
  }, [cargar])

  useRealtime(['comprobantes'], cargar)

  const reemplazar = (c: ComprobanteResponse) => setFilas((fs) => fs.map((f) => (f.id === c.id ? c : f)))

  const descargar = async (que: 'xml' | 'cdr', c: ComprobanteResponse) => {
    try {
      if (que === 'xml') await comprobanteApi.descargarXml(c)
      else await comprobanteApi.descargarCdr(c)
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos descargar el archivo')
    }
  }

  const reenviar = async (c: ComprobanteResponse) => {
    try {
      const nuevo = await comprobanteApi.reenviar(c.id)
      reemplazar(nuevo)
      if (nuevo.estado === 'ACEPTADO') toast.exito(`${nuevo.numeroCompleto} aceptado por SUNAT`)
      else toast.error(nuevo.mensajeSunat ?? ESTADOS_CPE[nuevo.estado].ayuda)
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos reenviar el comprobante')
    }
  }

  const columnas: DataTableColumn<ComprobanteResponse>[] = useMemo(
    () => [
      {
        key: 'fechaEmision',
        label: 'Emisión',
        filterType: 'date',
        value: (c) => new Date(c.fechaEmision).getTime(),
        render: (c) => fechaCorta(c.fechaEmision),
      },
      {
        key: 'tipo',
        label: 'Tipo',
        filterType: 'select',
        filterOptions: (Object.keys(TIPOS_CPE) as TipoCpe[]).map((t) => ({ value: t, label: TIPOS_CPE[t].corto })),
        value: (c) => c.tipo,
        render: (c) => TIPOS_CPE[c.tipo].corto,
      },
      {
        key: 'numeroCompleto',
        label: 'Número',
        filterable: false,
        render: (c) => (
          <span className="flex flex-col">
            <span className="font-medium text-ink">{c.numeroCompleto}</span>
            {c.afectadoNumero ? (
              <span className="text-xs text-ink-soft">corrige a {c.afectadoNumero}</span>
            ) : c.notaVentaNumero ? (
              <span className="text-xs text-ink-soft">de {c.notaVentaNumero}</span>
            ) : null}
          </span>
        ),
      },
      {
        key: 'cliente',
        label: 'Cliente',
        filterable: false,
        value: (c) => `${c.clienteNombre} ${c.clienteDocumento}`,
        render: (c) => (
          <span className="flex flex-col">
            <span>{c.clienteNombre}</span>
            <span className="text-xs text-ink-soft">{c.clienteDocumento === '-' ? 'sin documento' : c.clienteDocumento}</span>
          </span>
        ),
      },
      {
        key: 'total',
        label: 'Total',
        align: 'right',
        filterable: false,
        value: (c) => c.total,
        render: (c) => <span className="font-semibold">{monto(c.total)}</span>,
      },
      {
        key: 'estado',
        label: 'SUNAT',
        filterType: 'select',
        filterOptions: (Object.keys(ESTADOS_CPE) as EstadoCpe[]).map((e) => ({ value: e, label: ESTADOS_CPE[e].label })),
        value: (c) => c.estado,
        render: (c) => <EstadoCpeBadge estado={c.estado} />,
      },
    ],
    [],
  )

  const aceptados = filas.filter((f) => f.estado === 'ACEPTADO').length
  const rechazados = filas.filter((f) => f.estado === 'RECHAZADO').length
  const pendientes = filas.filter((f) => f.estado === 'GENERADO' || f.estado === 'ERROR').length
  const enPruebas = filas.some((f) => f.entorno !== 'produccion')

  return (
    <ListPage
      icon={<Receipt size={20} />}
      title="Comprobantes"
      description="Facturas, boletas y notas de crédito y débito emitidas a SUNAT, con su XML y su CDR para descargar."
      alert={
        error ? (
          <Alert>{error}</Alert>
        ) : enPruebas ? (
          <Alert tone="info">Hay comprobantes emitidos en el entorno de pruebas de SUNAT: no tienen validez tributaria.</Alert>
        ) : undefined
      }
      stats={
        <>
          <StatCard label="Aceptados" value={String(aceptados)} icon={<CircleCheck size={18} />} tono="success" />
          <StatCard
            label="Sin respuesta"
            value={String(pendientes)}
            icon={<Clock size={18} />}
            tono={pendientes > 0 ? 'warning' : 'neutral'}
            hint={pendientes > 0 ? 'se pueden reenviar' : 'ninguno'}
          />
          <StatCard
            label="Rechazados"
            value={String(rechazados)}
            icon={<CircleX size={18} />}
            tono={rechazados > 0 ? 'danger' : 'neutral'}
          />
          <StatCard label="Emitidos" value={String(filas.length)} icon={<Receipt size={18} />} />
        </>
      }
      columns={columnas}
      rows={filas}
      rowKey="id"
      cardIcon={Receipt}
      searchPlaceholder="Buscar por número, cliente..."
      empty={cargando ? 'Cargando comprobantes...' : 'Todavía no se emitió ningún comprobante. Se emiten desde Notas de venta.'}
      actionsWidth={190}
      rowActions={(c) => (
        <>
          <RowAction label={`Ver ${c.numeroCompleto}`} tone="view" onClick={() => setDetalle(c)}>
            <Eye size={15} />
          </RowAction>
          {puede('fact.comprobantes', 'exportar') && (
            <RowAction label="Descargar XML" onClick={() => void descargar('xml', c)}>
              <FileCode2 size={15} />
            </RowAction>
          )}
          {puede('fact.comprobantes', 'exportar') && c.tieneCdr && (
            <RowAction label="Descargar CDR" onClick={() => void descargar('cdr', c)}>
              <FileArchive size={15} />
            </RowAction>
          )}
          {puede('fact.comprobantes', 'crear') && (c.estado === 'GENERADO' || c.estado === 'ERROR') && (
            <RowAction label="Reenviar a SUNAT" tone="warning" onClick={() => void reenviar(c)}>
              <RefreshCw size={15} />
            </RowAction>
          )}
          {puede('fact.comprobantes', 'crear') && c.estado === 'ACEPTADO' && (c.tipo === '01' || c.tipo === '03') && (
            <RowAction label="Emitir nota de crédito o débito" tone="edit" onClick={() => setCorrigiendo(c)}>
              <FilePen size={15} />
            </RowAction>
          )}
        </>
      )}
    >
      <Modal
        open={detalle !== null}
        title={detalle ? detalle.numeroCompleto : ''}
        size="md"
        onClose={() => setDetalle(null)}
      >
        {detalle && (
          <PanelComprobante
            comprobante={detalle}
            onCambio={(c) => {
              reemplazar(c)
              setDetalle(c)
            }}
          />
        )}
      </Modal>

      <EmitirNotaModal
        comprobante={corrigiendo}
        onClose={() => setCorrigiendo(null)}
        onEmitida={(nota) => {
          setCorrigiendo(null)
          void cargar()
          setDetalle(nota)
        }}
      />
    </ListPage>
  )
}
