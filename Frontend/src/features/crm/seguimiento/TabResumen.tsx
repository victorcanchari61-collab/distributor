import { CalendarClock, CalendarDays, Hash, ShoppingCart, Ticket, TrendingUp } from 'lucide-react'
import { BarChart, Marco, PALETA, moneda, variacion } from '../../../components/charts'
import { Badge, Button } from '../../../components/ui'
import { fechaCorta, fechaHora } from '../../../lib/fechas'
import type { FichaCliente } from '../crmApi'
import { colorCambio, colorDeDias, mesCorto, soles } from '../formato'
import { EtiquetaResultado, IconoContacto, TarjetaReporte } from '../piezas'

function Fila({ etiqueta, children }: { etiqueta: string; children: React.ReactNode }) {
  return (
    <div className="grid grid-cols-[9.5rem_1fr] gap-3 border-b border-line py-2 text-sm last:border-b-0">
      <span className="text-ink-soft">{etiqueta}</span>
      <span className="min-w-0 font-medium break-words text-ink">{children}</span>
    </div>
  )
}

const vacio = <span className="font-normal text-ink-soft">—</span>

function Bloque({ titulo, children, className }: { titulo: React.ReactNode; children: React.ReactNode; className?: string }) {
  return (
    <section className={`rounded-panel border border-line bg-white p-4 ${className ?? ''}`}>
      <h3 className="mb-3 text-base font-semibold text-ink">{titulo}</h3>
      {children}
    </section>
  )
}

/**
 * El Resumen de la ficha: las cuatro tarjetas de siempre (días sin comprar, ventas, compras y ticket), la información
 * del cliente, su última gestión y el próximo contacto, su última compra y en qué gasta.
 */
