import { Component, Suspense } from 'react'
import type { ErrorInfo, ReactNode } from 'react'
import { TriangleAlert } from 'lucide-react'
import { idPanel, idPestana } from './estadoPestanas'

/** Si una pestaña se rompe, se rompe sola: las demás siguen funcionando. */
class ErrorDePestana extends Component<{ children: ReactNode }, { error: boolean }> {
  state = { error: false }

  static getDerivedStateFromError() {
    return { error: true }
  }

  componentDidCatch(error: unknown, info: ErrorInfo) {
    console.error(error, info.componentStack)
  }

  render() {
    if (!this.state.error) return this.props.children
    return (
      <div className="flex flex-col items-center gap-2 py-24 text-center">
        <TriangleAlert size={32} className="text-amber-500" />
        <p className="text-base font-semibold text-ink">Esta pantalla tuvo un problema</p>
        <p className="max-w-sm text-sm text-ink-muted">Ciérrala y vuelve a abrirla. Las demás pestañas siguen bien.</p>
      </div>
    )
  }
}

/**
 * El contenido de las pestañas abiertas. Todas siguen montadas aunque no se vean (solo se ocultan): al volver a una,
 * conserva su estado (filtros, página de la tabla, lo escrito en un formulario). Una pestaña se monta la primera vez
 * que se abre, no antes. Cada una tiene su propio Suspense: abrir una pantalla nueva no tapa las demás mientras carga.
 */
export function ContenidoPestanas({
  claves,
  activa,
  pintar,
  cargando,
  enFondo = [],
}: {
  claves: string[]
  activa: string
  pintar: (clave: string) => ReactNode
  /** Lo que se ve mientras llega el código de una pantalla. */
  cargando: ReactNode
  /**
   * Vistas montadas sin pestaña, siempre ocultas: un acceso rápido del menú pulsa ahí un botón y su modal sale encima
   * de la vista que se está usando (los modales se pintan fuera del panel). Si después se abre como pestaña, es la
   * misma vista montada: no se vuelve a cargar.
   */
  enFondo?: string[]
}) {
  const montadas = [...claves, ...enFondo.filter((c) => !claves.includes(c))]
  return (
    <>
      {montadas.map((clave) => (
        <div
          key={clave}
          role="tabpanel"
          id={idPanel(clave)}
          aria-labelledby={claves.includes(clave) ? idPestana(clave) : undefined}
          hidden={clave !== activa}
        >
          <ErrorDePestana>
            <Suspense fallback={cargando}>{pintar(clave)}</Suspense>
          </ErrorDePestana>
        </div>
      ))}
    </>
  )
}
