import { Building2, Mail, MapPin, MessageCircle, Phone, User } from 'lucide-react'
import { CategoriaBadge } from '../CategoriaBadge'
import type { FichaCliente } from '../crmApi'
import { whatsapp } from '../contacto'
import { ESTADOS_UI, porcentaje, soles, solesConSigno } from '../formato'
import { EtiquetaEstado } from '../piezas'

/**
 * La cabecera de la ficha, como en 7power: quién es el cliente (con su estado), cómo contactarlo y, a la derecha, cuánto
 * vendió de más o de menos del 1 de enero a hoy contra el mismo tramo del año anterior, con el rango del estado.
 */
export function FichaCabecera({ ficha }: { ficha: FichaCliente }) {
  const { cliente, periodo } = ficha
  const ui = ESTADOS_UI[cliente.estado.clave]
  const Icono = cliente.tipo === 'Empresa' ? Building2 : User

  const datos = [cliente.codigo, `${cliente.tipoDoc === 'RUC' ? 'RUC' : 'DNI'} ${cliente.documento}`, cliente.categoria, cliente.ciudad].filter(Boolean)

  const sinComparacion = cliente.estado.clave === 'SIN_BASE' || periodo.caidaPct === null
  const cayo = (periodo.caidaPct ?? 0) > 0

  return (
    <section className="rounded-panel border border-line bg-white p-4 sm:p-5">
      <div className="flex flex-wrap items-center gap-4">
        <span className="flex size-16 shrink-0 items-center justify-center rounded-2xl bg-violet-100 text-violet-500">
          <Icono size={30} />
        </span>

        <div className="min-w-0 flex-1 space-y-1.5">
          <div className="flex flex-wrap items-center gap-3">
            <h2 className="text-2xl leading-tight font-bold text-ink">{cliente.nombre}</h2>
            <EtiquetaEstado estado={cliente.estado.clave} />
            {!cliente.activo && <span className="rounded-md bg-slate-100 px-2 py-0.5 text-xs font-semibold text-slate-600">Inactivo</span>}
          </div>

          <p className="flex flex-wrap items-center gap-x-1.5 text-sm text-ink-muted">
            {datos.map((d, i) => (
              <span key={i} className="flex items-center gap-1.5">
                {i > 0 && <span className="text-ink-soft/50">|</span>}
                {d}
              </span>
            ))}
            {cliente.categoriaCodigo && (
              <CategoriaBadge codigo={cliente.categoriaCodigo} nombre={null} color={cliente.categoriaColor} className="ml-1" />
            )}
          </p>

          <div className="flex flex-wrap items-center gap-x-5 gap-y-1 text-sm text-ink-muted">
            {cliente.telefono && (
              <span className="flex items-center gap-1.5">
                <a href={`tel:${cliente.telefono.replace(/[^\d+]/g, '')}`} className="flex items-center gap-1.5 hover:text-sky-600">
                  <Phone size={14} className="text-sky-500" /> {cliente.telefono}
                </a>
                <a
                  href={`https://wa.me/${whatsapp(cliente.telefono)}`}
                  target="_blank"
                  rel="noreferrer"
                  title="WhatsApp"
                  aria-label="WhatsApp"
                  className="text-emerald-600 hover:text-emerald-700"
                >
                  <MessageCircle size={15} />
                </a>
              </span>
            )}
            {cliente.email && (
              <a href={`mailto:${cliente.email}`} className="flex items-center gap-1.5 hover:text-sky-600">
                <Mail size={14} className="text-sky-500" /> {cliente.email}
              </a>
            )}
            {cliente.direccion && (
              <span className="flex items-center gap-1.5">
                <MapPin size={14} className="text-sky-500" /> {cliente.direccion}
              </span>
            )}
          </div>
        </div>

        {/* El estado: lo vendido de más o de menos contra el mismo tramo del año anterior. */}
        <div className="w-full shrink-0 sm:w-72">
          <div className="flex items-start gap-3 rounded-panel border p-4" style={{ borderColor: `${ui.color}55`, backgroundColor: ui.fondo }}>
            <div className="min-w-0 flex-1">
              <p className="text-xs font-semibold" style={{ color: ui.color }}>
                {ui.etiqueta} <span className="font-normal text-ink-soft">{sinComparacion ? '' : ui.rango}</span>
              </p>
              {sinComparacion ? (
                <>
                  <p className="mt-0.5 text-2xl font-extrabold text-slate-500">—</p>
                  <p className="text-xs text-ink-soft">No compró del {periodo.etiquetaAnterior}</p>
                </>
              ) : (
                <>
                  <p className="mt-0.5 text-2xl leading-tight font-extrabold tabular-nums" style={{ color: ui.color }}>
                    {solesConSigno(periodo.variacion)}
                  </p>
                  <p className="text-xs text-ink-muted">
                    {porcentaje(cayo ? -(periodo.caidaPct ?? 0) : Math.abs(periodo.caidaPct ?? 0))} frente a {periodo.etiquetaAnterior}
                  </p>
                  <p className="mt-0.5 text-[11px] text-ink-soft">Antes: {soles(periodo.ventasAnterior)}</p>
                </>
              )}
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}
