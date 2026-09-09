import { useRef, useState } from 'react'
import { ImagePlus, Trash2 } from 'lucide-react'
import { Alert, Badge, Button } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { archivoApi, urlImagen } from './flotaApi'
import type { CarpetaImagen, EstadoDocumento } from './flotaApi'

export interface CampoFotoProps {
  label: string
  /** Ruta guardada ("/uploads/..."), o null si todavía no hay foto. */
  valor: string | null
  onChange: (ruta: string | null) => void
  carpeta: CarpetaImagen
  /** Se avisa hacia arriba para que el formulario bloquee "Guardar" mientras sube. */
  onSubiendo: (subiendo: boolean) => void
  disabled?: boolean
}

/**
 * Foto de un vehículo o de un conductor.
 *
 * La imagen se sube al elegirla y en el formulario queda solo la ruta: así una
 * corrección de cualquier otro dato no reenvía el archivo entero.
 */
export function CampoFoto({
  label,
  valor,
  onChange,
  carpeta,
  onSubiendo,
  disabled,
}: CampoFotoProps) {
  const entrada = useRef<HTMLInputElement>(null)
  const [subiendo, setSubiendo] = useState(false)
  const [error, setError] = useState('')

  const elegir = async (archivo: File | undefined) => {
    if (!archivo) return

    setSubiendo(true)
    onSubiendo(true)
    setError('')
    try {
      const { ruta } = await archivoApi.subirImagen(archivo, carpeta)
      onChange(ruta)
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos subir la imagen.')
    } finally {
      setSubiendo(false)
      onSubiendo(false)
      // Se limpia para que volver a elegir el mismo archivo dispare el change.
      if (entrada.current) entrada.current.value = ''
    }
  }

  return (
    <div className="flex flex-col gap-2">
      <span className="ui-label">
        {label}
        <span className="ml-1.5 font-normal text-ink-soft">(opcional)</span>
      </span>

      {error && <Alert>{error}</Alert>}

      <div className="flex items-center gap-3">
        <div className="flex size-20 shrink-0 items-center justify-center overflow-hidden rounded-field border border-line bg-slate-50">
          {valor ? (
            <img src={urlImagen(valor)} alt={label} className="size-full object-cover" />
          ) : (
            <ImagePlus size={22} className="text-ink-soft" />
          )}
        </div>

        <div className="flex flex-col items-start gap-1.5">
          <Button
            variant="secondary"
            size="sm"
            loading={subiendo}
            disabled={disabled}
            onClick={() => entrada.current?.click()}
          >
            {valor ? 'Cambiar foto' : 'Subir foto'}
          </Button>

          {valor && !subiendo && (
            <Button
              variant="secondary"
              size="sm"
              disabled={disabled}
              iconRight={<Trash2 size={14} />}
              onClick={() => onChange(null)}
            >
              Quitar
            </Button>
          )}

          <span className="text-xs text-ink-soft">JPG, PNG o WEBP. Hasta 5 MB.</span>
        </div>
      </div>

      <input
        ref={entrada}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={(e) => void elegir(e.target.files?.[0])}
      />
    </div>
  )
}

const TEXTO_ESTADO: Record<EstadoDocumento, string> = {
  vencido: 'Vencido',
  porVencer: 'Por vencer',
  alDia: 'Al día',
  sinFecha: 'Sin fecha',
}

const TONO_ESTADO = {
  vencido: 'danger',
  porVencer: 'warning',
  alDia: 'success',
  sinFecha: 'neutral',
} as const

/** El estado ya viene calculado del servidor: aquí solo se pinta. */
export function BadgeEstadoDocumentos({ estado }: { estado: EstadoDocumento }) {
  return <Badge tone={TONO_ESTADO[estado]}>{TEXTO_ESTADO[estado]}</Badge>
}
