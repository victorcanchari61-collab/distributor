import { useCallback, useEffect, useMemo, useState } from 'react'
import { CalendarClock, ClipboardList, Eye, Handshake, Pencil, Phone, Repeat } from 'lucide-react'
import { Badge, Button, Input, Modal, RowAction, SysDataTable, useToast } from '../../../components/ui'
import type { DataTableColumn } from '../../../components/ui'
import { ApiError } from '../../../lib/apiClient'
import { fechaCorta, fechaHora, fechaLocal, hoyLocal, instanteMs } from '../../../lib/fechas'
import { crmApi } from '../crmApi'
import type { CatalogoSeguimiento, Gestion, GestionesCliente, TipoContacto } from '../crmApi'
import { CONTACTO_UI, HORA_POR_DEFECTO, TONOS } from '../contacto'
import { nombreCorto } from '../formato'
import { EtiquetaResultado, IconoContacto, TarjetaReporte } from '../piezas'
import { FormularioGestion, VALORES_NUEVA_GESTION, comoFechaHora, textoDelProximo } from './FormularioGestion'
import type { ValoresGestion } from './FormularioGestion'

const dos = (n: number) => String(n).padStart(2, '0')

/** Un instante del servidor como día y hora locales, para los campos de fecha y hora. */
const aLocal = (iso: string) => {
  const d = new Date(instanteMs(iso))
  return { fecha: fechaLocal(d), hora: `${dos(d.getHours())}:${dos(d.getMinutes())}` }
}

/** "hoy", "ayer" o "hace 5 días". */
const haceCuanto = (iso: string) => {
  const dias = Math.round((new Date(hoyLocal()).getTime() - new Date(fechaLocal(new Date(instanteMs(iso)))).getTime()) / 86_400_000)
  return dias <= 0 ? 'hoy' : dias === 1 ? 'ayer' : `hace ${dias} días`
}

/** "10:00 a. m." para un instante del servidor. */
const horaCorta = (iso: string) =>
  new Date(instanteMs(iso)).toLocaleTimeString('es-PE', { hour: '2-digit', minute: '2-digit' })

const mensajeDe = (e: unknown, defecto: string) => (e instanceof ApiError ? e.message : defecto)

/** Los valores del formulario a partir de una gestión que se va a corregir. */
const valoresDe = (g: Gestion): ValoresGestion => {
  const proximo = g.proximoSeguimiento ? aLocal(g.proximoSeguimiento) : null
  return {
    tipo: g.tipoContacto,
    resultado: g.resultado,
    comentario: g.comentario ?? '',
    programar: proximo !== null,
    proxTipo: g.proximoTipoContacto,
    fecha: proximo?.fecha ?? '',
    hora: proximo?.hora ?? HORA_POR_DEFECTO,
    accion: g.proximaAccion ?? '',
  }
}

/**
 * La pestaña Seguimiento: las respuestas rápidas (último contacto, resultado, próxima gestión y total del año), el
 * historial de gestiones y, al lado, el formulario para registrar una nueva.
 */