export function TabResumen({
  ficha,
  puedeRegistrar,
  irASeguimiento,
}: {
  ficha: FichaCliente
  puedeRegistrar: boolean
  irASeguimiento: () => void
}) {
  const { cliente, kpis, periodo, ultimaGestion: ultima, proximaGestion: proxima, productosPrincipales: productos } = ficha

  // Los 24 meses en dos años de 12: el actual (los últimos) contra el anterior, mes a mes.
  const anterior = ficha.meses.slice(0, 12)
  const actual = ficha.meses.slice(12)
  const totalActual = actual.reduce((s, m) => s + m.importe, 0)
  const totalAnterior = anterior.reduce((s, m) => s + m.importe, 0)
  const cambio = variacion(totalActual, totalAnterior)
  const sinCompras = ficha.meses.every((m) => m.importe === 0)

  const sinComprar = kpis.diasSinComprar

  return (
    <div className="space-y-4">
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <TarjetaReporte
          titulo="Sin comprar"
          valor={sinComprar === null ? 'Sin compras' : `${sinComprar} días`}
          detalle={
            kpis.ultimaCompra ? (
              <>
                desde el {fechaCorta(kpis.ultimaCompra.fecha)}
                <br />
                Última compra {kpis.ultimaCompra.documento} · {soles(kpis.ultimaCompra.monto, 2)}
              </>
            ) : (
              'aún no compró'
            )
          }
          icono={CalendarDays}
          color={colorDeDias(sinComprar)}
        />
        <TarjetaReporte
          titulo="Ventas"
          nota={periodo.etiqueta}
          valor={soles(periodo.ventas)}
          detalle={`${periodo.etiquetaAnterior}: ${soles(periodo.ventasAnterior)}`}
          icono={TrendingUp}
          color="#2563eb"
        />
        <TarjetaReporte
          titulo="N.º de compras"
          nota={periodo.etiqueta}
          valor={periodo.compras}
          detalle="solo el año actual"
          icono={Hash}
          color="#0891b2"
        />
        <TarjetaReporte
          titulo="Ticket promedio"
          nota={periodo.etiqueta}
          valor={soles(periodo.ticketPromedio, 2)}
          detalle="ventas entre N.º de compras"
          icono={Ticket}
          color="#7c3aed"
        />
      </div>

      <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_minmax(0,1.15fr)]">
        <Bloque titulo="Información general">
          <Fila etiqueta={cliente.tipo === 'Empresa' ? 'Razón social' : 'Nombre'}>{cliente.nombre}</Fila>
          <Fila etiqueta={cliente.tipoDoc === 'RUC' ? 'RUC' : 'DNI / documento'}>{cliente.documento}</Fila>
          <Fila etiqueta="Tipo de cliente">{cliente.tipo}</Fila>
          <Fila etiqueta="Vendedor">{cliente.vendedor ?? vacio}</Fila>
          <Fila etiqueta="Teléfono">{cliente.telefono ?? vacio}</Fila>
          <Fila etiqueta="Correo">{cliente.email ?? vacio}</Fila>
          <Fila etiqueta="Dirección">{cliente.direccion ?? vacio}</Fila>
          <Fila etiqueta="Ciudad">{cliente.ciudad ?? vacio}</Fila>
          <Fila etiqueta="Mercado y ruta">
            {cliente.mercado || cliente.ruta ? [cliente.mercado, cliente.ruta].filter(Boolean).join(' · ') : vacio}
          </Fila>
          <Fila etiqueta="Día de visita">{cliente.diaVisita ?? vacio}</Fila>
          <Fila etiqueta="Lista de precios">{cliente.listaPrecio ?? vacio}</Fila>
          <Fila etiqueta="Clasificación">{cliente.categoria ?? vacio}</Fila>
          <Fila etiqueta="Debe">{kpis.saldoPorCobrar > 0 ? soles(kpis.saldoPorCobrar, 2) : 'Nada'}</Fila>
          <Fila etiqueta="Estado">
            {cliente.activo ? 'Activo' : 'Inactivo'} · {cliente.estado.etiqueta}
          </Fila>
        </Bloque>

        <div className="space-y-4">
          <Bloque titulo="Última gestión">
            {ultima ? (
              <div className="flex items-start gap-3">
                <IconoContacto tipo={ultima.tipoContacto} tamano={40} />
                <div className="min-w-0 flex-1 space-y-1">
                  <div className="flex flex-wrap items-center gap-2 text-sm">
                    <span className="font-semibold text-ink">{ultima.tipoEtiqueta}</span>
                    <span className="text-ink-soft">{fechaHora(ultima.fecha)}</span>
                    <EtiquetaResultado tono={ultima.tono} texto={ultima.resultadoEtiqueta} />
                  </div>
                  {ultima.comentario && <p className="text-sm text-ink-muted">{ultima.comentario}</p>}
                  <p className="text-xs text-ink-soft">Por: {ultima.registradoPor ?? '—'}</p>
                </div>
              </div>
            ) : (
              <div className="py-4 text-center">
                <p className="text-sm text-ink-soft">Todavía no hay gestiones con este cliente</p>
                {puedeRegistrar && (
                  <Button className="mt-3" size="sm" onClick={irASeguimiento}>
                    Registrar la primera gestión
                  </Button>
                )}
              </div>
            )}
          </Bloque>

          <Bloque titulo="Próximo contacto">
            {proxima?.proximoSeguimiento ? (
              <div className="flex items-center gap-3">
                <span className="flex size-11 shrink-0 items-center justify-center rounded-xl bg-blue-50 text-blue-500">
                  <CalendarClock size={20} />
                </span>
                <div className="text-sm">
                  <div className="font-semibold text-ink">{fechaHora(proxima.proximoSeguimiento)}</div>
                  <div className="text-ink-muted">
                    {proxima.proximoTipoEtiqueta ?? proxima.tipoEtiqueta}
                    {proxima.proximaAccion ? ` · ${proxima.proximaAccion}` : ''}
                  </div>
                </div>
                <Badge tone={proxima.vencida ? 'danger' : 'sys'} className="ml-auto">
                  {proxima.vencida ? 'Vencido' : 'Programado'}
                </Badge>
              </div>
            ) : (
              <p className="text-sm text-ink-soft">No hay un contacto programado.</p>
            )}
          </Bloque>

          <div className="grid gap-4 md:grid-cols-[minmax(0,0.8fr)_minmax(0,1.2fr)]">
            <Bloque titulo="Última compra">
              {kpis.ultimaCompra ? (
                <div className="flex items-center gap-3">
                  <span className="flex size-11 shrink-0 items-center justify-center rounded-xl bg-emerald-50 text-emerald-600">
                    <ShoppingCart size={20} />
                  </span>
                  <div className="text-sm">
                    <div className="font-semibold text-ink">{fechaCorta(kpis.ultimaCompra.fecha)}</div>
                    <div className="text-ink-soft">{kpis.ultimaCompra.documento}</div>
                    <div className="font-semibold text-ink tabular-nums">{soles(kpis.ultimaCompra.monto, 2)}</div>
                  </div>
                </div>
              ) : (
                <p className="text-sm text-ink-soft">Sin compras registradas.</p>
              )}
            </Bloque>

            <Bloque
              titulo={
                <>
                  Principales productos <span className="text-xs font-normal text-ink-soft">(año actual)</span>
                </>
              }
            >
              {productos.length ? (
                <div className="max-h-[13.75rem] space-y-2 overflow-y-auto pr-2">
                  {productos.map((p) => (
                    <div key={p.producto}>
                      <div className="mb-0.5 flex justify-between gap-2 text-xs">
                        <span className="truncate text-ink-muted" title={p.codigo ? `${p.codigo} · ${p.producto}` : p.producto}>
                          {p.codigo && <span className="mr-1.5 font-semibold text-ink">{p.codigo}</span>}
                          {p.producto}
                        </span>
                        <span className="shrink-0 whitespace-nowrap text-ink-soft tabular-nums">
                          {soles(p.monto)} · {p.porcentaje.toFixed(1)} %
                        </span>
                      </div>
                      <div className="h-1.5 rounded bg-slate-100">
                        <div className="h-1.5 rounded bg-sky-500" style={{ width: `${p.porcentaje}%` }} />
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-sm text-ink-soft">Sin compras este año.</p>
              )}
            </Bloque>
          </div>
        </div>
      </div>

      <Marco
        titulo="Compras mes a mes"
        subtitulo={
          <>
            {moneda(totalActual)} en los últimos 12 meses frente a {moneda(totalAnterior)} en los 12 anteriores
            {cambio !== null && (
              <span className={`ml-1.5 font-bold ${colorCambio(cambio)}`}>
                ({cambio > 0 ? '+' : ''}
                {cambio.toLocaleString('es-PE', { maximumFractionDigits: 0 })} %)
              </span>
            )}
          </>
        }
        vacio={sinCompras}
        mensajeVacio="Este cliente no tiene compras en los últimos 24 meses"
        alto={220}
        derecha={
          <span className="flex items-center gap-3 text-[11px] text-ink-muted">
            <span className="flex items-center gap-1.5">
              <span className="size-2 rounded-sm" style={{ backgroundColor: PALETA[0] }} /> Últimos 12 meses
            </span>
            <span className="flex items-center gap-1.5">
              <span className="size-2 rounded-sm bg-slate-300" /> Año anterior
            </span>
          </span>
        }
      >
        <BarChart
          etiquetas={actual.map((m) => mesCorto(m.mes))}
          etiquetasLargas={actual.map((m, i) => `${mesCorto(m.mes)} ${m.mes.slice(0, 4)} · antes ${mesCorto(anterior[i].mes)} ${anterior[i].mes.slice(0, 4)}`)}
          series={[
            { id: 'antes', nombre: 'Año anterior', color: '#cbd5e1', valores: anterior.map((m) => m.importe) },
            { id: 'ahora', nombre: 'Últimos 12 meses', color: PALETA[0], valores: actual.map((m) => m.importe) },
          ]}
          formato={(n) => moneda(n)}
          alto={220}
        />
      </Marco>
    </div>
  )
}

