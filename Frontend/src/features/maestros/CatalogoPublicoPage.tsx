import { useEffect } from 'react'
import { Phone } from 'lucide-react'
import { Logo } from '../../components/ui'
import { CatalogoVista } from './CatalogoVista'
import { useCatalogo } from './useCatalogo'

/**
 * El catálogo que los clientes abren con un enlace (`/catalogo`): sin cuenta, sin menú del panel y sin llamar a
 * nada que pida sesión. Solo se consulta —fotos, presentaciones y precios—; no hay carrito ni compra.
 */
export function CatalogoPublicoPage() {
  const { datos, cargando, error } = useCatalogo()

  useEffect(() => {
    const anterior = document.title
    document.title = datos?.empresa ? `Catálogo · ${datos.empresa}` : 'Catálogo'
    return () => {
      document.title = anterior
    }
  }, [datos?.empresa])

  return (
    // data-sys da el color del acento (los chips, el precio activo) igual que en el panel.
    <div data-sys="maestros" className="min-h-screen bg-surface-alt">
      <header className="bg-gradient-to-br from-navy to-navy-deep text-white">
        <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-x-6 gap-y-3 px-4 py-5 sm:px-6 sm:py-7">
          <div className="flex items-center gap-4">
            <Logo variant="emblem" size={52} className="shrink-0" />
            <div>
              <h1 className="text-xl font-bold tracking-tight sm:text-2xl">{datos?.empresa || 'Catálogo'}</h1>
              <p className="text-sm text-white/75">Catálogo de productos y precios</p>
            </div>
          </div>

          {datos?.telefono && (
            <a
              href={`tel:${datos.telefono.replace(/[^\d+]/g, '')}`}
              className="inline-flex items-center gap-2 rounded-full bg-white/10 px-4 py-2 text-sm font-medium ring-1 ring-white/20 transition hover:bg-white/20"
            >
              <Phone className="size-4" />
              {datos.telefono}
            </a>
          )}
        </div>
      </header>

      <main className="mx-auto max-w-7xl px-4 py-5 sm:px-6 sm:py-7">
        <CatalogoVista datos={datos} cargando={cargando} error={error} />
      </main>

      <footer className="mx-auto max-w-7xl px-4 pb-8 text-center text-xs text-ink-soft sm:px-6">
        Precios en soles (S/), sujetos a cambio sin previo aviso. Las imágenes son referenciales.
      </footer>
    </div>
  )
}
