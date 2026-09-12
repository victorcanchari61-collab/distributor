import { useState } from 'react'
import { FileText, Printer, Receipt } from 'lucide-react'
import { Alert } from './Alert'
import { Button } from './Button'
import { Modal } from './Modal'
import { RowAction } from './RowAction'
import { ApiError, descargarArchivo } from '../../lib/apiClient'

/** Los documentos que se pueden imprimir, con la ruta que los sirve. */
export type DocumentoPdf = 'pedido' | 'notaventa' | 'ordencompra' | 'compra'

export interface AccionPdfProps {
  documento: DocumentoPdf
  id: number
  /** El número visible — sale en el título del diálogo y en el archivo. */
  numero: string
}

/**
 * El botón de PDF de la columna Acciones.
 *
 * Pregunta el formato en vez de dar uno solo, porque los dos se usan de
 * verdad: la hoja A4 para archivar y para el proveedor, y el ticket de 80 mm
 * para el rollo de la camioneta. Un único botón obligaría a elegir por el
 * usuario, y quien reparte necesita el otro.
 *
 * La elección se pide con un diálogo y no con un menú flotante porque estas
 * pantallas se usan también en móvil, donde un menú al borde de la tabla queda
 * fuera de la pantalla o debajo del dedo.
 */
export function AccionPdf({ documento, id, numero }: AccionPdfProps) {
  const [abierto, setAbierto] = useState(false)
  const [bajando, setBajando] = useState<'a4' | 'ticket' | null>(null)
  const [error, setError] = useState('')

  const bajar = async (formato: 'a4' | 'ticket') => {
    setError('')
    setBajando(formato)
    try {
      const query = formato === 'ticket' ? '?formato=ticket' : ''
      await descargarArchivo(`/${documento}/${id}/pdf${query}`, `${documento}-${numero}.pdf`)
      setAbierto(false)
    } catch (e) {
      // El 403 ya abre por su cuenta el modal de pedir permiso; aquí solo hay
      // que decir por qué no se bajó nada.
      setError(e instanceof ApiError ? e.message : 'No pudimos generar el PDF.')
    } finally {
      setBajando(null)
    }
  }

  return (
    <>
      <RowAction label={`PDF de ${numero}`} tone="neutral" onClick={() => setAbierto(true)}>
        <FileText size={15} />
      </RowAction>

      <Modal
        open={abierto}
        size="sm"
        title={`Imprimir ${numero}`}
        description="Elige el papel en el que se va a imprimir."
        onClose={() => setAbierto(false)}
        footer={
          <Button variant="secondary" size="sm" onClick={() => setAbierto(false)}>
            Cancelar
          </Button>
        }
      >
        <div className="flex flex-col gap-3">
          {error && <Alert>{error}</Alert>}

          <Opcion
            icono={<Printer size={18} />}
            titulo="Hoja A4"
            nota="Impresora de oficina. Lleva el detalle completo y espacio para firmar."
            cargando={bajando === 'a4'}
            onClick={() => void bajar('a4')}
          />

          <Opcion
            icono={<Receipt size={18} />}
            titulo="Ticket 80 mm"
            nota="Rollo térmico del reparto. Más corto, pensado para entregar en mano."
            cargando={bajando === 'ticket'}
            onClick={() => void bajar('ticket')}
          />
        </div>
      </Modal>
    </>
  )
}

function Opcion({
  icono,
  titulo,
  nota,
  cargando,
  onClick,
}: {
  icono: React.ReactNode
  titulo: string
  nota: string
  cargando: boolean
  onClick: () => void
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={cargando}
      className="flex items-start gap-3 rounded-field border border-line p-3 text-left transition hover:border-ink-soft disabled:opacity-60"
    >
      <span className="mt-0.5 text-ink-soft">{icono}</span>
      <span className="flex flex-col">
        <span className="text-sm font-semibold text-ink">
          {titulo}
          {cargando && <span className="ml-2 text-xs font-normal text-ink-soft">generando...</span>}
        </span>
        <span className="text-xs text-ink-soft">{nota}</span>
      </span>
    </button>
  )
}
