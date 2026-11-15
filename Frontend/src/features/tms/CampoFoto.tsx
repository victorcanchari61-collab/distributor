import { useRef, useState } from 'react'
import { Expand, ImagePlus, LoaderCircle, Trash2 } from 'lucide-react'
import { Alert, Badge, Button, VisorImagen, cn } from '../../components/ui'
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
  /**
   * 'fila' (por defecto): miniatura chica con los botones al lado, para un formulario angosto.
   * 'recuadro': un cuadro grande donde se hace clic o se suelta la imagen, con "Ampliar" y "Quitar" debajo; va como
   * columna al lado de los datos (la ficha del producto).
   */
  variante?: 'fila' | 'recuadro'
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
  variante = 'fila',
}: CampoFotoProps) {
  const entrada = useRef<HTMLInputElement>(null)
  const [subiendo, setSubiendo] = useState(false)
  const [error, setError] = useState('')
  // Una imagen arrastrada encima del recuadro: se resalta para que se vea que ahí se suelta.
  const [encima, setEncima] = useState(false)

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

  const input = (
    <input
      ref={entrada}
      type="file"
      accept="image/*"
      className="hidden"
      onChange={(e) => void elegir(e.target.files?.[0])}
    />
  )

  if (variante === 'recuadro') {
    const bloqueado = disabled || subiendo
    return (
      <div className="flex flex-col gap-2">
        <span className="ui-label">
          {label}
          <span className="ml-1.5 font-normal text-ink-soft">(opcional)</span>
        </span>

        {error && <Alert>{error}</Alert>}

        <button
          type="button"
          disabled={bloqueado}
          onClick={() => entrada.current?.click()}
          onDragOver={(e) => {
            e.preventDefault()
            if (!bloqueado) setEncima(true)
          }}
          onDragLeave={() => setEncima(false)}
          onDrop={(e) => {
            e.preventDefault()
            setEncima(false)
            const archivo = e.dataTransfer.files?.[0]
            if (!bloqueado && archivo?.type.startsWith('image/')) void elegir(archivo)
          }}
          aria-label={valor ? 'Cambiar la foto' : 'Subir una foto'}
          className={cn(
            'group relative aspect-square w-full overflow-hidden rounded-panel border-2 transition-colors',
            valor ? 'border-solid border-line' : 'border-dashed border-line-strong bg-slate-50',
            encima && 'border-[rgb(var(--sys-rgb))] bg-[rgb(var(--sys-rgb)/0.06)]',
            bloqueado ? 'cursor-not-allowed' : 'cursor-pointer hover:border-[rgb(var(--sys-rgb)/0.6)]',
          )}
        >
          {valor ? (
            <>
              <img src={urlImagen(valor)} alt={label} className="size-full object-cover" />
              {/* Al pasar el mouse se avisa que un clic la cambia. */}
              <span className="absolute inset-0 flex items-center justify-center bg-ink/45 text-sm font-semibold text-white opacity-0 transition-opacity group-hover:opacity-100">
                Cambiar foto
              </span>
            </>
          ) : (
            <span className="flex size-full flex-col items-center justify-center gap-2 p-4 text-center">
              <span className="grid size-11 place-items-center rounded-full bg-[rgb(var(--sys-rgb)/0.12)] text-[rgb(var(--sys-ink-rgb))]">
                <ImagePlus size={22} />
              </span>
              <span className="text-sm font-semibold text-ink">Subir foto</span>
              <span className="text-xs text-ink-soft">Haz clic o arrastra la imagen aquí</span>
            </span>
          )}

          {subiendo && (
            <span className="absolute inset-0 flex flex-col items-center justify-center gap-2 bg-white/80 text-sm font-medium text-ink">
              <LoaderCircle size={22} className="animate-spin text-[rgb(var(--sys-rgb))]" />
              Subiendo…
            </span>
          )}
        </button>

        {valor && !subiendo ? (
          <div className="flex items-center gap-2">
            <VisorImagen src={urlImagen(valor)} titulo={label} zoom={false} className="flex-1">
              <span className="inline-flex w-full items-center justify-center gap-1.5 rounded-field border border-line bg-white px-2 py-1.5 text-xs font-semibold text-ink hover:bg-slate-50">
                <Expand size={13} />
                Ampliar
              </span>
            </VisorImagen>
            <button
              type="button"
              disabled={disabled}
              onClick={() => onChange(null)}
              className="inline-flex flex-1 cursor-pointer items-center justify-center gap-1.5 rounded-field border border-line bg-white px-2 py-1.5 text-xs font-semibold text-rose-600 hover:bg-rose-50 disabled:cursor-not-allowed disabled:opacity-50"
            >
              <Trash2 size={13} />
              Quitar
            </button>
          </div>
        ) : (
          <span className="text-center text-xs text-ink-soft">JPG, PNG o WEBP. Hasta 5 MB.</span>
        )}

        {input}
      </div>
    )
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

      {input}
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
