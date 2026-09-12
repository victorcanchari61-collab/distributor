import { useCallback, useEffect, useRef, useState } from 'react'
import { Download, FileText, Printer } from 'lucide-react'
import { Alert } from './Alert'
import { Button } from './Button'
import { Modal } from './Modal'
import { RowAction } from './RowAction'
import { cn } from './cn'
import { ApiError, guardarArchivo, obtenerArchivo } from '../../lib/apiClient'

/** Los documentos que se pueden imprimir, con la ruta que los sirve. */
export type DocumentoPdf =
  | 'pedido'
  | 'notaventa'
  | 'ordencompra'
  | 'compra'
  | 'ajustes'
  | 'transferencias'
  | 'recepciones'
  | 'prestamos'

type Formato = 'a4' | 'ticket'

const TITULOS: Record<DocumentoPdf, string> = {
  pedido: 'Pedido',
  notaventa: 'Nota de venta',
  ordencompra: 'Orden de compra',
  compra: 'Compra',
  ajustes: 'Ajuste',
  transferencias: 'Transferencia',
  recepciones: 'Recepción',
  prestamos: 'Préstamo',
}

/*
 * Los de inventario cuelgan de /inventario porque comparten tabla y numeracion
 * de id: cada tipo necesita su propia ruta para que el backend sepa que
 * permiso exigir antes de leer el documento.
 */
const INVENTARIO: DocumentoPdf[] = ['ajustes', 'transferencias', 'recepciones', 'prestamos']

const rutaDe = (documento: DocumentoPdf) =>
  INVENTARIO.includes(documento) ? `/inventario/${documento}` : `/${documento}`

export interface AccionPdfProps {
  documento: DocumentoPdf
  id: number
  /** El número visible — encabeza el visor y nombra el archivo. */
  numero: string
}

/**
 * El botón de PDF de la columna Acciones: abre el documento en un visor.
 *
 * Se ve antes de imprimir porque un documento se revisa: que el cliente sea el
 * que toca, que no falte una línea. Bajar el archivo a ciegas obliga a salir
 * del sistema, abrirlo, comprobar y volver — y si algo estaba mal, repetirlo.
 *
 * Los dos formatos conviven en pestañas y no en dos botones porque son el
 * mismo documento: se compara uno con otro y se imprime el que toque, la hoja
 * A4 para archivar o el ticket de 80 mm para el rollo de la camioneta.
 */
export function AccionPdf({ documento, id, numero }: AccionPdfProps) {
  const [abierto, setAbierto] = useState(false)

  return (
    <>
      <RowAction label={`PDF de ${numero}`} tone="neutral" onClick={() => setAbierto(true)}>
        <FileText size={15} />
      </RowAction>

      {/* Se monta solo al abrir: si no, cada fila de la tabla pediría su PDF. */}
      {abierto && (
        <VisorPdf
          documento={documento}
          id={id}
          numero={numero}
          onCerrar={() => setAbierto(false)}
        />
      )}
    </>
  )
}

function VisorPdf({
  documento,
  id,
  numero,
  onCerrar,
}: AccionPdfProps & { onCerrar: () => void }) {
  const [formato, setFormato] = useState<Formato>('a4')
  const [url, setUrl] = useState('')
  const [nombre, setNombre] = useState('')
  const [blob, setBlob] = useState<Blob | null>(null)
  const [cargando, setCargando] = useState(true)
  const [error, setError] = useState('')
  const marco = useRef<HTMLIFrameElement>(null)

  useEffect(() => {
    let vivo = true
    let creada = ''

    const traer = async () => {
      setCargando(true)
      setError('')
      try {
        const query = formato === 'ticket' ? '?formato=ticket' : ''
        const archivo = await obtenerArchivo(
          `${rutaDe(documento)}/${id}/pdf${query}`,
          `${documento}-${numero}.pdf`,
        )
        if (!vivo) return
        creada = URL.createObjectURL(archivo.blob)
        setUrl(creada)
        setNombre(archivo.nombre)
        setBlob(archivo.blob)
      } catch (e) {
        // El 403 ya abre por su cuenta el modal de pedir permiso; aquí solo
        // queda decir por qué no se ve nada.
        if (vivo) setError(e instanceof ApiError ? e.message : 'No pudimos generar el PDF.')
      } finally {
        if (vivo) setCargando(false)
      }
    }

    void traer()
    return () => {
      vivo = false
      // Cada cambio de formato crea un archivo en memoria; sin soltarlo, se
      // acumulan hasta recargar la página.
      if (creada) URL.revokeObjectURL(creada)
    }
  }, [documento, id, numero, formato])

  const imprimir = useCallback(() => {
    // Se imprime el propio visor incrustado. Algunos navegadores no dejan
    // llegar al documento de dentro; entonces se abre en otra pestaña, donde
    // el lector trae su propio botón de imprimir.
    try {
      const ventana = marco.current?.contentWindow
      if (!ventana) throw new Error('sin marco')
      ventana.focus()
      ventana.print()
    } catch {
      window.open(url, '_blank', 'noopener')
    }
  }, [url])

  return (
    <Modal
      open
      size="lg"
      title={`${TITULOS[documento]} ${numero}`}
      description="Revísalo antes de imprimirlo o guardarlo."
      onClose={onCerrar}
      footer={
        <>
          <Button variant="secondary" size="sm" onClick={onCerrar}>
            Cerrar
          </Button>
          <Button
            variant="secondary"
            size="sm"
            disabled={!url}
            onClick={imprimir}
            iconRight={<Printer size={15} />}
          >
            Imprimir
          </Button>
          <Button
            size="sm"
            disabled={!blob}
            onClick={() => blob && guardarArchivo(blob, nombre)}
            iconRight={<Download size={15} />}
          >
            Descargar
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <div className="flex gap-1.5">
          <Pestana activa={formato === 'a4'} onClick={() => setFormato('a4')}>
            A4
          </Pestana>
          <Pestana activa={formato === 'ticket'} onClick={() => setFormato('ticket')}>
            Ticket 80 mm
          </Pestana>
        </div>

        {error && <Alert>{error}</Alert>}

        <div className="relative h-[65vh] min-h-[360px] overflow-hidden rounded-field border border-line bg-surface-alt">
          {cargando && (
            <div className="absolute inset-0 grid place-items-center text-sm text-ink-soft">
              Generando el documento...
            </div>
          )}
          {url && !error && (
            <iframe
              ref={marco}
              src={url}
              title={`${TITULOS[documento]} ${numero}`}
              className="h-full w-full"
            />
          )}
        </div>
      </div>
    </Modal>
  )
}

function Pestana({
  activa,
  onClick,
  children,
}: {
  activa: boolean
  onClick: () => void
  children: React.ReactNode
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        'rounded-field px-3 py-1.5 text-xs font-semibold transition',
        activa ? 'bg-ink text-surface' : 'bg-surface-alt text-ink-soft hover:text-ink',
      )}
    >
      {children}
    </button>
  )
}
