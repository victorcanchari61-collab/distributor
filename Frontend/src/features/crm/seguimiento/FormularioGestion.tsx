import { CalendarClock } from 'lucide-react'
import { Input, Select, cn } from '../../../components/ui'
import { fechaCorta, hoyLocal } from '../../../lib/fechas'
import type { CatalogoSeguimiento, Gestion, TipoContacto } from '../crmApi'
import { CONTACTO_UI, HORA_POR_DEFECTO, TONOS } from '../contacto'

/** Lo que se escribe al registrar o corregir una gestión. */
export interface ValoresGestion {
  tipo: TipoContacto
  resultado: string
  comentario: string
  /** Si se programa un siguiente contacto. */
  programar: boolean
  /** Cómo será el siguiente contacto; sin elegir, sigue al tipo de la gestión de hoy. */
  proxTipo: TipoContacto | null
  fecha: string
  hora: string
  accion: string
}

export const VALORES_NUEVA_GESTION: ValoresGestion = {
  tipo: 'LLAMADA',
  resultado: '',
  comentario: '',
  programar: false,
  proxTipo: null,
  fecha: '',
  hora: HORA_POR_DEFECTO,
  accion: '',
}

/** El día y la hora (de Perú, sin zona) para la API: "2026-10-30T10:00:00". Sin día no hay siguiente contacto. */
export const comoFechaHora = (fecha: string, hora: string) => (fecha ? `${fecha}T${hora || HORA_POR_DEFECTO}:00` : undefined)

/** Los 4 tipos de contacto (llamada, WhatsApp, visita y correo) como botones. */
export function SelectorTipoContacto({ valor, onChange }: { valor: TipoContacto; onChange: (tipo: TipoContacto) => void }) {
  return (
    <div className="grid grid-cols-4 gap-2">
      {(Object.keys(CONTACTO_UI) as TipoContacto[]).map((clave) => {
        const ui = CONTACTO_UI[clave]
        const activo = valor === clave
        const Icono = ui.icono

        return (
          <button
            key={clave}
            type="button"
            aria-pressed={activo}
            onClick={() => onChange(clave)}
            className={cn(
              'flex flex-col items-center gap-1 rounded-lg border px-1 py-2 text-xs transition-colors',
              activo ? 'border-blue-500 bg-blue-50 font-semibold text-blue-700' : 'border-line bg-white text-ink-muted hover:bg-surface-alt',
            )}
          >
            <Icono size={17} style={{ color: ui.color }} />
            {ui.corto}
          </button>
        )
      })}
    </div>
  )
}

/** El interruptor "¿Deseas programar un próximo seguimiento?". */
function Interruptor({ activo, onChange }: { activo: boolean; onChange: (activo: boolean) => void }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={activo}
      onClick={() => onChange(!activo)}
      className={cn('relative h-6 w-11 shrink-0 rounded-full transition-colors', activo ? 'bg-blue-500' : 'bg-slate-300')}
    >
      <span className={cn('absolute top-0.5 left-0.5 size-5 rounded-full bg-white shadow transition-transform', activo && 'translate-x-5')} />
    </button>
  )
}

const etiqueta = 'mb-1.5 text-xs font-semibold text-ink-muted'

/**
 * Los campos de una gestión, para registrar una nueva y para corregir una hecha: cómo fue el contacto, en qué quedó,
 * qué se habló y —aparte, en azul— cuándo y cómo se vuelve a contactar al cliente.
 */
