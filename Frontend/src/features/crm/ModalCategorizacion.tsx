import { useCallback, useEffect, useState } from 'react'
import { Calculator, CalendarDays, Save } from 'lucide-react'
import { Alert, Button, Input, Modal, Select, Tabs, useConfirmacion, useToast } from '../../components/ui'
import { ApiError } from '../../lib/apiClient'
import { fechaCorta } from '../../lib/fechas'
import { ACCION, usePermisos } from '../../lib/permisos'
import { CategoriaBadge } from './CategoriaBadge'
import { categorizacionApi } from './categorizacionApi'
import type { Categorizacion, CicloCategorizacion, ColorCategoria } from './categorizacionApi'
import { CICLOS, COLORES_CATEGORIA, diaSiguiente } from './formato'

const SUBMODULO = 'crm.categorizacion'

/** Una categoría mientras se edita: el monto es texto para poder escribirlo sin que se reformatee. */
interface FilaEditable {
  codigo: string
  nombre: string
  color: ColorCategoria
  desde: string
}

interface Formulario {
  ciclo: CicloCategorizacion
  categorias: FilaEditable[]
}

const aFormulario = (c: Categorizacion): Formulario => ({
  ciclo: c.ciclo,
  categorias: c.categorias.map((x) => ({ codigo: x.codigo, nombre: x.nombre, color: x.color, desde: String(x.desde) })),
})

/** Cómo se llama lo que se evalúa en cada ciclo, para explicarlo a quien solo mira. */
const PERIODO: Record<CicloCategorizacion, { evalua: string; renueva: string }> = {
  MENSUAL: { evalua: 'último mes cerrado', renueva: 'cada mes' },
  TRIMESTRAL: { evalua: 'último trimestre cerrado', renueva: 'cada trimestre' },
  CUATRIMESTRAL: { evalua: 'último cuatrimestre cerrado', renueva: 'cada cuatrimestre' },
  ANUAL: { evalua: 'últimos doce meses cerrados', renueva: 'cada mes' },
}

const monto = (n: number) => n.toLocaleString('es-PE')

/**
 * La categorización de clientes (Socio, Distribuidor, Mayorista...) en una ventana, que se abre desde
 * Clientes y desde el CRM.
 *
 * Quien tiene Editar ajusta el ciclo y los tramos, y calcula. El resto (el vendedor, por ejemplo) ve lo mismo
 * en modo lectura: sin eso, la categoría de sus clientes sería una letra sin significado.
 *
 * Las fechas de cada ciclo las calcula el servidor (periodos): la pantalla solo muestra la del ciclo elegido.
 * "Calcular ahora" guarda primero lo que se ve, porque el cálculo usa lo guardado.
 */
