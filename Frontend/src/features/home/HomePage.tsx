import { Button, Logo, SystemCard } from '../../components/ui'
import type { UsuarioResponse } from '../auth/authApi'
import { SYSTEMS } from './systems'

export interface HomePageProps {
  usuario: UsuarioResponse
  onLogout: () => void
}

export function HomePage({ usuario, onLogout }: HomePageProps) {
  return (
    <div className="min-h-screen bg-surface-alt">
      <header className="sticky top-0 z-10 border-b border-line bg-surface/85 backdrop-blur">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-4 px-5 py-3 sm:px-8">
          <Logo size="sm" />
          <div className="flex items-center gap-3">
            <span className="hidden text-right sm:block">
              <span className="block text-sm font-semibold text-ink">{usuario.nombre}</span>
              <span className="block text-xs text-ink-muted">{usuario.email}</span>
            </span>
            <span
              aria-hidden="true"
              className="ui-brand inline-flex size-9 items-center justify-center rounded-full text-sm font-bold"
            >
              {usuario.nombre.charAt(0).toUpperCase()}
            </span>
            <Button variant="secondary" size="sm" onClick={onLogout}>
              Salir
            </Button>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-6xl px-5 py-10 sm:px-8 sm:py-14">
        <div className="mx-auto max-w-2xl text-center">
          <h1 className="text-3xl font-extrabold tracking-tight text-ink sm:text-4xl">
            DISTRIBUIDORA
          </h1>
          <p className="mt-2 text-sm text-ink-muted sm:text-base">Suite operativa para tu negocio</p>
          <p className="mt-5 text-sm text-ink-muted sm:text-base">
            Bienvenido, {usuario.nombre}. {SYSTEMS.length} sistemas integrados con una sola base de
            datos. Elige uno para empezar a trabajar.
          </p>
        </div>

        <section
          aria-label="Sistemas disponibles"
          className="mt-10 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3"
        >
          {SYSTEMS.map((system) => (
            <SystemCard
              key={system.key}
              icon={system.key}
              title={system.title}
              subtitle={system.subtitle}
              description={system.description}
              badge={`${system.modules} módulos`}
              from={system.from}
              to={system.to}
              aria-label={`Entrar a ${system.title}`}
              onClick={() => {
                // TODO: navegar al sistema cuando exista el router.
                console.info('abrir sistema', system.key)
              }}
            />
          ))}
        </section>
      </main>

      <footer className="border-t border-line px-5 py-6 text-center text-xs text-ink-soft sm:px-8">
        &copy; {new Date().getFullYear()} Distribuidora. Todos los derechos reservados.
      </footer>
    </div>
  )
}