export function FormularioGestion({
  valores,
  onChange,
  catalogo,
  alAbrirGuia,
  yaCumplida,
  aviso,
}: {
  valores: ValoresGestion
  onChange: (cambios: Partial<ValoresGestion>) => void
  catalogo: CatalogoSeguimiento | null
  alAbrirGuia: () => void
  /** Su siguiente contacto ya se cumplió: es historia, solo se puede retocar la acción. */
  yaCumplida?: { proximo: string | null; tipo: string | null }
  /** Algo que quien guarda debe saber antes (por ejemplo, que reemplaza otro contacto programado). */
  aviso?: string | null
}) {
  const elegido = catalogo?.resultados.find((r) => r.clave === valores.resultado)
  const proxTipo = valores.proxTipo ?? valores.tipo

  return (
    <div className="space-y-4">
      <div>
        <p className={etiqueta}>Tipo de contacto</p>
        <SelectorTipoContacto valor={valores.tipo} onChange={(tipo) => onChange({ tipo })} />
      </div>

      <div>
        <div className={cn(etiqueta, 'flex items-center justify-between')}>
          <span>Resultado</span>
          <button type="button" onClick={alAbrirGuia} className="text-xs font-medium text-sky-600 hover:underline">
            ¿Cuándo elegir cada uno?
          </button>
        </div>
        <Select aria-label="Resultado" value={valores.resultado} onChange={(e) => onChange({ resultado: e.target.value })}>
          <option value="">Selecciona el resultado</option>
          {(catalogo?.resultados ?? []).map((r) => (
            <option key={r.clave} value={r.clave}>
              {r.etiqueta}
            </option>
          ))}
        </Select>
        {elegido && (
          <p className="mt-1.5 flex items-start gap-1.5 text-xs text-ink-muted">
            <span className="mt-1 size-2 shrink-0 rounded-full" style={{ backgroundColor: TONOS[elegido.tono].color }} />
            {elegido.cuando}
          </p>
        )}
      </div>

      <div>
        <p className={etiqueta}>Comentario</p>
        <textarea
          rows={3}
          maxLength={500}
          value={valores.comentario}
          onChange={(e) => onChange({ comentario: e.target.value })}
          placeholder="Escribe un breve comentario..."
          className="w-full rounded-field border border-line px-3 py-2 text-sm"
        />
        <p className="text-right text-[11px] text-ink-soft">{valores.comentario.length} / 500</p>
      </div>

      {yaCumplida ? (
        // Ya se cumplió: se ve lo que se prometió, sin poder moverlo.
        <div className="rounded-xl border border-line bg-surface-alt px-3 py-3">
          <p className="text-xs font-semibold text-ink-muted">Siguiente contacto (ya cumplido)</p>
          <p className="mt-1 text-sm text-ink">
            {yaCumplida.proximo ?? '—'}
            {yaCumplida.tipo ? ` · ${yaCumplida.tipo}` : ''}
          </p>
          <Input
            className="mt-2"
            maxLength={150}
            value={valores.accion}
            onChange={(e) => onChange({ accion: e.target.value })}
            placeholder="¿Qué se iba a hacer? Ej.: Enviar cotización"
            aria-label="Acción"
          />
        </div>
      ) : (
        <div className="rounded-xl border border-blue-200 bg-blue-50">
          <div className="flex items-center gap-3 px-3 py-2.5">
            <span className="flex size-8 shrink-0 items-center justify-center rounded-full bg-blue-100 text-blue-600">
              <CalendarClock size={16} />
            </span>
            <div className="min-w-0 flex-1 leading-tight">
              <p className="text-sm font-semibold text-ink">¿Deseas programar un próximo seguimiento?</p>
              <p className="text-xs text-ink-muted">Aquí defines qué tipo de contacto harás y cuándo.</p>
            </div>
            <Interruptor activo={valores.programar} onChange={(programar) => onChange({ programar })} />
          </div>

          {valores.programar && (
            <div className="space-y-3 border-t border-blue-100 px-3 py-3">
              <div>
                <p className={etiqueta}>Tipo de próximo contacto</p>
                <SelectorTipoContacto valor={proxTipo} onChange={(tipo) => onChange({ proxTipo: tipo })} />
              </div>

              <div className="grid grid-cols-[1fr_8rem] gap-2">
                <Input
                  label="Fecha del próximo seguimiento"
                  type="date"
                  min={hoyLocal()}
                  value={valores.fecha}
                  onChange={(e) => onChange({ fecha: e.target.value })}
                />
                <Input
                  label="Hora (opcional)"
                  type="time"
                  step={900}
                  value={valores.hora}
                  onChange={(e) => onChange({ hora: e.target.value })}
                />
              </div>

              <Input
                label="¿Qué harás en ese contacto? (opcional)"
                maxLength={150}
                placeholder="Ej.: Enviar cotización"
                value={valores.accion}
                onChange={(e) => onChange({ accion: e.target.value })}
              />

              {aviso && <p className="rounded-md bg-amber-50 px-2 py-1.5 text-xs text-amber-700">{aviso}</p>}
            </div>
          )}
        </div>
      )}
    </div>
  )
}

/** Un contacto programado escrito para el aviso: "el 30/10/2026". */
export const textoDelProximo = (g: Gestion | null) => (g?.proximoSeguimiento ? `el ${fechaCorta(g.proximoSeguimiento)}` : '')