export function TabSeguimiento({
  clienteId,
  catalogo,
  puedeRegistrar,
  puedeEditar,
  alCambiar,
}: {
  clienteId: number
  catalogo: CatalogoSeguimiento | null
  puedeRegistrar: boolean
  puedeEditar: boolean
  /** Hubo un cambio: la ficha refresca su Resumen. */
  alCambiar: () => void
}) {
  const toast = useToast()
  const [datos, setDatos] = useState<GestionesCliente | null>(null)
  const [cargando, setCargando] = useState(true)

  // Registrar una nueva.
  const [nueva, setNueva] = useState<ValoresGestion>(VALORES_NUEVA_GESTION)
  const [guardando, setGuardando] = useState(false)

  // Ver, corregir y reprogramar.
  const [detalle, setDetalle] = useState<Gestion | null>(null)
  const [editando, setEditando] = useState<Gestion | null>(null)
  const [edicion, setEdicion] = useState<ValoresGestion>(VALORES_NUEVA_GESTION)
  const [guardandoEdicion, setGuardandoEdicion] = useState(false)
  const [reprogramando, setReprogramando] = useState<Gestion | null>(null)
  const [nuevoDia, setNuevoDia] = useState('')
  const [nuevaHora, setNuevaHora] = useState(HORA_POR_DEFECTO)
  const [guia, setGuia] = useState(false)

  const cargar = useCallback(async () => {
    try {
      setDatos(await crmApi.gestiones(clienteId))
    } catch (e) {
      toast.error(mensajeDe(e, 'No se pudieron cargar las gestiones'))
    } finally {
      setCargando(false)
    }
  }, [clienteId, toast])

  useEffect(() => {
    void cargar()
  }, [cargar])

  const items = datos?.items ?? []
  const proxima = datos?.proximaGestion ?? null
  const ultima = items[0] ?? null

  /** Lo que se manda a la API a partir de lo escrito; el mensaje de lo que falta si no se puede. */
  const comoCuerpo = (v: ValoresGestion) => {
    if (!v.resultado) return 'Elige el resultado de la gestión'
    if (v.programar && !v.fecha) return 'Elige la fecha del próximo seguimiento'

    return {
      tipoContacto: v.tipo,
      resultado: v.resultado,
      comentario: v.comentario.trim() || undefined,
      proximoSeguimiento: v.programar ? comoFechaHora(v.fecha, v.hora) : undefined,
      proximoTipoContacto: v.programar ? (v.proxTipo ?? v.tipo) : undefined,
      proximaAccion: v.programar ? v.accion.trim() || undefined : undefined,
    }
  }

  const guardar = async () => {
    const cuerpo = comoCuerpo(nueva)
    if (typeof cuerpo === 'string') return toast.error(cuerpo)

    setGuardando(true)
    try {
      await crmApi.registrar(clienteId, cuerpo)
      toast.exito(nueva.programar ? 'Gestión guardada y seguimiento programado' : 'Gestión guardada')
      setNueva(VALORES_NUEVA_GESTION)
      await cargar()
      alCambiar()
    } catch (e) {
      toast.error(mensajeDe(e, 'No se pudo guardar la gestión'))
    } finally {
      setGuardando(false)
    }
  }

  const abrirEditar = (g: Gestion) => {
    setEdicion(valoresDe(g))
    setEditando(g)
  }

  const cumplida = editando?.seguimientoEstado === 'CUMPLIDO'

  const guardarEdicion = async () => {
    if (!editando) return
    const cuerpo = comoCuerpo(edicion)
    if (typeof cuerpo === 'string') return toast.error(cuerpo)

    setGuardandoEdicion(true)
    try {
      // Un contacto cumplido solo acepta retocar la acción; el servidor ignora lo demás de su siguiente contacto.
      await crmApi.actualizar(editando.id, cumplida ? { ...cuerpo, proximaAccion: edicion.accion.trim() || undefined } : cuerpo)
      toast.exito('Gestión actualizada')
      setEditando(null)
      await cargar()
      alCambiar()
    } catch (e) {
      toast.error(mensajeDe(e, 'No se pudo actualizar la gestión'))
    } finally {
      setGuardandoEdicion(false)
    }
  }

  const abrirReprogramar = (g: Gestion) => {
    const actual = g.proximoSeguimiento ? aLocal(g.proximoSeguimiento) : null
    setNuevoDia(actual && actual.fecha >= hoyLocal() ? actual.fecha : '')
    setNuevaHora(actual?.hora ?? HORA_POR_DEFECTO)
    setReprogramando(g)
  }

  const reprogramar = async () => {
    if (!reprogramando || !nuevoDia) return toast.error('Elige la nueva fecha')
    try {
      await crmApi.reprogramar(reprogramando.id, comoFechaHora(nuevoDia, nuevaHora)!)
      toast.exito('Seguimiento reprogramado')
      setReprogramando(null)
      await cargar()
      alCambiar()
    } catch (e) {
      toast.error(mensajeDe(e, 'No se pudo reprogramar'))
    }
  }

  const columnas: DataTableColumn<Gestion>[] = useMemo(
    () => [
      {
        key: 'fecha',
        label: 'Fecha y hora',
        filterType: 'date',
        value: (g) => instanteMs(g.fecha),
        render: (g) => <span className="whitespace-nowrap">{fechaHora(g.fecha)}</span>,
      },
      {
        key: 'tipo',
        label: 'Tipo',
        filterType: 'select',
        filterOptions: (Object.keys(CONTACTO_UI) as TipoContacto[]).map((c) => ({ value: c, label: CONTACTO_UI[c].etiqueta })),
        value: (g) => g.tipoContacto,
        render: (g) => (
          <span className="flex items-center gap-2">
            <IconoContacto tipo={g.tipoContacto} tamano={26} />
            {CONTACTO_UI[g.tipoContacto].corto}
          </span>
        ),
      },
      {
        key: 'resultado',
        label: 'Resultado',
        filterType: 'select',
        filterOptions: (catalogo?.resultados ?? []).map((r) => ({ value: r.clave, label: r.etiqueta })),
        value: (g) => g.resultado,
        render: (g) => <EtiquetaResultado tono={g.tono} texto={g.resultadoEtiqueta} />,
      },
      {
        key: 'comentario',
        label: 'Comentario',
        filterable: false,
        render: (g) =>
          g.comentario ? <span className="line-clamp-2 max-w-xs text-ink-muted">{g.comentario}</span> : <span className="text-ink-soft">—</span>,
      },
      {
        key: 'proxima',
        label: 'Próxima gestión',
        filterable: false,
        render: (g) => {
          if (!g.proximoSeguimiento) return <span className="text-ink-soft">—</span>
          return (
            <span className="flex flex-col">
              <span className="flex items-center gap-1.5 whitespace-nowrap">
                {fechaCorta(g.proximoSeguimiento)}
                {g.seguimientoEstado === 'PROGRAMADO' && (
                  <Badge tone={g.vencida ? 'danger' : 'sys'}>{g.vencida ? 'Vencido' : 'Programado'}</Badge>
                )}
              </span>
              <span className="text-xs text-ink-soft">
                {[
                  horaCorta(g.proximoSeguimiento),
                  g.proximoTipoContacto ? CONTACTO_UI[g.proximoTipoContacto].corto : null,
                  g.proximaAccion,
                ]
                  .filter(Boolean)
                  .join(' · ')}
              </span>
            </span>
          )
        },
      },
      {
        key: 'usuario',
        label: 'Usuario',
        filterable: false,
        render: (g) => (g.registradoPor ? <span title={g.registradoPor}>{nombreCorto(g.registradoPor)}</span> : <span className="text-ink-soft">—</span>),
      },
    ],
    [catalogo],
  )

  const aviso =
    edicion.programar && proxima && editando && proxima.id !== editando.id
      ? `El cliente ya tiene un contacto programado ${textoDelProximo(proxima)}; al guardar, ese pasa a cumplido y queda este.`
      : null

  return (
    <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_23.75rem]">
      {/* Respuestas rápidas: último contacto, resultado, próxima gestión y total de gestiones del año. */}
      <div className="grid gap-4 sm:grid-cols-2 xl:col-span-2 xl:grid-cols-4">
        <TarjetaReporte
          titulo="Último contacto"
          valor={ultima ? fechaCorta(ultima.fecha) : '—'}
          detalle={ultima ? `${haceCuanto(ultima.fecha)} • ${CONTACTO_UI[ultima.tipoContacto].corto}` : 'sin gestiones'}
          icono={Phone}
          color="#16a34a"
        />
        <TarjetaReporte
          titulo="Resultado"
          valor={ultima ? <EtiquetaResultado tono={ultima.tono} texto={ultima.resultadoEtiqueta} /> : '—'}
          detalle={ultima ? (catalogo?.resultados.find((r) => r.clave === ultima.resultado)?.cuando ?? ultima.tipoEtiqueta) : 'sin gestiones'}
          icono={Handshake}
          color={ultima ? TONOS[ultima.tono].color : '#64748b'}
        />
        <TarjetaReporte
          titulo="Próxima gestión"
          valor={proxima?.proximoSeguimiento ? fechaCorta(proxima.proximoSeguimiento) : '—'}
          detalle={
            proxima?.proximoSeguimiento
              ? `${proxima.vencida ? 'Vencida · ' : ''}${horaCorta(proxima.proximoSeguimiento)} · ${
                  proxima.proximoTipoContacto ? CONTACTO_UI[proxima.proximoTipoContacto].corto : proxima.tipoEtiqueta
                }${proxima.proximaAccion ? ` · ${proxima.proximaAccion}` : ''}`
              : 'sin contacto programado'
          }
          icono={CalendarClock}
          color={proxima?.vencida ? '#dc2626' : '#2563eb'}
        />
        <TarjetaReporte
          titulo="Gestiones del año"
          valor={datos?.totalAnio ?? 0}
          detalle={datos ? `desde el ${fechaCorta(datos.desdeAnio)}` : undefined}
          icono={ClipboardList}
          color="#7c3aed"
        />
      </div>

      {/* Historial de gestiones. */}
      <section className="min-w-0 rounded-panel border border-line bg-white p-4">
        <h3 className="mb-3 text-base font-semibold text-ink">Historial de gestiones</h3>

        <SysDataTable
          columns={columnas}
          rows={items}
          rowKey="id"
          searchPlaceholder="Buscar en el historial..."
          pageSize={8}
          empty={cargando ? 'Cargando gestiones...' : items.length ? 'No hay gestiones con esos filtros' : 'Todavía no hay gestiones con este cliente'}
          actionsWidth={110}
          actions={(g) => (
            <>
              <RowAction label="Ver detalle" tone="view" onClick={() => setDetalle(g)}>
                <Eye size={16} />
              </RowAction>
              {puedeEditar && (
                <RowAction label="Editar" tone="edit" onClick={() => abrirEditar(g)}>
                  <Pencil size={16} />
                </RowAction>
              )}
              {puedeEditar && g.seguimientoEstado === 'PROGRAMADO' && (
                <RowAction label="Reprogramar" tone="warning" onClick={() => abrirReprogramar(g)}>
                  <Repeat size={16} />
                </RowAction>
              )}
            </>
          )}
        />
      </section>

      {/* Registrar nueva gestión. */}
      <section className="h-fit rounded-panel border border-line bg-white p-4">
        <h3 className="mb-3 text-base font-semibold text-ink">Registrar nueva gestión</h3>

        {puedeRegistrar ? (
          <div className="space-y-4">
            <FormularioGestion
              valores={nueva}
              onChange={(c) => setNueva((v) => ({ ...v, ...c }))}
              catalogo={catalogo}
              alAbrirGuia={() => setGuia(true)}
            />

            {!nueva.programar && (
              <p className="rounded-lg bg-surface-alt px-3 py-2.5 text-xs text-ink-muted">
                <b className="text-ink">Se registra la gestión de hoy.</b> Si no necesitas otro contacto por ahora, solo guardas.
              </p>
            )}

            <Button block loading={guardando} disabled={!nueva.resultado || (nueva.programar && !nueva.fecha)} onClick={guardar}>
              {nueva.programar ? 'Guardar gestión y programar' : 'Guardar gestión'}
            </Button>
          </div>
        ) : (
          <p className="text-sm text-ink-soft">No tienes permiso para registrar gestiones.</p>
        )}
      </section>

      <Modal open={detalle !== null} title="Detalle de la gestión" size="md" onClose={() => setDetalle(null)}>
        {detalle && (
          <dl className="divide-y divide-line text-sm">
            {[
              ['Fecha y hora', fechaHora(detalle.fecha)],
              ['Tipo de contacto', detalle.tipoEtiqueta],
              ['Resultado', <EtiquetaResultado key="r" tono={detalle.tono} texto={detalle.resultadoEtiqueta} />],
              ['Comentario', detalle.comentario ?? '—'],
              ['Próxima gestión', detalle.proximoSeguimiento ? fechaHora(detalle.proximoSeguimiento) : '—'],
              ['Tipo del próximo contacto', detalle.proximoTipoEtiqueta ?? '—'],
              ['Próxima acción', detalle.proximaAccion ?? '—'],
              ['Registrado por', detalle.registradoPor ?? '—'],
            ].map(([k, v]) => (
              <div key={String(k)} className="grid grid-cols-[10rem_1fr] gap-3 py-2">
                <dt className="text-ink-soft">{k}</dt>
                <dd className="font-medium text-ink">{v}</dd>
              </div>
            ))}
          </dl>
        )}
      </Modal>

      <Modal
        open={editando !== null}
        title="Editar la gestión"
        size="md"
        onClose={() => setEditando(null)}
        footer={
          <>
            <Button variant="secondary" onClick={() => setEditando(null)}>
              Cancelar
            </Button>
            <Button
              loading={guardandoEdicion}
              disabled={!edicion.resultado || (!cumplida && edicion.programar && !edicion.fecha)}
              onClick={guardarEdicion}
            >
              Guardar cambios
            </Button>
          </>
        }
      >
        {editando && (
          <FormularioGestion
            valores={edicion}
            onChange={(c) => setEdicion((v) => ({ ...v, ...c }))}
            catalogo={catalogo}
            alAbrirGuia={() => setGuia(true)}
            aviso={aviso}
            yaCumplida={
              cumplida && editando.proximoSeguimiento
                ? { proximo: fechaHora(editando.proximoSeguimiento), tipo: editando.proximoTipoEtiqueta }
                : undefined
            }
          />
        )}
      </Modal>

      <Modal
        open={reprogramando !== null}
        title="Reprogramar el siguiente contacto"
        size="sm"
        onClose={() => setReprogramando(null)}
        footer={
          <>
            <Button variant="secondary" onClick={() => setReprogramando(null)}>
              Cancelar
            </Button>
            <Button onClick={reprogramar}>Guardar</Button>
          </>
        }
      >
        <div className="grid grid-cols-[1fr_8rem] gap-2 py-1">
          <Input label="Fecha" type="date" min={hoyLocal()} value={nuevoDia} onChange={(e) => setNuevoDia(e.target.value)} />
          <Input label="Hora" type="time" step={900} value={nuevaHora} onChange={(e) => setNuevaHora(e.target.value)} />
        </div>
      </Modal>

      <Modal open={guia} title="Resultados de una gestión: cuándo elegir cada uno" size="lg" onClose={() => setGuia(false)}>
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-line text-left text-xs font-semibold text-ink-soft uppercase">
              <th className="py-2 pr-3">Resultado</th>
              <th className="py-2">¿Cuándo seleccionarlo?</th>
            </tr>
          </thead>
          <tbody>
            {(catalogo?.resultados ?? []).map((r) => (
              <tr key={r.clave} className="border-b border-line last:border-0">
                <td className="py-2 pr-3 align-top">
                  <EtiquetaResultado tono={r.tono} texto={r.etiqueta} />
                </td>
                <td className="py-2 text-ink-muted">{r.cuando}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Modal>
    </div>
  )
}
