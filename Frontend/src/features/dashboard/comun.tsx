import { useCallback, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { RefreshCw } from 'lucide-react'
import { Button, DateRangePicker, PageHeader, cn } from '../../components/ui'
import { SEMAFORO } from '../../components/charts'
import { ApiError } from '../../lib/apiClient'
import { desplazarDias, hoyLocal } from '../../lib/fechas'

// ------------------------------------------------------------------- Período

export interface Periodo {
  id: string
  etiqueta: string
  desde: string
  hasta: string
}

function periodos(): Periodo[] {
  const hoy = hoyLocal()
  return [
    { id: '7', etiqueta: '7 días', desde: desplazarDias(-6), hasta: hoy },
    { id: '30', etiqueta: '30 días', desde: desplazarDias(-29), hasta: hoy },
    { id: 'mes', etiqueta: 'Este mes', desde: `${hoy.slice(0, 8)}01`, hasta: hoy },
    { id: '90', etiqueta: '90 días', desde: desplazarDias(-89), hasta: hoy },
  ]
}

/** Cuántos días abarca un rango, ambos extremos incluidos. */
function diasDe(desde: string, hasta: string): number {
  const [a, b] = [desde, hasta].map((f) => {
    const [y, m, d] = f.split('-').map(Number)
    return new Date(y, m - 1, d).getTime()
  })
  return Math.round((b - a) / 86_400_000) + 1
}

/**
 * El período que mira un dashboard y el contador con el que "Actualizar" vuelve a pedir los
 * datos. Cada dashboard tiene el suyo: cambiar el rango de Ventas no mueve el de Cobranza.
 */
export function useTablero() {
  const opciones = useMemo(periodos, [])
  const [periodo, setPeriodo] = useState<Periodo>(opciones[1])
  const [version, setVersion] = useState(0)

  const cambiarRango = useCallback((d: string, h: string) => {
    if (d && h) setPeriodo({ id: 'custom', etiqueta: 'Personalizado', desde: d, hasta: h })
  }, [])

  return {
    opciones,
    periodo,
    elegir: setPeriodo,
    cambiarRango,
    desde: periodo.desde,
    hasta: periodo.hasta,
    dias: diasDe(periodo.desde, periodo.hasta),
    version,
    refrescar: () => setVersion((v) => v + 1),
  }
}

export type Tablero = ReturnType<typeof useTablero>

// ---------------------------------------------------------------------- Datos

export interface Bloque<T> {
  datos: T | null
  cargando: boolean
  error: string
}

/**
 * Carga los datos de un dashboard: mientras llegan muestra el esqueleto, si fallan lo dice en
 * pantalla, y si la persona cambia el período antes de que lleguen, la respuesta vieja se
 * descarta en vez de pisar la nueva.
 */
export function useBloque<T>(cargar: () => Promise<T>, dependencias: unknown[]): Bloque<T> {
  const [estado, setEstado] = useState<Bloque<T>>({ datos: null, cargando: true, error: '' })

  useEffect(() => {
    let vigente = true
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setEstado((e) => ({ ...e, cargando: true, error: '' }))
    cargar()
      .then((datos) => vigente && setEstado({ datos, cargando: false, error: '' }))
      .catch(
        (e) =>
          vigente &&
          setEstado({
            datos: null,
            cargando: false,
            error: e instanceof ApiError ? e.message : 'No pudimos cargar este dashboard.',
          }),
      )
    return () => {
      vigente = false
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, dependencias)

  return estado
}

// ------------------------------------------------------------------ Estructura

/**
 * Cabecera común: título, botón Actualizar y, si el dashboard depende de un rango, los atajos de
 * período (7 días, 30 días, este mes, 90 días) con el selector de fechas para uno propio.
 */
export function Encabezado({
  icono,
  titulo,
  descripcion,
  tablero,
  sinPeriodo = false,
}: {
  icono: ReactNode
  titulo: string
  descripcion: string
  tablero: Tablero
  /** Inventario es una foto de hoy: no tiene rango que elegir. */
  sinPeriodo?: boolean
}) {
  return (
    <div className="space-y-4">
      <PageHeader
        icon={icono}
        title={titulo}
        description={descripcion}
        actions={
          <Button variant="secondary" size="sm" onClick={tablero.refrescar}>
            <RefreshCw size={14} />
            Actualizar
          </Button>
        }
      />

      {!sinPeriodo && (
        <div className="flex flex-wrap items-center gap-2">
          <div className="flex flex-wrap gap-1.5" role="group" aria-label="Período">
            {tablero.opciones.map((o) => (
              <button
                key={o.id}
                type="button"
                onClick={() => tablero.elegir(o)}
                className={cn(
                  'cursor-pointer rounded-full border px-3 py-1.5 text-xs font-semibold transition-colors',
                  tablero.periodo.id === o.id
                    ? 'border-transparent bg-[rgb(var(--sys-rgb))] text-[var(--sys-on)]'
                    : 'border-line bg-white text-ink-muted hover:bg-surface-alt',
                )}
              >
                {o.etiqueta}
              </button>
            ))}
          </div>

          <div className="w-56 max-w-full">
            <DateRangePicker from={tablero.desde} to={tablero.hasta} onChange={tablero.cambiarRango} />
          </div>
        </div>
      )}
    </div>
  )
}

/** La fila de indicadores de arriba, con su esqueleto mientras carga. */
export function FilaKpi({ cargando, children }: { cargando: boolean; children: ReactNode }) {
  return (
    <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
      {cargando
        ? Array.from({ length: 4 }, (_, i) => (
            <div key={i} className="h-[132px] animate-pulse rounded-panel bg-surface-alt" aria-busy="true" />
          ))
        : children}
    </div>
  )
}

export const rejilla = (columnas: 2 | 3) => cn('grid gap-4', columnas === 3 ? 'lg:grid-cols-3' : 'lg:grid-cols-2')

/** "+12% frente a los 30 días anteriores": la conclusión de un gráfico en palabras. */
export function frase(cambio: number | null, contra: string): string {
  if (cambio === null) return `Sin ${contra} con qué comparar`
  const abs = Math.abs(cambio).toLocaleString('es-PE', { maximumFractionDigits: 0 })
  if (Math.abs(cambio) < 0.5) return `Igual que ${contra}`
  return `${cambio > 0 ? '+' : '−'}${abs}% frente a ${contra}`
}

export function mediana(valores: number[]): number {
  if (valores.length === 0) return 0
  const orden = [...valores].sort((a, b) => a - b)
  const m = Math.floor(orden.length / 2)
  return orden.length % 2 ? orden[m] : (orden[m - 1] + orden[m]) / 2
}

// -------------------------------------------------------------------- Colores

export const COLOR_SALUD: Record<string, string> = {
  Agotado: '#991b1b',
  Crítico: SEMAFORO.mal,
  Atención: SEMAFORO.alerta,
  Sano: SEMAFORO.bien,
  Sobrestock: '#7c3aed',
  'Sin rotación': SEMAFORO.neutro,
}

/** De lo reciente a lo vencido: verde a rojo. */
export const COLOR_DEUDA = [SEMAFORO.bien, '#65a30d', SEMAFORO.alerta, '#ea580c', SEMAFORO.mal]

/** Del ya vencido a lo que vence lejos: rojo a verde. */
export const COLOR_VENCE = [SEMAFORO.mal, '#ea580c', SEMAFORO.alerta, '#65a30d', SEMAFORO.bien]

export const semaforoDias = (dias: number) => (dias <= 15 ? SEMAFORO.bien : dias <= 30 ? SEMAFORO.alerta : SEMAFORO.mal)
export const semaforoCobertura = (dias: number) => (dias < 7 ? SEMAFORO.mal : dias < 15 ? SEMAFORO.alerta : SEMAFORO.bien)
