import { BookOpen, Copy, ExternalLink, Link2 } from 'lucide-react'
import { Button, PageHeader, useToast } from '../../components/ui'
import { RUTA_CATALOGO_PUBLICO } from './catalogoApi'
import { CatalogoVista } from './CatalogoVista'
import { useCatalogo } from './useCatalogo'

/**
 * Catálogo, para el equipo: el enlace público que se le manda al cliente (copiarlo o abrirlo) y una vista previa
 * de lo que va a ver. El catálogo en sí no necesita sesión: vive en `/catalogo` (ver CatalogoPublicoPage).
 */
export function CatalogoPage() {
  const toast = useToast()
  const { datos, cargando, error } = useCatalogo()

  // El enlace se arma con el origen actual: en producción el panel y el API comparten dominio.
  const enlace = `${window.location.origin}${RUTA_CATALOGO_PUBLICO}`

  const copiar = async () => {
    try {
      await navigator.clipboard.writeText(enlace)
      toast.exito('Enlace copiado. Ya puedes enviárselo al cliente.')
    } catch {
      toast.error('No se pudo copiar. Selecciona el enlace y cópialo a mano.')
    }
  }

  return (
    <div className="space-y-5">
      <PageHeader
        icon={<BookOpen className="size-5" />}
        title="Catálogo"
        description="Lo que ve el cliente: productos con fotos, presentaciones y precios. Solo consulta."
      />

      <div className="flex flex-col gap-3 rounded-2xl border border-line bg-surface p-4 shadow-sm sm:flex-row sm:items-center sm:p-5">
        <span className="hidden size-11 shrink-0 items-center justify-center rounded-full bg-[rgb(var(--sys-rgb)/0.1)] text-[rgb(var(--sys-ink-rgb))] sm:inline-flex">
          <Link2 className="size-5" />
        </span>
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold text-ink">Enlace público del catálogo</p>
          <p className="truncate text-sm text-ink-muted" title={enlace}>
            {enlace}
          </p>
          <p className="mt-0.5 text-xs text-ink-soft">Cualquiera con el enlace puede verlo, sin iniciar sesión.</p>
        </div>
        <div className="flex gap-2">
          <Button variant="secondary" onClick={() => void copiar()}>
            <Copy className="size-4" /> Copiar enlace
          </Button>
          <a href={RUTA_CATALOGO_PUBLICO} target="_blank" rel="noreferrer">
            <Button>
              <ExternalLink className="size-4" /> Abrir
            </Button>
          </a>
        </div>
      </div>

      <CatalogoVista datos={datos} cargando={cargando} error={error} />
    </div>
  )
}