export function ModalCategorizacion({
  open,
  onClose,
  onCambio,
}: {
  open: boolean
  onClose: () => void
  /** Se recalcularon las categorías: la pantalla de atrás las vuelve a pedir. */
  onCambio?: () => void
}) {
  const toast = useToast()
  const { confirmar, dialogo } = useConfirmacion()
  const { puede } = usePermisos()
  const puedeEditar = puede(SUBMODULO, ACCION.editar)

  const [datos, setDatos] = useState<Categorizacion | null>(null)
  const [form, setForm] = useState<Formulario | null>(null)
  const [error, setError] = useState('')
  const [guardando, setGuardando] = useState(false)
  const [calculando, setCalculando] = useState(false)

  const cargar = useCallback(async () => {
    try {
      const config = await categorizacionApi.obtener()
      setDatos(config)
      setForm(aFormulario(config))
      setError('')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'No pudimos cargar las categorías.')
    }
  }, [])

  // Cada vez que se abre se vuelve a pedir: lo que quedó a medias al cerrar no debe reaparecer.
  useEffect(() => {
    if (open) void cargar()
  }, [open, cargar])

  if (!open) return null

  const periodo = form && datos ? datos.periodos[form.ciclo] : null
  const texto = form ? PERIODO[form.ciclo] : PERIODO.TRIMESTRAL

  const cambiar = (indice: number, cambios: Partial<FilaEditable>) =>
    setForm((f) => (f ? { ...f, categorias: f.categorias.map((c, i) => (i === indice ? { ...c, ...cambios } : c)) } : f))

  /** Valida y guarda lo que se ve. Devuelve lo guardado, o null si no se pudo. */
  const persistir = async (): Promise<Categorizacion | null> => {
    if (!form) return null

    const montos = form.categorias.map((c) => Number(c.desde))
    if (montos.some((m) => !Number.isFinite(m) || m < 0)) {
      toast.error('Los montos tienen que ser números desde 0.')
      return null
    }
    if (form.categorias.some((c) => !c.nombre.trim())) {
      toast.error('Toda categoría necesita un nombre.')
      return null
    }

    try {
      const guardado = await categorizacionApi.guardar({
        ciclo: form.ciclo,
        categorias: form.categorias.map((c, i) => ({
          codigo: c.codigo,
          nombre: c.nombre.trim(),
          color: c.color,
          desde: montos[i],
        })),
      })
      setDatos(guardado)
      setForm(aFormulario(guardado))
      return guardado
    } catch (e) {
      toast.error(e instanceof ApiError ? e.message : 'No pudimos guardar la configuración.')
      return null
    }
  }

  const guardar = async () => {
    setGuardando(true)
    const guardado = await persistir()
    setGuardando(false)
    if (!guardado) return

    toast.exito(
      guardado.recalculado
        ? `Configuración guardada: las categorías se recalcularon con el ciclo ${CICLOS.find((c) => c.id === guardado.ciclo)?.label.toLowerCase()}.`
        : 'Configuración guardada.',
    )
    if (guardado.recalculado) onCambio?.()
    onClose()
  }

  const calcularAhora = () =>
    confirmar({
      titulo: '¿Calcular las categorías ahora?',
      mensaje:
        'Guarda estos montos y asigna a cada cliente su categoría según lo comprado en el último ciclo cerrado.',
      confirmar: 'Calcular',
      tono: 'pregunta',
      accion: async () => {
        setCalculando(true)
        try {
          const guardado = await persistir()
          if (!guardado) return

          // Si el ciclo cambió, guardar ya recalculó: calcular otra vez sería repetir lo mismo.
          const calculado = guardado.recalculado ? guardado : await categorizacionApi.calcular()
          setDatos(calculado)
          setForm(aFormulario(calculado))

          const v = calculado.vigente?.ventana
          toast.exito(
            v
              ? `Categorías calculadas con lo comprado del ${fechaCorta(v.evaluadoDesde)} al ${fechaCorta(v.evaluadoHasta)} (${calculado.vigente?.clientes ?? 0} clientes).`
              : 'Categorías calculadas.',
          )
          onCambio?.()
        } catch (e) {
          toast.error(e instanceof ApiError ? e.message : 'No pudimos calcular las categorías.')
        } finally {
          setCalculando(false)
        }
      },
    })

  return (
    <Modal
      open
      size="xl"
      title={puedeEditar ? 'Categorización de clientes' : 'Categorías de clientes'}
      onClose={onClose}
      footer={
        <div className="flex w-full flex-wrap items-center justify-between gap-3">
          <p className="text-xs text-ink-soft">Los montos están expresados en soles, con IGV y sin ventas anuladas.</p>
          {puedeEditar && (
            <div className="flex flex-wrap gap-2">
              <Button variant="secondary" loading={calculando} disabled={guardando} onClick={calcularAhora}>
                <Calculator size={16} /> Calcular ahora
              </Button>
              <Button loading={guardando} disabled={calculando} onClick={guardar}>
                <Save size={16} /> Guardar configuración
              </Button>
            </div>
          )}
        </div>
      }
    >
      {error && <Alert>{error}</Alert>}
      {!form && !error && <p className="py-10 text-center text-sm text-ink-soft">Cargando categorías...</p>}

      {form && datos && (
        <div className="space-y-4">
          {puedeEditar ? (
            <>
              <div>
                <p className="mb-1.5 text-xs font-semibold tracking-wide text-ink-soft uppercase">
                  Ciclo de actualización
                </p>
                <Tabs
                  items={CICLOS.map((c) => ({ id: c.id, label: c.label }))}
                  active={form.ciclo}
                  onChange={(id) => setForm({ ...form, ciclo: id as CicloCategorizacion })}
                />
              </div>

              {/* La categoría sale del último período CERRADO, no del que está corriendo. */}
              <div className="grid gap-3 sm:grid-cols-2">
                <div className="rounded-field border border-line px-3 py-2.5">
                  <p className="text-xs font-semibold tracking-wide text-ink-soft uppercase">
                    Compras evaluadas ({CICLOS.find((c) => c.id === form.ciclo)?.label.toLowerCase()})
                  </p>
                  <p className="mt-0.5 font-semibold text-[rgb(var(--sys-ink-rgb))]">
                    {periodo ? `${fechaCorta(periodo.evaluadoDesde)} – ${fechaCorta(periodo.evaluadoHasta)}` : '—'}
                  </p>
                </div>
                <div className="rounded-field border border-line px-3 py-2.5">
                  <p className="text-xs font-semibold tracking-wide text-ink-soft uppercase">
                    Fecha en que cambiará el resultado
                  </p>
                  <p className="mt-0.5 flex flex-wrap items-baseline gap-2 font-semibold">
                    <CalendarDays size={15} className="self-center text-[rgb(var(--sys-ink-rgb))]" />
                    {periodo ? fechaCorta(diaSiguiente(periodo.vigenteHasta)) : '—'}
                    <span className="text-xs font-normal text-ink-soft">
                      El actual rige desde el {periodo ? fechaCorta(periodo.vigenteDesde) : '—'}
                    </span>
                  </p>
                </div>
              </div>
            </>
          ) : (
            <p className="text-sm text-ink-muted">
              Cada cliente recibe una categoría según el monto total de sus compras durante el {texto.evalua}. La
              categoría se actualiza automáticamente {texto.renueva}.
            </p>
          )}

          <div className="overflow-x-auto">
            <table className="w-full min-w-[34rem] text-sm">
              <thead>
                <tr className="border-b border-line text-left text-xs font-semibold tracking-wide text-ink-soft uppercase">
                  <th className="py-2 pr-3">Categoría</th>
                  <th className="px-3 py-2 text-center">Código</th>
                  <th className="px-3 py-2">Desde (S/)</th>
                  <th className="px-3 py-2">Hasta (S/)</th>
                </tr>
              </thead>
              <tbody>
                {form.categorias.map((c, i) => {
                  const arriba = i === 0 ? null : Number(form.categorias[i - 1].desde)
                  const hasta = arriba !== null && Number.isFinite(arriba) ? arriba - 1 : null

                  return (
                    <tr key={c.codigo} className="border-b border-line last:border-0">
                      <td className="py-2 pr-3">
                        {puedeEditar ? (
                          <div className="flex items-center gap-2">
                            <Input
                              aria-label={`Nombre de la categoría ${c.codigo}`}
                              size="sm"
                              value={c.nombre}
                              maxLength={30}
                              onChange={(e) => cambiar(i, { nombre: e.target.value })}
                              className="min-w-36"
                            />
                            <Select
                              aria-label={`Color de la categoría ${c.codigo}`}
                              size="sm"
                              value={c.color}
                              onChange={(e) => cambiar(i, { color: e.target.value as ColorCategoria })}
                              className="max-w-28"
                            >
                              {COLORES_CATEGORIA.map((o) => (
                                <option key={o.id} value={o.id}>
                                  {o.label}
                                </option>
                              ))}
                            </Select>
                          </div>
                        ) : (
                          <CategoriaBadge codigo={c.codigo} nombre={c.nombre} color={c.color} className="min-w-32" />
                        )}
                      </td>
                      <td className="px-3 py-2 text-center font-bold text-ink-muted">{c.codigo}</td>
                      <td className="px-3 py-2">
                        {puedeEditar ? (
                          <Input
                            aria-label={`Monto desde de la categoría ${c.codigo}`}
                            size="sm"
                            inputMode="numeric"
                            value={c.desde}
                            // La última arranca en cero: así nadie queda sin categoría.
                            disabled={i === form.categorias.length - 1}
                            onChange={(e) => cambiar(i, { desde: e.target.value.replace(/[^\d.]/g, '') })}
                          />
                        ) : (
                          <span className="tabular-nums">{monto(Number(c.desde))}</span>
                        )}
                      </td>
                      <td className="px-3 py-2 text-ink-muted tabular-nums">
                        {hasta === null ? <span className="text-ink-soft">A MÁS</span> : monto(hasta)}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>

          {puedeEditar && (
            <p className="text-xs text-ink-soft">
              El «hasta» es lo que falta para llegar a la categoría de arriba: así los tramos nunca dejan huecos ni se
              pisan. Cambiar el ciclo recalcula las categorías al guardar; cambiar los montos, solo al calcular.
            </p>
          )}
        </div>
      )}

      {dialogo}
    </Modal>
  )
}
