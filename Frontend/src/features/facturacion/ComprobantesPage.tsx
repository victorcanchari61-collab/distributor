import { useCallback, useEffect, useMemo, useState } from 'react'
import { MessageCircle, CircleCheck, CircleX, Clock, FileArchive, FileCode2, FileMinus, FilePen, FilePlus, Eye, Receipt, RefreshCw, Ticket } from 'lucide-react'
import type { LucideIcon } from 'lucide-react'
import { AccionPdf, Alert, Badge, ListPage, Modal, RowAction, StatCard, useToast } from '../../components/ui'
import type { DataTableColumn } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta } from '../../lib/fechas'
import { usePermisos } from '../../lib/permisos'
import { useRealtime } from '../../lib/realtime'
import { ESTADOS_CPE, ESTADOS_WHATSAPP, SUBMODULO_CPE, comprobanteApi } from './comprobanteApi'
import type { ComprobanteResponse, EstadoCpe, TipoCpe } from './comprobanteApi'
import { EmitirNotaModal } from './EmitirNotaModal'
import { EstadoCpeBadge, PanelComprobante, monto } from './PanelComprobante'

const VISTAS: Record<TipoCpe, { titulo: string; descripcion: string; icono: LucideIcon; vacio: string }> = {
  '01': {
    titulo: 'Facturas',
    descripcion: 'Facturas electrónicas emitidas a SUNAT, con su XML y su CDR para descargar.',
    icono: Receipt,
    vacio: 'Todavía no se emitió ninguna factura. Se emiten desde Notas de venta.',
  },
  '03': {
    titulo: 'Boletas',
    descripcion: 'Boletas de venta electrónicas emitidas a SUNAT, con su XML y su CDR para descargar.',
    icono: Ticket,
    vacio: 'Todavía no se emitió ninguna boleta. Se emiten desde Notas de venta.',
  },
  '07': {
    titulo: 'Notas de crédito',
    descripcion: 'Notas de crédito electrónicas: devuelven o descuentan lo facturado.',
    icono: FileMinus,
    vacio: 'Todavía no se emitió ninguna nota de crédito. Se emiten desde Facturas o Boletas, sobre un comprobante aceptado.',
  },
  '08': {
    titulo: 'Notas de débito',
    descripcion: 'Notas de débito electrónicas: cobran de más sobre lo facturado.',
    icono: FilePlus,
    vacio: 'Todavía no se emitió ninguna nota de débito. Se emiten desde Facturas o Boletas, sobre un comprobante aceptado.',
  },
}

/**
 * Los comprobantes electrónicos de UN tipo (factura, boleta, nota de crédito o nota de débito), cada uno con su
 * entrada en el menú y su permiso. Muestra en qué quedó cada comprobante frente a SUNAT y deja bajar su XML firmado y
 * su CDR. Las facturas y boletas se emiten desde Notas de venta; las notas, desde Facturas y Boletas, sobre un
 * comprobante aceptado.
 */
