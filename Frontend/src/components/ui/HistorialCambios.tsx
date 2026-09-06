import { ScrollText } from 'lucide-react'
import { Badge } from './Badge'
import type { AccionAuditoria, AuditoriaResponse } from '../../features/config'

function accionTono(accion: AccionAuditoria) {
  return accion === 'CREADO' ? 'success' : accion === 'ELIMINADO' ? 'danger' : 'warning'
}

function accionTexto(accion: AccionAuditoria) {
  return accion === 'CREADO' ? 'Creado' : accion === 'ELIMINADO' ? 'Eliminado' : 'Editado'
}

/** Un valor de la bitácora, legible: fechas cortas, vacíos como "—". */
function formatearValor(valor: unknown): string {
  if (valor === null || valor === undefined || valor === '') return '—'
  if (typeof valor === 'boolean') return valor ? 'Sí' : 'No'
  if (typeof valor === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(valor)) {
    return new Date(valor).toLocaleString('es-PE')
  }
  if (typeof valor === 'object') return JSON.stringify(valor)
  return String(valor)
}

/** Campos legibles de una entidad técnica: para no mostrar "PrecioUnitario" tal cual. */
const ETIQUETAS: Record<string, string> = {
  Cantidad: 'Cantidad',
  CantidadPresentacion: 'Cantidad',
  PrecioUnitario: 'Precio',
  Anulado: 'Anulado',
  Observacion: 'Observación',
  ProductoId: 'Producto',
  PresentacionId: 'Presentación',
  Monto: 'Monto',
  MetodoPagoId: 'Método de pago',
  Estado: 'Estado',
}

export interface HistorialCambiosProps {
  registros: AuditoriaResponse[]
  cargando?: boolean
}

/**
 * Timeline compacto de cambios (fecha, quién, qué acción, qué campos), para
 * mostrar dentro del propio documento (Pedido, Nota de venta...) en vez de
 * mandar a Configuración → Auditoría a buscarlo.
 */
export function HistorialCambios({ registros, cargando }: HistorialCambiosProps) {
  if (cargando) {
    return <p className="py-4 text-center text-xs text-zinc-400">Cargando historial...</p>
  }

  if (registros.length === 0) {
    return (
      <p className="flex items-center gap-2 py-4 text-center text-xs text-zinc-400">
        <ScrollText size={14} />
        Todavía no hay cambios registrados.
      </p>
    )
  }

  return (
    <ul className="flex flex-col gap-2">
      {registros.map((r) => {
        const campos = Array.from(
          new Set([...Object.keys(r.valoresAnteriores ?? {}), ...Object.keys(r.valoresNuevos ?? {})]),
        )

        return (
          <li key={r.id} className="rounded-lg border border-zinc-200 bg-white px-3 py-2 text-[12.5px]">
            <div className="mb-1 flex flex-wrap items-center gap-2">
              <Badge tone={accionTono(r.accion)}>{accionTexto(r.accion)}</Badge>
              <span className="font-medium text-zinc-700">
                {r.entidad} #{r.entidadId}
              </span>
              <span className="ml-auto text-zinc-400">{new Date(r.fecha).toLocaleString('es-PE')}</span>
              <span className="text-zinc-400">· {r.usuario}</span>
            </div>

            {campos.length > 0 && (
              <ul className="flex flex-col gap-0.5 border-t border-zinc-100 pt-1.5">
                {campos.map((campo) => (
                  <li key={campo} className="flex items-center gap-2 text-zinc-600">
                    <span className="min-w-0 shrink-0 font-medium text-zinc-500">
                      {ETIQUETAS[campo] ?? campo}:
                    </span>
                    {r.accion !== 'CREADO' && (
                      <span className="truncate">{formatearValor(r.valoresAnteriores?.[campo])}</span>
                    )}
                    {r.accion === 'ACTUALIZADO' && <span className="shrink-0 text-zinc-300">→</span>}
                    {r.accion !== 'ELIMINADO' && (
                      <span className="truncate font-medium text-zinc-800">
                        {formatearValor(r.valoresNuevos?.[campo])}
                      </span>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </li>
        )
      })}
    </ul>
  )
}