function ComprobantesPage({ tipo }: { tipo: TipoCpe }) {
  const { puede } = usePermisos()
  const toast = useToast()
  const vista = VISTAS[tipo]
  const Icono = vista.icono
  const submodulo = SUBMODULO_CPE[tipo]
  const esNota = tipo === '07' || tipo === '08'
  // Una factura o boleta se corrige con la nota que el usuario tenga permiso de emitir.
  const notasPermitidas = (['07', '08'] as const).filter((t) => puede(SUBMODULO_CPE[t], 'crear'))

  const [filas, setFilas] = useState<ComprobanteResponse[]>([])
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const [detalle, setDetalle] = useState<ComprobanteResponse | null>(null)
  const [corrigiendo, setCorrigiendo] = useState<ComprobanteResponse | null>(null)

  const cargar = useCallback(async () => {
    try {
      setFilas(await comprobanteApi.listar({ tipo }))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar los comprobantes')
    } finally {
      setCargando(false)
    }
  }, [tipo])

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

  /** Manda el enlace por WhatsApp al teléfono del cliente. Si no tiene, el mensaje del error manda a escribirlo en el detalle. */
  const whatsapp = async (c: ComprobanteResponse) => {
    try {
      reemplazar(await comprobanteApi.enviarWhatsApp(c.id))
      toast.exito(`${c.numeroCompleto} enviado a la cola de WhatsApp`)
    } catch (e) {
      toast.error(e instanceof ApiError ? `${e.message}. Ábrelo con el ojo para escribir el teléfono.` : 'No pudimos enviarlo por WhatsApp')
      void cargar()
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
      // Solo facturas y boletas: qué notas de crédito o débito las corrigen.
      ...(esNota
        ? []
        : [
            {
              key: 'notas',
              label: 'Notas',
              filterType: 'select' as const,
              filterOptions: ['Sin notas', 'Solo crédito', 'Solo débito', 'Crédito y débito'].map((v) => ({ value: v, label: v })),
              value: (c: ComprobanteResponse) => {
                const vivas = c.notas.filter((n) => n.estado !== 'RECHAZADO')
                const cre = vivas.some((n) => n.tipo === '07')
                const deb = vivas.some((n) => n.tipo === '08')
                return cre && deb ? 'Crédito y débito' : cre ? 'Solo crédito' : deb ? 'Solo débito' : 'Sin notas'
              },
              render: (c: ComprobanteResponse) =>
                c.notas.length === 0 ? (
                  <span className="text-ink-soft">—</span>
                ) : (
                  <span className="flex flex-col items-start gap-0.5">
                    {c.notas.map((n) => (
                      <span key={n.id} className="flex items-center gap-1.5 text-xs">
                        <Badge tone={n.tipo === '07' ? 'warning' : 'sys'}>{n.tipo === '07' ? 'NC' : 'ND'}</Badge>
                        {n.numeroCompleto}
                        {n.estado === 'RECHAZADO' && <span className="text-red-600">rechazada</span>}
                      </span>
                    ))}
                  </span>
                ),
            },
          ]),
      {
        key: 'total',
        label: 'Total',
        align: 'right',
        filterable: false,
        value: (c) => c.total,
        render: (c) => <span className="font-semibold">{monto(c.total)}</span>,
      },
      {
        key: 'whatsapp',
        label: 'WhatsApp',
        filterType: 'select',
        filterOptions: [
          { value: 'Sin enviar', label: 'Sin enviar' },
          ...(Object.keys(ESTADOS_WHATSAPP) as (keyof typeof ESTADOS_WHATSAPP)[]).map((k) => ({ value: ESTADOS_WHATSAPP[k].label, label: ESTADOS_WHATSAPP[k].label })),
        ],
        value: (c) => (c.whatsAppEstado ? ESTADOS_WHATSAPP[c.whatsAppEstado].label : 'Sin enviar'),
        render: (c) =>
          c.whatsAppEstado ? <Badge tone={ESTADOS_WHATSAPP[c.whatsAppEstado].tone}>{ESTADOS_WHATSAPP[c.whatsAppEstado].label}</Badge> : <span className="text-ink-soft">—</span>,
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
    [esNota],
  )

  const aceptados = filas.filter((f) => f.estado === 'ACEPTADO').length
  const rechazados = filas.filter((f) => f.estado === 'RECHAZADO').length
  const pendientes = filas.filter((f) => f.estado === 'GENERADO' || f.estado === 'ERROR').length
  const enPruebas = filas.some((f) => f.entorno !== 'produccion')

  return (
    <ListPage
      icon={<Icono size={20} />}
      title={vista.titulo}
      description={vista.descripcion}
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
          <StatCard label="Emitidos" value={String(filas.length)} icon={<Icono size={18} />} />
        </>
      }
      columns={columnas}
      rows={filas}
      rowKey="id"
      cardIcon={Icono}
      searchPlaceholder="Buscar por número, cliente..."
      empty={cargando ? 'Cargando...' : vista.vacio}
      actionsWidth={250}
      rowActions={(c) => (
        <>
          <RowAction label={`Ver ${c.numeroCompleto}`} tone="view" onClick={() => setDetalle(c)}>
            <Eye size={15} />
          </RowAction>
          {puede(submodulo, 'exportar') && <AccionPdf documento="comprobante" id={c.id} numero={c.numeroCompleto} />}
          {puede(submodulo, 'exportar') && (
            <RowAction label="Descargar XML" onClick={() => void descargar('xml', c)}>
              <FileCode2 size={15} />
            </RowAction>
          )}
          {puede(submodulo, 'exportar') && c.tieneCdr && (
            <RowAction label="Descargar CDR" onClick={() => void descargar('cdr', c)}>
              <FileArchive size={15} />
            </RowAction>
          )}
          {puede(submodulo, 'exportar') && c.estado === 'ACEPTADO' && (
            <RowAction label={c.whatsAppEstado === 'ENCOLADO' ? 'Reenviar por WhatsApp' : 'Enviar por WhatsApp'} tone="success" onClick={() => void whatsapp(c)}>
              <MessageCircle size={15} />
            </RowAction>
          )}
          {puede(submodulo, 'crear') && (c.estado === 'GENERADO' || c.estado === 'ERROR') && (
            <RowAction label="Reenviar a SUNAT" tone="warning" onClick={() => void reenviar(c)}>
              <RefreshCw size={15} />
            </RowAction>
          )}
          {!esNota && notasPermitidas.length > 0 && c.estado === 'ACEPTADO' && (
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
        tiposPermitidos={notasPermitidas}
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

export const FacturasPage = () => <ComprobantesPage tipo="01" />
export const BoletasPage = () => <ComprobantesPage tipo="03" />
export const NotasCreditoPage = () => <ComprobantesPage tipo="07" />
export const NotasDebitoPage = () => <ComprobantesPage tipo="08" />
